enum PaperlessTaskStatus { pending, running, success, failure }

/// A paperless-ngx consumption task, as `/api/tasks/?task_id=` reports it.
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
    final related = json['related_document'];
    return PaperlessTask(
      status: status,
      result: json['result'] as String?,
      documentId: related is int ? related : int.tryParse('${related ?? ''}'),
    );
  }
}
