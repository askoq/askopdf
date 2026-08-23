import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PanningArea extends StatefulWidget {
  final Widget child;
  final ScrollController verticalController;
  final ScrollController horizontalController;

  const PanningArea({
    super.key,
    required this.child,
    required this.verticalController,
    required this.horizontalController,
  });

  @override
  State<PanningArea> createState() => _PanningAreaState();
}

class _PanningAreaState extends State<PanningArea> {
  bool _isPanning = false;
  bool _didPan = false;
  Offset _lastPosition = Offset.zero;

  bool get didPan => _didPan;

  void _jump(ScrollController c, double delta) {
    if (!c.hasClients) return;
    final pos = c.position;
    if (!pos.hasContentDimensions) return;
    c.jumpTo((c.offset + delta).clamp(0.0, pos.maxScrollExtent));
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (event.buttons == kSecondaryMouseButton ||
        event.buttons == kMiddleMouseButton) {
      setState(() {
        _isPanning = true;
        _didPan = false;
        _lastPosition = event.position;
      });
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_isPanning) return;
    final delta = event.position - _lastPosition;
    if (delta.distanceSquared < 1) return;
    _lastPosition = event.position;
    _didPan = true;
    _jump(widget.verticalController, -delta.dy);
    _jump(widget.horizontalController, -delta.dx);
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_isPanning) {
      setState(() => _isPanning = false);
    }
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final dx = event.scrollDelta.dx;
    final dy = event.scrollDelta.dy;
    // avoid double scroll
    if (shift) {
      _jump(widget.horizontalController, dy);
    } else if (dx.abs() > 0.5) {
      _jump(widget.horizontalController, dx);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: _isPanning
          ? SystemMouseCursors.grabbing
          : SystemMouseCursors.basic,
      child: Listener(
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerUp: _handlePointerUp,
        onPointerCancel: (_) => setState(() => _isPanning = false),
        onPointerSignal: _handlePointerSignal,
        child: widget.child,
      ),
    );
  }
}

class PdfPagesList extends StatelessWidget {
  final List<ui.Image?> renderedPages;
  final List<Size> pageSizes;
  final double pageSpacing;
  final double scale;
  final double globalRotationAngle;
  final List<double> pageRotations;
  final List<int>? visiblePageIndices;

  const PdfPagesList({
    super.key,
    required this.renderedPages,
    required this.pageSizes,
    required this.pageSpacing,
    required this.scale,
    required this.globalRotationAngle,
    required this.pageRotations,
    this.visiblePageIndices,
  });

  @override
  Widget build(BuildContext context) {
    final indicesToShow =
        visiblePageIndices ?? List.generate(renderedPages.length, (i) => i);

    final children = <Widget>[];
    for (var j = 0; j < indicesToShow.length; j++) {
      final i = indicesToShow[j];
      if (i < 0 || i >= renderedPages.length || i >= pageSizes.length) continue;
      if (children.isNotEmpty) children.add(SizedBox(height: pageSpacing));
      children.add(
        PdfPageWidget(
          image: renderedPages[i],
          pageSize: pageSizes[i],
          scale: scale,
          rotationAngle:
              globalRotationAngle +
              (i < pageRotations.length ? pageRotations[i] : 0.0),
        ),
      );
    }
    return Column(mainAxisSize: MainAxisSize.min, children: children);
  }
}

class PdfPageWidget extends StatelessWidget {
  final ui.Image? image;
  final Size pageSize;
  final double scale;
  final double rotationAngle;

  const PdfPageWidget({
    super.key,
    required this.image,
    required this.pageSize,
    required this.scale,
    required this.rotationAngle,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedAngle = ((rotationAngle % 360) + 360) % 360;
    final int quarterTurns = (normalizedAngle ~/ 90) % 4;

    var width = pageSize.width * scale;
    var height = pageSize.height * scale;
    final img = image;
    if (img != null && img.width > 0 && img.height > 0) {
      final imgAspect = img.width / img.height;
      final boxAspect = width / height;
      if ((imgAspect - boxAspect).abs() > 0.01) {
        height = width / imgAspect;
      }
    }

    final layoutW = quarterTurns.isOdd ? height : width;
    final layoutH = quarterTurns.isOdd ? width : height;

    return SizedBox(
      width: layoutW,
      height: layoutH,
      child: RotatedBox(
        quarterTurns: quarterTurns,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4.0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: img == null
              ? const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : RawImage(
                  image: img,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  width: width,
                  height: height,
                ),
        ),
      ),
    );
  }
}
