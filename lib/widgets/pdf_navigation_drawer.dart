import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PdfNavigationDrawer extends StatefulWidget {
  final int totalPages;
  final int currentPage;
  final List<ui.Image?> thumbnails;
  final Function(int) onPageSelected;
  final ValueChanged<int>? onThumbnailNeeded;

  const PdfNavigationDrawer({
    super.key,
    required this.totalPages,
    required this.currentPage,
    required this.thumbnails,
    required this.onPageSelected,
    this.onThumbnailNeeded,
  });

  @override
  State<PdfNavigationDrawer> createState() => _PdfNavigationDrawerState();
}

class _PdfNavigationDrawerState extends State<PdfNavigationDrawer> {
  late final TextEditingController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = TextEditingController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToSubmitted(String value) {
    final pageNum = int.tryParse(value);
    if (pageNum != null) {
      widget.onPageSelected(pageNum);
      _pageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [primary, primary.withValues(alpha: 0.95)],
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 20,
                left: 20,
                right: 20,
                bottom: 20,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.menu_book_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Navigation',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${widget.totalPages}',
                      style: TextStyle(
                        color: primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _pageController,
                                decoration: InputDecoration(
                                  hintText: 'Go to page...',
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search,
                                    color: Colors.grey.shade400,
                                    size: 20,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                onSubmitted: _goToSubmitted,
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                ),
                                onPressed: () =>
                                    _goToSubmitted(_pageController.text),
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        itemCount: widget.totalPages,
                        itemBuilder: (context, index) {
                          final pageNumber = index + 1;
                          final isCurrent = pageNumber == widget.currentPage;
                          if (index >= widget.thumbnails.length) {
                            return const SizedBox.shrink();
                          }
                          if (widget.thumbnails[index] == null) {
                            widget.onThumbnailNeeded?.call(index);
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () =>
                                    widget.onPageSelected(pageNumber),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isCurrent
                                        ? primary.withValues(alpha: 0.1)
                                        : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isCurrent
                                          ? primary.withValues(alpha: 0.4)
                                          : Colors.grey.shade200,
                                      width: isCurrent ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 64,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          color: Colors.white,
                                          boxShadow: [
                                            BoxShadow(
                                              color: isCurrent
                                                  ? primary.withValues(
                                                      alpha: 0.25,
                                                    )
                                                  : Colors.black.withValues(
                                                      alpha: 0.08,
                                                    ),
                                              blurRadius: isCurrent ? 8 : 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: widget.thumbnails[index] != null
                                            ? RawImage(
                                                image:
                                                    widget.thumbnails[index],
                                                fit: BoxFit.cover,
                                              )
                                            : Center(
                                                child: SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.grey.shade400,
                                                  ),
                                                ),
                                              ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(
                                          'Page $pageNumber',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: isCurrent
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: isCurrent
                                                ? primary
                                                : Colors.grey.shade800,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Icon(
                                        isCurrent
                                            ? Icons.remove_red_eye_rounded
                                            : Icons.chevron_right_rounded,
                                        color: isCurrent
                                            ? primary
                                            : Colors.grey.shade400,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
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
