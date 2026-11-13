import 'dart:io';

import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

/// On-device language identification and translation (ML Kit, Android only).
/// Language models (~30 MB each) download on first use.
class TranslationService {
  TranslationService._();

  static final TranslationService instance = TranslationService._();

  static bool get isSupported => Platform.isAndroid;

  static final List<TranslateLanguage> languages = [...TranslateLanguage.values]
    ..sort((a, b) => a.name.compareTo(b.name));

  LanguageIdentifier? _identifier;
  final Map<String, OnDeviceTranslator> _translators = {};

  /// Returns the BCP-47 code of [text]'s language, or null if undetermined.
  Future<String?> identifyLanguage(String text) async {
    if (!isSupported || text.trim().isEmpty) return null;
    final identifier = _identifier ??= LanguageIdentifier(
      confidenceThreshold: 0.5,
    );
    final sample = text.length > 2000 ? text.substring(0, 2000) : text;
    final code = await identifier.identifyLanguage(sample);
    return code == identifier.undeterminedLanguageCode ? null : code;
  }

  static TranslateLanguage? languageFor(String? code) {
    if (code == null) return null;
    return BCP47Code.fromRawValue(code.split(RegExp('[-_]')).first);
  }

  static String displayName(TranslateLanguage language) =>
      '${shortName(language)} (${language.bcpCode})';

  static String shortName(TranslateLanguage language) {
    final name = language.name;
    return '${name[0].toUpperCase()}${name.substring(1)}';
  }

  Future<bool> isModelReady(TranslateLanguage language) =>
      OnDeviceTranslatorModelManager().isModelDownloaded(language.bcpCode);

  /// Downloads [language]'s model over any network if it is missing.
  Future<bool> downloadModel(TranslateLanguage language) =>
      OnDeviceTranslatorModelManager().downloadModel(
        language.bcpCode,
        isWifiRequired: false,
      );

  /// English is built in and cannot be removed.
  static bool isRemovable(TranslateLanguage language) =>
      language != TranslateLanguage.english;

  Future<bool> deleteModel(TranslateLanguage language) async {
    if (!isRemovable(language)) return false;
    final prefix = '${language.bcpCode}>';
    final suffix = '>${language.bcpCode}';
    final stale = _translators.keys
        .where((k) => k.startsWith(prefix) || k.endsWith(suffix))
        .toList();
    for (final key in stale) {
      await _translators.remove(key)?.close();
    }
    return OnDeviceTranslatorModelManager().deleteModel(language.bcpCode);
  }

  /// Translates line by line so Markdown structure and blank lines survive.
  Future<String> translate(
    String text, {
    required TranslateLanguage source,
    required TranslateLanguage target,
  }) async {
    if (source == target) return text;
    final key = '${source.bcpCode}>${target.bcpCode}';
    final translator = _translators[key] ??= OnDeviceTranslator(
      sourceLanguage: source,
      targetLanguage: target,
    );
    final out = <String>[];
    for (final line in text.split('\n')) {
      out.add(
        line.trim().isEmpty ? line : await translator.translateText(line),
      );
    }
    return out.join('\n');
  }

  /// Picks [preferred], or English/German when the text is already in it.
  static TranslateLanguage defaultTarget(
    String preferredCode,
    TranslateLanguage? source,
  ) {
    final preferred = languageFor(preferredCode) ?? TranslateLanguage.english;
    if (source != preferred) return preferred;
    return preferred == TranslateLanguage.english
        ? TranslateLanguage.german
        : TranslateLanguage.english;
  }
}
