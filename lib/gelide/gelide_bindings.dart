import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
final class GelidePageInfoNative extends Struct {
  @Float()
  external double width;

  @Float()
  external double height;

  @Int32()
  external int rotation;
}

final class GelidePageInfosNative extends Struct {
  external Pointer<GelidePageInfoNative> infos;

  @Uint32()
  external int count;
}

final class GelideBitmapDataNative extends Struct {
  external Pointer<Uint8> data;

  @Uint32()
  external int len;

  @Uint32()
  external int width;

  @Uint32()
  external int height;
}
typedef _CreateEngineC = Pointer<Void> Function(Pointer<Utf8>);
typedef _CreateEngineDart = Pointer<Void> Function(Pointer<Utf8>);

typedef _CreateEngineSystemC = Pointer<Void> Function();
typedef _CreateEngineSystemDart = Pointer<Void> Function();

typedef _DestroyEngineC = Void Function(Pointer<Void>);
typedef _DestroyEngineDart = void Function(Pointer<Void>);

typedef _GetLastErrorC = Pointer<Utf8> Function();
typedef _GetLastErrorDart = Pointer<Utf8> Function();

typedef _OpenDocumentC = Pointer<Void> Function(Pointer<Void>, Pointer<Utf8>);
typedef _OpenDocumentDart = Pointer<Void> Function(Pointer<Void>, Pointer<Utf8>);

typedef _OpenDocumentPasswordC =
    Pointer<Void> Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);
typedef _OpenDocumentPasswordDart =
    Pointer<Void> Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);

typedef _CloseDocumentC = Void Function(Pointer<Void>);
typedef _CloseDocumentDart = void Function(Pointer<Void>);

typedef _PageCountC = Int32 Function(Pointer<Void>);
typedef _PageCountDart = int Function(Pointer<Void>);

typedef _GetPageInfoC = GelidePageInfoNative Function(Pointer<Void>, Int32);
typedef _GetPageInfoDart = GelidePageInfoNative Function(Pointer<Void>, int);

typedef _GetPageInfosC = GelidePageInfosNative Function(Pointer<Void>);
typedef _GetPageInfosDart = GelidePageInfosNative Function(Pointer<Void>);

typedef _FreePageInfosC = Void Function(GelidePageInfosNative);
typedef _FreePageInfosDart = void Function(GelidePageInfosNative);

typedef _RenderPageC =
    GelideBitmapDataNative Function(Pointer<Void>, Int32, Float);
typedef _RenderPageDart =
    GelideBitmapDataNative Function(Pointer<Void>, int, double);

typedef _RenderPageSizedC =
    GelideBitmapDataNative Function(Pointer<Void>, Int32, Uint32, Uint32);
typedef _RenderPageSizedDart =
    GelideBitmapDataNative Function(Pointer<Void>, int, int, int);

typedef _RenderPageScaledC =
    GelideBitmapDataNative Function(Pointer<Void>, Int32, Float);
typedef _RenderPageScaledDart =
    GelideBitmapDataNative Function(Pointer<Void>, int, double);

typedef _FreeBitmapC = Void Function(GelideBitmapDataNative);
typedef _FreeBitmapDart = void Function(GelideBitmapDataNative);

typedef _GetStringC = Pointer<Utf8> Function(Pointer<Void>);
typedef _GetStringDart = Pointer<Utf8> Function(Pointer<Void>);

typedef _FreeStringC = Void Function(Pointer<Utf8>);
typedef _FreeStringDart = void Function(Pointer<Utf8>);

class GelideBindings {
  GelideBindings._(this._lib)
    : createEngine = _lib.lookupFunction<_CreateEngineC, _CreateEngineDart>(
        'gelide_create_engine',
      ),
      createEngineSystem = _lib
          .lookupFunction<_CreateEngineSystemC, _CreateEngineSystemDart>(
            'gelide_create_engine_system',
          ),
      destroyEngine = _lib.lookupFunction<_DestroyEngineC, _DestroyEngineDart>(
        'gelide_destroy_engine',
      ),
      getLastErrorMessage = _lib
          .lookupFunction<_GetLastErrorC, _GetLastErrorDart>(
            'gelide_get_last_error_message',
          ),
      openDocument = _lib.lookupFunction<_OpenDocumentC, _OpenDocumentDart>(
        'gelide_open_document',
      ),
      openDocumentWithPassword = _lib
          .lookupFunction<_OpenDocumentPasswordC, _OpenDocumentPasswordDart>(
            'gelide_open_document_with_password',
          ),
      closeDocument = _lib.lookupFunction<_CloseDocumentC, _CloseDocumentDart>(
        'gelide_close_document',
      ),
      documentPageCount = _lib.lookupFunction<_PageCountC, _PageCountDart>(
        'gelide_document_page_count',
      ),
      getPageInfo = _lib.lookupFunction<_GetPageInfoC, _GetPageInfoDart>(
        'gelide_get_page_info',
      ),
      getPageInfos = _lib.lookupFunction<_GetPageInfosC, _GetPageInfosDart>(
        'gelide_get_page_infos',
      ),
      freePageInfos = _lib.lookupFunction<_FreePageInfosC, _FreePageInfosDart>(
        'gelide_free_page_infos',
      ),
      renderPage = _lib.lookupFunction<_RenderPageC, _RenderPageDart>(
        'gelide_render_page',
      ),
      renderPageSized = _lib
          .lookupFunction<_RenderPageSizedC, _RenderPageSizedDart>(
            'gelide_render_page_sized',
          ),
      renderPageScaled = _lib
          .lookupFunction<_RenderPageScaledC, _RenderPageScaledDart>(
            'gelide_render_page_scaled',
          ),
      freeBitmap = _lib.lookupFunction<_FreeBitmapC, _FreeBitmapDart>(
        'gelide_free_bitmap',
      ),
      getTitle = _lib.lookupFunction<_GetStringC, _GetStringDart>(
        'gelide_get_title',
      ),
      getAuthor = _lib.lookupFunction<_GetStringC, _GetStringDart>(
        'gelide_get_author',
      ),
      getPdfVersion = _lib.lookupFunction<_GetStringC, _GetStringDart>(
        'gelide_get_pdf_version',
      ),
      freeString = _lib.lookupFunction<_FreeStringC, _FreeStringDart>(
        'gelide_free_string',
      );

  // ignore: unused_field
  final DynamicLibrary _lib;

  final Pointer<Void> Function(Pointer<Utf8>) createEngine;
  final Pointer<Void> Function() createEngineSystem;
  final void Function(Pointer<Void>) destroyEngine;
  final Pointer<Utf8> Function() getLastErrorMessage;
  final Pointer<Void> Function(Pointer<Void>, Pointer<Utf8>) openDocument;
  final Pointer<Void> Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>)
      openDocumentWithPassword;
  final void Function(Pointer<Void>) closeDocument;
  final int Function(Pointer<Void>) documentPageCount;
  final GelidePageInfoNative Function(Pointer<Void>, int) getPageInfo;
  final GelidePageInfosNative Function(Pointer<Void>) getPageInfos;
  final void Function(GelidePageInfosNative) freePageInfos;
  final GelideBitmapDataNative Function(Pointer<Void>, int, double) renderPage;
  final GelideBitmapDataNative Function(Pointer<Void>, int, int, int)
      renderPageSized;
  final GelideBitmapDataNative Function(Pointer<Void>, int, double)
      renderPageScaled;
  final void Function(GelideBitmapDataNative) freeBitmap;
  final Pointer<Utf8> Function(Pointer<Void>) getTitle;
  final Pointer<Utf8> Function(Pointer<Void>) getAuthor;
  final Pointer<Utf8> Function(Pointer<Void>) getPdfVersion;
  final void Function(Pointer<Utf8>) freeString;

  static DynamicLibrary openLibrary([String? path]) {
    if (path != null) {
      return DynamicLibrary.open(path);
    }
    final executableDirectory = File(Platform.resolvedExecutable).parent.path;
    late final String libraryName;
    if (Platform.isWindows) {
      libraryName = 'gelide_core.dll';
    } else if (Platform.isLinux) {
      libraryName = 'libgelide_core.so';
    } else if (Platform.isMacOS) {
      libraryName = 'libgelide_core.dylib';
    } else {
      throw UnsupportedError('Gelide is not supported on this platform');
    }
    return DynamicLibrary.open(
      '$executableDirectory${Platform.pathSeparator}$libraryName',
    );
  }

  static GelideBindings load([String? libraryPath]) {
    return GelideBindings._(openLibrary(libraryPath));
  }

  String? takeLastError() {
    final ptr = getLastErrorMessage();
    if (ptr == nullptr) return null;
    final message = ptr.toDartString();
    freeString(ptr);
    return message;
  }

  String? readOwnedString(Pointer<Utf8> Function(Pointer<Void>) getter, Pointer<Void> doc) {
    final ptr = getter(doc);
    if (ptr == nullptr) return null;
    final value = ptr.toDartString();
    freeString(ptr);
    return value;
  }
}
