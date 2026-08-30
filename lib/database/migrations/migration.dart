import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/app_database.steps.dart';
import 'package:kover/database/migrations/steps/from_10_to_11.dart';
import 'package:kover/database/migrations/steps/from_11_to_12.dart';
import 'package:kover/database/migrations/steps/from_1_to_2.dart';
import 'package:kover/database/migrations/steps/from_2_to_3.dart';
import 'package:kover/database/migrations/steps/from_3_to_4.dart';
import 'package:kover/database/migrations/steps/from_4_to_5.dart';
import 'package:kover/database/migrations/steps/from_5_to_6.dart';
import 'package:kover/database/migrations/steps/from_6_to_7.dart';
import 'package:kover/database/migrations/steps/from_7_to_8.dart';
import 'package:kover/database/migrations/steps/from_8_to_9.dart';
import 'package:kover/database/migrations/steps/from_9_to_10.dart';

MigrationStrategy appDatabaseMigration(AppDatabase db) => MigrationStrategy(
  onUpgrade: stepByStep(
    from1To2: (m, schema) => migrateFrom1To2(db, m, schema),
    from2To3: (m, schema) => migrateFrom2To3(db, m, schema),
    from3To4: (m, schema) => migrateFrom3To4(db, m, schema),
    from4To5: (m, schema) => migrateFrom4To5(db, m, schema),
    from5To6: (m, schema) => migrateFrom5To6(db, m, schema),
    from6To7: (m, schema) => migrateFrom6To7(db, m, schema),
    from7To8: (m, schema) => migrateFrom7To8(db, m, schema),
    from8To9: (m, schema) => migrateFrom8To9(db, m, schema),
    from9To10: (m, schema) => migrateFrom9To10(db, m, schema),
    from10To11: (m, schema) => migrateFrom10To11(db, m, schema),
    from11To12: (m, schema) => migrateFrom11To12(db, m, schema),
  ),
);
