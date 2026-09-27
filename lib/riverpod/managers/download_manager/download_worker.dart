import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kover/riverpod/managers/download_manager/download_engine.dart';
import 'package:kover/utils/cancellation_token.dart';
import 'package:kover/utils/logging.dart';

/// Timeout applied to a single chapter download.
const _downloadTimeout = Duration(minutes: 5);

class const DownloadWorkerArgs({
  required final SendPort sendPort,
  required final RootIsolateToken rootIsolateToken,
  required final String url,
  required final String key,
  required final Map<String, String> customHeaders,
  required final bool ignoreCertificateValidation,
});

/// A [DownloadWorker] is responsible for downloading chapter pages in a
/// separate context.
abstract class DownloadWorker {
  /// Spawns a new [DownloadWorker] instance. On web, it returns a
  /// [RootDownloadWorker], while on other platforms it returns an
  /// [IsolatedDownloadWorker].
  static Future<DownloadWorker> spawn({
    required String url,
    required String key,
    Map<String, String> customHeaders = const {},
    bool ignoreCertificateValidation = false,
  }) async {
    if (kIsWeb) {
      return RootDownloadWorker.fromCredentials(
        url: url,
        key: key,
        customHeaders: customHeaders,
        ignoreCertificateValidation: ignoreCertificateValidation,
      );
    }

    return await IsolatedDownloadWorker.spawn(
      url: url,
      key: key,
      customHeaders: customHeaders,
      ignoreCertificateValidation: ignoreCertificateValidation,
    );
  }

  /// Downloads every page of chapter [chapterId].
  ///
  /// [requestId] identifies this invocation so that late results or
  /// cancellations cannot affect a newer download of the same chapter.
  Future<void> downloadChapter({
    required int requestId,
    required int chapterId,
  });

  /// Cancels the in-flight download identified by [requestId], if any.
  void cancel(int requestId);

  /// Closes the worker and releases any resources associated with it.
  void close();
}

/// A [DownloadWorker] that runs downloads in the main isolate.
class RootDownloadWorker implements DownloadWorker {
  final DownloadEngine _engine;
  final Map<int, CancellationToken> _tokens = {};

  new _(this._engine);

  factory fromCredentials({
    required String url,
    required String key,
    Map<String, String> customHeaders = const {},
    bool ignoreCertificateValidation = false,
  }) {
    final engine = DownloadEngine.fromCredentials(
      url: url,
      apiKey: key,
      customHeaders: customHeaders,
      ignoreCertificateValidation: ignoreCertificateValidation,
    );
    return RootDownloadWorker._(engine);
  }

  @override
  Future<void> downloadChapter({
    required int requestId,
    required int chapterId,
  }) async {
    final token = CancellationToken();
    _tokens[requestId] = token;

    try {
      await _engine
          .downloadChapter(
            chapterId: chapterId,
            cancellationToken: token,
          )
          .timeout(_downloadTimeout, onTimeout: token.cancel);
    } finally {
      _tokens.remove(requestId);
    }
  }

  @override
  void cancel(int requestId) {
    _tokens.remove(requestId)?.cancel();
  }

  @override
  void close() {
    for (final token in _tokens.values) {
      token.cancel();
    }
    _tokens.clear();
    log.debug('RootDownloadWorker closed');
  }
}

/// A [DownloadWorker] that runs downloads in a separate worker isolate.
class IsolatedDownloadWorker implements DownloadWorker {
  final SendPort _sendPort;
  final ReceivePort _receivePort;
  final Map<int, Completer<void>> _running = {};
  bool _closed = false;

  new _(this._receivePort, this._sendPort) {
    _receivePort.listen(_handleFromIsolate);
  }

  @override
  Future<void> downloadChapter({
    required int requestId,
    required int chapterId,
  }) {
    if (_closed) return Future.error(StateError('Closed'));

    final completer = Completer<void>();
    _running[requestId] = completer;
    _sendPort.send((requestId, chapterId));
    return completer.future;
  }

  @override
  void cancel(int requestId) {
    if (_closed) return;
    if (!_running.containsKey(requestId)) return;

    _sendPort.send((requestId, null));
  }

  void _handleFromIsolate(dynamic message) {
    final (int requestId, Object? response) = message as (int, Object?);
    final completer = _running.remove(requestId);

    if (response is RemoteError) {
      completer?.completeError(response);
    } else {
      completer?.complete();
    }
  }

  @override
  void close() {
    if (_closed) return;

    _closed = true;
    _sendPort.send('shutdown');
    if (_running.isEmpty) _receivePort.close();
    log.debug('DownloadWorker closed');
  }

  static Future<DownloadWorker> spawn({
    required String url,
    required String key,
    Map<String, String> customHeaders = const {},
    bool ignoreCertificateValidation = false,
  }) async {
    final token = RootIsolateToken.instance;
    if (token == null) {
      throw Exception('RootIsolateToken is not available');
    }

    final initPort = RawReceivePort();
    final connection = Completer<(ReceivePort, SendPort)>.sync();
    initPort.handler = (initialMessage) {
      final port = initialMessage as SendPort;
      connection.complete((
        ReceivePort.fromRawReceivePort(initPort),
        port,
      ));
    };

    try {
      await Isolate.spawn(
        _startRemoteIsolate,
        DownloadWorkerArgs(
          sendPort: initPort.sendPort,
          rootIsolateToken: token,
          url: url,
          key: key,
          customHeaders: customHeaders,
          ignoreCertificateValidation: ignoreCertificateValidation,
        ),
      );
    } on Object {
      initPort.close();
      rethrow;
    }

    final (ReceivePort receivePort, SendPort sendPort) =
        await connection.future;

    return IsolatedDownloadWorker._(receivePort, sendPort);
  }

  static void _startRemoteIsolate(DownloadWorkerArgs args) {
    BackgroundIsolateBinaryMessenger.ensureInitialized(args.rootIsolateToken);
    final receivePort = ReceivePort();
    args.sendPort.send(receivePort.sendPort);
    _handleCommandsToIsolate(receivePort, args);
  }

  static void _handleCommandsToIsolate(
    ReceivePort receivePort,
    DownloadWorkerArgs args,
  ) {
    final engine = DownloadEngine.fromCredentials(
      url: args.url,
      apiKey: args.key,
      customHeaders: args.customHeaders,
      ignoreCertificateValidation: args.ignoreCertificateValidation,
    );
    final tokens = <int, CancellationToken>{};

    receivePort.listen((message) async {
      if (message == 'shutdown') {
        for (final token in tokens.values) {
          token.cancel();
        }
        tokens.clear();
        receivePort.close();
        return;
      }

      final (int requestId, int? chapterId) = message as (int, int?);

      if (chapterId == null) {
        tokens.remove(requestId)?.cancel();
        return;
      }

      final token = CancellationToken();
      tokens[requestId] = token;

      try {
        await engine
            .downloadChapter(
              chapterId: chapterId,
              cancellationToken: token,
            )
            .timeout(_downloadTimeout, onTimeout: token.cancel);
        args.sendPort.send((requestId, null));
      } catch (e, stacktrace) {
        args.sendPort.send((
          requestId,
          RemoteError(e.toString(), stacktrace.toString()),
        ));
      } finally {
        tokens.remove(requestId);
      }
    });
  }
}
