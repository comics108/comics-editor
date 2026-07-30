import 'package:flutter/material.dart';

import '../../app_version.dart';
import '../controller.dart';
import '../models.dart';
import '../responsive.dart';
import '../theme.dart';
import 'common.dart';
import 'dialogs.dart';

/// App brand mark — the comics-editor smiley/speech-bubble glyph from
/// design/comics-editor-logo/app-icon.svg (not the HolySpots pin, which is
/// raster-only and must never be redrawn).
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 34});
  final double size;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(size * .24),
      ),
      child: CustomPaint(size: Size(size, size), painter: _BrandGlyphPainter()),
    );
  }
}

/// Vector redraw of the app-icon.svg mark (400x400 source viewBox): a
/// speech-bubble smiley in Hs.blue500 with dark eyes/mouth cut in.
class _BrandGlyphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 400);

    final fill = Paint()..color = Hs.blue500;
    canvas.drawCircle(const Offset(200, 196), 104, fill);
    canvas.drawPath(
      Path()
        ..moveTo(262, 258)
        ..cubicTo(292, 320, 272, 360, 212, 380)
        ..cubicTo(248, 338, 246, 300, 218, 270)
        ..close(),
      fill,
    );

    final stroke = Paint()
      ..color = const Color(0xFF111111)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
        Path()
          ..moveTo(162, 166)
          ..relativeQuadraticBezierTo(3, 16, -1, 28),
        stroke);
    canvas.drawPath(
        Path()
          ..moveTo(236, 164)
          ..relativeQuadraticBezierTo(5, 15, 1, 29),
        stroke);
    canvas.drawPath(
        Path()
          ..moveTo(142, 230)
          ..relativeQuadraticBezierTo(52, 52, 116, -7),
        stroke);
  }

  @override
  bool shouldRepaint(covariant _BrandGlyphPainter oldDelegate) => false;
}

class TopBar extends StatelessWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final c = EditorScope.of(context);
    final ff = formFactorOf(context);
    // vdd-comics-editor-uiux-lettering: was ff.isPhone only -- at tablet
    // width (up to 1024px) the full non-compact row (brand + title +
    // version badge + doc pill + mode switch + all actions + Divider + lang
    // segmented) genuinely overflows once the mode switch (Task 5.1) is
    // added. Touch devices generally want the denser layout anyway (this
    // flow's iPad-first direction), and the compact branch already has a
    // real Edit/Lettering toggle (icon button) and language picker, not
    // just a phone-specific stub.
    final compact = ff.isTouch;

    return Container(
      height: compact ? 56 : 60,
      color: Hs.white,
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
      child: Row(
        children: [
          BrandMark(size: compact ? 30 : 34),
          const SizedBox(width: 10),
          if (!compact) ...[
            const Text('Comics Editor',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: Hs.blue100, borderRadius: BorderRadius.circular(20)),
              child: Text(AppVersion.current,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Hs.blue500)),
            ),
            const SizedBox(width: 14),
            _DocPill(name: c.doc!.name),
            const SizedBox(width: 14),
            HsSegmented<EditorMode>(
              values: kEditorModes,
              labelOf: (m) => m.label,
              selected: c.mode,
              height: ff.controlH,
              onChanged: c.setMode,
            ),
          ] else
            Expanded(
              child: Text(c.doc!.name,
                  style:
                      const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis),
            ),
          if (!compact) const Spacer(),
          if (compact) ...[
            HsIconButton(
              c.mode == EditorMode.edit ? Icons.chat_bubble_outline : Icons.edit_outlined,
              size: ff.iconBtn,
              tooltip: c.mode == EditorMode.edit ? 'Lettering mode' : 'Edit mode',
              onTap: c.toggleMode,
            ),
            const SizedBox(width: 8),
          ],
          // actions
          HsIconButton(Icons.add, size: ff.iconBtn, onTap: () => showNewDialog(context)),
          const SizedBox(width: 8),
          HsIconButton(Icons.folder_open_outlined,
              size: ff.iconBtn, onTap: () => showOpenDialog(context)),
          const SizedBox(width: 8),
          if (!compact)
            HsButton('Save',
                icon: Icons.file_download_outlined,
                variant: HsVariant.save,
                height: ff.controlH,
                onTap: () => _saved(context))
          else
            HsIconButton(Icons.file_download_outlined,
                size: ff.iconBtn, tooltip: 'Save', onTap: () => _saved(context)),
          if (!compact) ...[
            // v2.9 обвязка: Export / Save As через системный диалог (file_picker).
            const SizedBox(width: 8),
            HsIconButton(Icons.ios_share,
                size: ff.iconBtn, onTap: () => _export(context)),
            // sdd-comics-editor-v2.9-fixes2: Undo/Redo (Ctrl+Z/Ctrl+Shift+Z также
            // работают — см. Shortcuts/Actions в editor_screen.dart).
            const SizedBox(width: 8),
            HsIconButton(Icons.undo,
                size: ff.iconBtn,
                tooltip: 'Undo',
                onTap: c.canUndo ? c.undo : null),
            const SizedBox(width: 8),
            HsIconButton(Icons.redo,
                size: ff.iconBtn,
                tooltip: 'Redo',
                onTap: c.canRedo ? c.redo : null),
            const SizedBox(width: 14),
            const _Divider(),
            const SizedBox(width: 14),
            HsSegmented<Lang>(
              values: kLangs,
              labelOf: (l) => l.label,
              selected: c.lang,
              height: ff.controlH,
              onChanged: c.setLanguage,
            ),
          ] else ...[
            // Compact width can't fit export/undo/redo/language as their own
            // icons alongside mode-toggle/new/open/save (found the hard way:
            // seven+ 44px targets don't fit a phone-width row) -- consolidated
            // into one overflow menu rather than dropping any capability.
            const SizedBox(width: 8),
            PopupMenuButton<void>(
              tooltip: 'More',
              itemBuilder: (_) => [
                PopupMenuItem<void>(onTap: () => _export(context), child: const Text('Export')),
                PopupMenuItem<void>(
                    enabled: c.canUndo, onTap: c.undo, child: const Text('Undo')),
                PopupMenuItem<void>(
                    enabled: c.canRedo, onTap: c.redo, child: const Text('Redo')),
                const PopupMenuDivider(),
                ...kLangs.map((l) => PopupMenuItem<void>(
                    onTap: () => c.setLanguage(l),
                    child: Text('Language: ${l.label}'))),
              ],
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    border: Border.all(color: Hs.cloud200),
                    borderRadius: BorderRadius.circular(Hs.rBtn)),
                child: const Icon(Icons.more_horiz, color: Hs.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // v2.9 обвязка: Export/Save As через системный диалог.
  Future<void> _export(BuildContext context) async {
    final c = EditorScope.of(context);
    if (c.coreDoc == null) return;
    final ok = await c.exportWithDialog();
    if (!context.mounted || !ok && c.coreError == null) return; // отмена — тихо
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Hs.gray800,
      content: Text(ok ? 'Exported ${c.doc!.name}' : 'Export failed: ${c.coreError}'),
    ));
  }

  // v2.9 обвязка: если документ открыт из файла — реальное сохранение через
  // headless-ядро; иначе прежнее поведение макета (снекбар).
  Future<void> _saved(BuildContext context) async {
    final c = EditorScope.of(context);
    var message = 'Saved ${c.doc!.name}';
    if (c.coreDoc != null) {
      final ok = await c.saveToPath();
      if (!ok) message = 'Save failed: ${c.coreError ?? 'unknown error'}';
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Hs.gray800,
      content: Text(message),
    ));
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 28, color: Hs.divider);
}

class _DocPill extends StatelessWidget {
  const _DocPill({required this.name});
  final String name;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Hs.gray50,
        border: Border.all(color: Hs.cloud200),
        borderRadius: BorderRadius.circular(Hs.rChip),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.image_outlined, size: 16, color: Hs.textSecondary),
        const SizedBox(width: 8),
        Text(name, style: const TextStyle(fontSize: 15, color: Hs.textBody)),
        const SizedBox(width: 6),
        const Icon(Icons.expand_more, size: 16, color: Hs.textSecondary),
      ]),
    );
  }
}
