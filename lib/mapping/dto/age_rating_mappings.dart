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

extension LocalAgeRatingMappings on AgeRating {
  api.AgeRating toApi() {
    return switch (this) {
      .unknown => .unknown,
      .ratingPending => .ratingpending,
      .earlyChildhood => .earlychildhood,
      .everyone => .everyone,
      .g => .g,
      .everyOne10Plus => .everyone10plus,
      .pg => .pg,
      .kidsToAdults => .kidstoadults,
      .teen => .teen,
      .mature15Plus => .mature15plus,
      .mature17Plus => .mature17plus,
      .mature => .mature,
      .r18Plus => .r18plus,
      .adultsOnly => .adultsonly,
      .x18Plus => .x18plus,
      .notApplicable => .notapplicable,
    };
  }
}
