import 'package:flutter/material.dart';

import '../../i18n/language_registry.dart';
import '../controller.dart';
import '../device_profile.dart';
import '../models.dart';
import '../theme.dart';
import 'balloon_editor_card.dart';
import 'common.dart';
import 'numeric_property_control.dart';
import 'used_language_tabs.dart';

/// Right "Properties" pane — Layer editor (localized artwork + animations)
/// or Sound editor, plus the per-animation parameter card.
class PropertiesPanel extends StatelessWidget {
  const PropertiesPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final c = EditorScope.of(context);
    return PanelCard(
      child: Column(
        children: [
          _PropertiesTabs(c),
          const Divider(height: 1, color: Hs.divider),
          Expanded(
            child: switch (c.propertiesTab) {
              PropertiesTab.selection => _SelectionProperties(c),
              PropertiesTab.document => _DocumentProperties(c),
              PropertiesTab.general => _GeneralProperties(c),
            },
          ),
        ],
      ),
    );
  }
}

class _PropertiesTabs extends StatelessWidget {
  const _PropertiesTabs(this.controller);
  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: HsSegmented<PropertiesTab>(
        values: PropertiesTab.values,
        labelOf: (tab) => switch (tab) {
          PropertiesTab.selection => 'Selection',
          PropertiesTab.document => 'Document',
          PropertiesTab.general => 'General',
        },
        selected: controller.propertiesTab,
        onChanged: controller.setPropertiesTab,
        height: 34,
        expand: true,
      ),
    );
  }
}

class _GeneralProperties extends StatelessWidget {
  const _GeneralProperties(this.controller);
  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final document = controller.doc!;
    final profile = controller.targetDeviceProfile;
    final visibleHeight = profile
        .verticalViewportHeight(document.width.toDouble())
        .clamp(0.0, document.height.toDouble());
    final visiblePercent = document.height <= 0
        ? 100
        : (visibleHeight / document.height * 100).round();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        const Text('TARGET VIEWPORT', style: kSectionLabel),
        const SizedBox(height: 8),
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Device',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<DeviceProfile>(
              value: profile,
              isExpanded: true,
              isDense: true,
              items: [
                for (final device in DeviceProfile.all)
                  DropdownMenuItem(
                    value: device,
                    child: Text('${device.label} · ${device.dimensionsLabel}'),
                  ),
              ],
              onChanged: (value) {
                if (value != null) controller.setTargetDeviceProfile(value);
              },
            ),
          ),
        ),
        const SizedBox(height: 14),
        _GeneralValueRow('Dimensions', '${profile.dimensionsLabel} px'),
        _GeneralValueRow('Aspect ratio', '${profile.width}:${profile.height}'),
        _GeneralValueRow(
          'Visible strip height',
          '${visibleHeight.round()} px · $visiblePercent%',
        ),
        const SizedBox(height: 14),
        const Text(
          'This target controls the Viewer range guide. It is independent '
          'of the desktop, tablet, or phone running Comics Editor.',
          style: TextStyle(color: Hs.textTertiary, fontSize: 12, height: 1.4),
        ),
      ],
    );
  }
}

class _GeneralValueRow extends StatelessWidget {
  const _GeneralValueRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Hs.textBody, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Hs.textTitle,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionProperties extends StatelessWidget {
  const _SelectionProperties(this.controller);
  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    Widget body;
    if (c.selectedLayer != null) {
      body = _LayerEditor(c);
    } else if (c.selectedSound != null) {
      body = _SoundEditor(c);
    } else {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Select a layer or sound in Scene',
            textAlign: TextAlign.center,
            style: TextStyle(color: Hs.textTertiary, fontSize: 14),
          ),
        ),
      );
    }
    return body;
  }
}

class _DocumentProperties extends StatelessWidget {
  const _DocumentProperties(this.controller);
  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final document = controller.doc!;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        const Text('DOCUMENT', style: kSectionLabel),
        const SizedBox(height: 8),
        NumericPropertyControl(
          label: 'Width',
          value: document.width,
          min: 1,
          max: 4096,
          step: 1,
          integer: true,
          isValid: (value) => value > 0,
          onGestureStart: controller.beginGestureHistory,
          onPreview: (value) =>
              controller.previewCanvasSize(value.toInt(), null),
          onGestureEnd: controller.commitGestureHistory,
          onCommit: (value) => controller.setCanvasSize(value.toInt(), null),
        ),
        NumericPropertyControl(
          label: 'Height',
          value: document.height,
          min: 1,
          max: 100000,
          step: 1,
          integer: true,
          isValid: (value) => value > 0,
          onGestureStart: controller.beginGestureHistory,
          onPreview: (value) =>
              controller.previewCanvasSize(null, value.toInt()),
          onGestureEnd: controller.commitGestureHistory,
          onCommit: (value) => controller.setCanvasSize(null, value.toInt()),
        ),
        if (document.type == DocType.puzzle)
          NumericPropertyControl(
            label: 'Puzzle Scale',
            value: document.scale,
            min: .125,
            max: 1,
            step: .05,
            isValid: (value) => value >= .125 && value <= 1,
            onGestureStart: controller.beginGestureHistory,
            onPreview: (value) => controller.previewScale(value.toDouble()),
            onGestureEnd: controller.commitGestureHistory,
            onCommit: (value) => controller.setScale(value.toDouble()),
          ),
        const SizedBox(height: 12),
        HsButton(
          'Convert',
          variant: HsVariant.secondary,
          icon: Icons.aspect_ratio,
          expand: true,
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text('Converting artwork to canvas size…'),
            ),
          ),
        ),
      ],
    );
  }
}

class _EditorHeader extends StatelessWidget {
  const _EditorHeader(this.swatch, this.name, this.kind);
  final Color? swatch;
  final String name;
  final String kind;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Hs.divider)),
      ),
      child: Row(
        children: [
          if (swatch != null) ...[
            HatchSwatch(swatch!, size: 28),
            const SizedBox(width: 10),
          ] else ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Hs.coral500,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.graphic_eq, size: 15, color: Hs.white),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            kind.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: .5,
              color: Hs.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LayerEditor extends StatelessWidget {
  const _LayerEditor(this.c);
  final EditorController c;
  @override
  Widget build(BuildContext context) {
    final l = c.selectedLayer!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EditorHeader(l.swatch, l.name, 'Layer'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              _KindField(l.kind, onChanged: c.setLayerKind),
              const SizedBox(height: 14),
              if (l.kind == 'balloon')
                _BalloonSection(c, l)
              else
                _ArtworkSection(c, l),
              const SizedBox(height: 14),
              InkWell(
                onTap: c.togglePreview,
                child: Row(
                  children: [
                    _Check(l.preview),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Preview this layer',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _AnimSection(c, sound: false),
            ],
          ),
        ),
      ],
    );
  }
}

class _ArtworkSection extends StatefulWidget {
  const _ArtworkSection(this.controller, this.layer);
  final EditorController controller;
  final EditorLayer layer;

  @override
  State<_ArtworkSection> createState() => _ArtworkSectionState();
}

class _ArtworkSectionState extends State<_ArtworkSection> {
  String? selectedCode;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LanguageRegistry>(
      future: widget.controller.languageRegistry,
      builder: (context, snapshot) {
        final registry = snapshot.data;
        if (registry == null) {
          return const SizedBox(height: 44);
        }
        final used = <String>[
          for (
            var index = 0;
            index < widget.layer.images.length &&
                index < registry.languages.length;
            index++
          )
            if (widget.layer.images[index].file.isNotEmpty ||
                widget.layer.images[index].popup.isNotEmpty)
              registry.languages[index].code,
        ];
        final code =
            selectedCode ??
            (used.isNotEmpty ? used.first : registry.languages.first.code);
        final index = registry.indexFor(code)!;
        final image = index < widget.layer.images.length
            ? widget.layer.images[index]
            : LayerImage();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('ARTWORK · PER LANGUAGE', style: kSectionLabel),
            const SizedBox(height: 10),
            UsedLanguageTabs(
              registry: registry,
              usedCodes: used,
              selectedCode: code,
              onSelected: (value) => setState(() => selectedCode = value),
            ),
            const SizedBox(height: 12),
            _FileField(
              'File',
              image.file.isEmpty ? '— none —' : image.file,
              onPick: () => widget.controller.pickImageFile(code),
            ),
            const SizedBox(height: 10),
            _FileField(
              'Popup',
              image.popup.isEmpty ? '— none —' : image.popup,
              onPick: () => widget.controller.pickImagePopup(code),
            ),
          ],
        );
      },
    );
  }
}

/// vdd-comics-editor-uiux-lettering, Task 4.3: hosts [BalloonEditorCard] in
/// Edit mode's Properties panel for a `kind == "balloon"` layer -- the same
/// component Lettering mode (Phase 5) will use, so a user who prefers
/// staying in Edit mode isn't blocked from basic lettering there too
/// (`02-visual.md`'s "Component: Balloon editor card"). `LanguageRegistry`
/// is loaded async (`EditorController.languageRegistry`, cached after the
/// first load) so this needs a `FutureBuilder`; `key: ValueKey(layer)`
/// forces a fresh `BalloonEditorCard` state when the selected layer changes
/// mid-build, matching `_LayerEditor`'s existing no-persistent-widget-key
/// pattern for a StatelessWidget parent.
class _BalloonSection extends StatelessWidget {
  const _BalloonSection(this.c, this.layer);
  final EditorController c;
  final EditorLayer layer;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LanguageRegistry>(
      future: c.languageRegistry,
      builder: (context, snapshot) {
        final registry = snapshot.data;
        if (registry == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return BalloonEditorCard(
          key: ValueKey(layer),
          controller: c,
          layer: layer,
          registry: registry,
          aiClient: c.aiClient,
        );
      },
    );
  }
}

class _SoundEditor extends StatelessWidget {
  const _SoundEditor(this.c);
  final EditorController c;
  @override
  Widget build(BuildContext context) {
    final s = c.selectedSound!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EditorHeader(null, s.file, 'Sound'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              const Text('SOUND FILE', style: kSectionLabel),
              const SizedBox(height: 10),
              _FileField('File', s.file, onPick: () {}),
              const SizedBox(height: 18),
              _AnimSection(c, sound: true),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnimSection extends StatelessWidget {
  const _AnimSection(this.c, {required this.sound});
  final EditorController c;
  final bool sound;
  @override
  Widget build(BuildContext context) {
    final anims = c.selectedAnims;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('ANIMATIONS', style: kSectionLabel),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < anims.length; i++)
              _AnimChip(anims[i].title, i == c.selAnim, () => c.selectAnim(i)),
          ],
        ),
        const SizedBox(height: 10),
        if (sound)
          Row(
            children: [
              Expanded(
                child: _AddChip('+ Sound cue', () => c.addAnim(AnimType.sound)),
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: _AddChip(
                  '+ Translate',
                  () => c.addAnim(AnimType.translate),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _AddChip('+ Rotate', () => c.addAnim(AnimType.rotate)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _AddChip('+ Scale', () => c.addAnim(AnimType.scale)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _AddChip('+ Alpha', () => c.addAnim(AnimType.alpha)),
              ),
            ],
          ),
        const SizedBox(height: 14),
        if (c.currentAnim != null) _AnimParams(c, c.currentAnim!),
      ],
    );
  }
}

class _AnimParams extends StatelessWidget {
  const _AnimParams(this.c, this.a);
  final EditorController c;
  final Anim a;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Hs.gray50,
        border: Border.all(color: Hs.divider),
        borderRadius: BorderRadius.circular(Hs.rChip),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Hs.animColor(a.title),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  a.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              InkWell(
                onTap: c.deleteAnim,
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: Hs.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _field(
            'Start',
            a.start,
            0,
            c.doc!.height > 600 ? c.doc!.height.toDouble() : 600,
            1,
            true,
            (animation, value) => animation.start = value.toInt(),
          ),
          _field(
            'End',
            a.end,
            0,
            c.doc!.height > 600 ? c.doc!.height.toDouble() : 600,
            1,
            true,
            (animation, value) => animation.end = value.toInt(),
          ),
          ..._typeFields(),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    num value,
    double min,
    double max,
    double step,
    bool integer,
    void Function(Anim animation, num value) assign,
  ) {
    return NumericPropertyControl(
      label: label,
      value: value,
      min: min,
      max: max,
      step: step,
      integer: integer,
      onGestureStart: c.beginGestureHistory,
      onPreview: (value) =>
          c.previewAnim((animation) => assign(animation, value)),
      onGestureEnd: c.commitGestureHistory,
      onCommit: (value) => c.editAnim((animation) => assign(animation, value)),
    );
  }

  List<Widget> _typeFields() {
    switch (a.type) {
      case AnimType.translate:
        return [
          _field(
            'Translate X',
            a.x,
            -c.doc!.width.toDouble(),
            c.doc!.width.toDouble(),
            1,
            false,
            (animation, value) => animation.x = value.toDouble(),
          ),
          _field(
            'Translate Y',
            a.y,
            -c.doc!.height.toDouble(),
            c.doc!.height.toDouble(),
            1,
            false,
            (animation, value) => animation.y = value.toDouble(),
          ),
        ];
      case AnimType.rotate:
        return [
          _field(
            'Center X',
            a.pivotX,
            -1,
            2,
            .01,
            false,
            (animation, value) => animation.pivotX = value.toDouble(),
          ),
          _field(
            'Center Y',
            a.pivotY,
            -1,
            2,
            .01,
            false,
            (animation, value) => animation.pivotY = value.toDouble(),
          ),
          _field(
            'Angle',
            a.angle,
            -360,
            360,
            1,
            false,
            (animation, value) => animation.angle = value.toDouble(),
          ),
        ];
      case AnimType.scale:
        return [
          _field(
            'Center X',
            a.pivotX,
            -1,
            2,
            .01,
            false,
            (animation, value) => animation.pivotX = value.toDouble(),
          ),
          _field(
            'Center Y',
            a.pivotY,
            -1,
            2,
            .01,
            false,
            (animation, value) => animation.pivotY = value.toDouble(),
          ),
          _field(
            'Scale X',
            a.scaleX,
            -4,
            4,
            .01,
            false,
            (animation, value) => animation.scaleX = value.toDouble(),
          ),
          _field(
            'Scale Y',
            a.scaleY,
            -4,
            4,
            .01,
            false,
            (animation, value) => animation.scaleY = value.toDouble(),
          ),
        ];
      case AnimType.alpha:
        return [
          _field(
            'Alpha',
            a.alpha,
            0,
            1,
            .01,
            false,
            (animation, value) => animation.alpha = value.toDouble(),
          ),
        ];
      case AnimType.sound:
        return const [];
    }
  }
}

class _AnimChip extends StatelessWidget {
  const _AnimChip(this.label, this.selected, this.onTap);
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Hs.blue500 : Hs.cloud200,
          borderRadius: BorderRadius.circular(Hs.rChip),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            color: selected ? Hs.white : Hs.primary,
          ),
        ),
      ),
    );
  }
}

class _AddChip extends StatelessWidget {
  const _AddChip(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Hs.rChip),
          border: Border.all(color: Hs.gray400, style: BorderStyle.solid),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, color: Hs.textSecondary),
        ),
      ),
    );
  }
}

/// vdd-comics-editor-uiux-lettering, Task 3.2: kind-setting dropdown --
/// resolves Specifications' open design question ("does `kind` get a real
/// picker, or stay data-only") as a simple dropdown in the per-layer editor,
/// since this flow has no other per-layer settings surface. Options match
/// Task 3.1's chip taxonomy exactly (background/character/balloon/caption/
/// sound + none) so every chip the list can show is reachable/clearable
/// here. `kind` stays an open string on the model (`Layer.cs`), so a value
/// already on the layer that isn't one of these -- from a legacy file, or
/// forward-compat data from `flows/vdd-comics-editor-jhanava/`'s eventual
/// taxonomy -- is shown verbatim as an extra entry instead of being dropped
/// or crashing `DropdownButton`'s "value must be among items" assertion.
class _KindField extends StatelessWidget {
  const _KindField(this.kind, {required this.onChanged});
  final String? kind;
  final ValueChanged<String?> onChanged;

  static const _knownOptions = <String?>[
    null,
    'balloon',
    'caption',
    'background',
    'character',
    'sound',
  ];

  static String _labelFor(String? kind) => switch (kind) {
    null => '(none)',
    'balloon' => 'Balloon',
    'caption' => 'Caption',
    'background' => 'Background',
    'character' => 'Character',
    'sound' => 'Sound',
    final other => other,
  };

  @override
  Widget build(BuildContext context) {
    final options = _knownOptions.contains(kind)
        ? _knownOptions
        : [..._knownOptions, kind];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'KIND',
          style: TextStyle(fontSize: 12, color: Hs.textSecondary),
        ),
        const SizedBox(height: 4),
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(color: Hs.cloud200, width: 2),
            borderRadius: BorderRadius.circular(Hs.rChip),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: kind,
              isExpanded: true,
              isDense: true,
              icon: const Icon(
                Icons.expand_more,
                size: 18,
                color: Hs.textSecondary,
              ),
              style: const TextStyle(fontSize: 14, color: Hs.textBody),
              items: [
                for (final option in options)
                  DropdownMenuItem<String?>(
                    value: option,
                    child: Text(_labelFor(option)),
                  ),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _FileField extends StatelessWidget {
  const _FileField(this.label, this.value, {required this.onPick});
  final String label;
  final String value;
  final VoidCallback onPick;
  @override
  Widget build(BuildContext context) {
    final empty = value.startsWith('—');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Hs.textSecondary),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 38,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: Hs.cloud200, width: 2),
                  borderRadius: BorderRadius.circular(Hs.rChip),
                ),
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: serifValue(empty ? Hs.textTertiary : Hs.primary),
                ),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onPick,
              child: Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Hs.cloud200,
                  borderRadius: BorderRadius.circular(Hs.rBtn),
                ),
                child: const Text(
                  '…',
                  style: TextStyle(fontSize: 16, color: Hs.primary),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Check extends StatelessWidget {
  const _Check(this.on);
  final bool on;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: on ? Hs.blue500 : Hs.white,
        border: Border.all(color: on ? Hs.blue500 : Hs.cloud200, width: 2),
        borderRadius: BorderRadius.circular(5),
      ),
      child: on ? const Icon(Icons.check, size: 14, color: Hs.white) : null,
    );
  }
}
