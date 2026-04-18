import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_body_atlas/flutter_body_atlas.dart' as atlas;
import 'package:flutter_svg/flutter_svg.dart';
import '../../../models/muscle_group.dart' as app_models;
import '../../../theme/app_theme.dart';

/// Pre-loaded SVG strings cached statically to avoid repeated asset loading.
class _SvgCache {
  static String? _frontSvg;
  static String? _backSvg;
  static Future<void>? _loadingFuture;

  static Future<void> ensureLoaded() {
    _loadingFuture ??= _load();
    return _loadingFuture!;
  }

  static Future<void> _load() async {
    final results = await Future.wait([
      rootBundle.loadString('packages/flutter_body_atlas/assets/svg/muscle_layer_front.svg'),
      rootBundle.loadString('packages/flutter_body_atlas/assets/svg/muscle_layer_back.svg'),
    ]);
    _frontSvg = results[0];
    _backSvg = results[1];
  }

  static String? get frontSvg => _frontSvg;
  static String? get backSvg => _backSvg;
  static bool get isLoaded => _frontSvg != null && _backSvg != null;
}

/// ColorMapper with proper equality so flutter_svg can cache parsed results.
class _MuscleColorMapper extends ColorMapper {
  final Map<String, Color> highlightedColors;
  final Color defaultColor;

  const _MuscleColorMapper({
    required this.highlightedColors,
    required this.defaultColor,
  });

  @override
  Color substitute(String? id, String elementName, String attributeName, Color color) {
    if (id == null) return color;
    return highlightedColors[id] ?? color;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _MuscleColorMapper &&
          const MapEquality<String, Color>().equals(highlightedColors, other.highlightedColors) &&
          defaultColor == other.defaultColor;

  @override
  int get hashCode => Object.hash(
        const MapEquality<String, Color>().hash(highlightedColors),
        defaultColor,
      );
}

class MiniMuscleAtlas extends StatefulWidget {
  final List<app_models.MuscleGroup> muscleGroups;

  const MiniMuscleAtlas({
    super.key,
    required this.muscleGroups,
  });

  @override
  State<MiniMuscleAtlas> createState() => _MiniMuscleAtlasState();
}

class _MiniMuscleAtlasState extends State<MiniMuscleAtlas> {
  bool _svgReady = false;

  @override
  void initState() {
    super.initState();
    _svgReady = _SvgCache.isLoaded;
    if (!_svgReady) {
      _SvgCache.ensureLoaded().then((_) {
        if (mounted) setState(() => _svgReady = true);
      });
    }
  }

  /// Map our MuscleGroup enum to flutter_body_atlas Muscle enum
  List<atlas.Muscle> _mapToAtlasMuscles() {
    final Set<atlas.Muscle> muscles = {};

    for (final group in widget.muscleGroups) {
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
    if (widget.muscleGroups.isEmpty) return false;

    final primaryGroup = widget.muscleGroups.first;

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
    if (widget.muscleGroups.isEmpty) {
      return (alignment: Alignment.center, scale: 1.0);
    }

    final primaryGroup = widget.muscleGroups.first;

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
    final zoomSettings = _getZoomSettings();

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.primaryOrange.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: _svgReady
            ? _buildSvg(zoomSettings)
            : Container(
                color: AppTheme.primaryOrange.withValues(alpha: 0.15),
                child: const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppTheme.primaryOrange,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSvg(({Alignment alignment, double scale}) zoomSettings) {
    final atlasMuscles = _mapToAtlasMuscles();
    final showBackView = _shouldShowBackView();
    final svgString = showBackView ? _SvgCache.backSvg! : _SvgCache.frontSvg!;

    final highlightedColors = {
      for (final muscle in atlasMuscles)
        muscle.id: AppTheme.primaryOrange.withValues(alpha: 0.8),
    };

    return Transform.scale(
      scale: zoomSettings.scale,
      alignment: zoomSettings.alignment,
      child: SvgPicture.string(
        svgString,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        colorMapper: _MuscleColorMapper(
          highlightedColors: highlightedColors,
          defaultColor: AppTheme.textSecondary.withValues(alpha: 0.2),
        ),
      ),
    );
  }
}
