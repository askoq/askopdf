import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'package:asko_pdf/gelide/gelide_bindings.dart';

void gelideWorkerMain(SendPort mainSendPort) {
  const maxBitmapDimension = 16384;
  const maxBitmapBytes = 256 * 1024 * 1024;

  final port = ReceivePort();
  mainSendPort.send(port.sendPort);

  GelideBindings? bindings;
  Pointer<Void>? engine;
  final documents = <int, Pointer<Void>>{};
  var nextDocId = 1;

  void reply(int id, Map<String, Object?> payload) {
    mainSendPort.send({'id': id, ...payload});
  }

  void replyOk(int id, [Map<String, Object?> data = const {}]) {
    reply(id, {'ok': true, ...data});
  }

  void replyErr(int id, Object error) {
    reply(id, {'ok': false, 'error': error.toString()});
  }

  String defaultPdfiumPath() {
    final dir = File(Platform.resolvedExecutable).parent.path;
    if (Platform.isWindows) {
      return '$dir${Platform.pathSeparator}pdfium.dll';
    }
    if (Platform.isLinux) {
      return '$dir${Platform.pathSeparator}libpdfium.so';
    }
    return '$dir${Platform.pathSeparator}libpdfium.dylib';
  }

  Pointer<Void> requireDoc(int docId) {
    final doc = documents[docId];
    if (doc == null || doc == nullptr) {
      throw StateError('Unknown document id: $docId');
    }
    return doc;
  }

  port.listen((message) {
    if (message is! Map) return;
    final id = message['id'] as int;
    final cmd = message['cmd'] as String;

    try {
      switch (cmd) {
        case 'init':
          if (engine != null && engine != nullptr) {
            replyOk(id);
            break;
          }
          final libPath = message['libraryPath'] as String?;
          final pdfium =
              (message['pdfiumPath'] as String?) ?? defaultPdfiumPath();
          final b = GelideBindings.load(libPath);
          final pdfiumNative = pdfium.toNativeUtf8();
          try {
            final eng = b.createEngine(pdfiumNative);
            if (eng == nullptr) {
              throw StateError(
                b.takeLastError() ?? 'gelide_create_engine failed',
              );
            }
            bindings = b;
            engine = eng;
          } finally {
            malloc.free(pdfiumNative);
          }
          replyOk(id, {'pdfium': pdfium});
          break;

        case 'open':
          final b = bindings!;
          final eng = engine!;
          final path = message['path'] as String;
          final password = message['password'] as String?;
          final pathNative = path.toNativeUtf8();
          try {
            late final Pointer<Void> doc;
            if (password != null) {
              final passNative = password.toNativeUtf8();
              try {
                doc = b.openDocumentWithPassword(eng, pathNative, passNative);
              } finally {
                malloc.free(passNative);
              }
            } else {
              doc = b.openDocument(eng, pathNative);
            }
            if (doc == nullptr) {
              throw StateError(b.takeLastError() ?? 'open failed');
            }
            final docId = nextDocId++;
            documents[docId] = doc;
            replyOk(id, {'docId': docId});
          } finally {
            malloc.free(pathNative);
          }
          break;

        case 'close':
          final docId = message['docId'] as int;
          final doc = documents.remove(docId);
          if (doc != null && doc != nullptr) {
            bindings?.closeDocument(doc);
          }
          replyOk(id);
          break;

        case 'pageCount':
          final doc = requireDoc(message['docId'] as int);
          final n = bindings!.documentPageCount(doc);
          if (n < 0) {
            throw StateError(bindings!.takeLastError() ?? 'page_count failed');
          }
          replyOk(id, {'count': n});
          break;

        case 'pageInfos':
          final doc = requireDoc(message['docId'] as int);
          final b = bindings!;
          final infos = b.getPageInfos(doc);
          try {
            if (infos.infos == nullptr || infos.count == 0) {
              final err = b.takeLastError();
              if (err != null) throw StateError(err);
              replyOk(id, {
                'widths': <double>[],
                'heights': <double>[],
                'rotations': <int>[],
              });
              break;
            }
            final widths = List<double>.filled(infos.count, 0);
            final heights = List<double>.filled(infos.count, 0);
            final rotations = List<int>.filled(infos.count, 0);
            for (var i = 0; i < infos.count; i++) {
              final p = infos.infos[i];
              widths[i] = p.width.toDouble();
              heights[i] = p.height.toDouble();
              rotations[i] = p.rotation;
            }
            replyOk(id, {
              'widths': widths,
              'heights': heights,
              'rotations': rotations,
            });
          } finally {
            if (infos.infos != nullptr) {
              b.freePageInfos(infos);
            }
          }
          break;

        case 'meta':
          final doc = requireDoc(message['docId'] as int);
          final b = bindings!;
          replyOk(id, {
            'title': b.readOwnedString(b.getTitle, doc),
            'author': b.readOwnedString(b.getAuthor, doc),
            'pdfVersion': b.readOwnedString(b.getPdfVersion, doc),
          });
          break;

        case 'render':
          final doc = requireDoc(message['docId'] as int);
          final pageIndex = message['pageIndex'] as int;
          final scale = (message['scale'] as num).toDouble();
          if (!scale.isFinite || scale <= 0) {
            throw ArgumentError.value(scale, 'scale', 'must be finite and > 0');
          }
          final b = bindings!;
          final bmp = b.renderPageScaled(doc, pageIndex, scale);
          try {
            if (bmp.data == nullptr ||
                bmp.len == 0 ||
                bmp.width == 0 ||
                bmp.height == 0) {
              throw StateError(b.takeLastError() ?? 'empty bitmap');
            }
            if (bmp.width > maxBitmapDimension ||
                bmp.height > maxBitmapDimension) {
              throw StateError(
                'Bitmap dimensions exceed the supported limit: '
                '${bmp.width}x${bmp.height}',
              );
            }
            final expectedBytes = bmp.width * bmp.height * 4;
            if (expectedBytes > maxBitmapBytes) {
              throw StateError(
                'Bitmap exceeds the supported memory limit: $expectedBytes bytes',
              );
            }
            if (bmp.len != expectedBytes) {
              throw StateError(
                'Invalid RGBA bitmap length: ${bmp.len}, expected $expectedBytes',
              );
            }

            final bytes = Uint8List.fromList(bmp.data.asTypedList(bmp.len));
            replyOk(id, {
              'width': bmp.width,
              'height': bmp.height,
              'pixels': TransferableTypedData.fromList([bytes]),
            });
          } finally {
            if (bmp.data != nullptr) {
              b.freeBitmap(bmp);
            }
          }
          break;

        case 'destroy':
          for (final doc in documents.values) {
            if (doc != nullptr) bindings?.closeDocument(doc);
          }
          documents.clear();
          if (engine != null && engine != nullptr) {
            bindings?.destroyEngine(engine!);
          }
          engine = null;
          bindings = null;
          replyOk(id);
          break;

        default:
          throw StateError('Unknown command: $cmd');
      }
    } catch (e) {
      replyErr(id, e);
    }
  });
}
