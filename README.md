<div align="center">
  <img src="assets/icon/icon_rounded.png" width="120" alt="Kover icon" />

# Kover

An unofficial cross-platform Kavita frontend.

</div>

## Overview

### Features

- **Library Browsing** — browse series, collections, and libraries hosted on the Kavita server
- **Offline Reading** — content can be downloaded for reading without an active connection
- **Progress Sync** — reading progress is synced with the Kavita server; progress made offline is stored locally until a connection is available
- **Cross-Platform** — built with Flutter with the goal of keeping all platforms supported, including desktop and
  (because why not) web

## Getting Started

### Building from Source

This project makes heavy use of code generation for APIs, model and database objects. The generated code is also not committed to the repository, so building from source requires a few extra steps:

- install dependencies with

  ```bash
  flutter pub get
  ```

- run build_runner to generate all annotated code

  ```bash
  dart run build_runner build --delete-conflicting-outputs
  ```

- finally the project can be build as usual with `flutter build` or run in debug mode with `flutter run`

Note: remember to regenerate code when modifying annotated classes or run with `dart run build_runner watch
--delete-conflicting-outputs` during development to watch for changes.

#### Building Web

Web requires additional dependencies to be available, namely the Drift worker and Sqlite3.

A script that pulls the correct versions based on the `pubspec.lock` is available under `tools` and can be run with

```
dart run tools/fetch_web_dependencies.dart
```

**Note**: due to CORS, the web version has to be deployed alongside the Kavita server. Alternatively a reverse proxy could
probably be used to inject additional HTTP headers. This is completely untested and no official guidance exists.

## Screenshots

<p align="center">
  <img src="screenshots/home.png" alt="Screenshot" width="220" />
  <img src="screenshots/series_details.png" alt="Screenshot" width="220" />
  <img src="screenshots/want_to_read.png" alt="Screenshot" width="220" />
</p>

<p align="center">
  <img src="screenshots/image_reader.png" alt="Screenshot" width="220" />
  <img src="screenshots/epub_reader.png" alt="Screenshot" width="220" />
  <img src="screenshots/image_reader_settings.png" alt="Screenshot" width="220" />
</p>

<p align="center">
  <img src="screenshots/epub_reader_settings.png" alt="Screenshot" width="220" />
  <img src="screenshots/menu.png" alt="Screenshot" width="220" />
  <img src="screenshots/settings.png" alt="Screenshot" width="220" />
</p>
