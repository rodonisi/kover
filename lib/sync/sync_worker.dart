import 'dart:async';
import 'dart:isolate';

import 'package:chopper/chopper.dart';
import 'package:flutter/services.dart';
import 'package:kover/riverpod/managers/sync_manager.dart';
import 'package:kover/sync/sync_engine.dart';
import 'package:kover/utils/logging.dart';

class const SyncWorkerArgs({
  required final SendPort sendPort,
  required final RootIsolateToken rootIsolateToken,
  required final String url,
  required final String key,
  required final Map<String, String> customHeaders,
});

class SyncWorker {
  final SendPort _sendPort;
  final ReceivePort _receivePort;
  final Map<SyncPhase, Completer<void>> _runningPhases = {};
  bool _closed = false;

  SyncWorker._(this._receivePort, this._sendPort) {
    _receivePort.listen(_handleFromIsolate);
  }

  Future<void> runPhase(SyncPhase phase) async {
    if (_closed) throw StateError('Closed');

    if (_runningPhases.containsKey(phase)) return;

    final completer = Completer<void>();
    _runningPhases[phase] = completer;
    _sendPort.send(phase);
    return completer.future;
  }

  void _handleFromIsolate(dynamic message) {
    final (SyncPhase phase, Object? response) = message as (SyncPhase, Object?);
    final completer = _runningPhases.remove(phase);

    if (response is RemoteError) {
      completer?.completeError(response);
    } else {
      completer?.complete();
    }
  }

  void close() {
    if (!_closed) {
      _closed = true;
      _sendPort.send('shutdown');
      if (_runningPhases.isEmpty) _receivePort.close();
      log.debug('SyncWorker closed');
    }
  }

  static Future<SyncWorker> spawn({
    required String url,
    required String key,
    Map<String, String> customHeaders = const {},
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
        SyncWorkerArgs(
          sendPort: initPort.sendPort,
          rootIsolateToken: token,
          url: url,
          key: key,
          customHeaders: customHeaders,
        ),
      );
    } on Object {
      initPort.close();
      rethrow;
    }

    final (ReceivePort receivePort, SendPort sendPort) =
        await connection.future;

    return SyncWorker._(receivePort, sendPort);
  }

  static void _startRemoteIsolate(SyncWorkerArgs args) {
    BackgroundIsolateBinaryMessenger.ensureInitialized(args.rootIsolateToken);
    final receivePort = ReceivePort();
    args.sendPort.send(receivePort.sendPort);
    _handleCommandsToIsolate(receivePort, args);
  }

  static void _handleCommandsToIsolate(
    ReceivePort receivePort,
    SyncWorkerArgs args,
  ) {
    final engine = SyncEngine.fromCredentials(url: args.url, apiKey: args.key);

    receivePort.listen((message) async {
      if (message == 'shutdown') {
        receivePort.close();
        return;
      }

      final phase = message as SyncPhase;
      try {
        await engine.runPhase(phase);
        args.sendPort.send((phase, null));
      } catch (e, stacktrace) {
        args.sendPort.send((
          phase,
          RemoteError(e.toString(), stacktrace.toString()),
        ));
      }
    });
  }
}
