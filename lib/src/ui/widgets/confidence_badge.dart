import 'package:flutter/material.dart';

import '../theme.dart';

/// vdd-comics-editor-ai-uiux: color-coded confidence badge for a Cutting-mode region --
/// green/amber/coral per `02-visual.md`'s high-fidelity reference (exact tokens: bg `#e3f2e6`/
/// text `#1f7a33` high, bg `#f7ecd4`/text `#8a6207` medium, bg `#fde4dc`/text `#c04a26` low).
/// Percentage text is always shown -- color is never the only signal (same accessibility rule
/// `KindChip` already follows).
class ConfidenceBadge extends StatelessWidget {
  const ConfidenceBadge(this.confidence, {super.key});
  final double confidence;

  static const _highBg = Color(0xFFE3F2E6);
  static const _highFg = Color(0xFF1F7A33);
  static const _mediumBg = Color(0xFFF7ECD4);
  static const _mediumFg = Color(0xFF8A6207);
  static const _lowBg = Color(0xFFFDE4DC);
  static const _lowFg = Color(0xFFC04A26);

  static (Color, Color) colorsFor(double confidence) => switch (confidence) {
        >= 0.85 => (_highBg, _highFg),
        >= 0.50 => (_mediumBg, _mediumFg),
        _ => (_lowBg, _lowFg),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = colorsFor(confidence);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Hs.rChip)),
      child: Text(
        '${(confidence * 100).round()}%',
        style: TextStyle(
          fontFamily: Hs.serifData.first,
          fontFamilyFallback: Hs.serifData.sublist(1),
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: fg,
        ),
      ),
    );
  }
}
