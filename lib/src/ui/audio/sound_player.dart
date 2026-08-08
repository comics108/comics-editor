import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_comics/flutter_comics.dart';

/// What [SoundPlayer.evaluate] decided to do this tick, for a given sound.
enum SoundAction { none, playOnce, startLooping, stop }

/// Pure port of legacy/comics-editor-v2.8/Comics.Editor's `SoundAnim.FindCurrent`
/// + `SoundViewModel.Scroll`'s scroll-driven half (see
/// flows/vdd-comics-editor-vertical-scroll/01-requirements.md, point 11).
/// Deliberately separated from any real playback call (per
/// 03-specifications.md's Interfaces) so the gating decision itself is
/// testable without `audioplayers`. The natural-clip-end restart-if-looping
/// behavior (legacy's `Player_MediaEnded`) is NOT part of this -- that's a
/// playback-completion event, not a scroll-driven one; [SoundPlayer] wires it
/// separately to the real player's completion stream.
class SoundGating {
  SoundGating._();

  static SoundAction decide({
    required List<Anim> soundAnims,
    required double prevTime,
    required double currentTime,
    required bool currentlyPlaying,
  }) {
    final anim = _findCurrent(soundAnims, prevTime, currentTime);
    if (anim != null) {
      if (currentlyPlaying) return SoundAction.none; // matches Play(state, force:false)
      return anim.start == anim.end ? SoundAction.playOnce : SoundAction.startLooping;
    }
    return currentlyPlaying ? SoundAction.stop : SoundAction.none;
  }

  /// `SoundAnim.FindCurrent`: matches either a genuine range (`start <=
  /// currentTime <= end`) or a point (`start == end`) crossed while scrolling
  /// DOWNWARD specifically (`prevTime < currentTime && prevTime <= start &&
  /// start <= currentTime`) -- scrolling back up past a point-trigger does
  /// not replay it.
  static Anim? _findCurrent(List<Anim> anims, double prevTime, double currentTime) {
    for (final a in anims) {
      if (a.type != AnimType.sound) continue;
      final inRange = a.start <= currentTime && a.end >= currentTime;
      final crossedPointDownward = a.start == a.end &&
          prevTime < currentTime &&
          prevTime <= a.start &&
          a.start <= currentTime;
      if (inRange || crossedPointDownward) return a;
    }
    return null;
  }
}

/// Wraps a real [AudioPlayer] (from `audioplayers`), gated by [SoundGating].
/// Mirrors `SoundViewModel`'s real `MediaPlayer` field/calls, but on a
/// cross-platform Flutter audio package instead of WPF's `MediaPlayer`.
class SoundPlayer {
  SoundPlayer(this.filePath) {
    _player.onPlayerComplete.listen((_) {
      // Legacy's Player_MediaEnded: if scroll still wants this looping,
      // restart; otherwise settle into stopped.
      if (_looping) {
        _player.resume();
      } else {
        _playing = false;
      }
    });
  }

  final String filePath;
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  bool _looping = false;

  /// Call once per `currentTime` change (mirrors `ComicsViewModel.Scroll`'s
  /// per-tick `sound.Scroll()` call). [prevTime] is the `currentTime` from
  /// the previous call.
  Future<void> evaluate(List<Anim> soundAnims, double prevTime, double currentTime) async {
    final action = SoundGating.decide(
      soundAnims: soundAnims,
      prevTime: prevTime,
      currentTime: currentTime,
      currentlyPlaying: _playing,
    );
    switch (action) {
      case SoundAction.none:
        return;
      case SoundAction.playOnce:
        _playing = true;
        _looping = false;
        await _player.play(DeviceFileSource(filePath));
      case SoundAction.startLooping:
        _playing = true;
        _looping = true;
        await _player.play(DeviceFileSource(filePath));
      case SoundAction.stop:
        _playing = false;
        _looping = false;
        await _player.stop();
    }
  }

  Future<void> dispose() => _player.dispose();
}
