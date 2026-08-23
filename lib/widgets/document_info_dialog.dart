import 'package:flutter/material.dart';
import 'package:asko_pdf/models/pdf_metadata.dart';

class DocumentInfoDialog extends StatelessWidget {
  final String documentTitle;
  final String filePath;
  final int totalPages;
  final List<Size> pageSizes;
  final PdfMetadata? metadata;

  const DocumentInfoDialog({
    super.key,
    required this.documentTitle,
    required this.filePath,
    required this.totalPages,
    required this.pageSizes,
    this.metadata,
  });

  @override
  Widget build(BuildContext context) {
    final meta = metadata;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.description_rounded,
                    color: Theme.of(context).primaryColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Properties',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: Colors.black54,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _section('File', [
                        _item('Name', documentTitle),
                        _item('Path', filePath),
                        _item(
                          'Size',
                          meta != null
                              ? _formatFileSize(meta.fileSize)
                              : 'Unknown',
                        ),
                        _item(
                          'Modified',
                          meta?.lastModified != null
                              ? _formatDateTime(meta!.lastModified!)
                              : 'Unknown',
                        ),
                        if (meta?.lastAccessed != null)
                          _item(
                            'Accessed',
                            _formatDateTime(meta!.lastAccessed!),
                          ),
                      ]),
                      const SizedBox(height: 24),
                      _section('Document', [
                        _item('Pages', '$totalPages'),
                        _item('Page Size', _pageSizeLabel()),
                        if (meta?.pdfVersion != null)
                          _item('PDF Version', meta!.pdfVersion!),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _pageSizeLabel() {
    if (pageSizes.isEmpty) return 'Unknown';
    final w = pageSizes.first.width.round();
    final h = pageSizes.first.height.round();
    final name = _detectPageSizeName(w.toDouble(), h.toDouble());
    return name != null ? '$w × $h pt ($name)' : '$w × $h pt';
  }

  String? _detectPageSizeName(double width, double height) {
    const t = 5.0;
    const sizes = {
      'A4': [595.0, 842.0],
      'A3': [842.0, 1191.0],
      'A5': [420.0, 595.0],
      'Letter': [612.0, 792.0],
      'Legal': [612.0, 1008.0],
      'Tabloid': [792.0, 1224.0],
    };
    for (final e in sizes.entries) {
      final a = e.value[0], b = e.value[1];
      if ((width - a).abs() < t && (height - b).abs() < t) return e.key;
      if ((width - b).abs() < t && (height - a).abs() < t) {
        return '${e.key} (Landscape)';
      }
    }
    return null;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDateTime(DateTime d) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.day)}.${p(d.month)}.${d.year}, ${p(d.hour)}:${p(d.minute)}';
  }

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade500,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++)
                DecoratedBox(
                  decoration: i == children.length - 1
                      ? const BoxDecoration()
                      : BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                  child: children[i],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _item(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
