import 'dart:io';

import 'package:flutter/material.dart';
import 'package:asko_pdf/models/pdf_tab.dart';

class PdfTabBar extends StatelessWidget {
  final List<PdfTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final ValueChanged<int> onTabClosed;
  final void Function(int, int) onReorder;
  final VoidCallback onNewTab;
  final bool isExpanded;
  final VoidCallback onToggleExpand;

  const PdfTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.onTabClosed,
    required this.onReorder,
    required this.onNewTab,
    required this.isExpanded,
    required this.onToggleExpand,
  });

  String _name(PdfTab tab) {
    if (tab.documentTitle.isNotEmpty) return tab.documentTitle;
    return tab.filePath.split(Platform.pathSeparator).last;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 16, bottom: 6),
          child: _RoundBtn(
            icon: isExpanded
                ? Icons.keyboard_arrow_down_rounded
                : Icons.keyboard_arrow_up_rounded,
            onTap: onToggleExpand,
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          height: isExpanded ? 72 : 0,
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: isExpanded
              ? Row(
                  children: [
                    Expanded(
                      child: ReorderableListView.builder(
                        scrollDirection: Axis.horizontal,
                        buildDefaultDragHandles: false,
                        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                        itemCount: tabs.length,
                        onReorder: onReorder,
                        proxyDecorator: (child, _, _) => Material(
                          elevation: 6,
                          shadowColor: Colors.black26,
                          borderRadius: BorderRadius.circular(12),
                          child: child,
                        ),
                        itemBuilder: (context, index) {
                          final tab = tabs[index];
                          final selected = index == selectedIndex;
                          return ReorderableDragStartListener(
                            key: ValueKey(tab.id),
                            index: index,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Material(
                                color: selected
                                    ? primary.withValues(alpha: 0.08)
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  onTap: () => onTabSelected(index),
                                  borderRadius: BorderRadius.circular(12),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: 210,
                                    height: 52,
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      8,
                                      2,
                                      8,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: selected
                                            ? primary.withValues(alpha: 0.35)
                                            : Colors.grey.shade200,
                                        width: selected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _name(tab),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: selected
                                                      ? FontWeight.w600
                                                      : FontWeight.w500,
                                                  color: selected
                                                      ? primary
                                                      : Colors.grey.shade800,
                                                  height: 1.15,
                                                ),
                                              ),
                                              if (tab.totalPages > 0) ...[
                                                const SizedBox(height: 3),
                                                Text(
                                                  '${tab.currentPage} / ${tab.totalPages}',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade500,
                                                    fontWeight: FontWeight.w500,
                                                    height: 1.1,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        InkWell(
                                          onTap: () => onTabClosed(index),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Padding(
                                            padding: const EdgeInsets.all(6),
                                            child: Icon(
                                              Icons.close_rounded,
                                              size: 15,
                                              color: selected
                                                  ? primary.withValues(
                                                      alpha: 0.7,
                                                    )
                                                  : Colors.grey.shade400,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: _RoundBtn(
                        icon: Icons.add_rounded,
                        color: primary,
                        filled: true,
                        tooltip: 'Open File',
                        onTap: onNewTab,
                      ),
                    ),
                  ],
                )
              : null,
        ),
      ],
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final bool filled;
  final String? tooltip;

  const _RoundBtn({
    required this.icon,
    required this.onTap,
    this.color,
    this.filled = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.grey.shade700;
    final child = Material(
      color: filled ? c.withValues(alpha: 0.1) : Colors.white,
      borderRadius: BorderRadius.circular(10),
      elevation: filled ? 0 : 1.5,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, size: 20, color: c),
        ),
      ),
    );
    return tooltip == null ? child : Tooltip(message: tooltip!, child: child);
  }
}
