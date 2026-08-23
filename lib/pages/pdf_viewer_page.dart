import 'dart:async';
import 'dart:math';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:asko_pdf/services/recent_files_service.dart';
import 'package:asko_pdf/services/document_state_service.dart';
import 'package:asko_pdf/widgets/pdf_navigation_drawer.dart';
import 'package:asko_pdf/widgets/document_info_dialog.dart';
import 'package:asko_pdf/widgets/custom_zoom_dialog.dart';
import 'package:asko_pdf/widgets/settings_dialog.dart';
import 'package:asko_pdf/models/pdf_tab.dart';
import 'package:asko_pdf/models/pdf_metadata.dart';
import 'package:asko_pdf/widgets/pdf_tab_bar.dart';
import 'package:asko_pdf/services/settings_service.dart';
import 'package:asko_pdf/gelide/gelide_engine.dart';
import 'package:asko_pdf/pages/pdf_viewer_components.dart';

class _PdfLoadCancelled implements Exception {
  const _PdfLoadCancelled();
}

class PdfViewerPage extends StatefulWidget {
  const PdfViewerPage({super.key});

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  static const double _minScale = 0.1;
  static const double _maxScale = 4.0;
  static const double _pageSpacing = 16.0;
  static const Duration _stateSaveDebounce = Duration(milliseconds: 350);

  final List<PdfTab> _tabs = [];
  int _currentTabIndex = -1;
  bool _isTabBarExpanded = false;

  final RecentFilesService _recentFilesService = RecentFilesService();
  final DocumentStateService _documentStateService = DocumentStateService();
  final SettingsService _settingsService = SettingsService();
  final Map<String, Timer> _stateSaveTimers = {};

  List<String> _recentFiles = [];
  bool _isRecentFilesExpanded = true;
  bool _isDragging = false;
  bool _copyPageAsImageEnabled = true;
  OverlayEntry? _rotationMenuOverlay;
  final GlobalKey _rotateButtonKey = GlobalKey();

  PdfTab? get _activeTab =>
      (_currentTabIndex >= 0 && _currentTabIndex < _tabs.length)
      ? _tabs[_currentTabIndex]
      : null;

  @override
  void initState() {
    super.initState();
    _loadRecentFiles();
    _loadRecentFilesExpanded();
    _loadSettings();
  }

  @override
  void dispose() {
    _closeRotationMenu();
    for (var tab in _tabs) {
      _saveStateNow(tab);
      tab.dispose();
    }
    for (final timer in _stateSaveTimers.values) {
      timer.cancel();
    }
    _stateSaveTimers.clear();
    unawaited(GelideEngine.instance.destroy());
    super.dispose();
  }

  void _closeRotationMenu() {
    _rotationMenuOverlay?.remove();
    _rotationMenuOverlay = null;
  }

  void _toggleRotationMenu(BuildContext context, GlobalKey buttonKey) {
    if (_rotationMenuOverlay != null) {
      _closeRotationMenu();
      return;
    }
    final tab = _activeTab;
    if (tab == null) return;

    _rotationMenuOverlay = createPdfRotationMenuOverlay(
      context: context,
      buttonKey: buttonKey,
      tab: tab,
      onClose: _closeRotationMenu,
      onRotatePage: _rotatePage,
      onRefresh: () {
        if (mounted) setState(() {});
      },
    );
    Overlay.of(context).insert(_rotationMenuOverlay!);
  }

  Future<void> _loadRecentFiles() async {
    final files = await _recentFilesService.getRecentFiles();
    if (mounted) {
      setState(() {
        _recentFiles = files;
      });
    }
  }

  Future<void> _loadRecentFilesExpanded() async {
    final expanded = await _recentFilesService.getRecentFilesExpanded();
    if (mounted) {
      setState(() {
        _isRecentFilesExpanded = expanded;
      });
    }
  }

  Future<void> _toggleRecentFilesExpanded() async {
    final newValue = !_isRecentFilesExpanded;
    await _recentFilesService.setRecentFilesExpanded(newValue);
    if (mounted) {
      setState(() {
        _isRecentFilesExpanded = newValue;
      });
    }
  }

  Future<void> _loadSettings() async {
    final copyEnabled = await _settingsService.getCopyPageAsImageEnabled();
    if (mounted) {
      setState(() {
        _copyPageAsImageEnabled = copyEnabled;
      });
    }
  }

  Future<void> _saveCurrentState(PdfTab tab) async {
    if (tab.filePath.isNotEmpty && tab.totalPages > 0) {
      try {
        await _documentStateService.saveDocumentState(
          tab.filePath,
          currentPage: tab.currentPage,
          scale: tab.scale,
        );
      } catch (e) {
        debugPrint('Failed to save document state: $e');
      }
    }
  }

  void _scheduleStateSave(PdfTab tab) {
    if (tab.isDisposed) return;
    _stateSaveTimers.remove(tab.id)?.cancel();
    _stateSaveTimers[tab.id] = Timer(_stateSaveDebounce, () {
      _stateSaveTimers.remove(tab.id);
      if (!tab.isDisposed) unawaited(_saveCurrentState(tab));
    });
  }

  void _saveStateNow(PdfTab tab) {
    _stateSaveTimers.remove(tab.id)?.cancel();
    unawaited(_saveCurrentState(tab));
  }

  Future<void> _openPdfFile() async {
    try {
      const typeGroup = XTypeGroup(
        label: 'PDF files',
        extensions: ['pdf'],
        mimeTypes: ['application/pdf'],
        uniformTypeIdentifiers: ['com.adobe.pdf'],
      );
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (!mounted || file == null) return;
      unawaited(_openFile(file.path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open file picker: $e'),
          ),
        );
      }
    }
  }

  Future<void> _openFile(String filePath, {bool fromRecent = false}) async {
    final file = File(filePath);
    final exists = await file.exists();
    if (!mounted) return;
    if (!exists) {
      await _recentFilesService.removeRecentFile(filePath);
      await _loadRecentFiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF file was deleted or moved'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    if (fromRecent) {
      final ok = await _recentFilesService.verifyRecentFile(filePath);
      if (!mounted) return;
      if (!ok) {
        await _recentFilesService.removeRecentFile(filePath);
        await _loadRecentFiles();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recent file no longer matches saved fingerprint'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
    }

    final existingIndex = _tabs.indexWhere((tab) => tab.filePath == filePath);
    if (existingIndex != -1) {
      if (_currentTabIndex != existingIndex) {
        setState(() {
          _currentTabIndex = existingIndex;
        });
      }
      await _recentFilesService.addRecentFile(filePath);
      await _loadRecentFiles();
      return;
    }

    final newTab = PdfTab(
      id: '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}',
      filePath: filePath,
    );

    newTab.scrollController.addListener(_onScroll);

    setState(() {
      _tabs.add(newTab);
      _currentTabIndex = _tabs.length - 1;
      _isTabBarExpanded = false;
    });

    await _loadAndRenderPdf(newTab);
  }

  Future<void> _loadAndRenderPdf(PdfTab tab) async {
    final loadGeneration = tab.beginLoad();
    int? openedDocumentId;
    setState(() {
      tab.isLoading = true;
      tab.loadingProgress = 0.0;
      tab.loadingMessage = 'Opening document...';
      tab.disposeImages();
      tab.pageSizes = [];
      tab.pageOffsets = [];
      tab.globalRotationAngle = 0.0;
      tab.pageRotations = [];
    });

    try {
      await GelideEngine.instance.ensureInitialized();
      _ensureLoadActive(tab, loadGeneration);

      if (mounted) {
        setState(() {
          tab.loadingProgress = 0.2;
          tab.loadingMessage = 'Opening with Gelide...';
        });
      }

      final docId = await GelideEngine.instance.openDocument(tab.filePath);
      openedDocumentId = docId;
      tab.documentId = docId;
      _ensureLoadActive(tab, loadGeneration);

      final pagesCount = await GelideEngine.instance.pageCount(docId);
      _ensureLoadActive(tab, loadGeneration);
      if (pagesCount <= 0) {
        throw StateError('Document has no pages');
      }

      if (mounted) {
        setState(() {
          tab.loadingProgress = 0.5;
          tab.loadingMessage = 'Reading page layout...';
        });
      }

      final infos = await GelideEngine.instance.getPageInfos(docId);
      _ensureLoadActive(tab, loadGeneration);
      final newPageSizes = List<Size>.generate(pagesCount, (i) {
        if (i < infos.length) {
          final info = infos[i];
          final rot = info.rotation % 360;
          if (rot == 90 || rot == 270) {
            return Size(info.height, info.width);
          }
          return Size(info.width, info.height);
        }
        return const Size(595, 842);
      });

      try {
        tab.documentTitle = tab.filePath.split(Platform.pathSeparator).last;

        final file = File(tab.filePath);
        final fileStat = await file.stat();
        final meta = await GelideEngine.instance.getMeta(docId);
        var pdfVersion = meta.pdfVersion;
        if (pdfVersion != null && pdfVersion.startsWith('Pdf')) {
          pdfVersion = pdfVersion
              .replaceFirst(RegExp(r'^Pdf'), '')
              .replaceAll('_', '.');
        }
        if (pdfVersion == null || pdfVersion.isEmpty) {
          try {
            final bytes = await file.openRead(0, 20).first;
            final header = String.fromCharCodes(bytes);
            final match = RegExp(r'%PDF-(\d+\.\d+)').firstMatch(header);
            if (match != null) {
              pdfVersion = match.group(1);
            }
          } catch (_) {}
        }

        tab.metadata = PdfMetadata(
          fileSize: fileStat.size,
          lastModified: fileStat.modified,
          lastAccessed: fileStat.accessed,
          pdfVersion: pdfVersion,
        );
      } catch (e) {
        debugPrint('Metadata error: $e');
      }
      _ensureLoadActive(tab, loadGeneration);

      final savedState = await _documentStateService.getDocumentState(
        tab.filePath,
      );
      _ensureLoadActive(tab, loadGeneration);
      final restoredPage = savedState?.currentPage ?? 1;
      final restoredScale = savedState?.scale ?? 1.0;

      setState(() {
        tab.totalPages = pagesCount;
        tab.pages.allocate(pagesCount);
        tab.thumbs.allocate(pagesCount);
        tab.pageSizes = newPageSizes;
        tab.pageRotations = List<double>.filled(pagesCount, 0.0);
        tab.calculatePageOffsets(pageSpacing: _pageSpacing);
        if (tab == _activeTab) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
        }
        tab.isLoading = false;
        tab.loadingProgress = 1.0;
        tab.scale = restoredScale.clamp(_minScale, _maxScale);
        tab.currentPage = restoredPage.clamp(1, pagesCount);
      });

      try {
        await _recentFilesService.addRecentFile(tab.filePath);
        if (mounted) await _loadRecentFiles();
      } catch (e) {
        debugPrint('Failed to update recent files: $e');
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isLoadActive(tab, loadGeneration)) return;
        if (restoredPage > 1 &&
            restoredPage <= pagesCount &&
            tab.pageOffsets.isNotEmpty &&
            tab.scrollController.hasClients) {
          final targetOffset = tab.pageOffsets[restoredPage - 1] * tab.scale;
          tab.scrollController.jumpTo(targetOffset);
        }
        _ensureVisiblePagesRendered(tab);
      });
    } on _PdfLoadCancelled {
      await _releaseTabDocument(tab, openedDocumentId);
    } catch (e) {
      await _releaseTabDocument(tab, openedDocumentId);
      if (!mounted) return;
      if (!_isLoadActive(tab, loadGeneration)) return;

      setState(() {
        final idx = _tabs.indexOf(tab);
        if (idx >= 0) {
          _tabs.removeAt(idx);
          if (_currentTabIndex >= _tabs.length) {
            _currentTabIndex = _tabs.length - 1;
          }
        }
      });
      tab.scrollController.removeListener(_onScroll);
      tab.dispose();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load PDF file. Error: $e')),
      );
    }
  }

  bool _isLoadActive(PdfTab tab, int generation) {
    return mounted &&
        !tab.isDisposed &&
        tab.loadGeneration == generation &&
        _tabs.contains(tab);
  }

  void _ensureLoadActive(PdfTab tab, int generation) {
    if (!_isLoadActive(tab, generation)) throw const _PdfLoadCancelled();
  }

  Future<void> _releaseTabDocument(PdfTab tab, int? documentId) async {
    if (tab.documentId == documentId) tab.documentId = null;
    if (documentId != null) {
      await GelideEngine.instance.closeDocument(documentId);
    }
  }

  void _closeTab(int index) {
    if (index < 0 || index >= _tabs.length) return;

    final tab = _tabs[index];

    _saveStateNow(tab);

    tab.dispose();

    setState(() {
      _tabs.removeAt(index);
      if (_currentTabIndex >= _tabs.length) {
        _currentTabIndex = _tabs.length - 1;
      }
      _isTabBarExpanded = false;
    });
  }

  void _onReorderTabs(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final PdfTab item = _tabs.removeAt(oldIndex);
      _tabs.insert(newIndex, item);

      if (_currentTabIndex == oldIndex) {
        _currentTabIndex = newIndex;
      } else if (_currentTabIndex > oldIndex && _currentTabIndex <= newIndex) {
        _currentTabIndex--;
      } else if (_currentTabIndex < oldIndex && _currentTabIndex >= newIndex) {
        _currentTabIndex++;
      }
    });
  }

  void _onScroll() {
    final tab = _activeTab;
    if (tab == null ||
        tab.pageOffsets.isEmpty ||
        !tab.scrollController.hasClients) {
      return;
    }

    final viewportCenter =
        tab.scrollController.offset +
        tab.scrollController.position.viewportDimension / 2;
    final scaledPadding = _pageSpacing * tab.scale;

    int newPage = 1;
    for (int i = 0; i < tab.pageOffsets.length; i++) {
      final scaledOffset = tab.pageOffsets[i] * tab.scale + scaledPadding;
      if (scaledOffset <= viewportCenter) {
        newPage = i + 1;
      } else {
        break;
      }
    }

    if (newPage != tab.currentPage) {
      setState(() {
        tab.currentPage = newPage;
      });
      _scheduleStateSave(tab);
    }

    _ensureVisiblePagesRendered(tab);
  }

  Set<int> _protectSet(List<int> indices) => indices.toSet();

  void _ensureVisiblePagesRendered(PdfTab? tab) {
    if (tab == null || tab.documentId == null || tab.isLoading) return;
    final indices = tab.prefetchPageIndices(pageSpacing: _pageSpacing);
    for (final i in indices) {
      tab.pages.touch(i);
      unawaited(_renderPageIfNeeded(tab, i, protect: _protectSet(indices)));
    }
  }

  double _rasterScale(PdfTab tab) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return GelideEngine.rasterScaleFor(tab.scale, dpr);
  }

  Future<void> _renderPageIfNeeded(
    PdfTab tab,
    int pageIndex, {
    Set<int> protect = const {},
  }) async {
    if (pageIndex < 0 || pageIndex >= tab.totalPages) return;
    final documentId = tab.documentId;
    if (documentId == null || tab.isDisposed) return;
    if (tab.pages[pageIndex] != null) {
      tab.pages.touch(pageIndex);
      return;
    }
    if (tab.pages.inFlight.contains(pageIndex)) return;

    tab.pages.inFlight.add(pageIndex);
    final generation = tab.pageRenderGeneration;
    try {
      final raster = _rasterScale(tab);
      tab.cachedRasterScale = raster;
      final result = await GelideEngine.instance.renderPageScaled(
        documentId,
        pageIndex,
        raster,
      );
      if (!mounted ||
          tab.isDisposed ||
          tab.documentId != documentId ||
          tab.pageRenderGeneration != generation) {
        result.image.dispose();
        return;
      }
      tab.pages.put(pageIndex, result.image, protect: protect);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Render page $pageIndex failed: $e');
    } finally {
      if (tab.pageRenderGeneration == generation) {
        tab.pages.inFlight.remove(pageIndex);
      }
    }
  }

  Future<void> _renderThumbnailIfNeeded(PdfTab tab, int pageIndex) async {
    if (pageIndex < 0 || pageIndex >= tab.totalPages) return;
    final documentId = tab.documentId;
    if (documentId == null || tab.isDisposed) return;
    if (tab.thumbs[pageIndex] != null) {
      tab.thumbs.touch(pageIndex);
      return;
    }
    if (tab.thumbs.inFlight.contains(pageIndex)) return;

    tab.thumbs.inFlight.add(pageIndex);
    final generation = tab.thumbnailRenderGeneration;
    try {
      final result = await GelideEngine.instance.renderPageScaled(
        documentId,
        pageIndex,
        GelideEngine.thumbnailScale,
      );
      if (!mounted ||
          tab.isDisposed ||
          tab.documentId != documentId ||
          tab.thumbnailRenderGeneration != generation) {
        result.image.dispose();
        return;
      }
      tab.thumbs.put(pageIndex, result.image);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Thumbnail $pageIndex failed: $e');
    } finally {
      if (tab.thumbnailRenderGeneration == generation) {
        tab.thumbs.inFlight.remove(pageIndex);
      }
    }
  }

  void _setScale(double newScale) {
    final tab = _activeTab;
    if (tab == null) return;

    final oldScale = tab.scale;
    final clamped = newScale.clamp(_minScale, _maxScale);
    if ((clamped - oldScale).abs() < 0.0001) return;

    final newRaster = GelideEngine.rasterScaleFor(
      clamped,
      MediaQuery.devicePixelRatioOf(context),
    );
    final needRerender =
        tab.cachedRasterScale == 0 ||
        (newRaster - tab.cachedRasterScale).abs() / tab.cachedRasterScale >
            0.12;

    final ratio = clamped / oldScale;
    final vOffset = tab.scrollController.hasClients
        ? tab.scrollController.offset
        : null;
    final hOffset = tab.horizontalScrollController.hasClients
        ? tab.horizontalScrollController.offset
        : null;

    setState(() {
      tab.scale = clamped;
      if (needRerender) {
        tab.clearPageImages();
        tab.cachedRasterScale = newRaster;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (vOffset != null && tab.scrollController.hasClients) {
        final maxV = tab.scrollController.position.maxScrollExtent;
        tab.scrollController.jumpTo((vOffset * ratio).clamp(0.0, maxV));
      }
      if (hOffset != null && tab.horizontalScrollController.hasClients) {
        final maxH = tab.horizontalScrollController.position.maxScrollExtent;
        tab.horizontalScrollController.jumpTo(
          (hOffset * ratio).clamp(0.0, maxH),
        );
      }
      _onScroll();
      _ensureVisiblePagesRendered(tab);
    });

    _scheduleStateSave(tab);
  }

  void _rotatePage(double angle) {
    final tab = _activeTab;
    if (tab == null) return;

    if (tab.rotateAllPagesMode) {
      setState(() {
        tab.globalRotationAngle = (tab.globalRotationAngle + angle) % 360;
        if (tab.globalRotationAngle < 0) tab.globalRotationAngle += 360;
        tab.calculatePageOffsets(pageSpacing: _pageSpacing);
      });
    } else {
      if (tab.currentPage > 0 && tab.currentPage <= tab.pageRotations.length) {
        setState(() {
          tab.pageRotations[tab.currentPage - 1] =
              (tab.pageRotations[tab.currentPage - 1] + angle) % 360;
          if (tab.pageRotations[tab.currentPage - 1] < 0) {
            tab.pageRotations[tab.currentPage - 1] += 360;
          }
          tab.calculatePageOffsets(pageSpacing: _pageSpacing);
        });
      }
    }

    if (tab == _activeTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
    }
  }

  void _goToPage(int pageNumber) {
    final tab = _activeTab;
    if (tab == null ||
        pageNumber < 1 ||
        pageNumber > tab.totalPages ||
        tab.pageOffsets.isEmpty) {
      return;
    }

    final targetOffset = tab.pageOffsets[pageNumber - 1] * tab.scale;
    tab.scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() {
      tab.currentPage = pageNumber;
    });
    unawaited(_renderPageIfNeeded(tab, pageNumber - 1));
    _ensureVisiblePagesRendered(tab);

    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _fitToPage() async {
    final tab = _activeTab;
    if (tab == null || tab.pageSizes.isEmpty || !mounted) {
      return;
    }

    final viewSize = Size(
      MediaQuery.of(context).size.width - (_pageSpacing * 2),
      MediaQuery.of(context).size.height -
          kToolbarHeight -
          MediaQuery.of(context).padding.top -
          (_pageSpacing * 2),
    );
    final firstPageSize = tab.pageSizes.first;
    final scaleW = viewSize.width / firstPageSize.width;
    final scaleH = viewSize.height / firstPageSize.height;
    _setScale(min(scaleW, scaleH));
  }

  Future<void> _showCustomZoomDialog() async {
    final tab = _activeTab;
    if (tab == null) return;

    final newScalePercent = await showDialog<String>(
      context: context,
      builder: (context) => CustomZoomDialog(currentScale: tab.scale),
    );

    if (newScalePercent != null && newScalePercent.isNotEmpty) {
      final percent = double.tryParse(newScalePercent);
      if (percent != null) {
        _setScale(percent / 100.0);
      }
    }
  }

  void _showDocumentInfoDialog() {
    final tab = _activeTab;
    if (tab == null) return;

    showDialog(
      context: context,
      builder: (context) => DocumentInfoDialog(
        documentTitle: tab.documentTitle,
        filePath: tab.filePath,
        totalPages: tab.totalPages,
        pageSizes: tab.pageSizes,
        metadata: tab.metadata,
      ),
    );
  }

  void _showSettingsDialog() async {
    await showDialog(
      context: context,
      builder: (context) => const SettingsDialog(),
    );
    _loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    final tab = _activeTab;
    final bool isPdfLoaded =
        tab != null && !tab.isLoading && tab.totalPages > 0;

    return Scaffold(
      appBar: PdfViewerAppBar(
        activeTab: tab,
        isPdfLoaded: isPdfLoaded,
        rotateButtonKey: _rotateButtonKey,
        onToggleRotationMenu: _toggleRotationMenu,
        onSetScale: _setScale,
        onFitToPage: _fitToPage,
        onShowCustomZoomDialog: _showCustomZoomDialog,
        onShowDocumentInfoDialog: _showDocumentInfoDialog,
        onShowSettingsDialog: _showSettingsDialog,
      ),
      drawer: isPdfLoaded
          ? PdfNavigationDrawer(
              totalPages: tab.totalPages,
              currentPage: tab.currentPage,
              thumbnails: tab.thumbs.slots,
              onPageSelected: _goToPage,
              onThumbnailNeeded: (index) {
                unawaited(_renderThumbnailIfNeeded(tab, index));
              },
            )
          : null,
      body: DropTarget(
        onDragDone: (details) {
          setState(() => _isDragging = false);

          if (details.files.length > 1) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Drop only one PDF file at a time'),
                duration: Duration(seconds: 3),
              ),
            );
            return;
          }

          if (details.files.isEmpty) return;

          for (final file in details.files) {
            final path = file.path;
            if (path.toLowerCase().endsWith('.pdf')) {
              unawaited(_openFile(path));
            }
          }
        },
        onDragEntered: (_) => setState(() => _isDragging = true),
        onDragExited: (_) => setState(() => _isDragging = false),
        child: Stack(
          fit: StackFit.expand,
          children: [
            buildBody(),
            if (_tabs.isNotEmpty && (tab == null || !tab.isLoading))
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: PdfTabBar(
                  tabs: _tabs,
                  selectedIndex: _currentTabIndex,
                  onTabSelected: (index) {
                    setState(() => _currentTabIndex = index);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _ensureVisiblePagesRendered(_activeTab);
                    });
                  },
                  onTabClosed: _closeTab,
                  onReorder: _onReorderTabs,
                  onNewTab: _openPdfFile,
                  isExpanded: _isTabBarExpanded,
                  onToggleExpand: () {
                    setState(() => _isTabBarExpanded = !_isTabBarExpanded);
                  },
                ),
              ),
            if (_isDragging) const PdfDragOverlay(),
          ],
        ),
      ),
    );
  }

  Widget buildBody() {
    final tab = _activeTab;
    if (tab == null) return _buildOpenFilePromptWidget();
    if (tab.isLoading) return PdfLoadingIndicator(tab: tab);
    if (tab.totalPages > 0) {
      return PdfViewerContent(
        tab: tab,
        pageSpacing: _pageSpacing,
        isTabBarExpanded: _isTabBarExpanded,
        copyPageAsImageEnabled: _copyPageAsImageEnabled,
        onShowPageContextMenu: (ctx, pos) =>
            showPdfPageContextMenu(ctx, pos, tab),
      );
    }
    return _buildOpenFilePromptWidget();
  }

  Widget _buildOpenFilePromptWidget() {
    return PdfOpenFilePrompt(
      onOpenPdfFile: _openPdfFile,
      onToggleRecentFilesExpanded: _toggleRecentFilesExpanded,
      isRecentFilesExpanded: _isRecentFilesExpanded,
      recentFiles: _recentFiles,
      onClearRecentFiles: () async {
        await _recentFilesService.clearRecentFiles();
        await _loadRecentFiles();
      },
      onOpenFile: _openFile,
      onRemoveRecentFile: (path) async {
        await _recentFilesService.removeRecentFile(path);
        await _loadRecentFiles();
      },
    );
  }
}
