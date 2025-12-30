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
  List<Uint8List?> _pages = [];
  bool _loading = false;

  Future<void> _open() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result?.files.single.path == null) return;

    setState(() => _loading = true);

    final doc = await PdfDocument.openFile(result!.files.single.path!);
    final pages = <Uint8List?>[];

    for (int i = 1; i <= doc.pagesCount; i++) {
      final page = await doc.getPage(i);
      final img = await page.render(
        width: page.width * 2,
        height: page.height * 2,
      );
      pages.add(img?.bytes);
      await page.close();
    }
    await doc.close();

    setState(() {
      _pages = pages;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_pages.isEmpty) {
      return Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: _open,
            child: const Text('Open PDF'),
          ),
        ),
      );
    }

    return Scaffold(
      body: ListView.builder(
        itemCount: _pages.length,
        itemBuilder: (_, i) => Center(
          child: Container(
            margin: const EdgeInsets.all(8),
            child: _pages[i] != null
                ? Image.memory(_pages[i]!)
                : const Icon(Icons.error),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _open,
        child: const Icon(Icons.folder_open),
      ),
    );
  }
}
