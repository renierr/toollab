enum PaperlessTaskStatus { pending, running, success, failure }

/// A paperless-ngx consumption task, as `/api/tasks/?task_id=` reports it.
/// Reads both the v9 shape (`result`, `related_document`) and the newer one
/// (`result_data`, `related_document_ids`).
class PaperlessTask {
  final PaperlessTaskStatus status;
  final String? result;
  final int? documentId;

  const PaperlessTask({required this.status, this.result, this.documentId});

  factory PaperlessTask.fromJson(Map<String, dynamic> json) {
    final status = switch ((json['status'] as String? ?? '').toUpperCase()) {
      'SUCCESS' => PaperlessTaskStatus.success,
      'FAILURE' || 'REVOKED' => PaperlessTaskStatus.failure,
      'STARTED' || 'RETRY' => PaperlessTaskStatus.running,
      _ => PaperlessTaskStatus.pending,
    };
    final data = json['result_data'];
    final resultData = data is Map ? data : const {};
    final relatedIds = json['related_document_ids'];
    final result = json['result'];
    return PaperlessTask(
      status: status,
      result: result is String
          ? result
          : (resultData['reason'] ?? resultData['error_message'])?.toString(),
      documentId:
          _toInt(json['related_document']) ??
          _toInt(resultData['document_id']) ??
          (relatedIds is List && relatedIds.isNotEmpty
              ? _toInt(relatedIds.first)
              : null),
    );
  }

  static int? _toInt(Object? value) =>
      value is int ? value : int.tryParse('${value ?? ''}');
}
