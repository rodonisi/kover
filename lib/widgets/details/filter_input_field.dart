import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class FilterInputField extends HookWidget {
  const FilterInputField({
    super.key,
    required this.controller,
  });

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    useListenable(controller);
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: l.filter,
        prefixIcon: const Icon(LucideIcons.listFilter),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                onPressed: () {
                  controller.clear();
                },
                icon: const Icon(LucideIcons.x),
              )
            : null,
      ),
      onTapOutside: (_) {
        FocusScope.of(context).unfocus();
      },
    );
  }
}
