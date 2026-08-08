import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_comics/flutter_comics.dart';

import '../../bridge/documents.dart';
import '../controller.dart';
import '../theme.dart';
import 'common.dart';

bool get _isMobile => Platform.isIOS || Platform.isAndroid;

/// New / Open / Error dialogs — same actions as the WPF menu, no new features.

Future<void> showNewDialog(BuildContext context) async {
  final c = EditorScope.of(context);
  DocType choice = DocType.comics;
  // tdd-dot-comics-format Plan Task 2.3: independent of `choice` and of
  // each other -- neither is inferred from the other (03-specifications.md).
  ScrollType scrollType = ScrollType.vertical;
  PreferredOrientation preferredOrientation = PreferredOrientation.portrait;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => _DialogShell(
        title: 'New document',
        width: 760,
        actions: [
          HsButton(
            'Cancel',
            variant: HsVariant.cancel,
            onTap: () => Navigator.pop(ctx),
          ),
          const SizedBox(width: 10),
          HsButton(
            'Create',
            onTap: () {
              c.newDoc(
                choice,
                scrollType: scrollType,
                preferredOrientation: preferredOrientation,
              );
              Navigator.pop(ctx);
            },
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('DOCUMENT TYPE', style: kSectionLabel),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final cards = <Widget>[
                  _TypeCard(
                    title: 'Vertical-scroll comic strip',
                    subtitle: 'Default · infinite vertical reading flow.',
                    selected:
                        choice == DocType.comics &&
                        scrollType == ScrollType.vertical,
                    preview: _stripPreview(),
                    onTap: () => setState(() {
                      choice = DocType.comics;
                      scrollType = ScrollType.vertical;
                    }),
                  ),
                  _TypeCard(
                    title: 'Horizontal-scroll comic strip',
                    // tdd-dot-comics-format Plan Task 2.3: sets the
                    // document's scrollType for real now -- the canvas/
                    // viewer playback direction itself is a separate,
                    // still-vertical-only capability, not part of this
                    // schema/dialog wiring.
                    subtitle:
                        'Sets the document\'s scroll axis; canvas/viewer '
                        'playback is still vertical-only.',
                    selected:
                        choice == DocType.comics &&
                        scrollType == ScrollType.horizontal,
                    preview: _stripPreview(),
                    onTap: () => setState(() {
                      choice = DocType.comics;
                      scrollType = ScrollType.horizontal;
                    }),
                  ),
                  _TypeCard(
                    title: 'Puzzle',
                    subtitle: 'Zoomable board of draggable pieces.',
                    selected: choice == DocType.puzzle,
                    preview: _boardPreview(),
                    onTap: () => setState(() => choice = DocType.puzzle),
                  ),
                ];
                if (constraints.maxWidth < 620) {
                  return Column(
                    children: [
                      for (var i = 0; i < cards.length; i++) ...[
                        cards[i],
                        if (i != cards.length - 1) const SizedBox(height: 10),
                      ],
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      Expanded(child: cards[i]),
                      if (i != cards.length - 1) const SizedBox(width: 12),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            const Text('DEVICE ORIENTATION', style: kSectionLabel),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _OptionTile(
                    icon: Icons.stay_current_portrait,
                    label: 'Portrait',
                    selected:
                        preferredOrientation == PreferredOrientation.portrait,
                    enabled: true,
                    onTap: () => setState(
                      () =>
                          preferredOrientation = PreferredOrientation.portrait,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _OptionTile(
                    icon: Icons.stay_current_landscape,
                    label: 'Landscape',
                    selected:
                        preferredOrientation == PreferredOrientation.landscape,
                    enabled: true,
                    onTap: () => setState(
                      () =>
                          preferredOrientation = PreferredOrientation.landscape,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // tdd-dot-comics-format Plan Task 2.4: the real dialog only
                // ever drew 2 tiles -- this third one didn't exist before.
                Expanded(
                  child: _OptionTile(
                    icon: Icons.screen_rotation_alt_outlined,
                    label: 'Auto',
                    selected: preferredOrientation == PreferredOrientation.auto,
                    enabled: true,
                    onTap: () => setState(
                      () => preferredOrientation = PreferredOrientation.auto,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> showOpenDialog(BuildContext context) async {
  final c = EditorScope.of(context);
  int sel = 0;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => _DialogShell(
        title: 'Open',
        width: 480,
        actions: [
          // v2.9 обвязка: Browse… — системный диалог выбора файла (file_picker).
          HsButton(
            'Browse…',
            variant: HsVariant.secondary,
            onTap: () async {
              Navigator.pop(ctx);
              final ok = await c.openWithDialog();
              if (!ok && c.coreError != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    behavior: SnackBarBehavior.floating,
                    content: Text('Open failed: ${c.coreError}'),
                  ),
                );
              }
            },
          ),
          const Spacer(),
          // v2.9: на мобильных локальный документ открывается тапом по строке.
          if (!_isMobile)
            HsButton(
              'Open',
              onTap: () {
                c.openRecent(EditorController.recents[sel]);
                Navigator.pop(ctx);
              },
            ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Hs.cloud200, width: 2),
                borderRadius: BorderRadius.circular(Hs.rChip),
              ),
              child: const Row(
                children: [
                  Icon(Icons.search, size: 16, color: Hs.textSecondary),
                  SizedBox(width: 10),
                  Text(
                    'Search…',
                    style: TextStyle(color: Hs.textTertiary, fontSize: 15),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // v2.9: на мобильных — реальные документы из песочницы приложения.
            if (_isMobile)
              FutureBuilder<List<FileSystemEntity>>(
                future: DocumentsStore.list(),
                builder: (ctx2, snap) {
                  final files = snap.data ?? const <FileSystemEntity>[];
                  if (files.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No local documents yet — use Browse…',
                        style: TextStyle(color: Hs.textSecondary, fontSize: 14),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final f in files)
                        _RecentRow(
                          file: RecentFile(
                            f.path.split('/').last,
                            f.path.endsWith('.puzzle')
                                ? DocType.puzzle
                                : DocType.comics,
                            'Local document',
                          ),
                          selected: false,
                          onTap: () async {
                            Navigator.pop(ctx);
                            await c.openPath(f.path);
                          },
                        ),
                    ],
                  );
                },
              )
            else
              for (var i = 0; i < EditorController.recents.length; i++)
                _RecentRow(
                  file: EditorController.recents[i],
                  selected: i == sel,
                  onTap: () => setState(() => sel = i),
                ),
          ],
        ),
      ),
    ),
  );
}

Future<void> showDuplicateError(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => _DialogShell(
      title: null,
      width: 380,
      actions: [
        const Spacer(),
        HsButton('OK', onTap: () => Navigator.pop(ctx)),
      ],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Hs.coral500,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close, color: Hs.white, size: 18),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'File already exists',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 4),
                Text(
                  'A file with this name already exists. Choose a different name.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Hs.textBody,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// tdd-dot-comics-format Plan Task 4.3, `04-visual.md` Screen 4: "a standard
// color picker, no new component needed" -- no color-picker package exists
// in this project (checked pubspec.yaml/pubspec.lock), and adding a new
// dependency for one dialog is a bigger call than this task warrants. A
// small preset-swatch grid + hex field is a complete, real picker without
// one -- no half-built "type raw hex only" fallback.
const List<Color> _solidColorPresets = [
  Hs.white,
  Color(0xFF000000),
  Hs.blue500,
  Hs.coral500,
  Hs.teal500,
  Hs.amber500,
  Hs.violet500,
  Hs.indigo500,
];

String colorToHex(Color color) =>
    '#${((color.a * 255).round() == 255 ? '' : (color.a * 255).round().toRadixString(16).padLeft(2, '0'))}'
    '${(color.r * 255).round().toRadixString(16).padLeft(2, '0')}'
    '${(color.g * 255).round().toRadixString(16).padLeft(2, '0')}'
    '${(color.b * 255).round().toRadixString(16).padLeft(2, '0')}';

Color? colorFromHex(String hex) {
  var value = hex.trim();
  if (value.startsWith('#')) value = value.substring(1);
  if (value.length == 6) value = 'FF$value';
  if (value.length != 8) return null;
  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? null : Color(parsed);
}

/// Returns the picked color, or null if cancelled.
Future<Color?> showSolidColorPicker(BuildContext context) async {
  Color picked = Hs.white;
  final hexController = TextEditingController(text: colorToHex(picked));
  return showDialog<Color>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => _DialogShell(
        title: 'Solid color layer',
        width: 380,
        actions: [
          HsButton(
            'Cancel',
            variant: HsVariant.cancel,
            onTap: () => Navigator.pop(ctx),
          ),
          const SizedBox(width: 10),
          HsButton('Create', onTap: () => Navigator.pop(ctx, picked)),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final swatch in _solidColorPresets)
                  InkWell(
                    onTap: () => setState(() {
                      picked = swatch;
                      hexController.text = colorToHex(picked);
                    }),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: swatch,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: swatch == picked ? Hs.blue500 : Hs.divider,
                          width: swatch == picked ? 2 : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: hexController,
              decoration: const InputDecoration(labelText: 'Hex color'),
              onChanged: (value) {
                final parsed = colorFromHex(value);
                if (parsed != null) setState(() => picked = parsed);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

// ---------------- shared shell ----------------

class _DialogShell extends StatelessWidget {
  const _DialogShell({
    required this.title,
    required this.width,
    required this.child,
    required this.actions,
  });
  final String? title;
  final double width;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Hs.white,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Hs.rCard),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Hs.divider)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title!,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close,
                        size: 18,
                        color: Hs.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(padding: const EdgeInsets.all(20), child: child),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(children: actions),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.preview,
    required this.onTap,
  });
  final String title, subtitle;
  final bool selected;
  final Widget preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? Hs.blue500 : Hs.divider,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(Hs.rCard),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 100, child: preview),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Hs.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.enabled,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final bool enabled;
  // tdd-dot-comics-format Plan Task 2.3: was permanently non-interactive
  // (Portrait had no way to toggle since Landscape was disabled) -- now a
  // real tap target when the caller wants one.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      enabled: enabled,
      selected: selected,
      button: true,
      child: Opacity(
        opacity: enabled ? 1 : .5,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(Hs.rChip),
          child: Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: selected ? Hs.blue100 : Hs.white,
              border: Border.all(color: selected ? Hs.blue500 : Hs.divider),
              borderRadius: BorderRadius.circular(Hs.rChip),
            ),
            child: Row(
              children: [
                Icon(icon, color: selected ? Hs.blue500 : Hs.textSecondary),
                const SizedBox(width: 10),
                Expanded(child: Text(label)),
                if (!enabled) const Icon(Icons.lock_outline, size: 17),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({
    required this.file,
    required this.selected,
    required this.onTap,
  });
  final RecentFile file;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final puzzle = file.type == DocType.puzzle;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Hs.blue100 : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: selected ? Hs.blue500 : Hs.cloud200,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Icon(
                puzzle ? Icons.grid_view : Icons.image_outlined,
                size: 15,
                color: selected ? Hs.white : Hs.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(file.name, style: const TextStyle(fontSize: 15)),
                  Text(
                    file.meta,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Hs.textSecondary,
                    ),
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

Widget _stripPreview() =>
    CustomPaint(painter: _StripPainter(), child: const SizedBox.expand());
Widget _boardPreview() =>
    CustomPaint(painter: _BoardPainter(), child: const SizedBox.expand());

class _StripPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    for (double y = 0; y < size.height; y += 22) {
      p.color = (y / 22).floor().isEven
          ? const Color(0xFF26384D)
          : const Color(0xFF2C4256);
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 22), p);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _BoardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cell = 22.0;
    final p = Paint();
    for (double y = 0; y < size.height; y += cell) {
      for (double x = 0; x < size.width; x += cell) {
        final even = (((x / cell) + (y / cell)).floor()).isEven;
        p.color = even ? const Color(0xFF3A4A58) : const Color(0xFF455663);
        canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), p);
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
