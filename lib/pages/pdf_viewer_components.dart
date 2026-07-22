import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:asko_pdf/gelide/gelide_engine.dart';
import 'package:asko_pdf/models/pdf_tab.dart';
import 'package:asko_pdf/widgets/pdf_view_components.dart';

OverlayEntry createPdfRotationMenuOverlay({
  required BuildContext context,
  required GlobalKey buttonKey,
  required PdfTab tab,
  required VoidCallback onClose,
  required void Function(double) onRotatePage,
  required VoidCallback onRefresh,
}) {
  final box = buttonKey.currentContext?.findRenderObject() as RenderBox?;
  if (box == null) {
    return OverlayEntry(builder: (_) => const SizedBox());
  }
  final pos = box.localToGlobal(Offset.zero);
  final size = box.size;

  return OverlayEntry(
    builder: (overlayContext) {
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: onClose,
            ),
          ),
          Positioned(
            left: (pos.dx + size.width - 220).clamp(8.0, double.infinity),
            top: pos.dy + size.height + 4,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).cardColor,
              child: StatefulBuilder(
                builder: (ctx, setMenuState) {
                  void refresh() {
                    onRefresh();
                    setMenuState(() {});
                  }

                  Widget item({
                    required IconData icon,
                    required String label,
                    required VoidCallback onTap,
                    Widget? trailing,
                  }) {
                    return InkWell(
                      onTap: onTap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              icon,
                              size: 20,
                              color: Theme.of(context).primaryColor,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                label,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            ?trailing,
                          ],
                        ),
                      ),
                    );
                  }

                  return SizedBox(
                    width: 220,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                          child: Text(
                            'Rotation options',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                        item(
                          icon: Icons.rotate_right,
                          label: 'Right (+90°)',
                          onTap: () {
                            onRotatePage(90);
                            refresh();
                          },
                        ),
                        item(
                          icon: Icons.rotate_left,
                          label: 'Left (-90°)',
                          onTap: () {
                            onRotatePage(-90);
                            refresh();
                          },
                        ),
                        item(
                          icon: Icons.sync,
                          label: '180°',
                          onTap: () {
                            onRotatePage(180);
                            refresh();
                          },
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                          child: Text(
                            'Mode',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                        item(
                          icon: Icons.note,
                          label: 'Current page',
                          trailing: Icon(
                            !tab.rotateAllPagesMode
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 18,
                            color: !tab.rotateAllPagesMode
                                ? Theme.of(context).primaryColor
                                : Colors.grey,
                          ),
                          onTap: () {
                            tab.rotateAllPagesMode = false;
                            refresh();
                          },
                        ),
                        item(
                          icon: Icons.photo_library_outlined,
                          label: 'All pages',
                          trailing: Icon(
                            tab.rotateAllPagesMode
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 18,
                            color: tab.rotateAllPagesMode
                                ? Theme.of(context).primaryColor
                                : Colors.grey,
                          ),
                          onTap: () {
                            tab.rotateAllPagesMode = true;
                            refresh();
                          },
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      );
    },
  );
}

class PdfOpenFilePrompt extends StatelessWidget {
  final VoidCallback onOpenPdfFile;
  final VoidCallback onToggleRecentFilesExpanded;
  final bool isRecentFilesExpanded;
  final List<String> recentFiles;
  final Future<void> Function() onClearRecentFiles;
  final void Function(String, {bool fromRecent}) onOpenFile;
  final Future<void> Function(String) onRemoveRecentFile;

  const PdfOpenFilePrompt({
    super.key,
    required this.onOpenPdfFile,
    required this.onToggleRecentFilesExpanded,
    required this.isRecentFilesExpanded,
    required this.recentFiles,
    required this.onClearRecentFiles,
    required this.onOpenFile,
    required this.onRemoveRecentFile,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(48.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AskoPDF',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black.withValues(alpha: 0.75),
                          ),
                    ),
                    const SizedBox(height: 32),
                    InkWell(
                      onTap: onOpenPdfFile,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: Text(
                          'Open File',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: 1,
              height: 500,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.grey.shade300,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(48.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: onToggleRecentFilesExpanded,
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 4.0,
                              horizontal: 4.0,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedRotation(
                                  turns: isRecentFilesExpanded ? 0.25 : 0,
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    Icons.chevron_right,
                                    size: 18,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Recent files',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (recentFiles.isNotEmpty && isRecentFilesExpanded)
                          TextButton(
                            onPressed: onClearRecentFiles,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey.shade500,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            child: const Text('Clear', style: TextStyle(fontSize: 12)),
                          ),
                      ],
                    ),
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 200),
                      crossFadeState: isRecentFilesExpanded
                          ? CrossFadeState.showFirst
                          : CrossFadeState.showSecond,
                      firstChild: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          if (recentFiles.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32.0),
                              child: Text(
                                'No recent files',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          else
                            Container(
                              constraints: BoxConstraints(
                                maxHeight: MediaQuery.of(context).size.height * 0.6,
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: recentFiles.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final path = recentFiles[index];
                                  final fileName = path.split(Platform.pathSeparator).last;
                                  return Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => onOpenFile(
                                        path,
                                        fromRecent: true,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      hoverColor: Colors.grey.shade100,
                                      child: Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 48,
                                              height: 48,
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: const Icon(
                                                Icons.description_rounded,
                                                color: Colors.black54,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    fileName,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 15,
                                                      color: Colors.black87,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    path,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey.shade500,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                Icons.close_rounded,
                                                size: 18,
                                                color: Colors.grey.shade400,
                                              ),
                                              onPressed: () => onRemoveRecentFile(path),
                                              splashRadius: 20,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                      secondChild: const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PdfViewerAppBar extends StatelessWidget implements PreferredSizeWidget {
  final PdfTab? activeTab;
  final bool isPdfLoaded;
  final GlobalKey rotateButtonKey;
  final void Function(BuildContext context, GlobalKey buttonKey) onToggleRotationMenu;
  final void Function(double) onSetScale;
  final VoidCallback onFitToPage;
  final VoidCallback onShowCustomZoomDialog;
  final VoidCallback onShowDocumentInfoDialog;
  final VoidCallback onShowSettingsDialog;

  const PdfViewerAppBar({
    super.key,
    required this.activeTab,
    required this.isPdfLoaded,
    required this.rotateButtonKey,
    required this.onToggleRotationMenu,
    required this.onSetScale,
    required this.onFitToPage,
    required this.onShowCustomZoomDialog,
    required this.onShowDocumentInfoDialog,
    required this.onShowSettingsDialog,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  Widget _buildZoomMenuItem(BuildContext context, String label, bool isSelected) {
    return Row(
      children: [
        if (isSelected)
          Icon(
            Icons.check_rounded,
            size: 18,
            color: Theme.of(context).primaryColor,
          )
        else
          const SizedBox(width: 18),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? Theme.of(context).primaryColor : null,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: isPdfLoaded
          ? Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Page navigation',
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            )
          : null,
      title: null,
      elevation: isPdfLoaded ? null : 0,
      backgroundColor: isPdfLoaded
          ? null
          : Theme.of(context).scaffoldBackgroundColor,
      actions: [
        if (isPdfLoaded && activeTab != null) ...[
          IconButton(
            key: rotateButtonKey,
            tooltip: 'Rotation options',
            icon: Icon(
              activeTab!.rotateAllPagesMode
                  ? Icons.rotate_90_degrees_ccw
                  : Icons.rotate_right,
            ),
            onPressed: () => onToggleRotationMenu(context, rotateButtonKey),
          ),
          PopupMenuButton<dynamic>(
            onSelected: (value) {
              if (value is double) {
                onSetScale(value);
              } else if (value == 'fit_page') {
                onFitToPage();
              } else if (value == 'custom') {
                onShowCustomZoomDialog();
              }
            },
            offset: const Offset(0, 45),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            itemBuilder: (ctx) => <PopupMenuEntry<dynamic>>[
              PopupMenuItem<double>(
                value: 1.0,
                child: _buildZoomMenuItem(context, '100%', activeTab!.scale == 1.0),
              ),
              PopupMenuItem<double>(
                value: 1.5,
                child: _buildZoomMenuItem(context, '150%', activeTab!.scale == 1.5),
              ),
              PopupMenuItem<double>(
                value: 2.0,
                child: _buildZoomMenuItem(context, '200%', activeTab!.scale == 2.0),
              ),
              PopupMenuItem<double>(
                value: 2.5,
                child: _buildZoomMenuItem(context, '250%', activeTab!.scale == 2.5),
              ),
              const PopupMenuDivider(height: 8),
              PopupMenuItem<String>(
                value: 'fit_page',
                child: Row(
                  children: [
                    Icon(
                      Icons.fit_screen_rounded,
                      size: 18,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 10),
                    const Text('Fit to page'),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 8),
              PopupMenuItem<String>(
                value: 'custom',
                child: Row(
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 18,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 10),
                    const Text('Custom...'),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${(activeTab!.scale * 100).round()}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: Theme.of(context).primaryColor,
                  ),
                ],
              ),
            ),
          ),
          if (!activeTab!.isLoading)
            IconButton(
              icon: const Icon(Icons.description_outlined),
              tooltip: 'Document info',
              onPressed: onShowDocumentInfoDialog,
            ),
        ] else if (activeTab == null) ...[
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: onShowSettingsDialog,
          ),
        ],
        const SizedBox(width: 8),
      ],
    );
  }
}

class PdfLoadingIndicator extends StatelessWidget {
  final PdfTab tab;

  const PdfLoadingIndicator({super.key, required this.tab});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              value: tab.loadingProgress,
              strokeWidth: 6,
            ),
          ),
          const SizedBox(height: 20),
          Text(tab.loadingMessage, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}

class PdfDragOverlay extends StatelessWidget {
  const PdfDragOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 48,
              vertical: 32,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).primaryColor,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.file_download_outlined,
                  size: 64,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'Drop files here to open',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PdfViewerContent extends StatelessWidget {
  final PdfTab tab;
  final double pageSpacing;
  final bool isTabBarExpanded;
  final bool copyPageAsImageEnabled;
  final void Function(BuildContext context, Offset position) onShowPageContextMenu;

  const PdfViewerContent({
    super.key,
    required this.tab,
    required this.pageSpacing,
    required this.isTabBarExpanded,
    required this.copyPageAsImageEnabled,
    required this.onShowPageContextMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            return PanningArea(
              verticalController: tab.scrollController,
              horizontalController: tab.horizontalScrollController,
              child: Scrollbar(
                controller: tab.scrollController,
                thumbVisibility: true,
                thickness: 8.0,
                trackVisibility: true,
                child: SingleChildScrollView(
                  controller: tab.scrollController,
                  child: SingleChildScrollView(
                    controller: tab.horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(pageSpacing * tab.scale),
                        child: GestureDetector(
                          onSecondaryTapUp: copyPageAsImageEnabled
                              ? (details) {
                                  onShowPageContextMenu(
                                    context,
                                    details.globalPosition,
                                  );
                                }
                              : null,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: PdfPagesList(
                              renderedPages: tab.pages.slots,
                              pageSizes: tab.pageSizes,
                              pageSpacing: pageSpacing * tab.scale,
                              scale: tab.scale,
                              globalRotationAngle: tab.globalRotationAngle,
                              pageRotations: tab.pageRotations,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubicEmphasized,
          bottom: 20 + (isTabBarExpanded ? 76 : 0),
          left: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${tab.currentPage} / ${tab.totalPages}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> copyCurrentPageAsImage(BuildContext context, PdfTab tab) async {
  if (tab.documentId == null) return;

  final pageIndex = tab.currentPage - 1;
  if (pageIndex < 0 || pageIndex >= tab.totalPages) return;

  try {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final png = await GelideEngine.instance.renderPagePng(
      tab.documentId!,
      pageIndex,
      GelideEngine.rasterScaleFor(tab.scale, dpr),
    );
    await Pasteboard.writeImage(png);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text('Page ${tab.currentPage} copied to clipboard'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to copy page: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }
}

void showPdfPageContextMenu(BuildContext context, Offset position, PdfTab tab) {
  showMenu(
    context: context,
    position: RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      position.dx + 1,
      position.dy + 1,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    items: [
      PopupMenuItem(
        onTap: () => copyCurrentPageAsImage(context, tab),
        child: Row(
          children: [
            Icon(
              Icons.content_copy_rounded,
              size: 20,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Copy page as image',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    softWrap: true,
                  ),
                  Text(
                    'Page ${tab.currentPage}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
