import 'package:flutter/foundation.dart';

/// Metadata read from a document's content. Every field is a suggestion.
@immutable
class DocumentInsight {
  final String text;
  final String? title;
  final DateTime? date;

  /// Names picked from the candidate lists passed to the analysis.
  final String? correspondent;
  final String? documentType;
  final List<String> tags;

  final List<String> amounts;
  final List<String> ibans;
  final List<String> emails;

  /// True when Gemini Nano contributed title or labels.
  final bool usedAi;

  const DocumentInsight({
    required this.text,
    this.title,
    this.date,
    this.correspondent,
    this.documentType,
    this.tags = const [],
    this.amounts = const [],
    this.ibans = const [],
    this.emails = const [],
    this.usedAi = false,
  });

  bool get hasText => text.trim().isNotEmpty;

  bool get isEmpty =>
      title == null &&
      date == null &&
      correspondent == null &&
      documentType == null &&
      tags.isEmpty;
}

/// Label names the analysis may choose from.
@immutable
class DocumentInsightCandidates {
  final List<String> correspondents;
  final List<String> documentTypes;
  final List<String> tags;

  const DocumentInsightCandidates({
    this.correspondents = const [],
    this.documentTypes = const [],
    this.tags = const [],
  });
}
