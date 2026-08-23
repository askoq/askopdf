class PdfMetadata {
  final int fileSize;
  final DateTime? lastModified;
  final DateTime? lastAccessed;
  final String? pdfVersion;

  PdfMetadata({
    required this.fileSize,
    this.lastModified,
    this.lastAccessed,
    this.pdfVersion,
  });
}
