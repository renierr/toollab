import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:google_mlkit_entity_extraction/google_mlkit_entity_extraction.dart';
import 'package:google_mlkit_genai_prompt/google_mlkit_genai_prompt.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/helpers/pdf_engine_helper.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/helpers/windows_ocr.dart';

import 'document_insight.dart';

/// Suggests archive metadata from a PDF, image or text file; each layer degrades per platform.
class DocumentInsightService {
  DocumentInsightService._();

  static final DocumentInsightService instance = DocumentInsightService._();

  static const int _maxPdfPages = 2;
  static const int _minPdfTextChars = 40;
  static const int _maxEntityChars = 6000;
  static const int _maxAiChars = 3000;
  static const int _maxAiCandidates = 50;
  static const int _maxTags = 3;
  static const Set<String> _imageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.bmp',
  };
  static const Set<String> _textExtensions = {'.txt', '.md'};

  Prompt? _prompt;

  static bool get canOcr => Platform.isAndroid || Platform.isWindows;

  Future<DocumentInsight> analyze(
    String path, {
    required DocumentInsightCandidates candidates,
    required String languageCode,
  }) async {
    final text = (await extractText(path)).trim();
    if (text.isEmpty) return const DocumentInsight(text: '');

    final entities = await _extractEntities(text, languageCode);
    final ai = await _askAi(text, candidates);
    final matchedTags = _matchTags(text, candidates.tags);

    return DocumentInsight(
      text: text,
      title: ai?.title,
      date: entities.date ?? ai?.date ?? _findDateByPattern(text),
      correspondent:
          ai?.correspondent ?? _earliestMatch(text, candidates.correspondents),
      documentType:
          ai?.documentType ?? _earliestMatch(text, candidates.documentTypes),
      tags: ai != null && ai.tags.isNotEmpty ? ai.tags : matchedTags,
      amounts: entities.amounts,
      ibans: entities.ibans,
      emails: entities.emails,
      usedAi: ai != null,
    );
  }

  Future<String> extractText(String path) async {
    final ext = p.extension(path).toLowerCase();
    try {
      if (ext == '.pdf') return await _pdfText(path);
      if (_imageExtensions.contains(ext)) {
        return await _ocrFile(path);
      }
      if (_textExtensions.contains(ext)) return await File(path).readAsString();
    } catch (e) {
      errorLog('[DocumentInsight] Text extraction failed for $path: $e');
    }
    return '';
  }

  Future<String> _pdfText(String path) async {
    final doc = await PdfEngineHelper.openPdf(path);
    try {
      final pages = doc.pages.take(_maxPdfPages).toList();
      final buffer = StringBuffer();
      for (final page in pages) {
        final raw = await page.loadText();
        if (raw != null) buffer.writeln(raw.fullText);
      }
      final layerText = buffer.toString().trim();
      if (layerText.length >= _minPdfTextChars || !canOcr) return layerText;

      // Scans have no text layer; OCR the rendered pages instead.
      final ocr = StringBuffer();
      for (final page in pages) {
        final png = await PdfEngineHelper.renderPageToBytes(page, dpi: 200);
        ocr.writeln(await _ocrBytes(png));
      }
      return ocr.toString();
    } finally {
      await doc.dispose();
    }
  }

  Future<String> _ocrFile(String path) async {
    if (Platform.isAndroid) return _mlKitOcr(path);
    if (Platform.isWindows) {
      return WindowsOcr.recognizeText(await File(path).readAsBytes());
    }
    return '';
  }

  Future<String> _ocrBytes(Uint8List bytes) async {
    if (Platform.isWindows) return WindowsOcr.recognizeText(bytes);
    if (!Platform.isAndroid) return '';
    final scope = TempFileManager.createScope();
    try {
      return await _mlKitOcr(
        await scope.createFile('document_insight_ocr.png', bytes: bytes),
      );
    } finally {
      await scope.cleanTracked();
    }
  }

  Future<String> _mlKitOcr(String path) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(path),
      );
      return result.text;
    } finally {
      await recognizer.close();
    }
  }

  Future<_Entities> _extractEntities(String text, String languageCode) async {
    if (!Platform.isAndroid) return const _Entities();
    final extractor = EntityExtractor(
      language: languageCode == 'de'
          ? EntityExtractorLanguage.german
          : EntityExtractorLanguage.english,
    );
    try {
      final annotations = await extractor.annotateText(
        text.substring(0, math.min(text.length, _maxEntityChars)),
        preferredLocale: languageCode,
      );
      annotations.sort((a, b) => a.start.compareTo(b.start));

      final latest = DateTime.now().add(const Duration(days: 1));
      DateTime? date;
      final amounts = <String>{};
      final ibans = <String>{};
      final emails = <String>{};
      for (final annotation in annotations) {
        for (final entity in annotation.entities) {
          switch (entity) {
            case DateTimeEntity(:final timestamp, :final dateTimeGranularity)
                when date == null &&
                    dateTimeGranularity.index >= DateTimeGranularity.day.index:
              final parsed = DateTime.fromMillisecondsSinceEpoch(timestamp);
              if (parsed.isBefore(latest)) {
                date = DateTime(parsed.year, parsed.month, parsed.day);
              }
            case MoneyEntity():
              amounts.add(annotation.text.trim());
            case IbanEntity(:final iban):
              ibans.add(iban);
            case EmailEntity():
              emails.add(annotation.text.trim());
            default:
              break;
          }
        }
      }
      return _Entities(
        date: date,
        amounts: amounts.toList(),
        ibans: ibans.toList(),
        emails: emails.toList(),
      );
    } catch (e) {
      // The language model downloads on first use and needs network.
      debugLog('[DocumentInsight] Entity extraction unavailable: $e');
      return const _Entities();
    } finally {
      await extractor.close();
    }
  }

  static final List<(RegExp, DateTime? Function(Match))> _datePatterns = [
    (
      RegExp(r'\b(\d{1,2})\.\s?(\d{1,2})\.\s?(\d{4})\b'),
      (m) => _date(m[3]!, m[2]!, m[1]!),
    ),
    (RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b'), (m) => _date(m[1]!, m[2]!, m[3]!)),
  ];

  static DateTime? _date(String y, String m, String d) {
    final year = int.parse(y), month = int.parse(m), day = int.parse(d);
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final date = DateTime(year, month, day);
    if (date.month != month || date.isAfter(DateTime.now())) return null;
    return date;
  }

  DateTime? _findDateByPattern(String text) {
    (int, DateTime)? best;
    for (final (pattern, parse) in _datePatterns) {
      for (final match in pattern.allMatches(text)) {
        final date = parse(match);
        if (date == null) continue;
        if (best == null || match.start < best.$1) best = (match.start, date);
        break;
      }
    }
    return best?.$2;
  }

  static int _indexOfName(String lowerText, String name) {
    final lower = name.trim().toLowerCase();
    if (lower.length < 3) return -1;
    final pattern = RegExp(
      '(^|[^\\p{L}\\p{N}])${RegExp.escape(lower)}(\$|[^\\p{L}\\p{N}])',
      unicode: true,
    );
    return pattern.firstMatch(lowerText)?.start ?? -1;
  }

  String? _earliestMatch(String text, List<String> names) {
    final lowerText = text.toLowerCase();
    String? best;
    var bestIndex = -1;
    for (final name in names) {
      final index = _indexOfName(lowerText, name);
      if (index >= 0 && (bestIndex < 0 || index < bestIndex)) {
        best = name;
        bestIndex = index;
      }
    }
    return best;
  }

  List<String> _matchTags(String text, List<String> tags) {
    final lowerText = text.toLowerCase();
    return tags
        .where((tag) => _indexOfName(lowerText, tag) >= 0)
        .take(_maxTags)
        .toList();
  }

  Future<_AiSuggestion?> _askAi(
    String text,
    DocumentInsightCandidates candidates,
  ) async {
    if (!Platform.isAndroid) return null;
    try {
      final prompt = _prompt ??= Prompt();
      if (await prompt.checkFeatureStatus() != FeatureStatus.available) {
        return null;
      }
      final reply = await prompt.runInference(
        _aiRequest(text, candidates),
        systemInstruction:
            'You extract metadata from scanned documents for a document '
            'archive. Reply with one JSON object and nothing else.',
      );
      return _parseAi(reply, candidates);
    } catch (e) {
      debugLog('[DocumentInsight] Gemini Nano suggestion failed: $e');
      return null;
    }
  }

  static String _list(List<String> names) =>
      jsonEncode(names.take(_maxAiCandidates).toList());

  static String _aiRequest(String text, DocumentInsightCandidates candidates) {
    final excerpt = text.length > _maxAiChars
        ? text.substring(0, _maxAiChars)
        : text;
    return '''
Document text (OCR, may contain errors):
"""
$excerpt
"""

Return JSON with these keys:
"title": a short descriptive title in the document's language, at most 8 words, no dates,
"date": the date the document was issued as YYYY-MM-DD, or null,
"correspondent": the sender, exactly one name from ${_list(candidates.correspondents)}, or null,
"documentType": exactly one name from ${_list(candidates.documentTypes)}, or null,
"tags": up to $_maxTags names from ${_list(candidates.tags)}.''';
  }

  static _AiSuggestion? _parseAi(
    String reply,
    DocumentInsightCandidates candidates,
  ) {
    final start = reply.indexOf('{');
    final end = reply.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(reply.substring(start, end + 1));
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, Object?>) return null;

    // Only names that exist on the server; the model may invent others.
    String? pick(Object? value, List<String> names) {
      if (value is! String) return null;
      final lower = value.trim().toLowerCase();
      for (final name in names) {
        if (name.toLowerCase() == lower) return name;
      }
      return null;
    }

    final title = decoded['title'];
    final date = decoded['date'];
    final tags = decoded['tags'];
    final parsedDate = date is String ? DateTime.tryParse(date) : null;
    return _AiSuggestion(
      title: title is String && title.trim().isNotEmpty ? title.trim() : null,
      date: parsedDate != null && !parsedDate.isAfter(DateTime.now())
          ? parsedDate
          : null,
      correspondent: pick(decoded['correspondent'], candidates.correspondents),
      documentType: pick(decoded['documentType'], candidates.documentTypes),
      tags: <String>{
        if (tags is List)
          for (final tag in tags) ?pick(tag, candidates.tags),
      }.take(_maxTags).toList(),
    );
  }
}

class _Entities {
  final DateTime? date;
  final List<String> amounts;
  final List<String> ibans;
  final List<String> emails;

  const _Entities({
    this.date,
    this.amounts = const [],
    this.ibans = const [],
    this.emails = const [],
  });
}

class _AiSuggestion {
  final String? title;
  final DateTime? date;
  final String? correspondent;
  final String? documentType;
  final List<String> tags;

  const _AiSuggestion({
    this.title,
    this.date,
    this.correspondent,
    this.documentType,
    this.tags = const [],
  });
}
