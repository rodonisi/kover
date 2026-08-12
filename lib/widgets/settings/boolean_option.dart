import 'package:material_ui/material_ui.dart';
import 'package:kover/widgets/settings/option_container.dart';

class BooleanOption extends StatelessWidget {
  final String title;
  final String? description;
  final bool value;
  final IconData? icon;
  final void Function(bool)? onChanged;
  const BooleanOption({
    super.key,
    required this.title,
    required this.value,
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
      child: Row(
        mainAxisAlignment: .end,
        children: [
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
