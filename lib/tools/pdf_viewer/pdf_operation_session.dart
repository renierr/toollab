import 'package:pdfrx/pdfrx.dart';
import 'package:tool_lab/helpers/pdf_engine_helper.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';

class PdfOperationSession {
  final String filePath;
  final String fileName;
  final TempFileScope tempScope;
  final PdfPasswordProvider? passwordProvider;

  const PdfOperationSession({
    required this.filePath,
    required this.fileName,
    required this.tempScope,
    this.passwordProvider,
  });

  Future<PdfDocument> openDocument() {
    return PdfEngineHelper.openPdfWithPassword(
      filePath,
      passwordProvider: passwordProvider,
    );
  }
}
