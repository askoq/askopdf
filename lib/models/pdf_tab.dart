import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:asko_pdf/models/pdf_metadata.dart';
import 'package:asko_pdf/gelide/gelide_engine.dart';

class PageImageLru {
  PageImageLru(this.maxSize, {required this.maxBytes});

  final int maxSize;
  final int maxBytes;
  final List<ui.Image?> slots = [];
  final LinkedHashSet<int> _order = LinkedHashSet<int>();
  final Map<int, int> _byteSizes = {};
  final Set<int> inFlight = {};
  int _estimatedBytes = 0;

  int get estimatedBytes => _estimatedBytes;

  void allocate(int pageCount) {
    disposeAll();
    slots
      ..clear()
      ..addAll(List<ui.Image?>.filled(pageCount, null));
  }

  ui.Image? operator [](int index) {
    if (index < 0 || index >= slots.length) return null;
    return slots[index];
  }

  void touch(int index) {
    if (index < 0 || index >= slots.length) return;
    if (slots[index] == null) return;
    _order.remove(index);
    _order.add(index);
  }

  void put(int index, ui.Image image, {Set<int> protect = const {}}) {
    if (index < 0 || index >= slots.length) {
      image.dispose();
      return;
    }
    _disposeIndex(index);
    slots[index] = image;
    final bytes = image.width * image.height * 4;
    _byteSizes[index] = bytes;
    _estimatedBytes += bytes;
    _order.remove(index);
    _order.add(index);
    _evict(protect);
  }

  void _evict(Set<int> protect) {
    while (_order.length > maxSize ||
        (_estimatedBytes > maxBytes && _order.length > 1)) {
      int? victim;
      for (final i in _order) {
        if (!protect.contains(i)) {
          victim = i;
          break;
        }
      }
      victim ??= _order.first;
      _disposeIndex(victim);
    }
  }

  void _disposeIndex(int index) {
    if (index < 0 || index >= slots.length) return;
    _order.remove(index);
    _estimatedBytes -= _byteSizes.remove(index) ?? 0;
    if (_estimatedBytes < 0) _estimatedBytes = 0;
    slots[index]?.dispose();
    slots[index] = null;
  }

  void clearImages() {
    for (var i = 0; i < slots.length; i++) {
      _disposeIndex(i);
    }
    _order.clear();
    _byteSizes.clear();
    _estimatedBytes = 0;
    inFlight.clear();
  }

  void disposeAll() {
    for (var i = 0; i < slots.length; i++) {
      _disposeIndex(i);
    }
    slots.clear();
    _order.clear();
    _byteSizes.clear();
    _estimatedBytes = 0;
    inFlight.clear();
  }
}

class PdfTab {
  final String id;
  final String filePath;
  String documentTitle;

  double scale = 1.0;

  double cachedRasterScale = 0.0;
  double globalRotationAngle = 0.0;
  List<double> pageRotations = [];
  bool rotateAllPagesMode = false;

  final ScrollController scrollController = ScrollController();
  final ScrollController horizontalScrollController = ScrollController();

  int totalPages = 0;
  int currentPage = 1;

  bool isLoading = true;
  double loadingProgress = 0.0;
  String loadingMessage = 'Initializing...';

  int? documentId;

  final PageImageLru pages = PageImageLru(
    GelideEngine.pageCacheMax,
    maxBytes: GelideEngine.pageCacheMaxBytes,
  );
  final PageImageLru thumbs = PageImageLru(
    GelideEngine.thumbCacheMax,
    maxBytes: GelideEngine.thumbCacheMaxBytes,
  );

  int loadGeneration = 0;
  int pageRenderGeneration = 0;
  int thumbnailRenderGeneration = 0;
  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;

  List<Size> pageSizes = [];
  List<double> pageOffsets = [];

  PdfMetadata? metadata;

  PdfTab({required this.id, required this.filePath, this.documentTitle = ''});

  int beginLoad() {
    if (_isDisposed) throw StateError('Cannot load a disposed PDF tab');
    return ++loadGeneration;
  }

  void clearPageImages() {
    pageRenderGeneration++;
    pages.clearImages();
  }

  void disposeImages() {
    pageRenderGeneration++;
    thumbnailRenderGeneration++;
    pages.disposeAll();
    thumbs.disposeAll();
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    loadGeneration++;
    disposeImages();
    final id = documentId;
    documentId = null;
    if (id != null) {
      unawaited(GelideEngine.instance.closeDocument(id));
    }
    scrollController.dispose();
    horizontalScrollController.dispose();
  }

  double pageLayoutHeight(int index) {
    if (index < 0 || index >= pageSizes.length) return 0.0;
    final size = pageSizes[index];
    final angle =
        (globalRotationAngle +
            (index < pageRotations.length ? pageRotations[index] : 0.0)) %
        360;
    final quarter = (((angle % 360) + 360) % 360 ~/ 90) % 4;
    return quarter.isOdd ? size.width : size.height;
  }

  void calculatePageOffsets({required double pageSpacing}) {
    if (pageSizes.isEmpty) return;
    final offsets = <double>[];
    double cumulativeHeight = 0;
    for (int i = 0; i < totalPages; i++) {
      offsets.add(cumulativeHeight);
      cumulativeHeight += pageLayoutHeight(i) + pageSpacing;
    }
    pageOffsets = offsets;
  }

  List<int> prefetchPageIndices({required double pageSpacing}) {
    if (totalPages == 0 || pageOffsets.isEmpty) return const [];

    int first;
    int last;

    if (!scrollController.hasClients) {
      final around = currentPage - 1;
      first = around;
      last = around;
    } else {
      final offset = scrollController.offset;
      final viewport = scrollController.position.viewportDimension;
      final top = offset;
      final bottom = offset + viewport;
      final scaledPadding = pageSpacing * scale;

      first = 0;
      last = totalPages - 1;

      for (var i = 0; i < pageOffsets.length; i++) {
        final pageTop = pageOffsets[i] * scale + scaledPadding;
        final pageHeight = pageLayoutHeight(i) * scale;
        final pageBottom = pageTop + pageHeight;
        if (pageBottom >= top) {
          first = i;
          break;
        }
      }
      for (var i = first; i < pageOffsets.length; i++) {
        final pageTop = pageOffsets[i] * scale + scaledPadding;
        if (pageTop > bottom) {
          last = i - 1;
          break;
        }
        last = i;
      }
    }

    final r = GelideEngine.prefetchRadius;
    first = (first - r).clamp(0, totalPages - 1);
    last = (last + r).clamp(0, totalPages - 1);
    return [for (var i = first; i <= last; i++) i];
  }
}
