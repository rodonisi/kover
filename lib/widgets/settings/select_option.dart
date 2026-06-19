import 'package:flutter/material.dart';
import 'package:kover/widgets/settings/option_container.dart';

class SelectOption<T> extends StatelessWidget {
  final String title;
  final String? description;
  final T value;
  final List<SelectOptionEntry<T>> options;
  final IconData? icon;
  final void Function(T?)? onChanged;

  const SelectOption({
    super.key,
    required this.title,
    required this.value,
    required this.options,
    this.description,
    this.icon,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return OptionContainer(
      title: title,
      description: description,
      icon: icon,
      sameRow: true,
      child: DropdownMenu<T>(
        inputDecorationTheme: const InputDecorationTheme(
          isDense: true,
        ),
        initialSelection: value,
        dropdownMenuEntries: options
            .map(
              (option) => DropdownMenuEntry<T>(
                value: option.value,
                label: option.label,
                leadingIcon: option.icon != null ? Icon(option.icon) : null,
              ),
            )
            .toList(),
        onSelected: (T? newValue) {
          onChanged?.call(newValue);
        },
      ),
    );
  }
}

class SelectOptionEntry<T> {
  final T value;
  final String label;
  final IconData? icon;

  const SelectOptionEntry({
    required this.value,
    required this.label,
    this.icon,
  });
}
