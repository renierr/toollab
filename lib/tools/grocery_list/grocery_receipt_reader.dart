import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/document_insight/document_insight_service.dart';
import 'package:tool_lab/tools/chat_ai/chat_ai_state.dart';

import 'grocery_text_parser.dart';

/// Reads purchased items from a receipt photo or PDF. Gemini Nano structures
/// the OCR text when available; otherwise priced lines are parsed.
class GroceryReceiptReader {
  GroceryReceiptReader._();

  static bool get isSupported => DocumentInsightService.canOcr;

  static const _maxAiChars = 3000;

  static Future<List<GroceryDraft>> read(String path, ChatAiState ai) async {
    final text = await _receiptText(path);
    if (text.trim().isEmpty) return const [];
    if (ai.isGenerativeAvailable) {
      try {
        final drafts = await _readWithAi(text, ai);
        if (drafts.isNotEmpty) return drafts;
      } catch (e) {
        errorLog('[GroceryReceiptReader] AI parsing failed: $e');
      }
    }
    return GroceryTextParser.parseReceipt(text);
  }

  static const _imageExtensions = {'.jpg', '.jpeg', '.png', '.webp'};

  /// ML Kit reads the name and price columns as separate blocks, so image
  /// receipts are rebuilt row by row from the line positions.
  static Future<String> _receiptText(String path) async {
    final extension = p.extension(path).toLowerCase();
    if (!Platform.isAndroid || !_imageExtensions.contains(extension)) {
      return DocumentInsightService.instance.extractText(path);
    }
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(path),
      );
      return joinRows([
        for (final block in result.blocks)
          for (final line in block.lines)
            (text: line.text, box: line.boundingBox),
      ]);
    } finally {
      await recognizer.close();
    }
  }

  /// Joins OCR lines that share a row (overlapping vertical centers), left to right.
  static String joinRows(List<({String text, Rect box})> lines) {
    final sorted = [...lines]
      ..sort((a, b) => a.box.center.dy.compareTo(b.box.center.dy));
    final rows = <List<({String text, Rect box})>>[];
    for (final line in sorted) {
      final row = rows.lastOrNull;
      if (row != null) {
        final anchor = row.first.box;
        final tolerance = anchor.height * 0.5;
        if ((line.box.center.dy - anchor.center.dy).abs() <= tolerance) {
          row.add(line);
          continue;
        }
      }
      rows.add([line]);
    }
    return rows
        .map(
          (row) => (row..sort((a, b) => a.box.left.compareTo(b.box.left)))
              .map((l) => l.text)
              .join('  '),
        )
        .join('\n');
  }

  static Future<List<GroceryDraft>> _readWithAi(
    String text,
    ChatAiState ai,
  ) async {
    final reply = await ai
        .streamTextTask(
          instruction:
              'Extract the purchased grocery products from this receipt. '
              'Reply with a JSON array of objects {"name": string, '
              '"amount": number, "unit": one of '
              '${GroceryTextParser.units.join(', ')}}. Use short readable '
              'product names in the receipt language without codes or prices. '
              'Skip totals, taxes, deposits, discounts and payment lines.',
          text: text.length > _maxAiChars
              ? text.substring(0, _maxAiChars)
              : text,
        )
        .join();
    return parseAiReply(reply);
  }

  static List<GroceryDraft> parseAiReply(String reply) {
    final start = reply.indexOf('[');
    final end = reply.lastIndexOf(']');
    if (start < 0 || end <= start) return const [];
    final decoded = jsonDecode(reply.substring(start, end + 1));
    if (decoded is! List) return const [];
    final drafts = <GroceryDraft>[];
    for (final entry in decoded) {
      if (entry is! Map) continue;
      final name = (entry['name'] as Object?)?.toString().trim() ?? '';
      if (name.isEmpty) continue;
      final amount = (entry['amount'] as num?)?.toDouble() ?? 1;
      final unit = entry['unit']?.toString();
      drafts.add(
        GroceryDraft(
          name,
          amount: amount > 0 ? amount : 1,
          unit: GroceryTextParser.units.contains(unit) ? unit! : 'pcs',
        ),
      );
    }
    return drafts;
  }
}
