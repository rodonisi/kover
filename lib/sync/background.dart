import 'dart:convert';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/riverpod/managers/sync_manager/sync_engine.dart';
import 'package:kover/riverpod/providers/settings/credentials.dart';
import 'package:kover/riverpod/repository/secure_storage.dart';
import 'package:kover/utils/logging.dart';
import 'package:kover/utils/safe_platform.dart';
import 'package:workmanager/workmanager.dart';

const String _periodicTaskId = 'com.rodonisi.kover.periodic_task';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    final db = AppDatabase();
    try {
      final storage = const FlutterSecureStorage(
        iOptions: secureStorageIOSOptions,
      );

      final storageEntry = await storage.read(key: Credentials.persistKey);

      if (storageEntry == null) return false;

      final decoded = SecureStorageEntry.fromJson(jsonDecode(storageEntry));
      final settings = CredentialsState.fromJson(jsonDecode(decoded.value));
      if (settings.url == null || settings.apiKey == null) return false;

      final engine = SyncEngine.fromCredentials(
        url: settings.url!,
        apiKey: settings.apiKey!,
        customHeaders: settings.customHeaders,
        ignoreCertificateValidation: settings.ignoreCertificateValidation,
      );

      await engine.syncAllSeries();
      await engine.syncRecentlyUpdated();
      await engine.syncRecentlyAdded();
      await engine.syncLibraries();
      await engine.syncMetadata();
      await engine.syncProgress();
      await engine.syncOnDeck();

      return true;
    } catch (e, stacktrace) {
      log.error(
        'failed background fetch',
        error: e,
        stacktrace: stacktrace,
      );
    } finally {
      await db.close();
    }

    return false;
  });
}

Future<void> initializeBackgroundTask() async {
  if (SafePlatform.isIOS || SafePlatform.isAndroid) {
    await Workmanager().initialize(
      callbackDispatcher,
    );

    await Workmanager().registerPeriodicTask(
      _periodicTaskId,
      _periodicTaskId,
      frequency: 1.hours,
      flexInterval: 1.hours,
      initialDelay: 5.minutes,
      existingWorkPolicy: .keep,
      backoffPolicy: .exponential,
      constraints: Constraints(
        networkType: .connected,
        requiresBatteryNotLow: true,
      ),
    );
  }
}
