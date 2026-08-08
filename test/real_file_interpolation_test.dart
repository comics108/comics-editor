// vdd-comics-editor-vertical-scroll, Task 5.1: real-file integration test.
// Opens a real .comics file (dataset/ is a monorepo-only fixture -- see
// dataset_backward_compat_test.dart's header for why this must degrade to a
// skip, not a crash, in a checkout that lacks it) and checks
// KeyframeInterpolator's computed translate values against hand-derived
// expectations from the file's own raw Anim data, at several real scroll
// positions -- the concrete bar Requirements set once the
// Anim.start/end-vs-document-height "unit mismatch" was resolved as a
// non-issue (there was never a scale factor to get right).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/bridge/dart_io_core.dart';
import 'package:comics_editor/src/bridge/models_mapping.dart';
import 'package:flutter_comics/flutter_comics.dart';

double _cubicEaseOut(double t) {
  final tm1 = t - 1;
  return tm1 * tm1 * tm1 + 1;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final repoRoot = Directory(Directory.current.path).parent.parent;
  final file = File('${repoRoot.path}/dataset/boranko/mahabharata/book1/'
      'comics_interactive/8a89f7d689fb441ea280cd782276bd7a.comics');
  final available = file.existsSync();

  test(
    'layer 2\'s two real TranslateAnims (Start=0/End=0 and Start=0/End=1054, '
    'both x=354, tying on Start=0) interpolate exactly as hand-derived at four '
    'real scroll positions',
    () async {
      final core =
          DartIoCore(workDirPath: Directory.systemTemp.createTempSync('real_file_test').path);
      addTearDown(core.dispose);
      final opened = await core.call('openComics', {'path': file.path}) as Map<String, dynamic>;
      final raw = opened['comics'] as Map<String, dynamic>;
      final document = comicsFromCore(raw, file.path, tempFolder: opened['tempFolder'] as String?);

      final layer = document.doc.layers[2];
      // Sanity: confirm this is still the layer this test was hand-derived
      // against, in case dataset/ content ever changes underneath it.
      expect(layer.images.first.file, '1_14_{0}_{1}_{2}.png');
      expect(layer.anims.length, 2);
      expect(layer.anims[0].start, 0);
      expect(layer.anims[0].end, 0);
      expect(layer.anims[0].y, 1855);
      expect(layer.anims[1].start, 0);
      expect(layer.anims[1].end, 1054);
      expect(layer.anims[1].y, 1631);

      // t=0: the Start=End=0 anim is already "passed" (end<=0); the Start=0/
      // End=1054 one hasn't "started" (needs strict start<currentTime) -- holds
      // the first anim's value exactly, no interpolation.
      expect(KeyframeInterpolator.translateAt(layer.anims, 0, layer.translate),
          const Offset(354, 1855));

      // t=1054: the second anim's End<=currentTime now too -- it becomes the
      // new held value, again exact (no interpolation, since curr is null once
      // every anim has "passed").
      expect(KeyframeInterpolator.translateAt(layer.anims, 1054, layer.translate),
          const Offset(354, 1631));

      // t=5000 (well past): holds the same value forever, however far past.
      expect(KeyframeInterpolator.translateAt(layer.anims, 5000, layer.translate),
          const Offset(354, 1631));

      // t=500: genuinely mid-interpolation -- prev=first anim (y=1855), curr=
      // second anim (y=1631, its own Start=0/End=1054 defines the fraction).
      final f = _cubicEaseOut(500 / 1054);
      final expectedY = 1855 + (1631 - 1855) * f;
      final result = KeyframeInterpolator.translateAt(layer.anims, 500, layer.translate);
      expect(result.dx, 354); // x is identical on both anims -- no change expected
      expect(result.dy, closeTo(expectedY, 1e-6));
      expect(result.dy.isFinite, isTrue);
    },
    skip: available ? false : 'dataset/ not present in this checkout (monorepo-only fixture)',
  );
}
