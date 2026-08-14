import 'package:kover/api/openapi.enums.swagger.dart' as api;
import 'package:kover/models/enums/publication_status.dart';

extension PublicationStatusMappings on api.PublicationStatus {
  PublicationStatus toLocal() {
    return switch (this) {
      .ongoing => .ongoing,
      .hiatus => .hiatus,
      .completed => .completed,
      .cancelled => .cancelled,
      .ended => .ended,
      _ => .unknown,
    };
  }
}
