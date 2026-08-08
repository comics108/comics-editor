import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_comics_viewer/flutter_comics_viewer.dart';

import '../controller.dart';
import '../editor_mode.dart';
import '../theme.dart';
import 'common.dart';

class ViewerWorkspace extends StatelessWidget {
  const ViewerWorkspace({super.key, this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final editor = EditorScope.of(context);
    final controller = editor.viewerController;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        final document = editor.doc!;
        final profile = editor.targetDeviceProfile;
        final visibleFraction = document.height <= 0
            ? 1.0
            : (profile.verticalViewportHeight(document.width.toDouble()) /
                      document.height)
                  .clamp(0.0, 1.0);
        return ColoredBox(
          color: Hs.gray800,
          child: Column(
            children: [
              _ViewerToolbar(editor: editor, onClose: onClose),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _TargetDeviceViewport(
                        aspectRatio: profile.width / profile.height,
                        profileLabel:
                            '${profile.label} · ${profile.dimensionsLabel}',
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ComicsViewer(controller: controller),
                            if (state.phase != ComicsViewerPhase.loaded)
                              _ViewerState(editor: editor, state: state),
                          ],
                        ),
                      ),
                    ),
                    VerticalPositionSelector(
                      value: state.position,
                      visibleFraction: visibleFraction,
                      profileLabel: profile.label,
                      enabled: state.phase == ComicsViewerPhase.loaded,
                      onChanged: (value) =>
                          unawaited(controller.setScrollPosition(value)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TargetDeviceViewport extends StatelessWidget {
  const _TargetDeviceViewport({
    required this.aspectRatio,
    required this.profileLabel,
    required this.child,
  });

  final double aspectRatio;
  final String profileLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = (constraints.maxWidth - 24).clamp(
          0.0,
          double.infinity,
        );
        final maxHeight = (constraints.maxHeight - 24).clamp(
          0.0,
          double.infinity,
        );
        var width = maxWidth;
        var height = width / aspectRatio;
        if (height > maxHeight) {
          height = maxHeight;
          width = height * aspectRatio;
        }
        return Center(
          child: Tooltip(
            message: 'Target viewport: $profileLabel',
            child: Container(
              key: const ValueKey('viewer-target-device-viewport'),
              width: width,
              height: height,
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color: Hs.gray800,
                border: Border.all(color: Hs.gray600),
                borderRadius: BorderRadius.circular(6),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _ViewerToolbar extends StatelessWidget {
  const _ViewerToolbar({required this.editor, this.onClose});
  final EditorController editor;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final controller = editor.viewerController;
    final playing = controller.state.playing;
    return Material(
      color: Hs.white,
      child: SizedBox(
        height: 52,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              HsIconButton(
                Icons.arrow_back,
                tooltip: 'Back to Editor',
                onTap:
                    onClose ??
                    () => editor.setWorkspace(EditorWorkspace.editor),
              ),
              const SizedBox(width: 10),
              const Text(
                'Viewer',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              HsIconButton(
                playing ? Icons.pause : Icons.play_arrow,
                tooltip: playing ? 'Pause' : 'Play',
                onTap: controller.state.phase == ComicsViewerPhase.loaded
                    ? () => unawaited(
                        playing ? controller.pause() : controller.play(),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              HsIconButton(
                Icons.refresh,
                tooltip: 'Refresh preview',
                onTap: () => unawaited(editor.refreshViewer()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewerState extends StatelessWidget {
  const _ViewerState({required this.editor, required this.state});
  final EditorController editor;
  final ComicsViewerState state;

  @override
  Widget build(BuildContext context) {
    final (icon, title, detail) = switch (state.phase) {
      ComicsViewerPhase.idle => (
        Icons.visibility_outlined,
        'Preparing preview',
        'The current document will appear here.',
      ),
      ComicsViewerPhase.loading => (
        Icons.hourglass_top,
        'Refreshing preview',
        'Building the latest unsaved revision…',
      ),
      ComicsViewerPhase.error => (
        Icons.error_outline,
        'Preview could not be loaded',
        state.error ?? 'Unknown Viewer error',
      ),
      ComicsViewerPhase.unsupported => (
        Icons.desktop_access_disabled_outlined,
        'Viewer is unavailable on this platform',
        state.error ?? 'Return to Editor to keep working.',
      ),
      ComicsViewerPhase.loaded => (Icons.check, '', ''),
    };
    return ColoredBox(
      color: Hs.gray800.withValues(alpha: .96),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 38, color: Hs.white),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Hs.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Hs.gray400, height: 1.4),
                ),
                if (state.phase == ComicsViewerPhase.error) ...[
                  const SizedBox(height: 18),
                  HsButton(
                    'Retry',
                    icon: Icons.refresh,
                    onTap: () => unawaited(editor.refreshViewer()),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class VerticalPositionSelector extends StatelessWidget {
  const VerticalPositionSelector({
    super.key,
    required this.value,
    required this.visibleFraction,
    required this.profileLabel,
    required this.enabled,
    required this.onChanged,
  });

  final double value;
  final double visibleFraction;
  final String profileLabel;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final normalized = value.clamp(0.0, 1.0);
    final extent = visibleFraction.clamp(0.0, 1.0);
    final start = normalized * (1 - extent);
    final end = (start + extent).clamp(0.0, 1.0);
    final startPercent = (start * 100).round();
    final endPercent = (end * 100).round();
    String rangeValue(double position) {
      final nextStart = position.clamp(0.0, 1.0) * (1 - extent);
      final nextEnd = (nextStart + extent).clamp(0.0, 1.0);
      return '$profileLabel, ${(nextStart * 100).round()}% to '
          '${(nextEnd * 100).round()}%';
    }

    void change(double next) {
      if (enabled) onChanged(next.clamp(0.0, 1.0));
    }

    void changeFromTrack(double y, double height) {
      if (!enabled || height <= 0 || extent >= 1) return;
      final center = (y / height).clamp(0.0, 1.0);
      final nextStart = (center - extent / 2).clamp(0.0, 1 - extent);
      change(nextStart / (1 - extent));
    }

    return CallbackShortcuts(
      bindings: enabled
          ? <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.home): () => change(0),
              const SingleActivator(LogicalKeyboardKey.end): () => change(1),
              const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                  change(normalized - .01),
              const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                  change(normalized + .01),
            }
          : const <ShortcutActivator, VoidCallback>{},
      child: Semantics(
        excludeSemantics: true,
        label: 'Viewer visible range',
        value: '$profileLabel, $startPercent% to $endPercent%',
        increasedValue: enabled ? rangeValue(normalized + .01) : null,
        decreasedValue: enabled ? rangeValue(normalized - .01) : null,
        enabled: enabled,
        onIncrease: enabled ? () => change(normalized + .01) : null,
        onDecrease: enabled ? () => change(normalized - .01) : null,
        child: Container(
          key: const ValueKey('viewer-position-right-edge'),
          width: 56,
          color: Hs.gray800,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              const Text(
                'START',
                style: TextStyle(fontSize: 9, color: Hs.gray400),
              ),
              const SizedBox(height: 4),
              Text(
                profileLabel,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9,
                  color: Hs.gray400,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final height = constraints.maxHeight;
                    final bandTop = start * height;
                    final bandHeight = (end - start) * height;
                    return Tooltip(
                      message:
                          '$profileLabel visible: $startPercent%–$endPercent%',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: enabled
                            ? (details) => changeFromTrack(
                                details.localPosition.dy,
                                height,
                              )
                            : null,
                        onVerticalDragStart: enabled
                            ? (details) => changeFromTrack(
                                details.localPosition.dy,
                                height,
                              )
                            : null,
                        onVerticalDragUpdate: enabled
                            ? (details) => changeFromTrack(
                                details.localPosition.dy,
                                height,
                              )
                            : null,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              top: 0,
                              bottom: 0,
                              left: 26,
                              child: Container(
                                width: 4,
                                decoration: BoxDecoration(
                                  color: Hs.gray600,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            Positioned(
                              key: const ValueKey('viewer-visible-range'),
                              top: bandTop,
                              left: 10,
                              width: 36,
                              height: bandHeight,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: enabled
                                      ? Hs.coral500.withValues(alpha: .32)
                                      : Hs.gray600.withValues(alpha: .35),
                                  border: Border.symmetric(
                                    horizontal: BorderSide(
                                      color: enabled ? Hs.coral500 : Hs.gray500,
                                      width: 2,
                                    ),
                                  ),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$startPercent–$endPercent%',
                style: const TextStyle(
                  fontSize: 9,
                  color: Hs.gray400,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'END',
                style: TextStyle(fontSize: 9, color: Hs.gray400),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
