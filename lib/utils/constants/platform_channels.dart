import 'package:flutter/services.dart';

sealed class PlatformChannels {
  /// Stream of volume key events captured natively on Android.
  static const volumeKeys = EventChannel('kover/volume_keys');

  /// Method channel for setting which volume keys should be captured natively on Android.
  static const volumeKeyCapture = MethodChannel('kover/volume_key_capture');

  /// Method name for setting which volume keys should be captured natively on Android.
  static const volumeKeyCaptureSetCapturedKeysMethod = 'setCapturedKeys';
}
