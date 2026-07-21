import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/helpers/text_analysis_helper.dart';

void main() {
  const text =
      'Solar panels convert sunlight into electricity. '
      'Solar energy is renewable and clean. '
      'Many homes now install solar panels on their roofs. '
      'The cost of solar panels has decreased significantly in recent years. '
      'Electricity generated from solar reduces carbon emissions.';

  group('TextAnalysisHelper', () {
    test('splitSentences drops short fragments', () {
      final sentences = TextAnalysisHelper.splitSentences(text);
      expect(sentences.length, 5);
      expect(sentences.first, startsWith('Solar panels convert'));
    });

    test('extractKeywords surfaces the dominant terms', () {
      final keywords = TextAnalysisHelper.extractKeywords(text, topN: 5);
      expect(keywords, isNotEmpty);
      expect(keywords, contains('solar'));
      // Stop words must not appear.
      expect(keywords, isNot(contains('the')));
      expect(keywords, isNot(contains('and')));
    });

    test('summarize returns non-empty subset in document order', () {
      final summary = TextAnalysisHelper.summarize(text, maxSentences: 2);
      expect(summary, isNotEmpty);
      expect(summary.split('\n\n').length, lessThanOrEqualTo(2));
      expect(summary.toLowerCase(), contains('solar'));
    });

    test('answer returns the most relevant passage', () {
      final result = TextAnalysisHelper.answer(
        text,
        'How much do solar panels cost?',
        maxPassages: 1,
      );
      expect(result, contains('cost'));
    });

    test('answer returns empty when no term overlaps', () {
      final result = TextAnalysisHelper.answer(
        text,
        'quantum banana orchestra',
      );
      expect(result, isEmpty);
    });

    test('handles empty input gracefully', () {
      expect(TextAnalysisHelper.summarize(''), isEmpty);
      expect(TextAnalysisHelper.extractKeywords(''), isEmpty);
      expect(TextAnalysisHelper.answer('', 'anything'), isEmpty);
    });
  });
}
