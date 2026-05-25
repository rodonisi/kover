import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'package_info.freezed.dart';
part 'package_info.g.dart';

@freezed
sealed class PackageInfoState with _$PackageInfoState {
  const factory PackageInfoState({
    required String appName,
    required String packageName,
    required String version,
    required String buildNumber,
  }) = _PackageInfoState;
}

@riverpod
Future<PackageInfo> packageInfo(Ref ref) async {
  final info = await PackageInfo.fromPlatform();

  return PackageInfo(
    appName: info.appName,
    packageName: info.packageName,
    version: info.version,
    buildNumber: info.buildNumber,
  );
}
