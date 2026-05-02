import 'package:flutter/material.dart';

class MeasuredWidget extends StatefulWidget {
  final Widget child;
  final ValueChanged<Size>? onSizeMeasured;

  const MeasuredWidget({
    super.key,
    required this.child,
    this.onSizeMeasured,
  });

  @override
  State<MeasuredWidget> createState() => _MeasuredWidgetState();
}

class _MeasuredWidgetState extends State<MeasuredWidget> {
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_measureSize);
  }

  @override
  void didUpdateWidget(covariant MeasuredWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback(_measureSize);
  }

  void _measureSize(_) {
    final renderBox = _key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      widget.onSizeMeasured?.call(renderBox.size);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: _key,
      child: widget.child,
    );
  }
}
