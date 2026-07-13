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

/// Minimal fitness-plan configuration surface (Phase 4 Part 2A deliverable
/// "configure my fitness plan"). Edits the persisted [FitnessPlan] and, on
/// save, regenerates the home workouts so duration/experience/day changes are
/// immediately reflected.
///
/// Split is fixed to PPL for 2A (the only generator-supported split); the other
/// splits are shown disabled so the architecture is visible but can't be
/// selected until their generators land.
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
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: plan == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                children: [
                  const Text(
                    'Fitness Plan',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'These settings drive your generated workouts.',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  _splitSection(plan),
                  _section(
                    'Days per week',
                    _segmented<int>(
                      values: const [2, 3, 4, 5, 6],
                      selected: plan.daysPerWeek,
                      label: (v) => '$v',
                      onChanged: (v) =>
                          _update(plan.copyWith(daysPerWeek: v)),
                    ),
                  ),
                  _section(
                    'Workout duration',
                    _segmented<int>(
                      values: kSupportedDurations,
                      selected: plan.durationMinutes,
                      label: (v) => '${v}m',
                      onChanged: (v) =>
                          _update(plan.copyWith(durationMinutes: v)),
                    ),
                  ),
                  _section(
                    'Experience',
                    _wrapChips<ExperienceLevel>(
                      values: ExperienceLevel.values,
                      selected: plan.experience,
                      label: (v) => v.displayName,
                      onChanged: (v) =>
                          _update(plan.copyWith(experience: v)),
                    ),
                  ),
                  _section(
                    'Units',
                    _segmented<WeightUnit>(
                      values: WeightUnit.values,
                      selected: plan.units,
                      label: (v) => v.displayName,
                      onChanged: (v) => _update(plan.copyWith(units: v)),
                    ),
                  ),
                  _section(
                    'Sex',
                    _wrapChips<Sex>(
                      values: Sex.values,
                      selected: plan.sex,
                      label: (v) => v.wireValue,
                      onChanged: (v) => _update(plan.copyWith(sex: v)),
                    ),
                  ),
                  _stepperSection(
                    'Age',
                    plan.age,
                    min: 14,
                    max: 90,
                    onChanged: (v) => _update(plan.copyWith(age: v)),
                  ),
                  _stepperSection(
                    'Weight (${plan.units.displayName})',
                    plan.weight.round(),
                    min: 30,
                    max: 400,
                    step: 5,
                    onChanged: (v) =>
                        _update(plan.copyWith(weight: v.toDouble())),
                  ),
                  const SizedBox(height: 24),
                  _saveButton(),
                ],
              ),
      ),
    );
  }

  Widget _splitSection(FitnessPlan plan) => _section(
        'Split',
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: SplitType.values.map((s) {
            final supported = s.isGeneratorSupported;
            final selected = plan.split == s;
            return _chip(
              label: s.displayName + (supported ? '' : ' (soon)'),
              selected: selected,
              enabled: supported,
              onTap: supported ? () => _update(plan.copyWith(split: s)) : null,
            );
          }).toList(),
        ),
      );

  Widget _section(String title, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );

  Widget _segmented<T>({
    required List<T> values,
    required T selected,
    required String Function(T) label,
    required ValueChanged<T> onChanged,
  }) =>
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: values
            .map((v) => _chip(
                  label: label(v),
                  selected: v == selected,
                  onTap: () => onChanged(v),
                ))
            .toList(),
      );

  Widget _wrapChips<T>({
    required List<T> values,
    required T selected,
    required String Function(T) label,
    required ValueChanged<T> onChanged,
  }) =>
      _segmented(
        values: values,
        selected: selected,
        label: label,
        onChanged: onChanged,
      );

  Widget _chip({
    required String label,
    required bool selected,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryOrange : AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? AppTheme.primaryOrange
                  : AppTheme.textSecondary.withOpacity(0.25),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepperSection(
    String title,
    int value, {
    required int min,
    required int max,
    int step = 1,
    required ValueChanged<int> onChanged,
  }) =>
      _section(
        title,
        Row(
          children: [
            _stepBtn(Icons.remove,
                () => onChanged((value - step).clamp(min, max))),
            const SizedBox(width: 16),
            Text(
              '$value',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 16),
            _stepBtn(Icons.add,
                () => onChanged((value + step).clamp(min, max))),
          ],
        ),
      );

  Widget _stepBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: AppTheme.textSecondary.withOpacity(0.25)),
          ),
          child: Icon(icon, color: AppTheme.textPrimary, size: 20),
        ),
      );

  Widget _saveButton() => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryOrange,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: _saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
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
