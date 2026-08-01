import 'package:flutter/material.dart';

import '../controller.dart';
import '../theme.dart';
import 'common.dart';
import 'confidence_badge.dart';
import 'scene_panel.dart' show KindChip;

/// vdd-comics-editor-ai-uiux, Task 4.2: shared, kind-parameterized review card for one selected
/// Cutting-mode region -- `02-visual.md`'s Component section ("CuttingReviewCard"). One card
/// instance per selected region; kind-conditional actions ("Insert into library" for
/// character/background, "Open in Lettering" shortcut for balloon) render inside the same shape
/// rather than four bespoke cards, per Requirements' resolved Open Question.
class CuttingReviewCard extends StatefulWidget {
  const CuttingReviewCard({
    super.key,
    required this.controller,
    required this.regionIndex,
    this.onOpenInLettering,
  });

  final EditorController controller;
  final int regionIndex;

  /// Balloon-kind regions offer a shortcut into Lettering mode once accepted -- the actual mode
  /// switch is owned by whatever hosts this card (Task 6.1's mode enum lives in `editor_screen`
  /// territory), so this card just calls back rather than depending on it directly.
  final VoidCallback? onOpenInLettering;

  @override
  State<CuttingReviewCard> createState() => _CuttingReviewCardState();
}

class _CuttingReviewCardState extends State<CuttingReviewCard> {
  static const _kinds = ['background', 'character', 'balloon', 'art'];

  @override
  Widget build(BuildContext context) {
    final session = widget.controller.cuttingSession;
    final pending = session?.regions[widget.regionIndex];
    if (pending == null) return const SizedBox.shrink();
    final region = pending.region;
    final canEdit = pending.status == RegionStatus.pending;

    return PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Expanded(
                child: Text('Region #${widget.regionIndex + 1}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ),
              KindChip(region.kind),
              const SizedBox(width: 8),
              ConfidenceBadge(region.confidence),
            ]),
          ),
          const Divider(height: 1, color: Hs.divider),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: region.bbox.width <= 0 || region.bbox.height <= 0
                      ? 1
                      : region.bbox.width / region.bbox.height,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Hs.divider),
                      borderRadius: BorderRadius.circular(Hs.rChip),
                      color: Hs.gray50,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.memory(region.cropPng, fit: BoxFit.contain,
                        errorBuilder: (context, error, stack) => const Center(
                            child: Icon(Icons.broken_image_outlined, color: Hs.gray400))),
                  ),
                ),
                const SizedBox(height: 6),
                const Text('Crop preview · boundary editable on canvas with resize handles',
                    style: TextStyle(fontSize: 12, color: Hs.textSecondary)),
                const SizedBox(height: 14),
                const Text('KIND', style: kSectionLabel),
                const SizedBox(height: 8),
                _KindDropdown(
                  value: region.kind,
                  kinds: _kinds,
                  enabled: canEdit,
                  onChanged: (k) => widget.controller.reclassifyRegion(widget.regionIndex, k),
                ),
                if (region.kind == 'character' || region.kind == 'background') ...[
                  const SizedBox(height: 8),
                  _InsertIntoLibraryButton(
                    controller: widget.controller,
                    regionIndex: widget.regionIndex,
                    enabled: pending.status == RegionStatus.accepted,
                  ),
                ],
                if (region.kind == 'balloon' && pending.status == RegionStatus.accepted) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: widget.onOpenInLettering,
                      child: const Text('Open in Lettering'),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                _ActionRow(
                  controller: widget.controller,
                  regionIndex: widget.regionIndex,
                  status: pending.status,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KindDropdown extends StatelessWidget {
  const _KindDropdown({
    required this.value,
    required this.kinds,
    required this.enabled,
    required this.onChanged,
  });
  final String value;
  final List<String> kinds;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Hs.cloud200, width: 2),
        borderRadius: BorderRadius.circular(Hs.rChip),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          onChanged: enabled ? (v) => v != null ? onChanged(v) : null : null,
          items: [
            for (final k in kinds)
              DropdownMenuItem(value: k, child: Text(_label(k), style: serifValue(Hs.textBody))),
          ],
        ),
      ),
    );
  }

  String _label(String kind) => switch (kind) {
        'background' => 'Background',
        'character' => 'Character',
        'balloon' => 'Balloon',
        _ => 'Art',
      };
}

class _InsertIntoLibraryButton extends StatelessWidget {
  const _InsertIntoLibraryButton({
    required this.controller,
    required this.regionIndex,
    required this.enabled,
  });
  final EditorController controller;
  final int regionIndex;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: enabled ? () => _promptAndInsert(context) : null,
        icon: const Icon(Icons.add, size: 15),
        label: const Text('Insert into library'),
      ),
    );
  }

  Future<void> _promptAndInsert(BuildContext context) async {
    final controllerText = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Insert into library'),
        content: TextField(
          controller: controllerText,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. amba (blank = unclustered)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, controllerText.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name == null) return; // cancelled
    await controller.insertIntoLibrary(regionIndex, name);
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.controller, required this.regionIndex, required this.status});
  final EditorController controller;
  final int regionIndex;
  final RegionStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == RegionStatus.accepted) {
      return const Row(children: [
        Icon(Icons.check_circle, color: Hs.blue500, size: 18),
        SizedBox(width: 8),
        Text('Accepted — now a layer', style: TextStyle(color: Hs.textSecondary, fontSize: 13)),
      ]);
    }
    if (status == RegionStatus.rejected) {
      return Row(children: [
        const Icon(Icons.cancel, color: Hs.gray400, size: 18),
        const SizedBox(width: 8),
        const Expanded(
            child: Text('Rejected', style: TextStyle(color: Hs.textSecondary, fontSize: 13))),
        TextButton(
          onPressed: () => controller.unrejectRegion(regionIndex),
          child: const Text('Undo'),
        ),
      ]);
    }
    return Row(children: [
      Expanded(
        child: HsButton(
          'Accept',
          onTap: () => controller.acceptRegion(regionIndex),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: HsButton(
          'Reject',
          variant: HsVariant.cancel,
          onTap: () => controller.rejectRegion(regionIndex),
        ),
      ),
    ]);
  }
}
