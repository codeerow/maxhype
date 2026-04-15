import 'package:flutter/material.dart';
import 'package:flutter_body_atlas/flutter_body_atlas.dart' as atlas;
import 'package:flutter_body_atlas/src/assets.dart' show SvgAsset;
import '../../../models/muscle_group.dart' as app_models;
import '../../../theme/app_theme.dart';

class MiniMuscleAtlas extends StatelessWidget {
  final List<app_models.MuscleGroup> muscleGroups;

  const MiniMuscleAtlas({
    super.key,
    required this.muscleGroups,
  });

  /// Map our MuscleGroup enum to flutter_body_atlas Muscle enum
  List<atlas.Muscle> _mapToAtlasMuscles() {
    final Set<atlas.Muscle> muscles = {};

    for (final group in muscleGroups) {
      switch (group) {
        case app_models.MuscleGroup.chest:
          muscles.addAll([
            atlas.Muscle.pectoralisMajorLeft,
            atlas.Muscle.pectoralisMajorRight,
          ]);
          break;
        case app_models.MuscleGroup.shoulders:
          muscles.addAll([
            atlas.Muscle.anteriorDeltoidLeft,
            atlas.Muscle.anteriorDeltoidRight,
            atlas.Muscle.lateralDeltoidLeft,
            atlas.Muscle.lateralDeltoidRight,
            atlas.Muscle.posteriorDeltoidLeft,
            atlas.Muscle.posteriorDeltoidRight,
          ]);
          break;
        case app_models.MuscleGroup.triceps:
          muscles.addAll([
            atlas.Muscle.tricepsBrachiiCaputLateraleLeft,
            atlas.Muscle.tricepsBrachiiCaputLateraleRight,
            atlas.Muscle.tricepsBrachiiCaputLongumLeft,
            atlas.Muscle.tricepsBrachiiCaputLongumRight,
            atlas.Muscle.tricepsBrachiiCaputMedialeLeft,
            atlas.Muscle.tricepsBrachiiCaputMedialeRight,
          ]);
          break;
        case app_models.MuscleGroup.back:
          muscles.addAll([
            atlas.Muscle.latissimusDorsiLeft,
            atlas.Muscle.latissimusDorsiRight,
            atlas.Muscle.trapeziusUpperLeft,
            atlas.Muscle.trapeziusUpperRight,
            atlas.Muscle.trapeziusMiddleLeft,
            atlas.Muscle.trapeziusMiddleRight,
          ]);
          break;
        case app_models.MuscleGroup.biceps:
          muscles.addAll([
            atlas.Muscle.bicepsBrachiiCaputBreveLeft,
            atlas.Muscle.bicepsBrachiiCaputBreveRight,
            atlas.Muscle.bicepsBrachiiCaputLongumLeft,
            atlas.Muscle.bicepsBrachiiCaputLongumRight,
          ]);
          break;
        case app_models.MuscleGroup.forearms:
          muscles.addAll([
            atlas.Muscle.brachioradialisLeft,
            atlas.Muscle.brachioradialisRight,
          ]);
          break;
        case app_models.MuscleGroup.quads:
          muscles.addAll([
            atlas.Muscle.rectusFemorisLeft,
            atlas.Muscle.rectusFemorisRight,
            atlas.Muscle.vastusLateralisLeft,
            atlas.Muscle.vastusLateralisRight,
            atlas.Muscle.vastusMedialisLeft,
            atlas.Muscle.vastusMedialisRight,
          ]);
          break;
        case app_models.MuscleGroup.hamstrings:
          muscles.addAll([
            atlas.Muscle.bicepsFemorisLeft,
            atlas.Muscle.bicepsFemorisRight,
            atlas.Muscle.semitendinosusLeft,
            atlas.Muscle.semitendinosusRight,
            atlas.Muscle.semimembranosus1Left,
            atlas.Muscle.semimembranosus1Right,
          ]);
          break;
        case app_models.MuscleGroup.glutes:
          muscles.addAll([
            atlas.Muscle.gluteusMaximusLeft,
            atlas.Muscle.gluteusMaximusRight,
            atlas.Muscle.gluteusMedius1Left,
            atlas.Muscle.gluteusMedius1Right,
          ]);
          break;
        case app_models.MuscleGroup.calves:
          muscles.addAll([
            atlas.Muscle.gastrocnemiusLeft,
            atlas.Muscle.gastrocnemiusRight,
          ]);
          break;
        case app_models.MuscleGroup.abs:
          muscles.addAll([
            atlas.Muscle.rectusAbdominis1,
            atlas.Muscle.rectusAbdominis2Left,
            atlas.Muscle.rectusAbdominis2Right,
            atlas.Muscle.rectusAbdominis3Left,
            atlas.Muscle.rectusAbdominis3Right,
          ]);
          break;
        case app_models.MuscleGroup.obliques:
          muscles.addAll([
            atlas.Muscle.externalObliqueLeft,
            atlas.Muscle.externalObliqueRight,
          ]);
          break;
        case app_models.MuscleGroup.lowerBack:
          muscles.addAll([
            atlas.Muscle.trapeziusLowerLeft,
            atlas.Muscle.trapeziusLowerRight,
          ]);
          break;
      }
    }

    return muscles.toList();
  }

  @override
  Widget build(BuildContext context) {
    final atlasMuscles = _mapToAtlasMuscles();

    // Create color mapping by muscle ID strings
    final highlightedColors = {
      for (final muscle in atlasMuscles)
        muscle.id: AppTheme.primaryOrange.withOpacity(0.8),
    };

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.primaryOrange.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: SvgAsset(
          path: atlas.AtlasAsset.musclesFront.path,
          highlightedColors: highlightedColors,
          defaultHoverColor: AppTheme.textSecondary.withOpacity(0.2),
        ),
      ),
    );
  }
}
