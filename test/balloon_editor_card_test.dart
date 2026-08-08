// vdd-comics-editor-uiux-lettering, Task 4.2: BalloonEditorCard's states,
// walked against 02-visual.md's "Component: Balloon editor card" +
// Lettering-mode "States" section, using StubBalloonAiClient to force each
// generation outcome. Success/failure/regenerate tests open the real
// sample.comics fixture (via a real EditorController + DartIoCore session)
// so there's a genuine tile-based artwork source to generate from, matching
// how the card behaves in the real app.
//
// Debugging note (kept for future maintainers): the first version of this
// file hung indefinitely. Two independent causes, both instances of the
// same Flutter testing rule -- genuine async platform/OS work doesn't
// progress inside testWidgets' fake-async zone unless awaited inside
// tester.runAsync():
//   1. Calling LanguageRegistry.load() (a real rootBundle platform-channel
//      read) fresh inside every testWidgets closure -- fixed by loading it
//      once in setUpAll instead.
//   2. Real dart:io File/Directory work (EditorController.openPath,
//      setImageFile's tile writes, saveToPath) awaited directly in a
//      testWidgets body -- fixed by wrapping those calls in
//      tester.runAsync().
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/ai/balloon_ai_client.dart';
import 'package:comics_editor/src/ai/stub_balloon_ai_client.dart';
import 'package:comics_editor/src/i18n/language_registry.dart';
import 'package:comics_editor/src/ui/controller.dart';
import 'package:flutter_comics/flutter_comics.dart';
import 'package:comics_editor/src/ui/theme.dart';
import 'package:comics_editor/src/ui/widgets/balloon_editor_card.dart';

/// Polls with real delays (must run inside `tester.runAsync`) until
/// [condition] holds or ~2 seconds elapse, pumping a frame each iteration.
/// A fixed real delay before a single pump is a guess; this waits only as
/// long as actually needed and fails fast once genuinely stuck.
Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 40; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await tester.pump();
  }
}

Future<void> _setLargeViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// `BalloonEditorCard.initState` fires an unawaited `_loadPreview()` call
/// that does real file I/O (`stitchImage` reads tiles off disk) whenever the
/// layer has real artwork -- needs `runAsync`, same as the other genuine
/// dart:io work in this file, or `_stitchedPreview` never resolves and
/// `canGenerate` stays permanently false.
Future<void> _pumpCard(
  WidgetTester tester, {
  required EditorController controller,
  required EditorLayer layer,
  required LanguageRegistry registry,
  required BalloonAiClient aiClient,
}) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: BalloonEditorCard(
            controller: controller,
            layer: layer,
            registry: registry,
            aiClient: aiClient,
          ),
        ),
      ),
    ));
    // pumpAndSettle only re-pumps when a frame gets scheduled DURING its own
    // loop -- it doesn't know to wait for _loadPreview's unawaited real I/O,
    // which may not have called setState yet by the time the first pump
    // returns. Give it a moment to actually finish, then settle.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  });
}

/// Opens the real fixture inside `runAsync` (real dart:io) and pumps the
/// resulting frames.
Future<EditorController> _openSample(WidgetTester tester) async {
  late EditorController controller;
  await tester.runAsync(() async {
    controller = EditorController();
    final ok = await controller.openPath('test/fixtures/sample.comics');
    if (!ok) throw StateError('failed to open sample.comics: ${controller.coreError}');
  });
  return controller;
}

void main() {
  // Loaded once (real rootBundle asset read) and reused -- avoids repeating
  // an async platform-channel round trip inside every testWidgets closure.
  late LanguageRegistry registry;
  setUpAll(() async {
    registry = await LanguageRegistry.load();
  });

  testWidgets('empty balloon: no text yet, shows the add-language hint', (tester) async {
    await _setLargeViewport(tester);
    final controller = EditorController()..newDoc(DocType.comics);
    controller.addLayer();
    final layer = controller.selectedLayer!
      ..kind = 'balloon'
      ..images.clear();
    layer.images.addAll([LayerImage(), LayerImage(), LayerImage()]);

    await _pumpCard(tester,
        controller: controller,
        layer: layer,
        registry: registry,
        aiClient: StubBalloonAiClient());

    expect(find.text('no text yet'), findsOneWidget);
    expect(find.text('Add a language to start lettering this balloon.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Generate artwork with AI'), findsNothing);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('hand-lettered balloon: generation disabled, no language tabs/text field',
      (tester) async {
    await _setLargeViewport(tester);
    final controller = EditorController()..newDoc(DocType.comics);
    controller.addLayer();
    final layer = controller.selectedLayer!
      ..kind = 'balloon'
      ..style = 'hand_lettered';

    await _pumpCard(tester,
        controller: controller,
        layer: layer,
        registry: registry,
        aiClient: StubBalloonAiClient());

    expect(find.text('hand-lettered'), findsOneWidget); // header style chip
    expect(find.textContaining('AI generation is disabled here'), findsOneWidget);
    expect(find.text('Open in Art mode to edit manually'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Generate artwork with AI'), findsNothing);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('text entered, not yet generated: field shows text, Generate enabled',
      (tester) async {
    await _setLargeViewport(tester);
    final controller = await _openSample(tester);
    controller.selectLayer(0);
    final layer = controller.selectedLayer!..kind = 'balloon';
    controller.setLayerTranslation('en', 'Hello there');

    await _pumpCard(tester,
        controller: controller,
        layer: layer,
        registry: registry,
        aiClient: StubBalloonAiClient());

    expect(find.text('TEXT (EN)'), findsOneWidget);
    expect(find.text('Hello there'), findsOneWidget);
    expect(find.text('Generate artwork with AI'), findsOneWidget);
    expect(find.text('(o) On-device'), findsOneWidget);

    // Enabled -- real artwork exists to generate from (a genuine tap has an
    // effect, rather than introspecting HsButton's internal GestureDetector).
    await tester.tap(find.text('Generate artwork with AI'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('generating: shows progress + routing message + Cancel; Cancel returns to idle',
      (tester) async {
    await _setLargeViewport(tester);
    final controller = await _openSample(tester);
    controller.selectLayer(0);
    final layer = controller.selectedLayer!..kind = 'balloon';
    controller.setLayerTranslation('en', 'Hello there');

    final aiClient = StubBalloonAiClient(
      stepDelay: const Duration(seconds: 10), // never resolves within this test
      onDevice: false,
      routingReason: "This device can't render Hindi shaping locally — sent to the server",
    );

    await _pumpCard(tester,
        controller: controller, layer: layer, registry: registry, aiClient: aiClient);

    // _generate resolves the source image (real disk I/O, stitching the
    // fixture's existing tiles) before starting the aiClient stream -- needs
    // runAsync + real polling, same as the other genuine dart:io work in
    // this file.
    await tester.runAsync(() async {
      await tester.tap(find.text('Generate artwork with AI'));
      await tester.pump();
      await _pumpUntil(tester, () => find.textContaining('Cloud').evaluate().isNotEmpty);
    });

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.textContaining('Cloud'), findsOneWidget);
    expect(find.textContaining("sent to the server"), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Generate artwork with AI'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets(
      'success: writes real artwork via setImageFile, shows Regenerate + Generated just now, tab fills',
      (tester) async {
    await _setLargeViewport(tester);
    final controller = await _openSample(tester);
    controller.selectLayer(0);
    final layer = controller.selectedLayer!..kind = 'balloon';
    controller.setLayerTranslation('en', 'Hello there');
    final originalEnFile = layer.images[0].file;

    await _pumpCard(tester,
        controller: controller,
        layer: layer,
        registry: registry,
        aiClient: StubBalloonAiClient(stepDelay: Duration.zero));

    // Generation success writes real tiles to disk (Task 2.3) -- genuine
    // dart:io work, needs runAsync + real polling for the write to actually
    // finish before settling (see _pumpCard's comment).
    await tester.runAsync(() async {
      await tester.tap(find.text('Generate artwork with AI'));
      await tester.pump();
      await _pumpUntil(tester, () => find.text('Regenerate').evaluate().isNotEmpty);
      await tester.pumpAndSettle();
    });

    expect(find.text('Regenerate'), findsOneWidget);
    expect(find.text('Generated just now'), findsOneWidget);
    // The real write path (Task 2.3) actually ran -- a new tile template,
    // distinct from the file the fixture originally had.
    expect(layer.images[0].file, isNot(originalEnFile));
    expect(layer.images[0].file, contains('{0}'));
    expect(find.byType(Image), findsWidgets); // artwork preview now shows something
  }, timeout: const Timeout(Duration(seconds: 30)));

  // vdd-comics-editor-uiux-lettering, Task 7.3: the "translations text
  // edited after generation" edge case flagged in 03-specifications.md as
  // not covered by 02-visual.md's states -- nothing auto-regenerates on a
  // text edit, so the UI needs its own signal that the on-screen artwork no
  // longer reflects the current text.
  testWidgets('stale artwork: editing text after a successful generation shows the notice '
      'and reverts the button to Generate (not Regenerate)', (tester) async {
    await _setLargeViewport(tester);
    final controller = await _openSample(tester);
    controller.selectLayer(0);
    final layer = controller.selectedLayer!..kind = 'balloon';
    controller.setLayerTranslation('en', 'Hello there');

    await _pumpCard(tester,
        controller: controller,
        layer: layer,
        registry: registry,
        aiClient: StubBalloonAiClient(stepDelay: Duration.zero));

    await tester.runAsync(() async {
      await tester.tap(find.text('Generate artwork with AI'));
      await tester.pump();
      await _pumpUntil(tester, () => find.text('Regenerate').evaluate().isNotEmpty);
      await tester.pumpAndSettle();
    });
    expect(find.text('Regenerate'), findsOneWidget);
    expect(find.textContaining('Artwork may be outdated'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Hello there, again');
    await tester.pump();

    expect(find.text('Regenerate'), findsNothing);
    expect(find.text('Generate artwork with AI'), findsOneWidget);
    expect(find.textContaining('Artwork may be outdated'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('stale artwork: regenerating clears the notice', (tester) async {
    await _setLargeViewport(tester);
    final controller = await _openSample(tester);
    controller.selectLayer(0);
    final layer = controller.selectedLayer!..kind = 'balloon';
    controller.setLayerTranslation('en', 'Hello there');

    await _pumpCard(tester,
        controller: controller,
        layer: layer,
        registry: registry,
        aiClient: StubBalloonAiClient(stepDelay: Duration.zero));

    await tester.runAsync(() async {
      await tester.tap(find.text('Generate artwork with AI'));
      await tester.pump();
      await _pumpUntil(tester, () => find.text('Regenerate').evaluate().isNotEmpty);
      await tester.pumpAndSettle();
    });

    await tester.enterText(find.byType(TextField), 'Hello there, again');
    await tester.pump();
    expect(find.textContaining('Artwork may be outdated'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Generate artwork with AI'));
      await tester.pump();
      await _pumpUntil(tester, () => find.text('Regenerate').evaluate().isNotEmpty);
      await tester.pumpAndSettle();
    });

    expect(find.text('Regenerate'), findsOneWidget);
    expect(find.text('Generated just now'), findsOneWidget);
    expect(find.textContaining('Artwork may be outdated'), findsNothing);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets(
      'stale artwork: editing text back to exactly the generated value clears the notice '
      '(no false positive on a no-op edit)', (tester) async {
    await _setLargeViewport(tester);
    final controller = await _openSample(tester);
    controller.selectLayer(0);
    final layer = controller.selectedLayer!..kind = 'balloon';
    controller.setLayerTranslation('en', 'Hello there');

    await _pumpCard(tester,
        controller: controller,
        layer: layer,
        registry: registry,
        aiClient: StubBalloonAiClient(stepDelay: Duration.zero));

    await tester.runAsync(() async {
      await tester.tap(find.text('Generate artwork with AI'));
      await tester.pump();
      await _pumpUntil(tester, () => find.text('Regenerate').evaluate().isNotEmpty);
      await tester.pumpAndSettle();
    });

    await tester.enterText(find.byType(TextField), 'Hello there!');
    await tester.pump();
    expect(find.textContaining('Artwork may be outdated'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Hello there');
    await tester.pump();
    expect(find.textContaining('Artwork may be outdated'), findsNothing);
    expect(find.text('Regenerate'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('failure: shows mapped error message + Retry/Edit text', (tester) async {
    await _setLargeViewport(tester);
    final controller = await _openSample(tester);
    controller.selectLayer(0);
    final layer = controller.selectedLayer!..kind = 'balloon';
    controller.setLayerTranslation('en', 'Hello there');

    await _pumpCard(tester,
        controller: controller,
        layer: layer,
        registry: registry,
        aiClient: StubBalloonAiClient(
            outcome: StubGenerationOutcome.textOverflow, stepDelay: Duration.zero));

    // _generate resolves the source image (real disk I/O) before starting
    // the aiClient stream -- needs runAsync + real polling, same as the
    // other genuine dart:io work in this file.
    await tester.runAsync(() async {
      await tester.tap(find.text('Generate artwork with AI'));
      await tester.pump();
      await _pumpUntil(tester, () => find.text('Retry').evaluate().isNotEmpty);
      await tester.pumpAndSettle();
    });

    expect(find.text("Text didn't fit the balloon even at minimum size."), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Edit text'), findsOneWidget);

    await tester.tap(find.text('Edit text'));
    await tester.pumpAndSettle();
    expect(find.text('Generate artwork with AI'), findsOneWidget); // back to idle
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('a target language beyond en/ru/hi round-trips through the real headless core',
      (tester) async {
    await _setLargeViewport(tester);
    final controller = await _openSample(tester);
    controller.selectLayer(0);
    final layer = controller.selectedLayer!..kind = 'balloon';
    controller.setLayerTranslation('uk', 'Привіт');

    await _pumpCard(tester,
        controller: controller,
        layer: layer,
        registry: registry,
        aiClient: StubBalloonAiClient(stepDelay: Duration.zero));

    // Default-selected language is the first translations key ('uk' here).
    expect(find.text('TEXT (UK)'), findsOneWidget);

    late String ukFile;
    late String savedPath;
    late EditorController reopened;
    await tester.runAsync(() async {
      await tester.tap(find.text('Generate artwork with AI'));
      await tester.pump();
      await _pumpUntil(tester, () => find.text('Regenerate').evaluate().isNotEmpty);
      await tester.pumpAndSettle();

      final ukIndex = registry.indexFor('uk')!;
      ukFile = layer.images[ukIndex].file;

      savedPath = '${Directory.systemTemp.createTempSync('balloon_card_uk').path}/roundtrip.comics';
      final saved = await controller.saveToPath(savedPath);
      if (!saved) throw StateError('saveToPath failed: ${controller.coreError}');

      reopened = EditorController();
      final ok = await reopened.openPath(savedPath);
      if (!ok) throw StateError('reopen failed: ${reopened.coreError}');
    });

    final ukIndex = registry.indexFor('uk')!;
    expect(layer.images.length, greaterThan(ukIndex));
    expect(ukFile, contains('{0}'));
    expect(reopened.doc!.layers[0].images[ukIndex].file, ukFile);
  }, timeout: const Timeout(Duration(seconds: 30)));

  // vdd-comics-editor-uiux-lettering, Task 7.2: state-coverage walkthrough
  // against 02-visual.md found this specific distinction ("[ En ] (filled)"
  // vs "[ Uk ] (outline only)" in the LANGUAGE row, and the `[+ Add]`
  // picker) implemented (`_LanguageTab.isFilled`, `_pickAddLanguage`) but
  // not exercised by any existing test -- closing that gap here rather than
  // just eyeballing the widget code.
  testWidgets('language tabs: filled for text+artwork, outline for text-only, '
      '+ Add opens a picker that adds and selects a new tab', (tester) async {
    await _setLargeViewport(tester);
    final controller = EditorController()..newDoc(DocType.comics);
    controller.addLayer();
    final layer = controller.selectedLayer!..kind = 'balloon';
    // Fake a real tile template for 'en' only -- _hasArtwork/_usedLanguages
    // key off the filename shape, not real disk I/O, matching how
    // stitchImage's own guard works.
    layer.images[0].file = 'balloon_1000_{0}_{1}.png';
    controller.setLayerTranslation('en', 'Hello there');
    controller.setLayerTranslation('ru', 'Привет');

    await _pumpCard(tester,
        controller: controller,
        layer: layer,
        registry: registry,
        aiClient: StubBalloonAiClient());

    BoxDecoration decorationFor(String code) {
      final container = tester.widget<Container>(find.ancestor(
        of: find.text(code),
        matching: find.byType(Container),
      ));
      return container.decoration as BoxDecoration;
    }

    expect(decorationFor('EN').color, Hs.blue500, reason: 'EN has artwork -- filled tab');
    expect(decorationFor('RU').color, isNot(Hs.blue500), reason: 'RU is text-only -- outline tab');

    // '+ Add' opens a real Material popup menu offering an unused language.
    await tester.tap(find.text('+ Add'));
    await tester.pumpAndSettle();
    expect(find.textContaining('(hi)'), findsOneWidget);

    await tester.tap(find.textContaining('(hi)'));
    await tester.pumpAndSettle();

    // Picking it selects it -- the TEXT editor switches to the newly-added
    // language, not a silent no-op. Its tab doesn't appear in the LANGUAGE
    // row yet: _usedLanguages() (same guard as every other "used" check in
    // this widget) only lists languages with real text or artwork, and a
    // freshly-picked language has neither until something is typed -- the
    // tab shows up on the next keystroke via _onTextChanged, same as any
    // other language.
    expect(find.text('TEXT (HI)'), findsOneWidget);
    expect(find.text('HI'), findsNothing);

    await tester.enterText(find.byType(TextField), 'नमस्ते');
    await tester.pump();
    expect(find.text('HI'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
