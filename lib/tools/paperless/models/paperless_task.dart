enum PaperlessTaskStatus { pending, running, success, failure }

/// A paperless-ngx consumption task, as `/api/tasks/?task_id=` reports it.
/// Reads the v9 shape (`result`, `related_document`, `duplicate_documents`)
/// and the newer v10 one (`result_message`, `result_data`,
/// `related_document_ids`).
class PaperlessTask {
  final PaperlessTaskStatus status;
  final String? result;
  final int? documentId;

  /// Points at the existing document when the upload was rejected as a
  /// duplicate. Parsed from `result_data.duplicate_of`, the v9
  /// `duplicate_documents` list, or the `(#id)` suffix Paperless appends to
  /// the failure message.
  final int? duplicateDocumentId;

  const PaperlessTask({
    required this.status,
    this.result,
    this.documentId,
    this.duplicateDocumentId,
  });

  bool get isDuplicate =>
      duplicateDocumentId != null ||
      (result != null && _duplicatePattern.hasMatch(result!));

  static final _duplicatePattern = RegExp(
    r'duplicate|already exists|bereits vorhanden|duplikat',
    caseSensitive: false,
  );
  static final _duplicateIdPattern = RegExp(r'\(#(\d+)\)');

  factory PaperlessTask.fromJson(Map<String, dynamic> json) {
    final status = switch ((json['status'] as String? ?? '').toUpperCase()) {
      'SUCCESS' => PaperlessTaskStatus.success,
      'FAILURE' ||
      'REVOKED' ||
      'FAILED' ||
      'CANCELLED' ||
      'CANCELED' => PaperlessTaskStatus.failure,
      'STARTED' ||
      'RUNNING' ||
      'RETRY' ||
      'PROGRESS' => PaperlessTaskStatus.running,
      _ => PaperlessTaskStatus.pending,
    };
    final data = json['result_data'];
    final resultData = data is Map ? data : const {};
    final relatedIds = json['related_document_ids'];
    final resultMessage = json['result_message'];
    final result = json['result'];
    final message =
        (resultMessage is String && resultMessage.isNotEmpty
                ? resultMessage
                : result is String && result.isNotEmpty
                ? result
                : _firstNonEmpty([
                    resultData['reason'],
                    resultData['error_message'],
                    resultData['message'],
                    resultData['error'],
                  ]))
            ?.toString();
    final duplicates = json['duplicate_documents'];
    final duplicateFromList = duplicates is List && duplicates.isNotEmpty
        ? _toInt(
            duplicates.first is Map
                ? (duplicates.first as Map)['id']
                : duplicates.first,
          )
        : null;
    final duplicateId =
        _toInt(resultData['duplicate_of']) ??
        duplicateFromList ??
        _duplicateIdFromMessage(message);
    return PaperlessTask(
      status: status,
      result: message,
      documentId:
          _toInt(json['related_document']) ??
          _toInt(resultData['document_id']) ??
          (relatedIds is List && relatedIds.isNotEmpty
              ? _toInt(relatedIds.first)
              : null) ??
          duplicateId,
      duplicateDocumentId: duplicateId,
    );
  }

  static int? _toInt(Object? value) =>
      value is int ? value : int.tryParse('${value ?? ''}');

  static String? _firstNonEmpty(List<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static int? _duplicateIdFromMessage(String? message) {
    if (message == null) return null;
    final match = _duplicateIdPattern.firstMatch(message);
    return match == null ? null : int.tryParse(match.group(1)!);
  }
}
