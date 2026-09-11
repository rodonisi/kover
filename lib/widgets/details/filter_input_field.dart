import 'package:kover/utils/constants/kover_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kover/generated/l10n/app_localizations.dart';

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
        prefixIcon: const Icon(KoverIcons.filter),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                onPressed: () {
                  controller.clear();
                },
                icon: const Icon(KoverIcons.clear),
              )
            : null,
      ),
      onTapOutside: (_) {
        FocusScope.of(context).unfocus();
      },
    );
  }
}
