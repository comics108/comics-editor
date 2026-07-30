import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../i18n/language_registry.dart';
import '../controller.dart';
import '../models.dart';
import '../responsive.dart';
import '../theme.dart';
import '../widgets/balloon_editor_card.dart';
import '../widgets/balloon_rail.dart';
import '../widgets/canvas_view.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';
import '../widgets/properties_panel.dart';
import '../widgets/scene_panel.dart';
import '../widgets/timeline.dart';
import '../widgets/top_bar.dart';

/// Ctrl+Z / Ctrl+Shift+Z — bound via [Shortcuts]/[Actions] (not a raw keyboard
/// listener) so Flutter's own focus/action resolution keeps working: a
/// focused [TextField] registers its own undo Actions closer to the focus
/// than this screen-level [Shortcuts], so text-field undo still wins there
/// instead of being stolen by the document-level shortcut.
class UndoIntent extends Intent {
  const UndoIntent();
}

class RedoIntent extends Intent {
  const RedoIntent();
}

/// Adaptive assembly of the editor:
///  • desktop  — Scene | Canvas | Properties, full timeline docked below
///  • tablet   — Scene | Canvas | Properties (narrower), compact timeline
///  • phone    — Canvas full-bleed; Scene / Properties / Timeline as sheets
class EditorScreen extends StatelessWidget {
  const EditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = EditorScope.of(context);
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        if (!c.isOpen) return const _Welcome();
        final ff = formFactorOf(context);
        return Shortcuts(
          shortcuts: {
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ):
                const UndoIntent(),
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift,
                LogicalKeyboardKey.keyZ): const RedoIntent(),
          },
          child: Actions(
            actions: {
              UndoIntent: CallbackAction<UndoIntent>(onInvoke: (_) => c.undo()),
              RedoIntent: CallbackAction<RedoIntent>(onInvoke: (_) => c.redo()),
            },
            child: Scaffold(
              backgroundColor: Hs.surfaceCloud,
              body: SafeArea(
                child: Column(
                  children: [
                    Material(
                      elevation: 0,
                      color: Hs.white,
                      child: const TopBar(),
                    ),
                    const Divider(height: 1, color: Hs.divider),
                    Expanded(
                      child: c.mode == EditorMode.lettering
                          ? switch (ff) {
                              FormFactor.desktop => const _LetteringDesktopBody(),
                              FormFactor.tablet => const _LetteringTabletBody(),
                              FormFactor.phone => const _LetteringPhoneBody(),
                            }
                          : switch (ff) {
                              FormFactor.desktop => const _DesktopBody(),
                              FormFactor.tablet => const _TabletBody(),
                              FormFactor.phone => const _PhoneBody(),
                            },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------- lettering mode ----------------

bool _isBalloonKind(EditorLayer? l) => l != null && (l.kind == 'balloon' || l.kind == 'caption');

/// vdd-comics-editor-uiux-lettering, Task 5.6: `[<] N/M [>]` prev/next
/// stepper, shared across all three platform Lettering layouts
/// (`02-visual.md`'s `[<prev] N/M [next>]` header element). Renders nothing
/// when there's no balloon-step position to show (no balloon/caption layers,
/// or nothing selected) -- callers don't need to guard on that themselves.
class _BalloonStepper extends StatelessWidget {
  const _BalloonStepper(this.c, {this.compact = false});
  final EditorController c;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final info = c.balloonStepInfo();
    if (info == null) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      HsIconButton(Icons.chevron_left,
          size: compact ? 32 : 28,
          tooltip: 'Previous balloon',
          onTap: info.position > 1 ? () => c.stepBalloon(-1) : null),
      Text('${info.position}/${info.total}',
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w500, color: Hs.textSecondary)),
      HsIconButton(Icons.chevron_right,
          size: compact ? 32 : 28,
          tooltip: 'Next balloon',
          onTap: info.position < info.total ? () => c.stepBalloon(1) : null),
    ]);
  }
}

/// vdd-comics-editor-uiux-lettering, Task 5.3: three-pane desktop Lettering
/// layout (`02-visual.md`'s "Screen: Lettering mode — Desktop") -- same
/// frame as `_DesktopBody`, with the balloon rail where Scene normally
/// sits and the balloon editor where Properties normally sits. The canvas
/// in the middle is the existing [CanvasView] unmodified: it already draws
/// selection handles around whichever layer is selected
/// (`c.selKind == SelKind.layer && c.selIndex == i`), and [BalloonRail]
/// selects through the same `EditorController.selectLayer`, so "current
/// balloon highlighted in context on the full page" falls out for free.
class _LetteringDesktopBody extends StatelessWidget {
  const _LetteringDesktopBody();
  @override
  Widget build(BuildContext context) {
    final c = EditorScope.of(context);
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(children: [
        SizedBox(
          width: 300,
          child: PanelCard(
            child: FutureBuilder<LanguageRegistry>(
              future: c.languageRegistry,
              builder: (context, snapshot) {
                final registry = snapshot.data;
                if (registry == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return BalloonRail(c, registry: registry, langCode: c.lang.name);
              },
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(child: CanvasView()),
        const SizedBox(width: 10),
        SizedBox(
          width: 330,
          child: PanelCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (c.balloonStepInfo() != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                  child: Align(alignment: Alignment.centerRight, child: _BalloonStepper(c)),
                ),
              Expanded(
                child: _isBalloonKind(c.selectedLayer)
                    ? Padding(
                        padding: const EdgeInsets.all(14),
                        child: SingleChildScrollView(
                          child: FutureBuilder<LanguageRegistry>(
                            future: c.languageRegistry,
                            builder: (context, snapshot) {
                              final registry = snapshot.data;
                              if (registry == null) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              return BalloonEditorCard(
                                key: ValueKey(c.selectedLayer),
                                controller: c,
                                layer: c.selectedLayer!,
                                registry: registry,
                                aiClient: c.aiClient,
                              );
                            },
                          ),
                        ),
                      )
                    : const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Select a balloon or caption layer from the rail',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Hs.textTertiary, fontSize: 14)),
                        ),
                      ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// vdd-comics-editor-uiux-lettering, Task 5.4: iPad-landscape Lettering
/// layout (`02-visual.md`'s "Screen: Lettering mode — iPad landscape
/// (primary target)") -- two-pane, no canvas (unlike desktop's three-pane):
/// a narrower rail and a large, touch-first balloon editor filling the rest
/// of the width. Omitting the canvas here (vs. Task 5.3's desktop layout)
/// is deliberate per the visual spec, to keep touch targets large on the
/// tighter landscape viewport rather than squeezing in a third pane.
/// Prev/next stepping (Task 5.6, the `[<prev] N/M [next>]` header element in
/// the mockup) is shared across all three platform layouts.
class _LetteringTabletBody extends StatelessWidget {
  const _LetteringTabletBody();
  @override
  Widget build(BuildContext context) {
    final c = EditorScope.of(context);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(children: [
        SizedBox(
          width: 300,
          child: PanelCard(
            child: FutureBuilder<LanguageRegistry>(
              future: c.languageRegistry,
              builder: (context, snapshot) {
                final registry = snapshot.data;
                if (registry == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return BalloonRail(c, registry: registry, langCode: c.lang.name);
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: PanelCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (c.balloonStepInfo() != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: Align(
                      alignment: Alignment.centerRight,
                      child: _BalloonStepper(c, compact: true)),
                ),
              Expanded(
                child: _isBalloonKind(c.selectedLayer)
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: SingleChildScrollView(
                          child: FutureBuilder<LanguageRegistry>(
                            future: c.languageRegistry,
                            builder: (context, snapshot) {
                              final registry = snapshot.data;
                              if (registry == null) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              return BalloonEditorCard(
                                key: ValueKey(c.selectedLayer),
                                controller: c,
                                layer: c.selectedLayer!,
                                registry: registry,
                                aiClient: c.aiClient,
                              );
                            },
                          ),
                        ),
                      )
                    : const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Select a balloon or caption layer from the rail',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Hs.textTertiary, fontSize: 14)),
                        ),
                      ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// vdd-comics-editor-uiux-lettering, Task 5.5: iPhone two-screen Lettering
/// flow (`02-visual.md`'s "Screen: Lettering mode — iPhone") -- a balloon
/// *list* screen and a balloon *editor* screen, kept at the same one-tap
/// depth as the other platforms rather than nesting further. Both screens
/// reuse [BalloonRail]/[BalloonEditorCard] full-width (neither widget
/// hardcodes a narrow sidebar width -- the caller's constraints decide),
/// so there's no separate phone-specific rail/card implementation. The
/// "screen" transition is a simple conditional swap driven by selection
/// state (matches how every other mode/pane switch in this app works, e.g.
/// [EditorController.mode] itself), not a pushed route -- back is
/// [EditorController.deselectForLettering], not `Navigator.pop`.
class _LetteringPhoneBody extends StatelessWidget {
  const _LetteringPhoneBody();
  @override
  Widget build(BuildContext context) {
    final c = EditorScope.of(context);
    return FutureBuilder<LanguageRegistry>(
      future: c.languageRegistry,
      builder: (context, snapshot) {
        final registry = snapshot.data;
        if (registry == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_isBalloonKind(c.selectedLayer)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
                child: Row(children: [
                  TextButton.icon(
                    onPressed: c.deselectForLettering,
                    icon: const Icon(Icons.arrow_back_ios_new, size: 16),
                    label: const Text('Balloons'),
                  ),
                  const Spacer(),
                  _BalloonStepper(c, compact: true),
                ]),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: SingleChildScrollView(
                    child: BalloonEditorCard(
                      key: ValueKey(c.selectedLayer),
                      controller: c,
                      layer: c.selectedLayer!,
                      registry: registry,
                      aiClient: c.aiClient,
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        return BalloonRail(c, registry: registry, langCode: c.lang.name);
      },
    );
  }
}

// ---------------- desktop ----------------

class _DesktopBody extends StatelessWidget {
  const _DesktopBody();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(children: [
        Expanded(
          child: Row(children: const [
            SizedBox(width: 300, child: ScenePanel()),
            SizedBox(width: 10),
            Expanded(child: CanvasView()),
            SizedBox(width: 10),
            SizedBox(width: 330, child: PropertiesPanel()),
          ]),
        ),
        const SizedBox(height: 10),
        const SizedBox(height: 190, child: Timeline()),
      ]),
    );
  }
}

// ---------------- tablet (iPad / Android tablet) ----------------

class _TabletBody extends StatelessWidget {
  const _TabletBody();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(children: [
        Expanded(
          child: Row(children: const [
            SizedBox(width: 250, child: ScenePanel()),
            SizedBox(width: 8),
            Expanded(child: CanvasView()),
            SizedBox(width: 8),
            SizedBox(width: 290, child: PropertiesPanel()),
          ]),
        ),
        const SizedBox(height: 8),
        _ExpandableTimeline(),
      ]),
    );
  }
}

/// Tablet timeline: a compact strip that expands into the full timeline sheet.
class _ExpandableTimeline extends StatefulWidget {
  @override
  State<_ExpandableTimeline> createState() => _ExpandableTimelineState();
}

class _ExpandableTimelineState extends State<_ExpandableTimeline> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: Hs.durBase,
      curve: Hs.easeStandard,
      child: SizedBox(
        height: expanded ? 220 : 64,
        child: Stack(children: [
          Positioned.fill(
              child: expanded ? const Timeline() : const Timeline(compact: true)),
          Positioned(
            right: 12,
            top: 12,
            child: IconButton(
              onPressed: () => setState(() => expanded = !expanded),
              icon: Icon(expanded ? Icons.expand_more : Icons.expand_less,
                  color: Hs.primary),
              tooltip: expanded ? 'Collapse timeline' : 'Expand timeline',
            ),
          ),
        ]),
      ),
    );
  }
}

// ---------------- phone ----------------

class _PhoneBody extends StatelessWidget {
  const _PhoneBody();
  @override
  Widget build(BuildContext context) {
    final c = EditorScope.of(context);
    return Stack(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
        child: Column(children: [
          const Expanded(child: CanvasView(showPreviewToggle: false)),
          const SizedBox(height: 8),
          const SizedBox(height: 60, child: Timeline(compact: true)),
        ]),
      ),
      // bottom sheet launcher bar
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: _PhoneDock(c),
      ),
    ]);
  }
}

class _PhoneDock extends StatelessWidget {
  const _PhoneDock(this.c);
  final dynamic c;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Hs.white,
        border: Border(top: BorderSide(color: Hs.divider)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom + 6, top: 8, left: 8, right: 8),
      child: Row(children: [
        _DockBtn(Icons.layers_outlined, 'Scene',
            () => _sheet(context, const ScenePanelSheet())),
        _DockBtn(Icons.tune, 'Properties',
            () => _sheet(context, const PropertiesSheet())),
        _DockBtn(Icons.add, 'New', () => showNewDialog(context)),
        _DockBtn(Icons.folder_open_outlined, 'Open',
            () => showOpenDialog(context)),
      ]),
    );
  }

  static void _sheet(BuildContext context, Widget child) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Hs.surfaceCloud,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => FractionallySizedBox(heightFactor: .85, child: child),
    );
  }
}

class _DockBtn extends StatelessWidget {
  const _DockBtn(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 22, color: Hs.primary),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 11, color: Hs.textSecondary)),
          ]),
        ),
      ),
    );
  }
}

/// Sheet wrappers reuse the same panels with an EditorScope re-provided,
/// so ListenableBuilder inside them keeps working within the modal route.
class ScenePanelSheet extends StatelessWidget {
  const ScenePanelSheet({super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(10),
        child: Column(children: const [
          _SheetGrip('Scene'),
          Expanded(child: ScenePanel()),
        ]),
      );
}

class PropertiesSheet extends StatelessWidget {
  const PropertiesSheet({super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(10),
        child: Column(children: const [
          _SheetGrip('Properties'),
          Expanded(child: PropertiesPanel()),
        ]),
      );
}

class _SheetGrip extends StatelessWidget {
  const _SheetGrip(this.title);
  final String title;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
              color: Hs.gray400, borderRadius: BorderRadius.circular(2)),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }
}

// ---------------- welcome / empty ----------------

class _Welcome extends StatelessWidget {
  const _Welcome();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Hs.surfaceCloud,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandMark(size: 64),
              const SizedBox(height: 20),
              const Text('Comics Editor',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              const Text('Your workspace for comics & puzzles.',
                  style: TextStyle(fontSize: 16, color: Hs.textSecondary)),
              const SizedBox(height: 28),
              Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
                SizedBox(
                  width: 200,
                  child: _BigAction(
                    icon: Icons.add,
                    label: 'New document',
                    onTap: () => showNewDialog(context),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: _BigAction(
                    icon: Icons.folder_open_outlined,
                    label: 'Open recent',
                    filled: false,
                    onTap: () => showOpenDialog(context),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigAction extends StatelessWidget {
  const _BigAction(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.filled = true});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 96,
        decoration: BoxDecoration(
          color: filled ? Hs.blue500 : Hs.white,
          border: filled ? null : Border.all(color: Hs.cloud200, width: 2),
          borderRadius: BorderRadius.circular(Hs.rCard),
          boxShadow: Hs.cardShadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 26, color: filled ? Hs.white : Hs.primary),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: filled ? Hs.white : Hs.primary)),
          ],
        ),
      ),
    );
  }
}
