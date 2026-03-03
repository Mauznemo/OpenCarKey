import 'package:flutter/material.dart';

import '../helpers/color_helper.dart';

/// A dialog where exactly two action buttons are placed side by side,
/// each stretching to 50% of the available width.
///
/// Example usage:
/// ```dart
/// showDialog(
///   context: context,
///   builder: (context) => SplitButtonDialog(
///     title: 'Delete item?',
///     content: Text('This will permanently delete the item.'),
///     primaryButton: SplitDialogButton(
///       label: 'Delete',
///       onPressed: () => Navigator.of(context).pop(true),
///       style: SplitDialogButtonStyle.filled,
///     ),
///     secondaryButton: SplitDialogButton(
///       label: 'Cancel',
///       onPressed: () => Navigator.of(context).pop(false),
///       style: SplitDialogButtonStyle.outlined,
///     ),
///   ),
/// );
/// ```
class SplitButtonDialog extends StatelessWidget {
  const SplitButtonDialog({
    super.key,
    required this.title,
    required this.content,
    required this.primaryButton,
    required this.secondaryButton,
    this.buttonSpacing = 8.0,
    this.contentPadding = const EdgeInsets.fromLTRB(24, 16, 24, 0),
    this.actionsPadding = const EdgeInsets.fromLTRB(16, 16, 16, 16),
  });

  final String title;
  final Widget content;
  final SplitDialogButton primaryButton;
  final SplitDialogButton secondaryButton;
  final double buttonSpacing;
  final EdgeInsets contentPadding;
  final EdgeInsets actionsPadding;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      contentPadding: contentPadding,
      actionsPadding: actionsPadding,
      content: content,
      actions: [
        Row(
          children: [
            Expanded(child: secondaryButton._build(context)),
            SizedBox(width: buttonSpacing),
            Expanded(child: primaryButton._build(context)),
          ],
        ),
      ],
    );
  }
}

enum SplitDialogButtonStyle { filled, outlined, red, green }

class SplitDialogButton {
  const SplitDialogButton({
    required this.label,
    required this.onPressed,
    this.style = SplitDialogButtonStyle.outlined,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final SplitDialogButtonStyle style;
  final Widget? icon;

  Widget _build(BuildContext context) {
    final child = icon != null
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [icon!, const SizedBox(width: 8), Text(label)],
          )
        : Text(label);

    switch (style) {
      case SplitDialogButtonStyle.filled:
        return FilledButton(onPressed: onPressed, child: child);
      case SplitDialogButtonStyle.outlined:
        return OutlinedButton(onPressed: onPressed, child: child);
      case SplitDialogButtonStyle.red:
        return FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: ColorHelper.themedColor(context, Colors.red),
          ),
          child: child,
        );
      case SplitDialogButtonStyle.green:
        return FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: ColorHelper.themedColor(context, Colors.green),
          ),
          child: child,
        );
    }
  }
}
