import 'dart:io';
import 'package:yaml/yaml.dart';

void main() async {
  final lockFile = File('pubspec.lock');
  if (!lockFile.existsSync()) {
    print('Error: Run "flutter pub get" first to generate pubspec.lock');
    return;
  }

  final yaml = loadYaml(lockFile.readAsStringSync());
  final packages = yaml['packages'] as Map;

  // Extract exact resolved versions
  final driftVersion = packages['drift']?['version'];
  final sqliteVersion = packages['sqlite3']?['version'];

  if (driftVersion == null || sqliteVersion == null) {
    print('Error: drift or sqlite3 not found in pubspec.lock');
    return;
  }

  print('Detected Drift: $driftVersion, Sqlite3: $sqliteVersion');

  final files = {
    'sqlite3.wasm':
        'https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-$sqliteVersion/sqlite3.wasm',
    'drift_worker.js':
        'https://github.com/simolus3/drift/releases/download/drift-$driftVersion/drift_worker.js',
  };

  final webDir = Directory('web');
  if (!webDir.existsSync()) {
    print('Error: no web platform directort');
    return;
  }

  for (var entry in files.entries) {
    final file = File('web/${entry.key}');
    print('Downloading ${entry.key} to ${file.path}...');

    final request = await HttpClient().getUrl(Uri.parse(entry.value));
    final response = await request.close();

    if (response.statusCode == 200) {
      await response.pipe(file.openWrite());
    } else {
      print('Failed to download ${entry.key}: ${response.statusCode}');
    }
  }
  print('Update complete!');
}

