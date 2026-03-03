import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:oklch/oklch.dart';

class ColorHelper {
  static Color themedColor(BuildContext context, Color color) {
    final primary = Theme.of(context).colorScheme.primary;

    final primaryOklch = OKLCHColor.fromColor(primary);
    final targetOklch = OKLCHColor.fromColor(color);

    // How "colorful" the target is (0 = grey/black, 1 = vivid)
    // We use this to scale how much we impose the primary's chroma
    final targetVividness = (targetOklch.chroma / 0.7).clamp(0.0, 1.0);

    return OKLCHColor(
      // Blend lightness: mostly follow target, nudge toward primary
      lerpDouble(targetOklch.lightness, primaryOklch.lightness, 0.7)!,
      // For vivid colors: use primary chroma. For neutrals: keep their low chroma
      lerpDouble(
        targetOklch.chroma,
        primaryOklch.chroma,
        targetVividness * 0.8,
      )!,
      targetOklch.hue,
    ).toColor();
  }

  static Color mixedPrimary(
    BuildContext context,
    Color color,
    double strength,
  ) {
    return Color.lerp(Theme.of(context).colorScheme.primary, color, strength) ??
        Theme.of(context).colorScheme.primary;
  }
}
