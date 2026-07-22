import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../models/exercise.dart';
import 'exercise_options_sheet.dart';
import 'replace_exercise_sheet.dart';

/// Push the Replace Exercise screen and return the user's selection
/// (`null` if they backed out).
///
/// [usedNames] are the other exercises already in the workout, excluded from
/// the replacement pool so a swap can't duplicate an existing pick (mirrors the
/// prototype's picker).
Future<Exercise?> pickReplacementExercise(
  BuildContext context, {
  required Exercise currentExercise,
  Set<String> usedNames = const {},
}) {
  final completer = Completer<Exercise?>();
  Navigator.of(context)
      .push<void>(
        CupertinoPageRoute<void>(
          builder: (_) => ReplaceExerciseSheet(
            currentExercise: currentExercise,
            usedNames: usedNames,
            onExerciseSelected: (newExercise) {
              if (!completer.isCompleted) completer.complete(newExercise);
            },
          ),
        ),
      )
      .then((_) {
        if (!completer.isCompleted) completer.complete(null);
      });
  return completer.future;
}

/// Open the exercise options bottom sheet (Replace / Favorite / Exclude).
/// `onReplace` is invoked when the user picks a replacement exercise.
///
/// [usedNames] are the other exercises in the workout, so they're excluded from
/// the replacement candidates.
Future<void> showExerciseOptionsSheet(
  BuildContext context, {
  required Exercise exercise,
  required void Function(Exercise newExercise) onReplace,
  Set<String> usedNames = const {},
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => ExerciseOptionsSheet(
      exercise: exercise,
      onReplaceExercise: () async {
        final picked = await pickReplacementExercise(
          context,
          currentExercise: exercise,
          usedNames: usedNames,
        );
        if (picked != null) onReplace(picked);
      },
    ),
  );
}
