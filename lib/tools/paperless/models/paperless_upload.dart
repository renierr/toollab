import 'package:flutter/foundation.dart';

enum PaperlessUploadStatus {
  pending,
  uploading,

  /// Accepted; polling the paperless-ngx task until it is consumed.
  processing,

  /// Accepted, but the server offers no task to follow (paperless-ng).
  queued,
  done,
  failed,
}

enum PaperlessAnalysisStatus { none, running, done, empty, failed }

class PaperlessUpload {
  final String id;
  final String path;
  final String fileName;

  /// Null leaves the title to Paperless, which derives it from the file name.
  final String? title;

  /// Per-upload metadata; null falls back to the batch [PaperlessUploadOptions].
  final DateTime? created;
  final int? correspondentId;
  final int? documentTypeId;
  final Set<int>? tagIds;
  final PaperlessAnalysisStatus analysis;

  final PaperlessUploadStatus status;
  final double? progress;
  final String? taskId;
  final int? documentId;
  final Object? error;

  const PaperlessUpload({
    required this.id,
    required this.path,
    required this.fileName,
    this.title,
    this.created,
    this.correspondentId,
    this.documentTypeId,
    this.tagIds,
    this.analysis = PaperlessAnalysisStatus.none,
    this.status = PaperlessUploadStatus.pending,
    this.progress,
    this.taskId,
    this.documentId,
    this.error,
  });

  String get displayTitle => title ?? fileName;

  bool get hasMetadata =>
      created != null ||
      correspondentId != null ||
      documentTypeId != null ||
      tagIds != null;

  bool get isActive =>
      status == PaperlessUploadStatus.uploading ||
      status == PaperlessUploadStatus.processing;

  bool get isFinished =>
      status == PaperlessUploadStatus.done ||
      status == PaperlessUploadStatus.queued;

  PaperlessUpload copyWith({
    ValueGetter<String?>? title,
    ValueGetter<DateTime?>? created,
    ValueGetter<int?>? correspondentId,
    ValueGetter<int?>? documentTypeId,
    ValueGetter<Set<int>?>? tagIds,
    PaperlessAnalysisStatus? analysis,
    PaperlessUploadStatus? status,
    ValueGetter<double?>? progress,
    String? taskId,
    int? documentId,
    ValueGetter<Object?>? error,
  }) {
    return PaperlessUpload(
      id: id,
      path: path,
      fileName: fileName,
      title: title != null ? title() : this.title,
      created: created != null ? created() : this.created,
      correspondentId: correspondentId != null
          ? correspondentId()
          : this.correspondentId,
      documentTypeId: documentTypeId != null
          ? documentTypeId()
          : this.documentTypeId,
      tagIds: tagIds != null ? tagIds() : this.tagIds,
      analysis: analysis ?? this.analysis,
      status: status ?? this.status,
      progress: progress != null ? progress() : this.progress,
      taskId: taskId ?? this.taskId,
      documentId: documentId ?? this.documentId,
      error: error != null ? error() : this.error,
    );
  }
}

/// Metadata applied to every upload in the next batch.
@immutable
class PaperlessUploadOptions {
  final int? correspondentId;
  final int? documentTypeId;
  final Set<int> tagIds;

  const PaperlessUploadOptions({
    this.correspondentId,
    this.documentTypeId,
    this.tagIds = const {},
  });

  PaperlessUploadOptions copyWith({
    ValueGetter<int?>? correspondentId,
    ValueGetter<int?>? documentTypeId,
    Set<int>? tagIds,
  }) {
    return PaperlessUploadOptions(
      correspondentId: correspondentId != null
          ? correspondentId()
          : this.correspondentId,
      documentTypeId: documentTypeId != null
          ? documentTypeId()
          : this.documentTypeId,
      tagIds: tagIds ?? this.tagIds,
    );
  }
}
