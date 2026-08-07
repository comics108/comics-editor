// vdd-comics-editor-vertical-scroll, Tasks 2.1-2.2: KeyframeInterpolator is a
// faithful Dart port of legacy/comics-editor-v2.8/Comics.Editor/Models/Anim.cs's
// FindNearest<T>/Factor/Interpolate<T>. These tests exercise it directly (pure
// functions, no controller/canvas wiring) against the exact cases documented in
// flows/vdd-comics-editor-vertical-scroll/03-specifications.md's Testing Strategy.
import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/ui/anim/keyframe_interpolator.dart';
import 'package:comics_editor/src/ui/models.dart';

double _cubicEaseOut(double t) {
  final tm1 = t - 1;
  return tm1 * tm1 * tm1 + 1;
}

void main() {
  group('translateAt', () {
    test('no translate anims at all falls back to the layer static translate', () {
      final result = KeyframeInterpolator.translateAt(
          [Anim(AnimType.alpha, start: 0, end: 100)], 50, const Offset(10, 20));
      expect(result, const Offset(10, 20));
    });

    test('before any anim has ever completed, both null, falls back to the caller value', () {
      // currentTime=50 is before this anim even starts (start=100) -- neither prev nor
      // curr get set, so this hits the true "nothing to go on" fallback path.
      final anim = Anim(AnimType.translate, start: 100, end: 300)..x = 500..y = 700;
      final result = KeyframeInterpolator.translateAt([anim], 50, const Offset(10, 20));
      expect(result, const Offset(10, 20));
    });

    test('inside the very first anim range, with no earlier completed anim, eases '
        'from the type default (0,0) toward curr -- NOT the caller fallback', () {
      // currentTime=150 is inside [100,300) -- curr=anim, but prev stays null since
      // nothing has completed yet (Requirements point 6: this is a real, distinct case
      // from "nothing to go on at all" above).
      final anim = Anim(AnimType.translate, start: 100, end: 300)..x = 500..y = 700;
      final result = KeyframeInterpolator.translateAt([anim], 150, const Offset(10, 20));
      final f = _cubicEaseOut(0.25);
      expect(result.dx, closeTo(0 + (500 - 0) * f, 1e-9));
      expect(result.dy, closeTo(0 + (700 - 0) * f, 1e-9));
    });

    test('mid-range applies the cubic ease-out between prev and curr', () {
      final seed = Anim(AnimType.translate, start: 0, end: 0)..y = 1000;
      final move = Anim(AnimType.translate, start: 4800, end: 5000)..x = 200..y = 1000;
      final result = KeyframeInterpolator.translateAt([seed, move], 4900, Offset.zero);
      final f = _cubicEaseOut(0.5);
      expect(result.dx, closeTo(0 + (200 - 0) * f, 1e-9));
      expect(result.dy, closeTo(1000 + (1000 - 1000) * f, 1e-9));
    });

    test('past the last anim holds its value unchanged, however far past', () {
      final seed = Anim(AnimType.translate, start: 0, end: 0)..y = 1000;
      final move = Anim(AnimType.translate, start: 4800, end: 5000)..x = 200..y = 1500;
      final result = KeyframeInterpolator.translateAt([seed, move], 90000, Offset.zero);
      expect(result, const Offset(200, 1500));
    });

    test('a real single seed anim (Start=End=0) is immediately "prev" from currentTime=0', () {
      final seed = Anim(AnimType.translate, start: 0, end: 0)..y = 4242;
      final result = KeyframeInterpolator.translateAt([seed], 0, Offset.zero);
      expect(result, const Offset(0, 4242));
    });

    test('two anims tying on Start=0 keep JSON/original order (real dataset shape, '
        'not a theoretical case): dataset/.../8a89f7d689fb441ea280cd782276bd7a.comics '
        'layer 1 has exactly this -- {y:2000} then {y:1776,end:1054}, both Start=0', () {
      final first = Anim(AnimType.translate, start: 0, end: 0)..y = 2000;
      final second = Anim(AnimType.translate, start: 0, end: 1054)..y = 1776;
      final result = KeyframeInterpolator.translateAt([first, second], 0, Offset.zero);
      // At currentTime=0: `first` (end=0) is already "passed" (end<=0), `second`
      // (start=0) has NOT yet "started" (needs start<currentTime, strictly) --
      // so `first`'s value holds, matching legacy's real, order-dependent
      // FindNearest exactly (see the stable-sort comment on _sorted).
      expect(result, const Offset(0, 2000));

      // Reversing the JSON order changes the outcome entirely -- FindNearest's
      // loop BREAKS at the first not-yet-passed anim it hits, so if `second`
      // (not yet passed at currentTime=0) comes first, `first` is never even
      // reached, and the result falls back to [fallback] instead. Order isn't
      // just a tie-break here, it changes which anims get considered at all.
      final reversed = KeyframeInterpolator.translateAt([second, first], 0, Offset.zero);
      expect(reversed, Offset.zero);
    });
  });

  group('scaleAt', () {
    test('no scale anims falls back to identity scale and centered pivot', () {
      final result = KeyframeInterpolator.scaleAt([], 50);
      expect(result, (1.0, 1.0, 0.5, 0.5));
    });

    test('pivot snaps to curr, never eased', () {
      final prev = Anim(AnimType.scale, start: 0, end: 0)
        ..scaleX = 1
        ..scaleY = 1
        ..pivotX = 0.1
        ..pivotY = 0.1;
      final curr = Anim(AnimType.scale, start: 100, end: 200)
        ..scaleX = 2
        ..scaleY = 2
        ..pivotX = 0.9
        ..pivotY = 0.9;
      final (scaleX, scaleY, pivotX, pivotY) =
          KeyframeInterpolator.scaleAt([prev, curr], 100.001);
      expect(pivotX, 0.9);
      expect(pivotY, 0.9);
      expect(scaleX, lessThan(2));
      expect(scaleY, lessThan(2));
    });
  });

  group('rotateAt', () {
    test('no rotate anims falls back to angle 0 and centered pivot', () {
      expect(KeyframeInterpolator.rotateAt([], 50), (0.0, 0.5, 0.5));
    });

    test('past the last anim holds the angle unchanged', () {
      final seed = Anim(AnimType.rotate, start: 0, end: 0)..angle = 0;
      final spin = Anim(AnimType.rotate, start: 100, end: 300)..angle = 45;
      final result = KeyframeInterpolator.rotateAt([seed, spin], 10000);
      expect(result.$1, 45.0);
    });
  });

  group('alphaAt', () {
    test('no alpha anims falls back to fully opaque', () {
      expect(KeyframeInterpolator.alphaAt([], 50), 1.0);
    });

    test('mid-range fade applies the cubic ease-out', () {
      final seed = Anim(AnimType.alpha, start: 0, end: 0)..alpha = 1;
      final fade = Anim(AnimType.alpha, start: 0, end: 200)..alpha = 0;
      final result = KeyframeInterpolator.alphaAt([seed, fade], 100);
      expect(result, closeTo(1 + (0 - 1) * _cubicEaseOut(0.5), 1e-9));
    });
  });

  group('degenerate zero-length ranges', () {
    test('a Start==End anim can only ever become prev (held value), never curr -- '
        'confirming _easedFactor\'s zero-length guard is unreachable through this API, '
        'by construction of _findNearest\'s own start<currentTime<end selection', () {
      final seed = Anim(AnimType.translate, start: 0, end: 0)..y = 0;
      final point = Anim(AnimType.translate, start: 100, end: 100)..y = 999;
      final result = KeyframeInterpolator.translateAt([seed, point], 100.5, Offset.zero);
      expect(result, const Offset(0, 999));
    });
  });

  // tdd-dot-comics-format, Plan Task 5.4: Anim.basis == time composes an
  // independent contribution alongside the scroll-driven one -- sum for
  // translate/rotate.angle, multiply for scale/alpha, exactly matching the
  // Task 5.4 verification bar: "a layer with one scroll-driven Translate
  // and one time-driven Alpha: scrolling changes position but not
  // opacity-over-time; time passing (simulated clock) changes opacity
  // independent of scroll position."
  group('Anim.basis == time composition', () {
    test('a layer with zero time-basis anims is byte-identical to before this feature', () {
      final scrollOnly = Anim(AnimType.translate, start: 0, end: 200)..x = 100;
      final withWallClock =
          KeyframeInterpolator.translateAt([scrollOnly], 100, Offset.zero, 999999);
      final withoutWallClock = KeyframeInterpolator.translateAt([scrollOnly], 100, Offset.zero);
      expect(withWallClock, withoutWallClock);
    });

    test('scrolling changes position but not a time-driven alpha, independent of scroll', () {
      final scrollTranslate = Anim(AnimType.translate, start: 0, end: 200)..x = 100;
      final timeAlpha = Anim(AnimType.alpha, start: 0, end: 1000)
        ..basis = AnimBasis.time
        ..alpha = 0;
      final anims = [scrollTranslate, timeAlpha];

      final atScroll0 = KeyframeInterpolator.translateAt(anims, 0, Offset.zero, 0);
      final atScroll100 = KeyframeInterpolator.translateAt(anims, 100, Offset.zero, 0);
      expect(atScroll0, isNot(atScroll100)); // scroll-driven translate moved

      final alphaAtWallClock0 = KeyframeInterpolator.alphaAt(anims, 0, 0);
      final alphaAtWallClock0Scrolled = KeyframeInterpolator.alphaAt(anims, 9999, 0);
      expect(alphaAtWallClock0, alphaAtWallClock0Scrolled); // alpha ignores scroll position
    });

    test('time passing changes a time-driven alpha independent of scroll', () {
      final timeAlpha = Anim(AnimType.alpha, start: 0, end: 1000)
        ..basis = AnimBasis.time
        ..alpha = 0;
      final atStart = KeyframeInterpolator.alphaAt([timeAlpha], 0, 0);
      final atMid = KeyframeInterpolator.alphaAt([timeAlpha], 0, 500);
      expect(atStart, 1.0); // resting default before the time-anim starts easing
      expect(atMid, closeTo(1 + (0 - 1) * _cubicEaseOut(0.5), 1e-9));
    });

    test('translate/rotate.angle sum scroll and time contributions', () {
      final scrollTranslate = Anim(AnimType.translate, start: 0, end: 0)..x = 100;
      final timeTranslate = Anim(AnimType.translate, start: 0, end: 0)
        ..basis = AnimBasis.time
        ..y = 50;
      final result =
          KeyframeInterpolator.translateAt([scrollTranslate, timeTranslate], 0, Offset.zero, 0);
      expect(result, const Offset(100, 50));
    });

    test('scale/alpha multiply scroll and time contributions', () {
      final scrollScale = Anim(AnimType.scale, start: 0, end: 0)..scaleX = 2..scaleY = 2;
      final timeScale = Anim(AnimType.scale, start: 0, end: 0)
        ..basis = AnimBasis.time
        ..scaleX = 3
        ..scaleY = 3;
      final (scaleX, scaleY, _, _) =
          KeyframeInterpolator.scaleAt([scrollScale, timeScale], 0, 0);
      expect(scaleX, 6);
      expect(scaleY, 6);
    });

    test('a looping time-basis anim wraps wallClockMs modulo the largest end', () {
      final loop = Anim(AnimType.alpha, start: 0, end: 100)
        ..basis = AnimBasis.time
        ..alpha = 0;
      // loop defaults to true (Task 5.1's resolution) -- 1150ms wraps to 50ms,
      // same as evaluating at 50ms directly.
      final wrapped = KeyframeInterpolator.alphaAt([loop], 0, 1150);
      final direct = KeyframeInterpolator.alphaAt([loop], 0, 50);
      expect(wrapped, direct);
    });

    test('a non-looping time-basis anim holds its final value past its own end', () {
      final once = Anim(AnimType.alpha, start: 0, end: 100)
        ..basis = AnimBasis.time
        ..alpha = 0
        ..loop = false;
      final result = KeyframeInterpolator.alphaAt([once], 0, 5000);
      expect(result, 0.0); // held at the fully-eased final value, not wrapped/restarted
    });
  });
}
