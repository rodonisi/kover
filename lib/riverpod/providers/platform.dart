import 'package:kover/utils/safe_platform.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'platform.g.dart';

enum AppPlatform {
  android,
  iOS,
  windows,
  macOS,
  linux,
  web,
  unknown,
}

@riverpod
AppPlatform appPlatform(Ref ref) {
  if (SafePlatform.isWeb) return .web;
  if (SafePlatform.isAndroid) return .android;
  if (SafePlatform.isIOS) return .iOS;
  if (SafePlatform.isWindows) return .windows;
  if (SafePlatform.isMacOS) return .macOS;
  if (SafePlatform.isLinux) return .linux;
  return .unknown;
}
