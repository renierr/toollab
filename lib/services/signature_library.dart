import 'dart:typed_data';

import 'package:tool_lab/tools/signatures/signature_models.dart';
import 'package:tool_lab/tools/signatures/signature_painter.dart';
import 'package:tool_lab/tools/signatures/signatures_db_helper.dart';

export 'package:tool_lab/tools/signatures/signature_models.dart'
    show SignatureRecord;

/// Read-only access to stored signatures for other tools (e.g. the PDF
/// viewer's "Place Signature" operation), so they depend on this service
/// rather than reaching into the Signatures tool internals.
class SignatureLibrary {
  SignatureLibrary._();
  static final SignatureLibrary instance = SignatureLibrary._();

  Future<List<SignatureRecord>> getSignatures() =>
      SignaturesDbHelper.instance.getActiveRecords();

  /// Re-renders a stored signature to a transparent PNG at [dpi] (the stored
  /// preview is only 96 DPI, too low to place crisply in a document).
  Future<Uint8List> renderPng(SignatureRecord record, {int dpi = 300}) {
    return renderSignaturePng(
      record.rawPaths,
      record.width,
      record.height,
      record.settings.copyWith(dpi: dpi),
    );
  }
}
