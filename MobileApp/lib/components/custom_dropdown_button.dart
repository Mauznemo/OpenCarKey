import 'package:flutter/material.dart';

class CustomDropdownButton<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;
  final Widget? hint;

  const CustomDropdownButton({
    Key? key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .secondaryContainer, // Background color
        borderRadius: BorderRadius.circular(50), // Rounded corners
      ),
      child: DropdownButton<T>(
        isExpanded: true,
        hint: hint,
        menuWidth: MediaQuery.of(context).size.width - 25,
        value: value,
        items: items,
        onChanged: onChanged,
        underline: const SizedBox(), // Removes default underline
        borderRadius: BorderRadius.circular(20),
        itemHeight: 55,
        dropdownColor: Theme.of(context)
            .colorScheme
            .secondaryContainer, // Match dropdown list color
        style: Theme.of(context).textTheme.bodyMedium, // Text style
      ),
    );
  }
}
