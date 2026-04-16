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

  /// Determine if we should show back view based on muscle group
  bool _shouldShowBackView() {
    if (muscleGroups.isEmpty) return false;

    final primaryGroup = muscleGroups.first;

    switch (primaryGroup) {
      case app_models.MuscleGroup.back:
      case app_models.MuscleGroup.lowerBack:
      case app_models.MuscleGroup.triceps:
      case app_models.MuscleGroup.hamstrings:
      case app_models.MuscleGroup.glutes:
      case app_models.MuscleGroup.calves:
        return true;
      case app_models.MuscleGroup.chest:
      case app_models.MuscleGroup.shoulders:
      case app_models.MuscleGroup.biceps:
      case app_models.MuscleGroup.forearms:
      case app_models.MuscleGroup.quads:
      case app_models.MuscleGroup.abs:
      case app_models.MuscleGroup.obliques:
        return false;
    }
  }

  /// Get the appropriate body region and zoom level based on muscle groups
  ({Alignment alignment, double scale}) _getZoomSettings() {
    if (muscleGroups.isEmpty) {
      return (alignment: Alignment.center, scale: 1.0);
    }

    final primaryGroup = muscleGroups.first;

    switch (primaryGroup) {
      // Upper body - zoom to chest/shoulders area
      case app_models.MuscleGroup.chest:
      case app_models.MuscleGroup.shoulders:
        return (alignment: Alignment(0, -0.35), scale: 2.2);

      // Arms - zoom to upper body with arms
      case app_models.MuscleGroup.triceps:
      case app_models.MuscleGroup.biceps:
      case app_models.MuscleGroup.forearms:
        return (alignment: Alignment(0, -0.2), scale: 2.0);

      // Back - zoom to torso
      case app_models.MuscleGroup.back:
      case app_models.MuscleGroup.lowerBack:
        return (alignment: Alignment(0, -0.15), scale: 1.9);

      // Core - zoom to midsection
      case app_models.MuscleGroup.abs:
      case app_models.MuscleGroup.obliques:
        return (alignment: Alignment(0, 0.1), scale: 2.1);

      // Legs - zoom to lower body
      case app_models.MuscleGroup.quads:
      case app_models.MuscleGroup.hamstrings:
      case app_models.MuscleGroup.glutes:
        return (alignment: Alignment(0, 0.4), scale: 1.9);

      // Calves - zoom to lower legs
      case app_models.MuscleGroup.calves:
        return (alignment: Alignment(0, 0.65), scale: 2.4);
    }
  }

  @override
  Widget build(BuildContext context) {
    final atlasMuscles = _mapToAtlasMuscles();
    final zoomSettings = _getZoomSettings();
    final showBackView = _shouldShowBackView();

    // Create color mapping by muscle ID strings
    final highlightedColors = {
      for (final muscle in atlasMuscles)
        muscle.id: AppTheme.primaryOrange.withOpacity(0.8),
    };

    // Choose front or back view
    final atlasAsset = showBackView
        ? atlas.AtlasAsset.musclesBack
        : atlas.AtlasAsset.musclesFront;

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
        child: Transform.scale(
          scale: zoomSettings.scale,
          alignment: zoomSettings.alignment,
          child: SvgAsset(
            path: atlasAsset.path,
            highlightedColors: highlightedColors,
            defaultHoverColor: AppTheme.textSecondary.withOpacity(0.2),
          ),
        ),
      ),
    );
  }
}
