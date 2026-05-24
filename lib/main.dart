import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:file_picker/file_picker.dart';

void main() => runApp(const MaterialApp(home: PdfViewer()));

class PdfViewer extends StatefulWidget {
  const PdfViewer({super.key});
  @override
  State<PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<PdfViewer> {
  PdfDocument? _doc;
  String _title = '';
  double _docW = 0, _docH = 0, _scale = 1.0;
  final _cache = <int, Future<Uint8List>>{}, _thumbCache = <int, Future<Uint8List>>{};
  bool _loading = false;
  int _loadId = 0;
  final _scroll = ScrollController();
  final _hScroll = ScrollController();

  Future<void> _open() async {
    if (_loading) return;
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (res?.files.single.path == null) return;

    final id = ++_loadId;
    setState(() => _loading = true);
    
    try {
      final doc = await PdfDocument.openFile(res!.files.single.path!);
      final p1 = await doc.getPage(1);
      final w = p1.width, h = p1.height;
      await p1.close();
      
      final old = _doc;
      if (!mounted) return;
      setState(() { _doc = doc; _docW = w; _docH = h; _title = res.files.single.name; _cache.clear(); _thumbCache.clear(); _loading = false; _scale = 1.0; });
      await old?.close();
    } catch (e) {
      if (_loadId == id) setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<Uint8List> _loadPage(int i, int id, double scale, {bool t = false}) {
    final c = t ? _thumbCache : _cache;
    if (c.containsKey(i)) { final f = c.remove(i)!; c[i] = f; return f; }
    return c.putIfAbsent(i, () async {
      try {
        if (_doc == null || id != _loadId) throw Exception();
        final p = await _doc!.getPage(i + 1);
        final img = await p.render(width: p.width * (t ? 0.4 : scale), height: p.height * (t ? 0.4 : scale));
        await p.close();
        if (img == null || id != _loadId) throw Exception();
        if (c.length > (t ? 20 : 8)) c.remove(c.keys.first);
        return img.bytes;
      } catch (_) {
        c.remove(i);
        rethrow;
      }
    });
  }

  void _jumpTo(int i) {
    Navigator.pop(context);
    _scroll.animateTo(i * (_docH * _scale + 60), duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _doc?.close();
    _scroll.dispose();
    _hScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;

    return Scaffold(
      backgroundColor: const Color(0xFF525659),
      drawer: _doc == null ? null : Drawer(
        child: ListView.builder(
          itemCount: _doc!.pagesCount,
          itemBuilder: (_, i) => InkWell(
            onTap: () => _jumpTo(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                SizedBox(
                  width: 120, height: 160,
                  child: FutureBuilder<Uint8List>(
                    future: _loadPage(i, _loadId, 1.0, t: true),
                    builder: (_, snap) => snap.hasData ? Image.memory(snap.data!, fit: BoxFit.contain) : const Card(child: Center(child: CircularProgressIndicator())),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: Text('Page ${i + 1}', style: const TextStyle(fontSize: 16))),
              ]),
            ),
          ),
        ),
      ),
      appBar: _doc == null ? null : AppBar(
        title: Text(_title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16)),
        actions: [
          PopupMenuButton<double>(
            tooltip: 'Zoom', onSelected: (v) => setState(() { _scale = v; _cache.clear(); _loadId++; }),
            itemBuilder: (_) => [0.5, 1.0, 1.5].map((v) => PopupMenuItem(value: v, child: Text('${(v * 100).toInt()}%'))).toList(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Text('${(_scale * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 4), const Icon(Icons.zoom_in),
              ]),
            ),
          ),
          IconButton(icon: const Icon(Icons.folder_open), onPressed: _open),
        ],
        bottom: _loading ? const PreferredSize(preferredSize: Size.fromHeight(4), child: LinearProgressIndicator()) : null,
      ),
      body: _doc == null
          ? Center(child: _loading ? const CircularProgressIndicator() : ElevatedButton(onPressed: _open, child: const Text('Open PDF')))
          : Listener(
              onPointerMove: (e) {
                if (e.buttons == 2) {
                  if (_hScroll.hasClients) _hScroll.jumpTo((_hScroll.offset - e.delta.dx).clamp(0.0, _hScroll.position.maxScrollExtent));
                  if (_scroll.hasClients) _scroll.jumpTo((_scroll.offset - e.delta.dy).clamp(0.0, _scroll.position.maxScrollExtent));
                }
              },
              child: LayoutBuilder(
                builder: (_, constraints) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal, controller: _hScroll,
                  child: Container(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth), alignment: Alignment.topCenter, width: _docW * _scale + 96,
                    child: ListView.builder(
                      controller: _scroll, cacheExtent: 1500, itemCount: _doc!.pagesCount, itemExtent: _docH * _scale + 60, 
                      itemBuilder: (_, i) => FutureBuilder<Uint8List>(
                        future: _loadPage(i, _loadId, _scale * pr * 2.0),
                        builder: (_, snap) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Card(
                              margin: EdgeInsets.zero, elevation: 6, shadowColor: Colors.black54, clipBehavior: Clip.antiAlias,
                              child: SizedBox(
                                width: _docW * _scale, height: _docH * _scale, 
                                child: snap.hasData 
                                  ? Image.memory(snap.data!, fit: BoxFit.fill)
                                  : Center(child: snap.hasError ? const Icon(Icons.error, color: Colors.red) : const CircularProgressIndicator()),
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(height: 22, child: Text('${i + 1} / ${_doc!.pagesCount}', style: const TextStyle(color: Colors.white60, fontSize: 12))),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
