import 'package:kover/api/openapi.swagger.dart' as api;

enum FontProvider {
  unknown,
  system,
  user;

  factory FontProvider.fromDto(api.FontProvider provider) => switch (provider) {
    .system => .system,
    .user => .user,
    _ => .unknown,
  };
}
