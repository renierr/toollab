import 'dart:math';

/// Pure-Dart, offline, dependency-free extractive text analysis.
///
/// Provides a useful capability on platforms where the on-device LLM
/// (Gemini Nano, Android-only) is unavailable: extractive summarization,
/// keyword extraction, and passage-based question answering. Bilingual
/// (English + German), matching the app's supported locales.
class TextAnalysisHelper {
  TextAnalysisHelper._();

  /// Combined English + German stop words. Kept small and common on purpose —
  /// enough to strip filler without a full linguistic model.
  static const Set<String> _stopwords = {
    // English
    'the', 'a', 'an', 'and', 'or', 'but', 'if', 'then', 'else', 'when', 'of',
    'to', 'in', 'on', 'for', 'with', 'as', 'by', 'at', 'from', 'is', 'are',
    'was', 'were', 'be', 'been', 'being', 'it', 'its', 'this', 'that', 'these',
    'those', 'you', 'he', 'she', 'we', 'they', 'them', 'his', 'her', 'their',
    'our', 'your', 'my', 'me', 'us', 'do', 'does', 'did', 'not', 'no', 'yes',
    'can', 'could', 'should', 'would', 'will', 'shall', 'may', 'might', 'must',
    'have', 'has', 'had', 'having', 'so', 'than', 'too', 'very', 'just',
    'about', 'into', 'over', 'after', 'before', 'between', 'out', 'up', 'down',
    'off', 'above', 'below', 'only', 'own', 'same', 'such', 'each', 'few',
    'more', 'most', 'other', 'some', 'any', 'all', 'both', 'because', 'while',
    'during', 'through', 'against', 'again', 'further', 'once', 'here', 'there',
    'where', 'why', 'how', 'what', 'which', 'who', 'whom', 'whose', 'also',
    'per', 'via', 'etc',
    // German
    'der', 'die', 'das', 'und', 'oder', 'aber', 'wenn', 'dann', 'als', 'von',
    'zu', 'im', 'auf', 'für', 'mit', 'bei', 'aus', 'ist', 'sind', 'war',
    'waren', 'sein', 'dies', 'diese', 'dieser', 'dieses', 'ich', 'du', 'er',
    'sie', 'wir', 'ihr', 'ihnen', 'ihre', 'unser', 'dein', 'mein', 'mich',
    'uns', 'nicht', 'kein', 'keine', 'ja', 'nein', 'kann', 'könnte', 'soll',
    'würde', 'wird', 'werden', 'haben', 'hat', 'hatte', 'auch', 'nur', 'über',
    'unter', 'nach', 'vor', 'zwischen', 'durch', 'gegen', 'wieder', 'hier',
    'dort', 'wo', 'warum', 'wie', 'welche', 'wer', 'den', 'dem', 'des',
    'ein', 'eine', 'einen', 'einem', 'einer', 'eines', 'am', 'zum', 'zur',
    'vom', 'beim', 'man', 'sowie', 'bzw',
  };

  static final RegExp _tokenSplitter = RegExp(r'[^\p{L}\p{N}]+', unicode: true);
  static final RegExp _sentenceSplitter = RegExp(r'(?<=[.!?])\s+|\n+');
  static final RegExp _pureNumber = RegExp(r'^\d+$');

  static List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .split(_tokenSplitter)
        .where((t) => t.isNotEmpty)
        .toList();
  }

  static bool _isContentWord(String token) {
    return token.length >= 3 &&
        !_stopwords.contains(token) &&
        !_pureNumber.hasMatch(token);
  }

  /// Splits [text] into trimmed sentences, dropping short fragments.
  static List<String> splitSentences(String text) {
    return text
        .split(_sentenceSplitter)
        .map((s) => s.trim())
        .where((s) => s.length >= 15)
        .toList();
  }

  static Map<String, int> _contentTermFrequency(String text) {
    final freq = <String, int>{};
    for (final token in _tokenize(text)) {
      if (_isContentWord(token)) {
        freq[token] = (freq[token] ?? 0) + 1;
      }
    }
    return freq;
  }

  /// Extractive summary: the [maxSentences] highest-scoring sentences returned
  /// in their original document order. Scoring is mean content-word frequency.
  static String summarize(String text, {int maxSentences = 5}) {
    final sentences = splitSentences(text);
    if (sentences.isEmpty) return '';

    final freq = _contentTermFrequency(text);
    if (freq.isEmpty) {
      return sentences.take(maxSentences).join('\n\n');
    }
    final maxFreq = freq.values.reduce(max).toDouble();

    final scored = <_ScoredSentence>[];
    for (int i = 0; i < sentences.length; i++) {
      final words = _tokenize(sentences[i]).where(_isContentWord).toList();
      if (words.isEmpty) continue;
      double score = 0;
      for (final w in words) {
        score += (freq[w] ?? 0) / maxFreq;
      }
      scored.add(_ScoredSentence(i, score / words.length));
    }
    if (scored.isEmpty) return sentences.take(maxSentences).join('\n\n');

    scored.sort((a, b) => b.score.compareTo(a.score));
    final chosen = scored.take(maxSentences).map((s) => s.index).toList()
      ..sort();
    return chosen.map((i) => sentences[i]).join('\n\n');
  }

  /// The [topN] most frequent content words, most significant first.
  static List<String> extractKeywords(String text, {int topN = 12}) {
    final freq = _contentTermFrequency(text);
    final entries = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(topN).map((e) => e.key).toList();
  }

  /// Extractive question answering: returns the [maxPassages] sentences most
  /// relevant to [question] (light TF-IDF over the question's content terms),
  /// in document order. Returns an empty string when nothing matches.
  static String answer(String text, String question, {int maxPassages = 4}) {
    final sentences = splitSentences(text);
    if (sentences.isEmpty) return '';

    final queryTerms = _tokenize(question).where(_isContentWord).toSet();
    if (queryTerms.isEmpty) return '';

    final tokenized = sentences
        .map((s) => _tokenize(s).where(_isContentWord).toList())
        .toList();
    final n = sentences.length;

    final docFreq = <String, int>{};
    for (final term in queryTerms) {
      var count = 0;
      for (final words in tokenized) {
        if (words.contains(term)) count++;
      }
      docFreq[term] = count;
    }

    final scored = <_ScoredSentence>[];
    for (int i = 0; i < sentences.length; i++) {
      final words = tokenized[i];
      if (words.isEmpty) continue;
      double score = 0;
      for (final term in queryTerms) {
        final tf = words.where((w) => w == term).length;
        if (tf == 0) continue;
        final idf = log(n / (1 + docFreq[term]!));
        score += tf * (idf <= 0 ? 0.1 : idf);
      }
      if (score > 0) scored.add(_ScoredSentence(i, score));
    }
    if (scored.isEmpty) return '';

    scored.sort((a, b) => b.score.compareTo(a.score));
    final chosen = scored.take(maxPassages).map((s) => s.index).toList()
      ..sort();
    return chosen.map((i) => sentences[i]).join('\n\n');
  }
}

class _ScoredSentence {
  final int index;
  final double score;

  const _ScoredSentence(this.index, this.score);
}
