import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/demo_clock.dart';
import '../../core/service_locator.dart';
import '../../models/generator/experience_level.dart';
import '../../models/generator/fitness_plan.dart';
import '../../models/generator/split_type.dart';
import '../../repositories/fitness_plan_repository.dart';
import '../../repositories/generated_workout_repository.dart';
import '../../repositories/workout_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/tap_scale.dart';
import 'plan_option_screen.dart';
import 'workout_duration_screen.dart';

/// Minimal fitness-plan configuration surface (Phase 4 Part 2A deliverable
/// "configure my fitness plan"). Edits the persisted [FitnessPlan]; each change
/// is applied immediately — there is no explicit save step. Picking a new value
/// auto-saves the plan and regenerates the home workouts so
/// duration/experience/day changes are reflected right away.
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final plan = await getIt<FitnessPlanRepository>().load();
    if (mounted) setState(() => _plan = plan);
  }

  /// Applies a settings change immediately: updates the UI, persists the plan,
  /// and regenerates the home workouts. There is no explicit save step — every
  /// picker funnels through here, so each edit auto-saves and regenerates.
  Future<void> _update(
    FitnessPlan next, {
    String toast = 'Plan updated — workouts regenerated',
  }) async {
    setState(() => _plan = next);
    await getIt<FitnessPlanRepository>().save(next);
    // Rebuild the home cards from the new plan.
    final repo = getIt<WorkoutRepository>();
    if (repo is GeneratedWorkoutRepository) {
      await repo.regenerate();
    }
    if (!mounted) return;
    AppToast.showPremium(context, toast);
  }

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
                      title: 'Weekly Goal',
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
                    // Weight Unit is a straight KG ↔ LB toggle: tapping the row
                    // flips the unit in place, no picker sub-screen.
                    _menuRow(
                      title: 'Weight Unit',
                      value: plan.units.displayName.toUpperCase(),
                      onTap: () => _toggleUnits(plan),
                      showChevron: false,
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
                  const SizedBox(height: 28),
                  // Debug-only: fast-forward the app's week to demo the
                  // "Completed this week" lock + rotation memory without
                  // touching the device clock. Compiled out of release builds.
                  if (kDebugMode && getIt<WeekClock>() is DemoWeekClock) ...[
                    _sectionLabel('Demo (debug only)'),
                    _demoWeekCard(),
                  ],
                  const SizedBox(height: 24),
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
    if (result != null) await _update(plan.copyWith(split: result));
  }

  Future<void> _pickDays(FitnessPlan plan) async {
    final result = await PlanOptionScreen.show<int>(
      context,
      title: 'Weekly Goal',
      selected: plan.daysPerWeek,
      options: const [2, 3, 4, 5, 6]
          .map((d) => PlanOption<int>(value: d, title: '$d days per week'))
          .toList(),
    );
    if (result != null) await _update(plan.copyWith(daysPerWeek: result));
  }

  Future<void> _pickDuration(FitnessPlan plan) async {
    final result = await WorkoutDurationScreen.show(
      context,
      selected: plan.durationMinutes,
      options: kSupportedDurations,
    );
    if (result != null) await _update(plan.copyWith(durationMinutes: result));
  }

  Future<void> _pickExperience(FitnessPlan plan) async {
    final result = await PlanOptionScreen.show<ExperienceLevel>(
      context,
      // Picker sub-screen title; the menu-row label stays 'Experience'.
      title: 'Fitness Experience',
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
    if (result != null) await _update(plan.copyWith(experience: result));
  }

  /// Flips the weight unit in place (KG ↔ LB) — no picker sub-screen.
  Future<void> _toggleUnits(FitnessPlan plan) async {
    final next = plan.units == WeightUnit.kg ? WeightUnit.lb : WeightUnit.kg;
    await _update(plan.copyWith(units: next));
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
    if (result != null) await _update(plan.copyWith(sex: result));
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
    if (result != null) await _update(plan.copyWith(age: result));
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
    if (result != null) await _update(plan.copyWith(weight: result.toDouble()));
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
  ///
  /// Uses the app-standard [TapScale] (scale + opacity press, light haptic)
  /// like every other tappable row/card. Deliberately not an [InkWell]: the
  /// card paints an opaque background above the row, so a Material ripple would
  /// render behind that fill and bleed past the card's rounded corners.
  Widget _menuRow({
    required String title,
    required String value,
    required VoidCallback onTap,
    bool showChevron = true,
  }) => TapScale.preset(
    preset: TapScalePreset.surface,
    enableHaptic: true,
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
          if (showChevron) ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: Color(0x33FFFFFF), // white @ 20%
              size: 22,
            ),
          ],
        ],
      ),
    ),
  );

  // ---- Debug: demo week fast-forward ---------------------------------------

  /// Reads the current demo week offset (0 = real time). Only called when the
  /// registered [WeekClock] is a [DemoWeekClock] (debug builds).
  int get _demoWeekOffset => (getIt<WeekClock>() as DemoWeekClock).weekOffset;

  Future<void> _bumpDemoWeeks(int delta) async {
    await (getIt<WeekClock>() as DemoWeekClock).bumpWeeks(delta);
    if (!mounted) return;
    // Rebuild so the label updates; home cards re-read the clock on their next
    // build (returning to Home / RefreshCompletions), reverting stale locks.
    setState(() {});
  }

  Future<void> _resetDemoWeeks() async {
    await (getIt<WeekClock>() as DemoWeekClock).reset();
    if (!mounted) return;
    setState(() {});
  }

  Widget _demoWeekCard() {
    final offset = _demoWeekOffset;
    final label = offset == 0
        ? 'Real time (today)'
        : '+$offset week${offset == 1 ? '' : 's'} ahead';
    return _card([
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Demo week',
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            _demoStepButton(
              icon: Icons.remove,
              onTap: offset > 0 ? () => _bumpDemoWeeks(-1) : null,
            ),
            const SizedBox(width: 10),
            _demoStepButton(
              icon: Icons.add,
              onTap: offset < 12 ? () => _bumpDemoWeeks(1) : null,
            ),
            if (offset > 0) ...[
              const SizedBox(width: 10),
              TapScale.preset(
                preset: TapScalePreset.surface,
                enableHaptic: true,
                onTap: _resetDemoWeeks,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Text(
                    'Reset',
                    style: TextStyle(
                      color: AppTheme.primaryOrange,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ]);
  }

  Widget _demoStepButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) => TapScale.preset(
    preset: TapScalePreset.surface,
    enableHaptic: true,
    onTap: onTap,
    child: Opacity(
      opacity: onTap == null ? 0.35 : 1,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.planBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.planCardBorder),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    ),
  );
}
