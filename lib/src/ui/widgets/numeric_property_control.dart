import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../responsive.dart';
import '../theme.dart';

class NumericPropertyControl extends StatefulWidget {
  const NumericPropertyControl({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onPreview,
    required this.onCommit,
    this.integer = false,
    this.isValid,
    this.onGestureStart,
    this.onGestureEnd,
  });

  final String label;
  final num value;
  final double min;
  final double max;
  final double step;
  final bool integer;
  final bool Function(num value)? isValid;
  final ValueChanged<num> onPreview;
  final ValueChanged<num> onCommit;
  final VoidCallback? onGestureStart;
  final VoidCallback? onGestureEnd;

  @override
  State<NumericPropertyControl> createState() => _NumericPropertyControlState();
}

class _NumericPropertyControlState extends State<NumericPropertyControl> {
  late final TextEditingController _text = TextEditingController(
    text: _format(widget.value),
  );
  late final FocusNode _focus = FocusNode()..addListener(_onFocus);
  bool _touchEditing = false;
  bool _invalid = false;
  String? _editStartText;

  String _format(num value) => widget.integer
      ? value.toInt().toString()
      : value.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');

  @override
  void didUpdateWidget(NumericPropertyControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus) _text.text = _format(widget.value);
  }

  num? _parse() => widget.integer
      ? int.tryParse(_text.text.trim())
      : double.tryParse(_text.text.trim());

  bool _valid(num? value) =>
      value != null &&
      (!value.isNaN && value.isFinite) &&
      (widget.isValid?.call(value) ?? true);

  void _commit() {
    final value = _parse();
    if (_valid(value)) {
      widget.onCommit(value!);
      _text.text = _format(value);
      _invalid = false;
    } else {
      _text.text = _format(widget.value);
      _invalid = true;
      SemanticsService.sendAnnouncement(
        View.of(context),
        '${widget.label}: invalid number',
        TextDirection.ltr,
      );
    }
    if (mounted) setState(() => _touchEditing = false);
  }

  void _onFocus() {
    if (_focus.hasFocus) {
      _editStartText = _text.text;
      return;
    }
    if (!_focus.hasFocus &&
        (_touchEditing || _text.text != _format(widget.value))) {
      _commit();
    }
  }

  void _cancelEdit() {
    _text.text = _editStartText ?? _format(widget.value);
    _invalid = false;
    _touchEditing = false;
    _focus.unfocus();
    if (mounted) setState(() {});
  }

  void _startTouchEdit() {
    setState(() => _touchEditing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      _text.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _text.text.length,
      );
    });
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final touch = formFactorOf(context).isTouch;
    final real = widget.value.toDouble();
    final sliderValue = real.clamp(widget.min, widget.max);
    final overflow = real < widget.min || real > widget.max;
    final valueEditor = _ValueEditor(
      controller: _text,
      focusNode: _focus,
      integer: widget.integer,
      invalid: _invalid,
      onSubmitted: (_) => _commit(),
      onCancel: _cancelEdit,
    );
    return Semantics(
      label: widget.label,
      value: _format(widget.value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Hs.textSecondary,
                    ),
                  ),
                ),
                if (overflow)
                  const Tooltip(
                    message: 'Value is outside the slider range',
                    child: Icon(Icons.more_horiz, size: 14, color: Hs.amber500),
                  ),
                const SizedBox(width: 5),
                if (!touch || _touchEditing)
                  SizedBox(width: 72, height: 30, child: valueEditor)
                else
                  InkWell(
                    onTap: _startTouchEdit,
                    borderRadius: BorderRadius.circular(Hs.rChip),
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 52,
                        minHeight: 36,
                      ),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Hs.cloud200,
                        borderRadius: BorderRadius.circular(Hs.rChip),
                      ),
                      child: Text(_format(widget.value)),
                    ),
                  ),
              ],
            ),
            Slider(
              value: sliderValue,
              min: widget.min,
              max: widget.max,
              divisions: ((widget.max - widget.min) / widget.step)
                  .round()
                  .clamp(1, 100000),
              onChangeStart: (_) => widget.onGestureStart?.call(),
              onChanged: (value) {
                final snapped =
                    (widget.min +
                            ((value - widget.min) / widget.step).round() *
                                widget.step)
                        .clamp(widget.min, widget.max);
                widget.onPreview(widget.integer ? snapped.round() : snapped);
              },
              onChangeEnd: (_) => widget.onGestureEnd?.call(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValueEditor extends StatelessWidget {
  const _ValueEditor({
    required this.controller,
    required this.focusNode,
    required this.integer,
    required this.invalid,
    required this.onSubmitted,
    required this.onCancel,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool integer;
  final bool invalid;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): onCancel},
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.numberWithOptions(
          signed: true,
          decimal: !integer,
        ),
        textInputAction: TextInputAction.done,
        onSubmitted: onSubmitted,
        onTapOutside: (_) => focusNode.unfocus(),
        style: const TextStyle(fontSize: 13),
        textAlign: TextAlign.end,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 7,
            vertical: 7,
          ),
          errorText: invalid ? '' : null,
          errorStyle: const TextStyle(fontSize: 0, height: 0),
          border: const OutlineInputBorder(),
        ),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[-+0-9.eE]')),
        ],
      ),
    );
  }
}
