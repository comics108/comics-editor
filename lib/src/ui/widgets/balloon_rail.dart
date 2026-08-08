import 'package:flutter/material.dart';
import 'package:flutter_comics/flutter_comics.dart';

import '../../i18n/language_registry.dart';
import '../controller.dart';
import '../theme.dart';

/// vdd-comics-editor-uiux-lettering, Task 5.2: filtered list of the current
/// page's balloon/caption-kind layers, replacing the general Scene panel in
/// Lettering mode (`02-visual.md`'s "Screen: Lettering mode — iPad
/// landscape"). Status dot is per-*target-language* (`langCode`), not a
/// single balloon-wide flag: solid = artwork ready for that language, ring =
/// text-only, dash = empty.
class BalloonRail extends StatelessWidget {
  const BalloonRail(
    this.c, {
    super.key,
    required this.registry,
    required this.langCode,
  });

  final EditorController c;
  final LanguageRegistry registry;
  final String langCode;

  List<MapEntry<int, EditorLayer>> _balloons() {
    final doc = c.doc;
    if (doc == null) return const [];
    return [
      for (var i = 0; i < doc.layers.length; i++)
        if (doc.layers[i].kind == 'balloon' || doc.layers[i].kind == 'caption')
          MapEntry(i, doc.layers[i]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final balloons = _balloons();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child: Text('BALLOONS (${balloons.length})', style: kSectionLabel),
        ),
        const Divider(height: 1, color: Hs.divider),
        Expanded(
          child: balloons.isEmpty
              ? const _EmptyRail()
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: balloons.length,
                  itemBuilder: (_, i) {
                    final entry = balloons[i];
                    final selected = c.selKind == SelKind.layer && c.selIndex == entry.key;
                    return _BalloonRailRow(
                      layer: entry.value,
                      number: i + 1,
                      selected: selected,
                      registry: registry,
                      langCode: langCode,
                      onTap: () => c.selectLayer(entry.key),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Edge case per `03-specifications.md`: "Lettering mode entered on a file
/// with zero balloon-kind layers ... Rail shows an empty state directing
/// back to Edit mode to tag a layer's kind."
class _EmptyRail extends StatelessWidget {
  const _EmptyRail();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No balloon or caption layers yet.\nSwitch to Edit mode and set a '
          "layer's kind to Balloon or Caption to start lettering.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Hs.textTertiary, fontSize: 13),
        ),
      ),
    );
  }
}

enum _DotState { solid, ring, empty }

class _BalloonRailRow extends StatelessWidget {
  const _BalloonRailRow({
    required this.layer,
    required this.number,
    required this.selected,
    required this.registry,
    required this.langCode,
    required this.onTap,
  });
  final EditorLayer layer;
  final int number;
  final bool selected;
  final LanguageRegistry registry;
  final String langCode;
  final VoidCallback onTap;

  _DotState _dotState() {
    final hasText = (layer.translations[langCode] ?? '').isNotEmpty;
    if (!hasText) return _DotState.empty;
    final index = registry.indexFor(langCode);
    final hasArtwork = index != null &&
        index < layer.images.length &&
        layer.images[index].file.contains('{0}');
    return hasArtwork ? _DotState.solid : _DotState.ring;
  }

  @override
  Widget build(BuildContext context) {
    final isBalloon = layer.kind == 'balloon';
    final chipColor = isBalloon ? Hs.violet500 : Hs.amber500;
    final chipLabel = isBalloon ? 'Bln' : 'Cap';

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? Hs.blue100 : Hs.white,
          border: Border(
            left: BorderSide(color: selected ? Hs.blue500 : Colors.transparent, width: 3),
            top: const BorderSide(color: Hs.dividerLight),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(9, 8, 12, 8),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: chipColor.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(Hs.rChip),
              border: Border.all(color: chipColor.withValues(alpha: .4)),
            ),
            child: Text(chipLabel,
                style:
                    TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: chipColor)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text('#${number.toString().padLeft(2, '0')}',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                    color: Hs.textBody)),
          ),
          _StatusDot(_dotState()),
        ]),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot(this.state);
  final _DotState state;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _DotState.solid:
        return Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(color: Hs.blue500, shape: BoxShape.circle),
        );
      case _DotState.ring:
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Hs.blue500, width: 1.5),
          ),
        );
      case _DotState.empty:
        return const Text('--', style: TextStyle(fontSize: 12, color: Hs.textTertiary));
    }
  }
}
