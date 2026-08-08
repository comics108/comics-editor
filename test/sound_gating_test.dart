// vdd-comics-editor-vertical-scroll, Task 4.2: SoundGating.decide is a pure
// port of legacy/comics-editor-v2.8's SoundAnim.FindCurrent + the scroll-driven
// half of SoundViewModel.Scroll -- testable without any real audio playback.
import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/ui/audio/sound_player.dart';
import 'package:flutter_comics/flutter_comics.dart';

void main() {
  group('point trigger (Start == End)', () {
    final anims = [Anim(AnimType.sound, start: 3000, end: 3000)];

    test('crossing downward through the point plays once', () {
      final action = SoundGating.decide(
          soundAnims: anims, prevTime: 2999, currentTime: 3001, currentlyPlaying: false);
      expect(action, SoundAction.playOnce);
    });

    test('crossing upward through the point does not replay it', () {
      final action = SoundGating.decide(
          soundAnims: anims, prevTime: 3001, currentTime: 2999, currentlyPlaying: false);
      expect(action, SoundAction.none);
    });

    test('landing exactly on the point (prevTime==start==currentTime) still counts', () {
      // prevTime < currentTime is required, so an exact stationary sit does not
      // trigger -- but arriving with prevTime just before and currentTime
      // exactly at the point does.
      final action = SoundGating.decide(
          soundAnims: anims, prevTime: 2999.9, currentTime: 3000, currentlyPlaying: false);
      expect(action, SoundAction.playOnce);
    });
  });

  group('range trigger (Start < End)', () {
    final anims = [Anim(AnimType.sound, start: 5000, end: 5400)];

    test('entering the range while not playing starts looping', () {
      final action = SoundGating.decide(
          soundAnims: anims, prevTime: 4900, currentTime: 5100, currentlyPlaying: false);
      expect(action, SoundAction.startLooping);
    });

    test('already playing inside the range is not retriggered', () {
      final action = SoundGating.decide(
          soundAnims: anims, prevTime: 5100, currentTime: 5200, currentlyPlaying: true);
      expect(action, SoundAction.none);
    });

    test('exactly at the start/end boundaries is still inside the range', () {
      expect(
          SoundGating.decide(
              soundAnims: anims, prevTime: 4900, currentTime: 5000, currentlyPlaying: false),
          SoundAction.startLooping);
      expect(
          SoundGating.decide(
              soundAnims: anims, prevTime: 5300, currentTime: 5400, currentlyPlaying: true),
          SoundAction.none);
    });

    test('exiting the range while playing stops immediately', () {
      final action = SoundGating.decide(
          soundAnims: anims, prevTime: 5400, currentTime: 5401, currentlyPlaying: true);
      expect(action, SoundAction.stop);
    });
  });

  group('no matching sound anim', () {
    test('not playing and nothing matches: no action', () {
      final action = SoundGating.decide(
          soundAnims: const [], prevTime: 0, currentTime: 100, currentlyPlaying: false);
      expect(action, SoundAction.none);
    });

    test('playing but nothing matches anymore: stop', () {
      final action = SoundGating.decide(
          soundAnims: const [], prevTime: 0, currentTime: 100, currentlyPlaying: true);
      expect(action, SoundAction.stop);
    });

    test('non-sound anims on the same list are ignored', () {
      final anims = [Anim(AnimType.translate, start: 0, end: 5000)..y = 10];
      final action = SoundGating.decide(
          soundAnims: anims, prevTime: 0, currentTime: 100, currentlyPlaying: false);
      expect(action, SoundAction.none);
    });
  });
}
