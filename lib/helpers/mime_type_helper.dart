class MimeTypeHelper {
  MimeTypeHelper._();

  /// Resolves a mime type for [filePath].
  ///
  /// When [bytes] are provided, magic-byte (file signature) detection runs
  /// first and wins over the file extension — this catches uploads that arrive
  /// with a wrong or missing extension. Falls back to the extension lookup, and
  /// finally to `application/octet-stream`.
  static String getMimeType(String filePath, {List<int>? bytes}) {
    if (bytes != null) {
      final fromMagic = detectFromMagicBytes(bytes);
      if (fromMagic != null) {
        return fromMagic;
      }
    }
    return _getMimeTypeFromExtension(filePath);
  }

  static String _getMimeTypeFromExtension(String filePath) {
    if (!filePath.contains('.')) {
      return 'application/octet-stream';
    }
    final ext = filePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'txt':
      case 'dart':
      case 'py':
      case 'go':
      case 'java':
      case 'c':
      case 'cpp':
      case 'h':
      case 'hpp':
      case 'ts':
      case 'kt':
      case 'gradle':
      case 'properties':
      case 'ini':
      case 'conf':
      case 'log':
      case 'bat':
      case 'sh':
      case 'sql':
      case 'toml':
        return 'text/plain';
      case 'md':
      case 'markdown':
        return 'text/markdown';
      case 'json':
        return 'application/json';
      // Web / Text / Code
      case 'html':
      case 'htm':
        return 'text/html';
      case 'css':
        return 'text/css';
      case 'js':
      case 'mjs':
        return 'text/javascript';
      case 'csv':
        return 'text/csv';
      case 'xml':
        return 'application/xml';
      case 'yaml':
      case 'yml':
        return 'text/yaml';
      // Images
      case 'svg':
        return 'image/svg+xml';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      case 'ico':
        return 'image/x-icon';
      case 'tif':
      case 'tiff':
        return 'image/tiff';
      // Audio
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
        return 'audio/ogg';
      case 'm4a':
      case 'alac':
        return 'audio/mp4';
      case 'mka':
        return 'audio/x-matroska';
      case 'aac':
        return 'audio/aac';
      case 'aiff':
      case 'aif':
        return 'audio/aiff';
      case 'amr':
        return 'audio/amr';
      case 'opus':
        return 'audio/opus';
      case 'wma':
        return 'audio/x-ms-wma';
      case 'flac':
        return 'audio/flac';
      // Tracker modules
      case 'mod':
        return 'audio/x-mod';
      case 'xm':
        return 'audio/x-xm';
      case 'it':
        return 'audio/x-it';
      case 's3m':
        return 'audio/x-s3m';
      // Video
      case 'mp4':
        return 'video/mp4';
      case 'webm':
        return 'video/webm';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      case 'mkv':
        return 'video/x-matroska';
      case '3gp':
        return 'video/3gpp';
      // Archives
      case 'zip':
        return 'application/zip';
      case 'tar':
        return 'application/x-tar';
      case 'gz':
        return 'application/gzip';
      case 'rar':
        return 'application/x-rar-compressed';
      case '7z':
        return 'application/x-7z-compressed';
      // Documents
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'apk':
        return 'application/vnd.android.package-archive';
      default:
        return 'application/octet-stream';
    }
  }

  /// Identifies a mime type by inspecting leading file signature bytes.
  ///
  /// Returns `null` when no known signature matches, so callers can fall back
  /// to extension-based detection.
  static String? detectFromMagicBytes(List<int> bytes) {
    if (bytes.isEmpty) return null;

    // Images
    if (_startsWith(bytes, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
      return 'image/png';
    }
    if (_startsWith(bytes, [0xFF, 0xD8, 0xFF])) {
      return 'image/jpeg';
    }
    if (_matchesAscii(bytes, 0, 'GIF87a') ||
        _matchesAscii(bytes, 0, 'GIF89a')) {
      return 'image/gif';
    }
    if (_startsWith(bytes, [0x42, 0x4D])) {
      return 'image/bmp';
    }
    if (_startsWith(bytes, [0x00, 0x00, 0x01, 0x00])) {
      return 'image/x-icon';
    }
    if (_startsWith(bytes, [0x49, 0x49, 0x2A, 0x00]) ||
        _startsWith(bytes, [0x4D, 0x4D, 0x00, 0x2A])) {
      return 'image/tiff';
    }

    // RIFF container: WEBP / WAV / AVI
    if (_matchesAscii(bytes, 0, 'RIFF')) {
      if (_matchesAscii(bytes, 8, 'WEBP')) return 'image/webp';
      if (_matchesAscii(bytes, 8, 'WAVE')) return 'audio/wav';
      if (_matchesAscii(bytes, 8, 'AVI ')) return 'video/x-msvideo';
    }

    // Documents
    if (_matchesAscii(bytes, 0, '%PDF')) {
      return 'application/pdf';
    }

    // Archives (ZIP-based formats — Office files share the ZIP signature, so
    // extension lookup remains the better source for docx/xlsx/pptx).
    if (_startsWith(bytes, [0x50, 0x4B, 0x03, 0x04]) ||
        _startsWith(bytes, [0x50, 0x4B, 0x05, 0x06]) ||
        _startsWith(bytes, [0x50, 0x4B, 0x07, 0x08])) {
      return 'application/zip';
    }
    if (_startsWith(bytes, [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07])) {
      return 'application/x-rar-compressed';
    }
    if (_startsWith(bytes, [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C])) {
      return 'application/x-7z-compressed';
    }
    if (_startsWith(bytes, [0x1F, 0x8B])) {
      return 'application/gzip';
    }
    if (_matchesAscii(bytes, 257, 'ustar')) {
      return 'application/x-tar';
    }

    // Audio
    if (_matchesAscii(bytes, 0, 'ID3') ||
        (bytes.length >= 2 && bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0)) {
      return 'audio/mpeg';
    }
    if (_matchesAscii(bytes, 0, 'OggS')) {
      return 'audio/ogg';
    }
    if (_matchesAscii(bytes, 0, 'fLaC')) {
      return 'audio/flac';
    }

    // Tracker modules
    if (_matchesAscii(bytes, 0, 'Extended Module: ')) {
      return 'audio/x-xm';
    }
    if (_matchesAscii(bytes, 0, 'IMPM')) {
      return 'audio/x-it';
    }
    if (_matchesAscii(bytes, 1080, 'M.K.') ||
        _matchesAscii(bytes, 1080, 'M!K!') ||
        _matchesAscii(bytes, 1080, 'FLT4') ||
        _matchesAscii(bytes, 1080, '4CHN') ||
        _matchesAscii(bytes, 1080, '6CHN') ||
        _matchesAscii(bytes, 1080, '8CHN')) {
      return 'audio/x-mod';
    }

    // Video (ISO base media: 'ftyp' box at offset 4)
    if (_matchesAscii(bytes, 4, 'ftyp')) {
      if (_matchesAscii(bytes, 8, 'qt')) return 'video/quicktime';
      return 'video/mp4';
    }
    // Matroska / WebM (EBML header)
    if (_startsWith(bytes, [0x1A, 0x45, 0xDF, 0xA3])) {
      return 'video/webm';
    }

    // Text-based
    if (_matchesAscii(bytes, 0, '<?xml')) {
      return 'application/xml';
    }

    return null;
  }

  static bool _startsWith(List<int> bytes, List<int> signature) {
    if (bytes.length < signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) return false;
    }
    return true;
  }

  static bool _matchesAscii(List<int> bytes, int offset, String ascii) {
    if (bytes.length < offset + ascii.length) return false;
    for (var i = 0; i < ascii.length; i++) {
      if (bytes[offset + i] != ascii.codeUnitAt(i)) return false;
    }
    return true;
  }
}
