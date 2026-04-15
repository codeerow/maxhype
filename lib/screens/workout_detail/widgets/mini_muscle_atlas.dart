import 'package:flutter/material.dart';
import 'package:flutter_body_atlas/flutter_body_atlas.dart';
import '../../../models/muscle_group.dart';
import '../../../theme/app_theme.dart';

class MiniMuscleAtlas extends StatelessWidget {
  final List<MuscleGroup> muscleGroups;

  const MiniMuscleAtlas({
    super.key,
    required this.muscleGroups,
  });

  /// Map our MuscleGroup enum to flutter_body_atlas Muscle enum
  List<Muscle> _mapToAtlasMuscles() {
    final Set<Muscle> muscles = {};

    for (final group in muscleGroups) {
      switch (group) {
        case MuscleGroup.chest:
          muscles.addAll([
            Muscle.pectoralisMajor,
          ]);
          break;
        case MuscleGroup.shoulders:
          muscles.addAll([
            Muscle.deltoidAnterior,
            Muscle.deltoidLateral,
            Muscle.deltoidPosterior,
          ]);
          break;
        case MuscleGroup.triceps:
          muscles.addAll([
            Muscle.tricepsBrachiiLateralHead,
            Muscle.tricepsBrachiiLongHead,
            Muscle.tricepsBrachiiMedialHead,
          ]);
          break;
        case MuscleGroup.back:
          muscles.addAll([
            Muscle.latissimusDorsi,
            Muscle.trapezius,
          ]);
          break;
        case MuscleGroup.biceps:
          muscles.addAll([
            Muscle.bicepsBrachiiShortHead,
            Muscle.bicepsBrachiiLongHead,
          ]);
          break;
        case MuscleGroup.forearms:
          muscles.addAll([
            Muscle.brachioradialis,
          ]);
          break;
        case MuscleGroup.quads:
          muscles.addAll([
            Muscle.rectusFemoris,
            Muscle.vastusLateralis,
            Muscle.vastusMedialis,
          ]);
          break;
        case MuscleGroup.hamstrings:
          muscles.addAll([
            Muscle.bicepsFemorisLongHead,
            Muscle.bicepsFemorisShortHead,
            Muscle.semitendinosus,
            Muscle.semimembranosus,
          ]);
          break;
        case MuscleGroup.glutes:
          muscles.addAll([
            Muscle.gluteusMaximus,
            Muscle.gluteusMedius,
          ]);
          break;
        case MuscleGroup.calves:
          muscles.addAll([
            Muscle.gastrocnemiusLateralHead,
            Muscle.gastrocnemiusMedialHead,
            Muscle.soleus,
          ]);
          break;
        case MuscleGroup.abs:
          muscles.addAll([
            Muscle.rectusAbdominis,
          ]);
          break;
        case MuscleGroup.obliques:
          muscles.addAll([
            Muscle.obliqueAbdominis,
          ]);
          break;
        case MuscleGroup.lowerBack:
          muscles.addAll([
            Muscle.erectorSpinae,
          ]);
          break;
      }
    }

    return muscles.toList();
  }

  @override
  Widget build(BuildContext context) {
    final atlasMuscles = _mapToAtlasMuscles();

    // Create color mapping for highlighted muscles
    final colorMapping = {
      for (final muscle in atlasMuscles)
        muscle: AppTheme.primaryOrange.withOpacity(0.8),
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
        child: BodyAtlas(
          preset: BodyAtlasPreset.simple,
          side: BodySide.front,
          colorMapping: colorMapping,
          defaultMuscleColor: AppTheme.textSecondary.withOpacity(0.2),
          strokeColor: AppTheme.cardBackground,
          strokeWidth: 0.5,
        ),
      ),
    );
  }
}
