// Replacing an exercise from the preview screen's three-dot menu has
// to remove the preview draft for the *old* exerciseId. Otherwise the
// obsolete draft would ride into the next StartSession via
// previewDrafts and the live session would carry rows for an exercise
// the workout no longer contains.

import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/session/session_set.dart';
import 'package:maxhype/screens/workout_detail/bloc/workout_preview_bloc.dart';

void main() {
  test(
      'dropDraft removes only the named exercise — other drafts in the '
      'preview cubit are left alone', () {
    final bloc = WorkoutPreviewBloc();

    bloc.seedEffectiveSets('ex_old', 3);
    bloc.addRow('ex_old', SetKind.warmup);
    bloc.seedEffectiveSets('ex_other', 2);

    expect(bloc.state.drafts.keys, containsAll(['ex_old', 'ex_other']));

    bloc.dropDraft('ex_old');

    expect(bloc.state.drafts.containsKey('ex_old'), isFalse,
        reason: 'obsolete draft must not survive the replacement');
    expect(bloc.state.drafts.containsKey('ex_other'), isTrue,
        reason: 'other drafts are independent of the replaced one');
  });

  test('dropDraft on an unknown id is a safe no-op', () {
    final bloc = WorkoutPreviewBloc();
    bloc.seedEffectiveSets('ex1', 2);
    expect(() => bloc.dropDraft('mystery'), returnsNormally);
    expect(bloc.state.drafts.containsKey('ex1'), isTrue);
  });
}
