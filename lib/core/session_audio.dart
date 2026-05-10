import 'package:audioplayers/audioplayers.dart';

/// Foreground-only audio for workout session.
///
/// Part 1 scope: plays the boxing-bell on rest-timer completion **only when the
/// app is in the foreground**. Part 2 will add background notifications, a
/// foreground service on Android, and exact alarms — none of that is here.
///
/// The bell asset is loaded from `assets/audio/boxing_bell.mp3` (a tri-bell
/// "3 short rings" sample). If the asset is missing or the platform isn't
/// ready, playback is silently skipped so the app still builds and runs.
class SessionAudio {
  SessionAudio._();
  static final instance = SessionAudio._();

  final AudioPlayer _player = AudioPlayer();
  bool _disabled = false;

  Future<void> playRestComplete() async {
    if (_disabled) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('audio/boxing_bell.mp3'));
    } catch (_) {
      // Asset missing or platform not ready — disable for the rest of the
      // session so we don't spam the log.
      _disabled = true;
    }
  }

  Future<void> dispose() async => _player.dispose();
}
