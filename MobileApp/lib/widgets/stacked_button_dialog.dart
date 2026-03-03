import 'package:flutter/material.dart';

import '../helpers/color_helper.dart';

/// A dialog where action buttons are stacked vertically, each full width.
///
/// Example usage:
/// ```dart
/// showDialog(
///   context: context,
///   builder: (context) => StackedButtonDialog(
///     title: 'Are you sure?',
///     content: Text('This action cannot be undone.'),
///     buttons: [
///       StackedDialogButton(
///         label: 'Confirm',
///         onPressed: () => Navigator.of(context).pop(true),
///         style: StackedDialogButtonStyle.filled,
///       ),
///       StackedDialogButton(
///         label: 'Cancel',
///         onPressed: () => Navigator.of(context).pop(false),
///         style: StackedDialogButtonStyle.outlined,
///       ),
///     ],
///   ),
/// );
/// ```
class StackedButtonDialog extends StatelessWidget {
  const StackedButtonDialog({
    super.key,
    required this.title,
    required this.content,
    required this.buttons,
    this.buttonSpacing = 4.0,
    this.contentPadding = const EdgeInsets.fromLTRB(24, 16, 24, 0),
    this.actionsPadding = const EdgeInsets.fromLTRB(16, 16, 16, 16),
  });

  final String title;
  final Widget content;
  final List<StackedDialogButton> buttons;
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < buttons.length; i++) ...[
              if (i > 0) SizedBox(height: buttonSpacing),
              buttons[i]._build(context),
            ],
          ],
        ),
      ],
    );
  }
}

enum StackedDialogButtonStyle { filled, outlined, red, green }

class StackedDialogButton {
  const StackedDialogButton({
    required this.label,
    required this.onPressed,
    this.style = StackedDialogButtonStyle.filled,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final StackedDialogButtonStyle style;
  final Widget? icon;

  Widget _build(BuildContext context) {
    final child = icon != null
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [icon!, const SizedBox(width: 8), Text(label)],
          )
        : Text(label);

    switch (style) {
      case StackedDialogButtonStyle.filled:
        return FilledButton(onPressed: onPressed, child: child);
      case StackedDialogButtonStyle.outlined:
        return OutlinedButton(onPressed: onPressed, child: child);
      case StackedDialogButtonStyle.red:
        return FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: ColorHelper.themedColor(context, Colors.red),
          ),
          child: child,
        );
      case StackedDialogButtonStyle.green:
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
