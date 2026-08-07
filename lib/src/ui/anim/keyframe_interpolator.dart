import 'dart:ui';

import '../models.dart';

/// Faithful Dart port of legacy/comics-editor-v2.8/Comics.Editor/Models/Anim.cs's
/// `FindNearest<T>`/`Factor`/`Interpolate<T>` (see
/// flows/vdd-comics-editor-vertical-scroll/01-requirements.md, Major Finding
/// points 6-8). One function per visual [AnimType]; each mirrors legacy's
/// per-type Interpolate() override and Init() resting default exactly,
/// including the non-obvious detail that pivot is never eased -- it snaps
/// straight to the active segment's own pivot, matching
/// ScaleAnim.cs/RotateAnim.cs's `Interpolate` overrides.
///
/// tdd-dot-comics-format Plan Task 5.4: each function now also composes an
/// independent time-driven contribution (per-`Anim` [AnimBasis.time],
/// `03-specifications.md`/`04-visual.md` Screen 5) alongside the original
/// scroll-driven one. Composition rule, per this plan's own resolution of
/// Task 5.1(d): translate/rotate.angle *sum* (two independent additive
/// motions); scale/alpha *multiply* (two independent multiplicative
/// factors) -- in both cases the "no time-basis anims of this type" case
/// yields exactly that operation's identity element (0 for sum, 1 for
/// product), so every document with zero time-basis anims produces
/// byte-identical results to before this change. Pivot (never eased) has
/// no natural sum/product -- ties are broken toward the scroll dimension's
/// own active pivot, since that's the only one any real content has ever
/// used; this is a disclosed, not-otherwise-specified tie-break, not a
/// finding from real data.
class KeyframeInterpolator {
  KeyframeInterpolator._();

  /// [scrollTime] drives scroll-basis anims (unchanged meaning/units from
  /// before this plan). [wallClockMs] drives time-basis anims -- ignored
  /// entirely (never even read) whenever a layer has none, which is every
  /// document that predates this feature.
  static Offset translateAt(
    List<Anim> anims,
    double scrollTime,
    Offset fallback, [
    double wallClockMs = 0,
  ]) {
    final scrollResult = _translateFrom(
      _sorted(anims, AnimType.translate, AnimBasis.scroll),
      scrollTime,
      fallback,
    );
    final timeAnims = _sorted(anims, AnimType.translate, AnimBasis.time);
    if (timeAnims.isEmpty) return scrollResult;
    final timeResult = _translateFrom(timeAnims, _wrappedTime(timeAnims, wallClockMs), Offset.zero);
    return scrollResult + timeResult;
  }

  static Offset _translateFrom(List<Anim> sortedAnims, double currentTime, Offset fallback) {
    final (prev, curr) = _findNearest(sortedAnims, currentTime);
    if (prev == null && curr == null) return fallback;
    // TranslateAnim has no Init() override in legacy -- C#'s implicit default (0,0).
    final px = prev?.x ?? 0.0;
    final py = prev?.y ?? 0.0;
    if (curr == null) return Offset(px, py);
    final f = _easedFactor(curr, currentTime);
    return Offset(px + (curr.x - px) * f, py + (curr.y - py) * f);
  }

  /// AnimType.scale. Resting default (1, 1, 0.5, 0.5) matches
  /// ScaleAnim.Init() (scaleX/Y=1) + its PivotAnim base (pivot=0.5/0.5).
  static (double scaleX, double scaleY, double pivotX, double pivotY) scaleAt(
    List<Anim> anims,
    double scrollTime, [
    double wallClockMs = 0,
  ]) {
    final (ssx, ssy, spx, spy, sActive) =
        _scaleFrom(_sorted(anims, AnimType.scale, AnimBasis.scroll), scrollTime);
    final timeAnims = _sorted(anims, AnimType.scale, AnimBasis.time);
    if (timeAnims.isEmpty) return (ssx, ssy, spx, spy);
    final (tsx, tsy, tpx, tpy, tActive) =
        _scaleFrom(timeAnims, _wrappedTime(timeAnims, wallClockMs));
    final (pivotX, pivotY) = sActive ? (spx, spy) : (tActive ? (tpx, tpy) : (spx, spy));
    return (ssx * tsx, ssy * tsy, pivotX, pivotY);
  }

  static (double scaleX, double scaleY, double pivotX, double pivotY, bool active) _scaleFrom(
      List<Anim> sortedAnims, double currentTime) {
    final (prev, curr) = _findNearest(sortedAnims, currentTime);
    final psx = prev?.scaleX ?? 1.0;
    final psy = prev?.scaleY ?? 1.0;
    if (curr == null) {
      return (psx, psy, prev?.pivotX ?? 0.5, prev?.pivotY ?? 0.5, false);
    }
    final f = _easedFactor(curr, currentTime);
    return (
      psx + (curr.scaleX - psx) * f,
      psy + (curr.scaleY - psy) * f,
      curr.pivotX,
      curr.pivotY,
      true,
    );
  }

  /// AnimType.rotate. Resting default (0, 0.5, 0.5) -- RotateAnim itself has
  /// no Init() override (angle defaults to C#'s implicit 0), but it inherits
  /// PivotAnim.Init()'s pivot=0.5/0.5.
  static (double angle, double pivotX, double pivotY) rotateAt(
    List<Anim> anims,
    double scrollTime, [
    double wallClockMs = 0,
  ]) {
    final (sa, spx, spy, sActive) =
        _rotateFrom(_sorted(anims, AnimType.rotate, AnimBasis.scroll), scrollTime);
    final timeAnims = _sorted(anims, AnimType.rotate, AnimBasis.time);
    if (timeAnims.isEmpty) return (sa, spx, spy);
    final (ta, tpx, tpy, tActive) = _rotateFrom(timeAnims, _wrappedTime(timeAnims, wallClockMs));
    final (pivotX, pivotY) = sActive ? (spx, spy) : (tActive ? (tpx, tpy) : (spx, spy));
    return (sa + ta, pivotX, pivotY);
  }

  static (double angle, double pivotX, double pivotY, bool active) _rotateFrom(
      List<Anim> sortedAnims, double currentTime) {
    final (prev, curr) = _findNearest(sortedAnims, currentTime);
    final pa = prev?.angle ?? 0.0;
    if (curr == null) {
      return (pa, prev?.pivotX ?? 0.5, prev?.pivotY ?? 0.5, false);
    }
    final f = _easedFactor(curr, currentTime);
    return (pa + (curr.angle - pa) * f, curr.pivotX, curr.pivotY, true);
  }

  /// AnimType.alpha. Resting default 1.0 matches AlphaAnim.Init().
  static double alphaAt(List<Anim> anims, double scrollTime, [double wallClockMs = 0]) {
    final scrollResult = _alphaFrom(_sorted(anims, AnimType.alpha, AnimBasis.scroll), scrollTime);
    final timeAnims = _sorted(anims, AnimType.alpha, AnimBasis.time);
    if (timeAnims.isEmpty) return scrollResult;
    final timeResult = _alphaFrom(timeAnims, _wrappedTime(timeAnims, wallClockMs));
    return scrollResult * timeResult;
  }

  static double _alphaFrom(List<Anim> sortedAnims, double currentTime) {
    final (prev, curr) = _findNearest(sortedAnims, currentTime);
    final pAlpha = prev?.alpha ?? 1.0;
    if (curr == null) return pAlpha;
    final f = _easedFactor(curr, currentTime);
    return pAlpha + (curr.alpha - pAlpha) * f;
  }

  /// tdd-dot-comics-format Plan Task 5.4: folds continuous [wallClockMs]
  /// into a single loop cycle when at least one of [timeAnims] has `loop ==
  /// true` (Task 5.1's resolved default) -- the cycle length is the largest
  /// `end` among them, since anims of one type on one layer share one
  /// timeline conceptually, mirroring how the scroll dimension already
  /// treats same-type anims as one sorted sequence rather than
  /// independently. A non-looping anim past its own `end` simply holds at
  /// its last value via the existing `_findNearest`/`curr == null` path --
  /// no special-casing needed for that half.
  static double _wrappedTime(List<Anim> timeAnims, double wallClockMs) {
    if (!timeAnims.any((a) => a.loop)) return wallClockMs;
    final totalDuration = timeAnims.fold<int>(0, (max, a) => a.end > max ? a.end : max);
    if (totalDuration <= 0) return wallClockMs;
    return wallClockMs % totalDuration;
  }

  /// Sorted by `start`, with ties broken by original list order -- matching
  /// legacy's `OrderBy` (LINQ), which is a stable sort. This is not a
  /// theoretical concern: real `.comics` files genuinely have multiple
  /// `Anim`s of the same type sharing `start=0` (the common "no explicit
  /// start" JSON omission, per Task 1.1), where original order determines
  /// which one legacy's `FindNearest` treats as already-passed at
  /// currentTime=0 -- Dart's `List.sort` does not document itself as stable,
  /// so relying on it directly here would risk a real, silent divergence
  /// from legacy for exactly this common case.
  static List<Anim> _sorted(List<Anim> anims, AnimType type, AnimBasis basis) {
    final indexed = <MapEntry<int, Anim>>[
      for (var i = 0; i < anims.length; i++)
        if (anims[i].type == type && anims[i].basis == basis) MapEntry(i, anims[i]),
    ]..sort((a, b) {
        final byStart = a.value.start.compareTo(b.value.start);
        return byStart != 0 ? byStart : a.key.compareTo(b.key);
      });
    return [for (final e in indexed) e.value];
  }

  /// Anim.cs's `FindNearest<T>` (Requirements point 6). [sortedAnims] must
  /// already be filtered to one type and sorted by `start`. Unlike legacy,
  /// this does NOT substitute a synthetic default instance for a null `prev`
  /// -- callers apply their own per-type resting default to `prev == null`,
  /// since Dart has no per-subclass `Init()` override to call polymorphically
  /// on a flat [Anim] class. Both `prev` and `curr` null means either zero
  /// anims of this type exist, or currentTime is before the very first one
  /// even starts.
  static (Anim? prev, Anim? curr) _findNearest(List<Anim> sortedAnims, double currentTime) {
    Anim? prev;
    Anim? curr;
    for (final anim in sortedAnims) {
      if (anim.end <= currentTime) {
        prev = anim;
      } else {
        if (anim.start < currentTime) curr = anim;
        break;
      }
    }
    return (prev, curr);
  }

  /// Anim.cs's `Factor`: `t = (currentTime - curr.start) / (curr.end -
  /// curr.start)`, eased via `(t-1)^3+1` (cubic ease-out). Guarded against
  /// `curr.end == curr.start` purely as defensive division-by-zero safety --
  /// in practice this is unreachable through the four public functions
  /// above, since `_findNearest` only ever selects a `curr` satisfying
  /// `start < currentTime < end`, which structurally requires `end > start`.
  static double _easedFactor(Anim curr, double currentTime) {
    if (curr.end == curr.start) return 1.0;
    final t = (currentTime - curr.start) / (curr.end - curr.start);
    final tm1 = t - 1;
    return tm1 * tm1 * tm1 + 1;
  }
}
