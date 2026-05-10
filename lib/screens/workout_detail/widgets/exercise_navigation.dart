import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../models/exercise.dart';
import 'exercise_options_sheet.dart';
import 'replace_exercise_sheet.dart';

/// Push the Replace Exercise screen and return the user's selection
/// (`null` if they backed out).
Future<Exercise?> pickReplacementExercise(
  BuildContext context, {
  required Exercise currentExercise,
}) {
  final completer = Completer<Exercise?>();
  Navigator.of(context)
      .push<void>(
        CupertinoPageRoute(
          builder: (_) => ReplaceExerciseSheet(
            currentExercise: currentExercise,
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
Future<void> showExerciseOptionsSheet(
  BuildContext context, {
  required Exercise exercise,
  required void Function(Exercise newExercise) onReplace,
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
        );
        if (picked != null) onReplace(picked);
      },
    ),
  );
}
