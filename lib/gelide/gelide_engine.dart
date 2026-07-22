import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:asko_pdf/gelide/gelide_worker.dart';

class GelidePageInfo {
  final double width;
  final double height;
  final int rotation;

  const GelidePageInfo({
    required this.width,
    required this.height,
    required this.rotation,
  });
}

class GelideRenderResult {
  final ui.Image image;
  final int width;
  final int height;

  const GelideRenderResult({
    required this.image,
    required this.width,
    required this.height,
  });
}

class GelideEngine {
  GelideEngine._();

  static final GelideEngine instance = GelideEngine._();

  static const double minRasterScale = 1.5;
  static const double maxRasterScale = 4.0;

  static const double thumbnailScale = 0.35;

  static double rasterScaleFor(double uiZoom, double devicePixelRatio) {
    final dpr = devicePixelRatio.clamp(1.0, 2.5);
    final zoom = uiZoom.clamp(0.5, 4.0);
    return (zoom * dpr).clamp(minRasterScale, maxRasterScale);
  }

  static const int prefetchRadius = 2;

  static const int pageCacheMax = 8;
  static const int pageCacheMaxBytes = 96 * 1024 * 1024;

  static const int thumbCacheMax = 48;
  static const int thumbCacheMaxBytes = 24 * 1024 * 1024;

  static const Duration _bootstrapTimeout = Duration(seconds: 10);
  static const Duration _initTimeout = Duration(seconds: 15);
  static const Duration _requestTimeout = Duration(seconds: 60);
  static const Duration _destroyTimeout = Duration(seconds: 2);

  Isolate? _isolate;
  SendPort? _workerPort;
  ReceivePort? _responsePort;
  ReceivePort? _errorPort;
  ReceivePort? _exitPort;
  final Map<int, Completer<Map<String, Object?>>> _pending = {};
  var _nextRequestId = 1;
  var _workerGeneration = 0;
  var _ready = false;
  var _destroying = false;
  StreamSubscription<dynamic>? _responseSub;
  StreamSubscription<dynamic>? _errorSub;
  StreamSubscription<dynamic>? _exitSub;
  Completer<SendPort>? _bootstrap;
  Future<void>? _initializationFuture;
  Future<void>? _destroyFuture;

  bool get isInitialized => _ready;

  Future<void> initialize({String? gelideLibraryPath, String? pdfiumPath}) {
    if (_ready) return Future<void>.value();
    if (_destroying) {
      return Future<void>.error(StateError('Gelide engine is being destroyed'));
    }

    final existing = _initializationFuture;
    if (existing != null) return existing;

    final operation = _initialize(
      gelideLibraryPath: gelideLibraryPath,
      pdfiumPath: pdfiumPath,
    );
    _initializationFuture = operation;
    return operation.whenComplete(() {
      if (identical(_initializationFuture, operation)) {
        _initializationFuture = null;
      }
    });
  }

  Future<void> _initialize({
    String? gelideLibraryPath,
    String? pdfiumPath,
  }) async {
    await _releaseWorkerResources(
      StateError('Gelide worker restarted'),
      killIsolate: true,
    );

    final responsePort = ReceivePort();
    final errorPort = ReceivePort();
    final exitPort = ReceivePort();
    final generation = ++_workerGeneration;

    _responsePort = responsePort;
    _errorPort = errorPort;
    _exitPort = exitPort;
    _bootstrap = Completer<SendPort>();
    _responseSub = responsePort.listen(
      (message) => _onWorkerMessage(generation, message),
    );
    _errorSub = errorPort.listen(
      (message) => _onWorkerError(generation, message),
    );
    _exitSub = exitPort.listen((_) => _onWorkerExit(generation));

    try {
      _isolate = await Isolate.spawn(
        gelideWorkerMain,
        responsePort.sendPort,
        onError: errorPort.sendPort,
        onExit: exitPort.sendPort,
        errorsAreFatal: true,
        debugName: 'gelide_worker',
      );
      _workerPort = await _bootstrap!.future.timeout(_bootstrapTimeout);
      await _request('init', {
        'libraryPath': ?gelideLibraryPath,
        'pdfiumPath': ?pdfiumPath,
      }, _initTimeout);
      _ready = true;
      debugPrint('Gelide worker isolate ready');
    } catch (error, stackTrace) {
      await _releaseWorkerResources(error, killIsolate: true);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  void _onWorkerMessage(int generation, dynamic message) {
    if (generation != _workerGeneration) return;
    if (message is SendPort && _bootstrap != null && !_bootstrap!.isCompleted) {
      _bootstrap!.complete(message);
      return;
    }
    if (message is! Map) return;
    final id = message['id'] as int?;
    if (id == null) return;
    final completer = _pending.remove(id);
    if (completer == null) return;
    if (message['ok'] == true) {
      completer.complete(Map<String, Object?>.from(message));
    } else {
      completer.completeError(
        StateError(message['error']?.toString() ?? 'Gelide worker error'),
      );
    }
  }

  void _onWorkerError(int generation, dynamic message) {
    if (generation != _workerGeneration || _destroying) return;
    final description = switch (message) {
      [final Object error, final Object stack] => '$error\n$stack',
      _ => message.toString(),
    };
    _handleWorkerFailure(
      generation,
      StateError('Gelide worker failed: $description'),
    );
  }

  void _onWorkerExit(int generation) {
    if (generation != _workerGeneration || _destroying) return;
    _handleWorkerFailure(
      generation,
      StateError('Gelide worker exited unexpectedly'),
    );
  }

  void _handleWorkerFailure(int generation, Object error) {
    if (generation != _workerGeneration) return;
    _ready = false;
    _workerPort = null;
    final bootstrap = _bootstrap;
    if (bootstrap != null && !bootstrap.isCompleted) {
      bootstrap.completeError(error);
    }
    _completePendingWithError(error);
    unawaited(_releaseWorkerResources(error, killIsolate: false));
  }

  Future<Map<String, Object?>> _request(
    String cmd, [
    Map<String, Object?> args = const {},
    Duration timeout = _requestTimeout,
  ]) async {
    if (_destroying && cmd != 'destroy') {
      throw StateError('Gelide engine is being destroyed');
    }
    final port = _workerPort;
    if (port == null) {
      throw StateError('Gelide worker is not running');
    }
    final id = _nextRequestId++;
    final completer = Completer<Map<String, Object?>>();
    _pending[id] = completer;
    port.send({'id': id, 'cmd': cmd, ...args});
    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      _pending.remove(id);
      throw TimeoutException('Gelide request "$cmd" timed out', timeout);
    }
  }

  Future<void> ensureInitialized() async {
    if (!_ready) await initialize();
  }
  Future<int> openDocument(String path, {String? password}) async {
    await ensureInitialized();
    final res = await _request('open', {
      'path': path,
      'password': ?password,
    });
    return res['docId'] as int;
  }

  Future<void> closeDocument(int? docId) async {
    if (docId == null || !_ready) return;
    try {
      await _request('close', {'docId': docId});
    } catch (e) {
      debugPrint('closeDocument: $e');
    }
  }

  Future<int> pageCount(int docId) async {
    final res = await _request('pageCount', {'docId': docId});
    return res['count'] as int;
  }

  Future<List<GelidePageInfo>> getPageInfos(int docId) async {
    final res = await _request('pageInfos', {'docId': docId});
    final widths = (res['widths'] as List)
        .map((e) => (e as num).toDouble())
        .toList();
    final heights = (res['heights'] as List)
        .map((e) => (e as num).toDouble())
        .toList();
    final rotations = (res['rotations'] as List)
        .map((e) => (e as num).toInt())
        .toList();
    return [
      for (var i = 0; i < widths.length; i++)
        GelidePageInfo(
          width: widths[i],
          height: heights[i],
          rotation: rotations[i],
        ),
    ];
  }

  Future<({String? title, String? author, String? pdfVersion})> getMeta(
    int docId,
  ) async {
    final res = await _request('meta', {'docId': docId});
    return (
      title: res['title'] as String?,
      author: res['author'] as String?,
      pdfVersion: res['pdfVersion'] as String?,
    );
  }

  Future<GelideRenderResult> renderPageScaled(
    int docId,
    int pageIndex,
    double scale,
  ) async {
    final res = await _request('render', {
      'docId': docId,
      'pageIndex': pageIndex,
      'scale': scale,
    });
    final w = res['width'] as int;
    final h = res['height'] as int;
    final transferable = res['pixels'] as TransferableTypedData;
    final bytes = transferable.materialize().asUint8List();

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      bytes,
      w,
      h,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final image = await completer.future;
    return GelideRenderResult(image: image, width: w, height: h);
  }

  Future<Uint8List> renderPagePng(
    int docId,
    int pageIndex,
    double scale,
  ) async {
    final result = await renderPageScaled(docId, pageIndex, scale);
    try {
      final bd = await result.image.toByteData(format: ui.ImageByteFormat.png);
      if (bd == null) throw StateError('Failed to encode PNG');
      return bd.buffer.asUint8List();
    } finally {
      result.image.dispose();
    }
  }

  Future<void> destroy() {
    final existing = _destroyFuture;
    if (existing != null) return existing;

    final operation = _destroy();
    _destroyFuture = operation;
    return operation.whenComplete(() {
      if (identical(_destroyFuture, operation)) {
        _destroyFuture = null;
      }
    });
  }

  Future<void> _destroy() async {
    _destroying = true;
    try {
      final initializing = _initializationFuture;
      if (initializing != null) {
        try {
          await initializing;
        } catch (_) {}
      }
      if (_workerPort != null) {
        await _request('destroy', const {}, _destroyTimeout);
      }
    } catch (_) {} finally {
      await _releaseWorkerResources(
        StateError('Gelide engine destroyed'),
        killIsolate: true,
      );
      _destroying = false;
    }
  }

  void _completePendingWithError(Object error) {
    for (final c in _pending.values) {
      if (!c.isCompleted) {
        c.completeError(error);
      }
    }
    _pending.clear();
  }

  Future<void> _releaseWorkerResources(
    Object pendingError, {
    required bool killIsolate,
  }) async {
    final isolate = _isolate;
    final responsePort = _responsePort;
    final errorPort = _errorPort;
    final exitPort = _exitPort;
    final responseSub = _responseSub;
    final errorSub = _errorSub;
    final exitSub = _exitSub;

    ++_workerGeneration;
    _isolate = null;
    _workerPort = null;
    _ready = false;
    _bootstrap = null;
    _responsePort = null;
    _errorPort = null;
    _exitPort = null;
    _responseSub = null;
    _errorSub = null;
    _exitSub = null;
    _completePendingWithError(pendingError);

    if (killIsolate) {
      isolate?.kill(priority: Isolate.immediate);
    }
    await responseSub?.cancel();
    await errorSub?.cancel();
    await exitSub?.cancel();
    responsePort?.close();
    errorPort?.close();
    exitPort?.close();
  }
}
