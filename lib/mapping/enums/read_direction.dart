import 'dart:ui';

import 'package:kover/models/read_direction.dart';

extension ReadDirectionExtension on ReadDirection {
  TextDirection toTextDirection() {
    return switch (this) {
      .leftToRight => .ltr,
      .rightToLeft => .rtl,
    };
  }
}
