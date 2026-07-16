import 'package:flutter/material.dart';

import '../../core/service_locator.dart';
import '../../models/generator/experience_level.dart';
import '../../models/generator/fitness_plan.dart';
import '../../models/generator/split_type.dart';
import '../../repositories/fitness_plan_repository.dart';
import '../../repositories/generated_workout_repository.dart';
import '../../repositories/workout_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_toast.dart';
import 'plan_option_screen.dart';

/// Minimal fitness-plan configuration surface (Phase 4 Part 2A deliverable
/// "configure my fitness plan"). Edits the persisted [FitnessPlan] and, on
/// save, regenerates the home workouts so duration/experience/day changes are
/// immediately reflected.
///
/// Split is fixed to PPL for 2A (the only generator-supported split); the other
/// splits are shown disabled so the architecture is visible but can't be
/// selected until their generators land.
///
/// Layout mirrors the MaxHype web prototype's Fitness Plan screen: a single
/// uniform dark-navy background, lighter-navy section cards, muted uppercase
/// section labels on the dark navy between them, and an orange circular back
/// arrow. Each field is a `Title → value ›` menu row that opens a full-screen
/// picker ([PlanOptionScreen]) — the same "tap a row, choose on a sub-screen"
/// flow as the web app. No generator logic is touched.
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  FitnessPlan? _plan;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final plan = await getIt<FitnessPlanRepository>().load();
    if (mounted) setState(() => _plan = plan);
  }

  Future<void> _save() async {
    final plan = _plan;
    if (plan == null) return;
    setState(() => _saving = true);
    await getIt<FitnessPlanRepository>().save(plan);
    // Rebuild the home cards from the new plan.
    final repo = getIt<WorkoutRepository>();
    if (repo is GeneratedWorkoutRepository) {
      await repo.regenerate();
    }
    if (!mounted) return;
    setState(() => _saving = false);
    AppToast.showPremium(context, 'Plan saved — workouts regenerated');
  }

  void _update(FitnessPlan next) => setState(() => _plan = next);

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    return Scaffold(
      backgroundColor: AppTheme.planBackground,
      body: SafeArea(
        child: plan == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                children: [
                  _title(context),
                  const SizedBox(height: 12),
                  // ---- ROUTINE ----
                  _sectionLabel('Routine'),
                  _card([
                    _menuRow(
                      title: 'Routine',
                      value: plan.split.displayName,
                      onTap: () => _pickSplit(plan),
                    ),
                  ]),
                  // ---- WORKOUT STRUCTURE ----
                  _sectionLabel('Workout Structure'),
                  _card([
                    _menuRow(
                      title: 'Days per week',
                      value: '${plan.daysPerWeek} days/week',
                      onTap: () => _pickDays(plan),
                    ),
                    _menuRow(
                      title: 'Workout duration',
                      value: '${plan.durationMinutes} min',
                      onTap: () => _pickDuration(plan),
                    ),
                    _menuRow(
                      title: 'Experience',
                      value: plan.experience.displayName,
                      onTap: () => _pickExperience(plan),
                    ),
                    _menuRow(
                      title: 'Weight Unit',
                      value: plan.units.displayName.toUpperCase(),
                      onTap: () => _pickUnits(plan),
                    ),
                  ]),
                  // ---- PROFILE ----
                  _sectionLabel('Profile'),
                  _card([
                    _menuRow(
                      title: 'Sex',
                      value: plan.sex.wireValue,
                      onTap: () => _pickSex(plan),
                    ),
                    _menuRow(
                      title: 'Age',
                      value: '${plan.age}',
                      onTap: () => _pickAge(plan),
                    ),
                    _menuRow(
                      title: 'Weight',
                      value: '${plan.weight.round()} ${plan.units.displayName}',
                      onTap: () => _pickWeight(plan),
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _saveButton(),
                ],
              ),
      ),
    );
  }

  // ---- Pickers (open a full-screen [PlanOptionScreen], apply the result) ----

  Future<void> _pickSplit(FitnessPlan plan) async {
    final result = await PlanOptionScreen.show<SplitType>(
      context,
      title: 'Routine',
      selected: plan.split,
      options: SplitType.values
          .map(
            (s) => PlanOption<SplitType>(
              value: s,
              title: s.displayName,
              enabled: s.isGeneratorSupported,
              comingSoon: !s.isGeneratorSupported,
            ),
          )
          .toList(),
    );
    if (result != null) _update(plan.copyWith(split: result));
  }

  Future<void> _pickDays(FitnessPlan plan) async {
    final result = await PlanOptionScreen.show<int>(
      context,
      title: 'Days per week',
      selected: plan.daysPerWeek,
      options: const [2, 3, 4, 5, 6]
          .map((d) => PlanOption<int>(value: d, title: '$d days per week'))
          .toList(),
    );
    if (result != null) _update(plan.copyWith(daysPerWeek: result));
  }

  Future<void> _pickDuration(FitnessPlan plan) async {
    final result = await PlanOptionScreen.show<int>(
      context,
      title: 'Workout duration',
      selected: plan.durationMinutes,
      options: kSupportedDurations
          .map((m) => PlanOption<int>(value: m, title: '$m minutes'))
          .toList(),
    );
    if (result != null) _update(plan.copyWith(durationMinutes: result));
  }

  Future<void> _pickExperience(FitnessPlan plan) async {
    final result = await PlanOptionScreen.show<ExperienceLevel>(
      context,
      title: 'Experience',
      selected: plan.experience,
      options: ExperienceLevel.values
          .map(
            (e) => PlanOption<ExperienceLevel>(
              value: e,
              title: e.displayName,
            ),
          )
          .toList(),
    );
    if (result != null) _update(plan.copyWith(experience: result));
  }

  Future<void> _pickUnits(FitnessPlan plan) async {
    final result = await PlanOptionScreen.show<WeightUnit>(
      context,
      title: 'Weight Unit',
      selected: plan.units,
      options: WeightUnit.values
          .map(
            (u) => PlanOption<WeightUnit>(
              value: u,
              title: u.displayName.toUpperCase(),
            ),
          )
          .toList(),
    );
    if (result != null) _update(plan.copyWith(units: result));
  }

  Future<void> _pickSex(FitnessPlan plan) async {
    final result = await PlanOptionScreen.show<Sex>(
      context,
      title: 'Sex',
      selected: plan.sex,
      options: Sex.values
          .map((s) => PlanOption<Sex>(value: s, title: s.wireValue))
          .toList(),
    );
    if (result != null) _update(plan.copyWith(sex: result));
  }

  Future<void> _pickAge(FitnessPlan plan) async {
    final result = await PlanOptionScreen.show<int>(
      context,
      title: 'Age',
      selected: plan.age,
      options: [
        for (var age = 14; age <= 90; age++)
          PlanOption<int>(value: age, title: '$age'),
      ],
    );
    if (result != null) _update(plan.copyWith(age: result));
  }

  Future<void> _pickWeight(FitnessPlan plan) async {
    final unit = plan.units.displayName;
    final current = plan.weight.round();
    // Snap the current weight onto the 5-step grid so it can be pre-selected.
    final snapped = (current / 5).round() * 5;
    final result = await PlanOptionScreen.show<int>(
      context,
      title: 'Weight ($unit)',
      selected: snapped.clamp(30, 400),
      options: [
        for (var w = 30; w <= 400; w += 5)
          PlanOption<int>(value: w, title: '$w $unit'),
      ],
    );
    if (result != null) _update(plan.copyWith(weight: result.toDouble()));
  }

  Widget _title(BuildContext context) => Text(
    'Fitness Plan',
    style: Theme.of(context).textTheme.headlineMedium,
  );

  // ---- Section scaffolding (label on dark navy + lighter navy card) --------

  Widget _sectionLabel(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 26, 4, 12),
    child: Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: AppTheme.planSectionLabel,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.6,
      ),
    ),
  );

  Widget _card(List<Widget> rows) {
    const radius = BorderRadius.all(Radius.circular(20));
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: AppTheme.planCardBorder),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: ColoredBox(
          color: AppTheme.planCardBackground,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0x0FFFFFFF), // white @ 6%
                  ),
                rows[i],
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// A `Title → value ›` menu row that opens a picker on tap.
  Widget _menuRow({
    required String title,
    required String value,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.chevron_right,
            color: Color(0x33FFFFFF), // white @ 20%
            size: 22,
          ),
        ],
      ),
    ),
  );

  Widget _saveButton() => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: _saving ? null : _save,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryOrange,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _saving
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text(
              'Save & Regenerate',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
    ),
  );
}
