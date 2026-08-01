import 'package:flutter/material.dart';

import '../controller.dart';
import '../theme.dart';
import 'confidence_badge.dart';
import 'scene_panel.dart' show KindChip;

/// vdd-comics-editor-ai-uiux, Task 4.3: Cutting-mode region list -- kind chip + confidence badge
/// + accept/reject status icon per row, a header status summary
/// ("N regions · N pending · N accepted · N rejected"), and a bulk "Accept all >N%" action, per
/// `02-visual.md`'s results screen and its high-fidelity reference.
class CuttingRegionRail extends StatefulWidget {
  const CuttingRegionRail({
    super.key,
    required this.controller,
    required this.selectedIndex,
    required this.onSelect,
  });

  final EditorController controller;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  State<CuttingRegionRail> createState() => _CuttingRegionRailState();
}

class _CuttingRegionRailState extends State<CuttingRegionRail> {
  final double _bulkThreshold = 0.90;

  @override
  Widget build(BuildContext context) {
    final session = widget.controller.cuttingSession;
    final regions = session?.regions ?? const [];
    final pendingCount = regions.where((r) => r.status == RegionStatus.pending).length;
    final acceptedCount = regions.where((r) => r.status == RegionStatus.accepted).length;
    final rejectedCount = regions.where((r) => r.status == RegionStatus.rejected).length;
    final eligibleForBulk = regions
        .where((r) => r.status == RegionStatus.pending && r.region.confidence > _bulkThreshold)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Text(
            regions.isEmpty
                ? 'No regions yet'
                : '${regions.length} regions · $pendingCount pending · '
                    '$acceptedCount accepted · $rejectedCount rejected',
            style: const TextStyle(fontSize: 12, color: Hs.textSecondary),
          ),
        ),
        const Divider(height: 1, color: Hs.divider),
        Expanded(
          child: regions.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Run Cut / Segment to see proposed regions here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Hs.textSecondary, fontSize: 13)),
                  ),
                )
              : ListView.builder(
                  itemCount: regions.length,
                  itemBuilder: (context, i) {
                    final pending = regions[i];
                    final selected = widget.selectedIndex == i;
                    return InkWell(
                      onTap: () => widget.onSelect(i),
                      child: Container(
                        color: selected ? Hs.blue100 : null,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        child: Opacity(
                          opacity: pending.status == RegionStatus.rejected ? .5 : 1,
                          child: Row(children: [
                            KindChip(pending.region.kind),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '#${i + 1}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                                  decoration: pending.status == RegionStatus.rejected
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                            ConfidenceBadge(pending.region.confidence),
                            const SizedBox(width: 8),
                            _StatusIcon(pending.status),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (regions.isNotEmpty) ...[
          const Divider(height: 1, color: Hs.divider),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: eligibleForBulk == 0 ? null : () => _acceptAllAboveThreshold(regions),
                child: Text('Accept all >${(_bulkThreshold * 100).round()}% · '
                    '$eligibleForBulk region${eligibleForBulk == 1 ? '' : 's'}'),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _acceptAllAboveThreshold(List<PendingRegion> regions) async {
    for (var i = 0; i < regions.length; i++) {
      final pending = regions[i];
      if (pending.status == RegionStatus.pending && pending.region.confidence > _bulkThreshold) {
        await widget.controller.acceptRegion(i);
      }
    }
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon(this.status);
  final RegionStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      RegionStatus.accepted => const CircleAvatar(
          radius: 8,
          backgroundColor: Hs.blue500,
          child: Icon(Icons.check, size: 11, color: Colors.white),
        ),
      RegionStatus.rejected => const CircleAvatar(
          radius: 8,
          backgroundColor: Hs.gray400,
          child: Icon(Icons.close, size: 11, color: Colors.white),
        ),
      RegionStatus.pending => const SizedBox(width: 16),
    };
  }
}
