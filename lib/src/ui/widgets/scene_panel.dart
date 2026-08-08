import 'package:flutter/material.dart';
import 'package:flutter_comics/flutter_comics.dart';

import '../controller.dart';
import '../responsive.dart';
import '../theme.dart';
import 'common.dart';
import 'dialogs.dart' show colorFromHex, colorToHex, showSolidColorPicker;

/// Left "Scene" column: canvas settings + Layers + Sounds
/// (LayersListControl + SoundsListControl + SettingsControl in the original).
class ScenePanel extends StatelessWidget {
  const ScenePanel({super.key, this.showSettings = false});
  final bool showSettings;

  @override
  Widget build(BuildContext context) {
    final c = EditorScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showSettings) ...[
          PanelCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CANVAS', style: kSectionLabel),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: NumberField(
                        label: 'Width',
                        value: c.doc!.width,
                        height: 38,
                        onChanged: (v) => c.setCanvasSize(v.toInt(), null),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: NumberField(
                        label: 'Height',
                        value: c.doc!.height,
                        height: 38,
                        onChanged: (v) => c.setCanvasSize(null, v.toInt()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    HsButton(
                      'Convert',
                      variant: HsVariant.secondary,
                      height: 38,
                      onTap: () => _convertToast(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        Expanded(
          child: PanelCard(
            child: Column(
              children: [
                Expanded(child: _LayersSection(c)),
                const Divider(height: 1, color: Hs.divider),
                _SoundsSection(c),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _convertToast(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Hs.gray800,
        content: Text('Converting artwork to canvas size…'),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, this.actions);
  final String title;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: kSectionLabel)),
          ...actions,
        ],
      ),
    );
  }
}

class _LayersSection extends StatelessWidget {
  const _LayersSection(this.c);
  final EditorController c;
  @override
  Widget build(BuildContext context) {
    final layers = c.doc!.layers;
    // tdd-dot-comics-format Plan Task 3.3: render in ParentId hierarchy
    // order (depth-first, each parent immediately followed by its own
    // children) rather than raw document order -- identical to today's flat
    // order whenever no layer has a parentId, by construction.
    final order = c.hierarchicalLayerOrder(layers);
    return Column(
      children: [
        _SectionHeader('LAYERS', [
          _AddLayerMenuButton(c),
          const SizedBox(width: 6),
          HsIconButton(
            Icons.arrow_upward,
            tooltip: 'Up',
            onTap: () => c.moveLayer(-1),
          ),
          const SizedBox(width: 6),
          HsIconButton(
            Icons.arrow_downward,
            tooltip: 'Down',
            onTap: () => c.moveLayer(1),
          ),
          const SizedBox(width: 6),
          HsIconButton(
            Icons.close,
            filled: true,
            tooltip: 'Delete',
            onTap: c.deleteSelected,
          ),
        ]),
        Expanded(
          child: layers.isEmpty
              ? const _Empty('No layers yet')
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: order.length,
                  itemBuilder: (_, row) {
                    final (index, depth) = order[row];
                    return _LayerRow(c, index, depth);
                  },
                ),
        ),
      ],
    );
  }
}

enum _AddLayerChoice { image, organizational, solidColor }

/// tdd-dot-comics-format Plan Task 3.5/4.3, `04-visual.md` Screens 2/4: the
/// `[+]` used to be a single-action icon (`c.addLayer`, no choice) -- now a
/// small menu covering every new layer-creation path this flow added.
class _AddLayerMenuButton extends StatelessWidget {
  const _AddLayerMenuButton(this.c);
  final EditorController c;

  Future<void> _onSelected(BuildContext context, _AddLayerChoice choice) async {
    switch (choice) {
      case _AddLayerChoice.image:
        c.addLayer();
      case _AddLayerChoice.organizational:
        c.addOrganizationalLayer();
      case _AddLayerChoice.solidColor:
        final picked = await showSolidColorPicker(context);
        if (picked != null) c.addSolidColorLayer(colorToHex(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_AddLayerChoice>(
      tooltip: 'Add',
      onSelected: (choice) => _onSelected(context, choice),
      itemBuilder: (_) => const [
        PopupMenuItem(value: _AddLayerChoice.image, child: Text('Image layer')),
        PopupMenuItem(
          value: _AddLayerChoice.organizational,
          child: Text('Organizational anchor'),
        ),
        PopupMenuItem(
          value: _AddLayerChoice.solidColor,
          child: Text('Solid color layer'),
        ),
      ],
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Hs.white,
          border: Border.all(color: Hs.cloud200),
          borderRadius: BorderRadius.circular(Hs.rChip),
        ),
        child: Icon(Icons.add, size: 30 * .48, color: Hs.primary),
      ),
    );
  }
}

/// `04-visual.md` Screen 2 called for a dashed border; stock `Border` has no
/// dashed style (would need a custom painter for that alone) -- a solid
/// muted border reads the same "not real artwork" signal without one.
class _OrganizationalPlaceholder extends StatelessWidget {
  const _OrganizationalPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Hs.gray400),
      ),
      child: Icon(Icons.account_tree_outlined, size: 16, color: Hs.gray400),
    );
  }
}

/// `04-visual.md` Screen 4: a solid-color layer's swatch shows the actual
/// flat fill color -- distinct from [HatchSwatch]'s diagonal-stripe "no
/// artwork yet" placeholder, since the color *is* this layer's real content.
class _SolidColorSwatch extends StatelessWidget {
  const _SolidColorSwatch(this.color);
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Hs.gray200),
      ),
    );
  }
}

class _LayerRow extends StatelessWidget {
  const _LayerRow(this.c, this.i, this.depth);
  final EditorController c;
  final int i;
  final int depth;

  /// tdd-dot-comics-format Plan Task 3.3: right-click (desktop) or
  /// long-press (touch) opens "Set parent.../Clear parent" -- distinct from
  /// the plain tap, which selects the layer as it always has.
  Future<void> _showContextMenu(BuildContext context, Offset globalPosition) async {
    final layers = c.doc!.layers;
    final layer = layers[i];
    final position = RelativeRect.fromLTRB(
      globalPosition.dx,
      globalPosition.dy,
      globalPosition.dx,
      globalPosition.dy,
    );
    final action = await showMenu<VoidCallback>(
      context: context,
      position: position,
      items: [
        PopupMenuItem<VoidCallback>(
          value: () => _pickParent(context, globalPosition, layer),
          child: const Text('Set parent...'),
        ),
        if (layer.parentId != null)
          PopupMenuItem<VoidCallback>(
            value: () => c.setLayerParent(layer, null),
            child: const Text('Clear parent'),
          ),
      ],
    );
    action?.call();
  }

  /// Lists every other layer, excluding [child] itself and anything that
  /// would close a parenting cycle (`c.wouldCreateParentCycle`) -- the
  /// picker only ever offers choices that are actually safe to apply.
  Future<void> _pickParent(
    BuildContext context,
    Offset globalPosition,
    EditorLayer child,
  ) async {
    final layers = c.doc!.layers;
    final candidates = [
      for (final l in layers)
        if (l.id != child.id && !c.wouldCreateParentCycle(child, l.id, layers)) l,
    ];
    if (candidates.isEmpty) return;
    final position = RelativeRect.fromLTRB(
      globalPosition.dx,
      globalPosition.dy,
      globalPosition.dx,
      globalPosition.dy,
    );
    final pickedId = await showMenu<String>(
      context: context,
      position: position,
      items: [for (final l in candidates) PopupMenuItem(value: l.id, child: Text(l.name))],
    );
    if (pickedId != null) c.setLayerParent(child, pickedId);
  }

  @override
  Widget build(BuildContext context) {
    final layers = c.doc!.layers;
    final l = layers[i];
    final selected = c.selKind == SelKind.layer && c.selIndex == i;
    final eyeSize = formFactorOf(context).isTouch ? 44.0 : 32.0;
    final hasChildren = c.layerHasChildren(l, layers);
    final collapsed = c.isLayerCollapsed(l.id);
    return GestureDetector(
      onSecondaryTapDown: (details) => _showContextMenu(context, details.globalPosition),
      onLongPressStart: (details) => _showContextMenu(context, details.globalPosition),
      child: InkWell(
        onTap: () => c.selectLayer(i),
        child: Container(
          decoration: BoxDecoration(
            color: selected ? Hs.blue100 : Hs.white,
            border: Border(
              left: BorderSide(
                color: selected ? Hs.blue500 : Colors.transparent,
                width: 3,
              ),
              top: const BorderSide(color: Hs.dividerLight),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(9, 8, 12, 8),
          child: Row(
            children: [
              // tdd-dot-comics-format Plan Task 3.3, `04-visual.md` Screen 3:
              // indentation matches ParentId depth -- 0 for every layer in a
              // document where no layer has a parent, identical to today.
              SizedBox(width: depth * 16.0),
              SizedBox(
                width: 20,
                child: hasChildren
                    ? InkWell(
                        onTap: () => c.toggleLayerCollapsed(l.id),
                        child: Icon(
                          collapsed ? Icons.arrow_right : Icons.arrow_drop_down,
                          size: 18,
                          color: Hs.textSecondary,
                        ),
                      )
                    : null,
              ),
              Semantics(
                button: true,
                label: l.visible
                    ? 'Hide layer ${l.name}'
                    : 'Show layer ${l.name}',
                child: HsIconButton(
                  l.visible ? Icons.visibility : Icons.visibility_off,
                  size: eyeSize,
                  tooltip: l.visible ? 'Hide layer' : 'Show layer',
                  onTap: () => c.toggleVisible(i),
                ),
              ),
              const SizedBox(width: 10),
              KindChip(l.kind),
              const SizedBox(width: 8),
              Opacity(
                opacity: l.visible ? 1 : .4,
                // 04-visual.md Screen 2: an organizational layer has no
                // thumbnail (nothing to show) -- a muted dashed placeholder
                // instead of the real artwork swatch. Screen 4: a
                // solid-color layer's swatch shows the actual flat color,
                // not the hatched "no artwork yet" placeholder.
                child: switch (l.kind) {
                  EditorLayer.organizationalKind => const _OrganizationalPlaceholder(),
                  _ when l.solidColor != null =>
                    _SolidColorSwatch(colorFromHex(l.solidColor!) ?? l.swatch),
                  _ => HatchSwatch(l.swatch),
                },
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                    color: l.visible ? Hs.textBody : Hs.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// vdd-comics-editor-uiux-lettering, Task 3.1: coarse layer-kind chip
/// (`02-visual.md`'s "Scene panel — layer list with kind badges") --
/// `[Bln]` violet, `[Cap]` amber, `[Art]` neutral gray for every other/unset
/// kind. A legacy layer (`kind == null`) renders as `[Art]`, visually
/// identical across the whole list to today's shipped app -- this is the
/// backward-compat acceptance criterion made visual, not just a data-layer
/// guarantee. `background`/`character`/`sound` extend the same chip to the
/// fuller taxonomy explored in `flows/vdd-comics-editor-jhanava/` -- `kind`
/// is an open string (see `Layer.cs`), so this is purely additive styling,
/// not a schema change; any value not recognized here still falls back to
/// the neutral `[Art]` chip.
class KindChip extends StatelessWidget {
  const KindChip(this.kind, {super.key});
  final String? kind;

  /// vdd-comics-editor-ai-uiux: the label/color/icon mapping, exposed as a static so Cutting
  /// mode's canvas overlays and region rail (`cutting_canvas.dart`, `cutting_region_rail.dart`)
  /// can color-match this chip exactly instead of re-deriving their own mapping -- avoids the
  /// kind of two-different-colors-for-the-same-kind drift a duplicated mapping would risk.
  static (String, Color, IconData?) styleFor(String? kind) => switch (kind) {
    'balloon' => ('Bln', Hs.violet500, Icons.chat_bubble_outline),
    'caption' => ('Cap', Hs.amber500, Icons.crop_din),
    'background' => ('Bg', Hs.teal500, Icons.image_outlined),
    'character' => ('Chr', Hs.indigo500, Icons.person_outline),
    'sound' => ('Snd', Hs.coral500, Icons.graphic_eq),
    // 04-visual.md's Screen 2 proposed `Hs.gray300`, which doesn't exist in
    // the real theme (`theme.dart` only has 200/400/500/600...) -- gray600
    // used instead, still visually distinct from the `Art` fallback's gray500.
    'organizational' => ('Org', Hs.gray600, Icons.account_tree_outlined),
    _ => ('Art', Hs.gray500, null),
  };

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = styleFor(kind);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(Hs.rChip),
        border: Border.all(color: color.withValues(alpha: .4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoundsSection extends StatelessWidget {
  const _SoundsSection(this.c);
  final EditorController c;
  @override
  Widget build(BuildContext context) {
    final sounds = c.doc!.sounds;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SectionHeader('SOUNDS', [
          HsIconButton(Icons.add, tooltip: 'Add', onTap: c.addSound),
          const SizedBox(width: 6),
          HsIconButton(
            c.muted ? Icons.volume_off : Icons.volume_up,
            filled: c.muted,
            tooltip: 'Mute',
            onTap: c.toggleMute,
          ),
          const SizedBox(width: 6),
          HsIconButton(
            Icons.close,
            filled: true,
            tooltip: 'Delete',
            onTap: c.deleteSelected,
          ),
        ]),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 140),
          child: sounds.isEmpty
              ? const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: _Empty('No sounds'),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 6),
                  itemCount: sounds.length,
                  itemBuilder: (_, i) {
                    final s = sounds[i];
                    final sel = c.selKind == SelKind.sound && c.selIndex == i;
                    return InkWell(
                      onTap: () => c.selectSound(i),
                      child: Container(
                        color: sel ? Hs.blue100 : null,
                        padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: Hs.coral500,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Icon(
                                c.muted ? Icons.volume_off : Icons.graphic_eq,
                                size: 12,
                                color: Hs.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                s.file,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: c.muted
                                      ? Hs.textTertiary
                                      : Hs.textBody,
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
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        text,
        style: const TextStyle(color: Hs.textTertiary, fontSize: 13),
      ),
    ),
  );
}
