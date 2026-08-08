import 'package:flutter/material.dart';

import '../controller.dart';
import '../lottie/lottie_import.dart';
import '../theme.dart';
import 'common.dart';
import 'numeric_property_control.dart';

/// tdd-dot-lottie-import-export Plan Task 6.2/6.3: the review screen --
/// shows [EditorController.lottiePreview] (built by
/// [EditorController.pickLottieToImport]), lets the user override the
/// detected [ExportImportMode] (Task 6.3's wrong-mode banner reacts to
/// that), edit `scrollSpeed`/`EasingChoice`, see per-layer clean/flagged/
/// missingAsset status, and either commit (Task 6.4's real import) or
/// cancel (Test A4 -- a true no-op, nothing has mutated `.comics` yet).
///
/// A real triage screen, not a silent one-shot conversion -- per the
/// Джанава-informed UI entry-point decision this flow's Requirements cite.
Future<void> showLottieImportDialog(BuildContext context) async {
  final c = EditorScope.of(context);
  final ok = await c.pickLottieToImport();
  if (!ok) return; // отмена (file picker) — не ошибка
  if (!context.mounted) return;
  if (c.lottiePreview == null) {
    // Test F1: a corrupt/non-Lottie file — surfaced directly, no preview
    // to review at all.
    await showDialog<void>(
      context: context,
      builder: (ctx) => _ErrorDialog(message: c.lottieImportError ?? 'Unknown error'),
    );
    return;
  }
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _LottieImportReviewDialog(),
  );
}

class _ErrorDialog extends StatelessWidget {
  const _ErrorDialog({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Hs.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Hs.rCard)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Could not read this file',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              Text(message, style: const TextStyle(color: Hs.textSecondary, fontSize: 14)),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  HsButton('OK', onTap: () => Navigator.pop(context)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LottieImportReviewDialog extends StatelessWidget {
  const _LottieImportReviewDialog();

  @override
  Widget build(BuildContext context) {
    final c = EditorScope.of(context);
    final preview = c.lottiePreview;
    // The controller may have been cancelled/committed from elsewhere
    // (e.g. a second rapid tap) while this route was still animating in --
    // close quietly rather than rendering a stale/null preview.
    if (preview == null) {
      Future.microtask(() {
        if (context.mounted && Navigator.canPop(context)) Navigator.pop(context);
      });
      return const SizedBox.shrink();
    }

    // Task 6.3: the wrong-mode banner. Recomputing the auto-detected mode
    // fresh each build (pure, cheap) rather than caching it once, so an
    // override always compares against the real signal, not a stale copy.
    final autoDetected = detectMode(preview.document);
    final modeOverridden = preview.mode != autoDetected;

    return Dialog(
      backgroundColor: Hs.white,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Hs.rCard)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Hs.divider)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Import from .lottie',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      c.cancelLottieImport();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.close, size: 18, color: Hs.textSecondary),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('MODE', style: kSectionLabel),
                    const SizedBox(height: 8),
                    HsSegmented<ExportImportMode>(
                      values: const [ExportImportMode.fullCanvas, ExportImportMode.playbackViewport],
                      labelOf: (m) => m == ExportImportMode.fullCanvas ? 'Full Canvas' : 'Playback Viewport',
                      selected: preview.mode,
                      onChanged: c.setLottieImportMode,
                      expand: true,
                    ),
                    if (modeOverridden) ...[
                      const SizedBox(height: 10),
                      _WarningBanner(
                        text: 'Auto-detected mode was '
                            '"${autoDetected == ExportImportMode.fullCanvas ? 'Full Canvas' : 'Playback Viewport'}" '
                            '— you\'ve overridden it. Double-check the layer list below still looks right.',
                      ),
                    ],
                    const SizedBox(height: 18),
                    if (preview.mode == ExportImportMode.playbackViewport) ...[
                      const Text('SCROLL SPEED (px/frame)', style: kSectionLabel),
                      const SizedBox(height: 8),
                      if (preview.scrollSpeed == null)
                        const _WarningBanner(
                          text: 'No sweep detected to auto-derive a scroll speed from — enter one manually.',
                        )
                      else
                        NumericPropertyControl(
                          label: 'Scroll speed',
                          value: preview.scrollSpeed!,
                          min: 0.01,
                          max: 10000,
                          step: 0.1,
                          onPreview: (v) => c.setLottieScrollSpeed(v.toDouble()),
                          onCommit: (v) => c.setLottieScrollSpeed(v.toDouble()),
                        ),
                      const SizedBox(height: 18),
                    ],
                    const Text('EASING', style: kSectionLabel),
                    const SizedBox(height: 8),
                    HsSegmented<EasingChoice>(
                      values: const [EasingChoice.easyEaseApproximation, EasingChoice.exactCubicFit],
                      labelOf: (e) => e == EasingChoice.easyEaseApproximation ? 'Easy Ease' : 'Exact cubic fit',
                      selected: preview.easing,
                      onChanged: c.setLottieEasingChoice,
                      expand: true,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Text(
                          '${preview.cleanCount} clean',
                          style: const TextStyle(color: Hs.teal500, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 12),
                        if (preview.flaggedCount > 0)
                          Text(
                            '${preview.flaggedCount} flagged',
                            style: const TextStyle(color: Hs.amber500, fontWeight: FontWeight.w500),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 320,
                      decoration: BoxDecoration(
                        border: Border.all(color: Hs.cloud200),
                        borderRadius: BorderRadius.circular(Hs.rChip),
                      ),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: preview.layers.length,
                        itemBuilder: (context, i) => _LayerRow(preview.layers[i]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Row(
                children: [
                  HsButton(
                    'Cancel',
                    variant: HsVariant.cancel,
                    onTap: () {
                      c.cancelLottieImport();
                      Navigator.pop(context);
                    },
                  ),
                  const Spacer(),
                  HsButton(
                    'Import ${preview.cleanCount} layer${preview.cleanCount == 1 ? '' : 's'}',
                    onTap: preview.cleanCount == 0
                        ? null
                        : () async {
                            await c.commitLottieImport();
                            if (context.mounted) Navigator.pop(context);
                          },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Hs.amber500.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(Hs.rChip),
        border: Border.all(color: Hs.amber500.withValues(alpha: .4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 16, color: Hs.amber500),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: Hs.textBody))),
        ],
      ),
    );
  }
}

class _LayerRow extends StatelessWidget {
  const _LayerRow(this.layer);
  final LayerPreview layer;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (layer.status) {
      LayerPreviewStatus.clean => (Icons.check_circle, Hs.teal500),
      LayerPreviewStatus.flagged => (Icons.warning_amber_rounded, Hs.amber500),
      LayerPreviewStatus.missingAsset => (Icons.error, Hs.coral500),
    };
    final badges = <String>[
      if (layer.groupName != null) 'from precomp "${layer.groupName}"',
      if (layer.sceneIndex != null) 'scene ${layer.sceneIndex}',
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  layer.sourceLayer.name,
                  style: const TextStyle(fontSize: 14, color: Hs.textBody),
                  overflow: TextOverflow.ellipsis,
                ),
                if (layer.reason != null || badges.isNotEmpty)
                  Text(
                    [if (layer.reason != null) layer.reason!, ...badges].join(' · '),
                    style: const TextStyle(fontSize: 12, color: Hs.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Plan Task 6.1: the export side's own, much simpler dialog -- per
/// `lottie_export.dart`'s own doc comment, this direction is deterministic
/// ("the easy direction... no user review step needed"), so there's no
/// per-layer status list here, just the one real choice this app can't
/// auto-detect from a `ComicsDoc` the way import detects it from a real
/// file: which [ExportImportMode] to export as, plus the scroll speed
/// Playback Viewport needs to synthesize its sweep.
Future<void> showLottieExportDialog(BuildContext context) async {
  final c = EditorScope.of(context);
  if (c.doc == null) return;
  var mode = ExportImportMode.fullCanvas;
  var scrollSpeed = 2.5; // matches ASHES.json's real ~2.49-2.50 px/frame convention
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Dialog(
        backgroundColor: Hs.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Hs.rCard)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Export to .lottie',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 18),
                const Text('MODE', style: kSectionLabel),
                const SizedBox(height: 8),
                HsSegmented<ExportImportMode>(
                  values: const [ExportImportMode.fullCanvas, ExportImportMode.playbackViewport],
                  labelOf: (m) => m == ExportImportMode.fullCanvas ? 'Full Canvas' : 'Playback Viewport',
                  selected: mode,
                  onChanged: (m) => setState(() => mode = m),
                  expand: true,
                ),
                if (mode == ExportImportMode.playbackViewport) ...[
                  const SizedBox(height: 18),
                  const Text('SCROLL SPEED (px/frame)', style: kSectionLabel),
                  const SizedBox(height: 8),
                  NumericPropertyControl(
                    label: 'Scroll speed',
                    value: scrollSpeed,
                    min: 0.01,
                    max: 10000,
                    step: 0.1,
                    onPreview: (v) => setState(() => scrollSpeed = v.toDouble()),
                    onCommit: (v) => setState(() => scrollSpeed = v.toDouble()),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    HsButton(
                      'Cancel',
                      variant: HsVariant.cancel,
                      onTap: () => Navigator.pop(ctx),
                    ),
                    const Spacer(),
                    HsButton(
                      'Export',
                      onTap: () async {
                        final ok = await c.exportLottieWithDialog(
                          mode,
                          scrollSpeed: mode == ExportImportMode.playbackViewport ? scrollSpeed : null,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Hs.gray800,
                              content: Text(
                                ok ? 'Exported to .lottie' : 'Export failed: ${c.coreError}',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
