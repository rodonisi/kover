import 'package:material_ui/material_ui.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/settings/option_container.dart';

class NumericOption extends StatelessWidget {
  final String title;
  final String? description;
  final double value;
  final double step;
  final double min;
  final double max;
  final int decimalPlaces;
  final IconData? icon;
  final void Function(double)? onChanged;
  const NumericOption({
    super.key,
    required this.title,
    required this.value,
    required this.step,
    required this.min,
    required this.max,
    this.description,
    this.decimalPlaces = 1,
    this.icon,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return OptionContainer(
      title: title,
      description: description,
      icon: icon,
      value: value.toStringAsFixed(decimalPlaces),
      child: Slider(
        padding: const EdgeInsets.symmetric(
          horizontal: LayoutConstants.smallPadding,
        ),
        value: value,
        min: min,
        max: max,
        divisions: ((max - min) / step).round(),
        onChanged: (newValue) => onChanged?.call(newValue),
      ),
    );
  }
}
