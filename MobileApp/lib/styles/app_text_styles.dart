import 'package:flutter/material.dart';

extension CustomTextStyles on TextTheme {
  TextStyle cardTitle(BuildContext context) {
    return bodyLarge!.copyWith(
      color: Theme.of(context).colorScheme.onSecondaryContainer,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    );
  }
}
