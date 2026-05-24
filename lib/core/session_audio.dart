import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// Foreground rest-timer bell. `WorkoutSessionBloc` depends on this
/// interface rather than [SessionAudio] directly so tests can supply a
/// fake bell that records rings without touching the audio plugin.
// ignore: one_member_abstracts
abstract class RestBell {
  Future<void> playRestComplete();
}

/// Plays the boxing-bell sound from inside the app while the user is on
/// a session screen. Used by `WorkoutSessionBloc` as the foreground bell
/// source — `RestTimerNotifications` plays the same sample when the app
/// is backgrounded.
class SessionAudio implements RestBell {
  SessionAudio._();
  static final instance = SessionAudio._();

  // One long-lived player. Spawning a fresh AudioPlayer per ring is
  // unreliable: the native side disposes asynchronously and a quick
  // second ring can race the previous instance's teardown, producing
  // silence on Android. A single player kept in ReleaseMode.stop holds
  // the asset loaded between rings and replays it deterministically.
  AudioPlayer? _player;
  Future<void>? _ready;

  Future<void> _ensureReady() {
    return _ready ??= _initPlayer();
  }

  Future<void> _initPlayer() async {
    final p = AudioPlayer();
    await p.setReleaseMode(ReleaseMode.stop);
    // Route through the alarm stream on Android (matches the notification
    // channel's USAGE_ALARM so the bell respects the alarm volume slider
    // and plays through Do-Not-Disturb) and use the playback category on
    // iOS so the sample is audible even when the ringer switch is on
    // silent.
    await p.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.alarm,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {
            AVAudioSessionOptions.mixWithOthers,
            AVAudioSessionOptions.duckOthers,
          },
        ),
      ),
    );
    await p.setSource(AssetSource('audio/boxing_bell.mp3'));
    _player = p;
  }

  @override
  Future<void> playRestComplete() async {
    try {
      await _ensureReady();
      final p = _player;
      if (p == null) return;
      // stop() returns the player to the initial state; the source stays
      // loaded thanks to ReleaseMode.stop. seek+resume guarantees we
      // start from frame zero on every ring even if the previous play
      // was interrupted mid-sample.
      await p.stop();
      await p.seek(Duration.zero);
      await p.resume();
    } on Object {
      // Reset so the next call retries from scratch instead of being
      // stuck on a broken player.
      final dead = _player;
      _player = null;
      _ready = null;
      await dead?.dispose();
    }
  }
}
