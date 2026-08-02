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
class KeyframeInterpolator {
  KeyframeInterpolator._();

  /// AnimType.translate. [fallback] (the layer's static `translate`) is used
  /// only when the layer has zero translate-type anims at all -- unreachable
  /// for normally-authored layers, since EditorLayer's constructor (and
  /// legacy's Layer.Create) always seeds one anim whose Start=End=0
  /// immediately qualifies as "already passed" from currentTime=0 onward.
  /// Kept as a defensive fallback for malformed/hand-edited data, per
  /// 03-specifications.md.
  static Offset translateAt(List<Anim> anims, double currentTime, Offset fallback) {
    final (prev, curr) = _findNearest(_sorted(anims, AnimType.translate), currentTime);
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
  /// Pivot is never eased -- it snaps to `curr`'s own pivot, matching
  /// ScaleAnim.Interpolate exactly.
  static (double scaleX, double scaleY, double pivotX, double pivotY) scaleAt(
      List<Anim> anims, double currentTime) {
    final (prev, curr) = _findNearest(_sorted(anims, AnimType.scale), currentTime);
    final psx = prev?.scaleX ?? 1.0;
    final psy = prev?.scaleY ?? 1.0;
    if (curr == null) {
      return (psx, psy, prev?.pivotX ?? 0.5, prev?.pivotY ?? 0.5);
    }
    final f = _easedFactor(curr, currentTime);
    return (psx + (curr.scaleX - psx) * f, psy + (curr.scaleY - psy) * f, curr.pivotX, curr.pivotY);
  }

  /// AnimType.rotate. Resting default (0, 0.5, 0.5) -- RotateAnim itself has
  /// no Init() override (angle defaults to C#'s implicit 0), but it inherits
  /// PivotAnim.Init()'s pivot=0.5/0.5. Pivot is never eased, same as scale.
  static (double angle, double pivotX, double pivotY) rotateAt(List<Anim> anims, double currentTime) {
    final (prev, curr) = _findNearest(_sorted(anims, AnimType.rotate), currentTime);
    final pa = prev?.angle ?? 0.0;
    if (curr == null) {
      return (pa, prev?.pivotX ?? 0.5, prev?.pivotY ?? 0.5);
    }
    final f = _easedFactor(curr, currentTime);
    return (pa + (curr.angle - pa) * f, curr.pivotX, curr.pivotY);
  }

  /// AnimType.alpha. Resting default 1.0 matches AlphaAnim.Init().
  static double alphaAt(List<Anim> anims, double currentTime) {
    final (prev, curr) = _findNearest(_sorted(anims, AnimType.alpha), currentTime);
    final pAlpha = prev?.alpha ?? 1.0;
    if (curr == null) return pAlpha;
    final f = _easedFactor(curr, currentTime);
    return pAlpha + (curr.alpha - pAlpha) * f;
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
  static List<Anim> _sorted(List<Anim> anims, AnimType type) {
    final indexed = <MapEntry<int, Anim>>[
      for (var i = 0; i < anims.length; i++)
        if (anims[i].type == type) MapEntry(i, anims[i]),
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
