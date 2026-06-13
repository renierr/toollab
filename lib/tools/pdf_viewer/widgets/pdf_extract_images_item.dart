class PdfExtractedImageItem {
  final String id;
  final String fileName;
  final String path;
  final int pageNumber;
  final int width;
  final int height;
  final int bitsPerPixel;
  final List<String> filters;

  const PdfExtractedImageItem({
    required this.id,
    required this.fileName,
    required this.path,
    required this.pageNumber,
    required this.width,
    required this.height,
    required this.bitsPerPixel,
    required this.filters,
  });
}
