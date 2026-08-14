import 'package:kover/api/openapi.enums.swagger.dart' as api;
import 'package:kover/models/enums/age_rating.dart';

extension AgeRatingMappings on api.AgeRating {
  AgeRating toLocal() {
    return switch (this) {
      .ratingpending => .ratingPending,
      .earlychildhood => .earlyChildhood,
      .everyone => .everyone,
      .g => .g,
      .everyone10plus => .everyOne10Plus,
      .pg => .pg,
      .kidstoadults => .kidsToAdults,
      .teen => .teen,
      .mature15plus => .mature15Plus,
      .mature17plus => .mature17Plus,
      .mature => .mature,
      .r18plus => .r18Plus,
      .adultsonly => .adultsOnly,
      .x18plus => .x18Plus,
      .notapplicable => .notApplicable,
      _ => .unknown,
    };
  }
}
