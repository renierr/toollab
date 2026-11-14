import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/chat_ai/chat_models.dart';
import 'package:tool_lab/tools/chat_ai/deepseek/deepseek_history.dart';
import 'package:tool_lab/tools/chat_ai/deepseek/deepseek_stream.dart';
import 'package:tool_lab/tools/chat_ai/widgets/chat_citation.dart';
import 'package:tool_lab/widgets/markdown_view.dart';

const _result = {
  'url': 'https://example.com/a',
  'title': 'Example title',
  'snippet': 'Example snippet',
  'cite_index': 1,
  'site_name': 'example.com',
};

void main() {
  test('stream keeps search results as citations', () {
    final parser = DeepSeekStreamParser();
    String data(Object json) => 'data: ${jsonEncode(json)}';
    parser.addLine(
      data({
        'v': {
          'response': {
            'message_id': 2,
            'fragments': [
              {'type': 'SEARCH', 'content': '', 'results': <Object>[]},
            ],
          },
        },
      }),
    );
    parser.addLine(
      data({
        'p': 'response/fragments/-1/results',
        'o': 'SET',
        'v': [_result],
      }),
    );
    parser.addLine(
      data({
        'p': 'response/fragments',
        'o': 'APPEND',
        'v': [
          {'type': 'RESPONSE', 'content': 'Fact'},
        ],
      }),
    );
    parser.addLine(
      data({
        'p': 'response/fragments/-1/content',
        'o': 'APPEND',
        'v': ' [citation:1]',
      }),
    );
    final reply = parser.reply;
    expect(reply.text, 'Fact [citation:1]');
    expect(reply.citations.single.url, 'https://example.com/a');
  });

  test('history reads citations from search fragments', () {
    final history = DeepSeekHistory.fromJson({
      'chat_messages': [
        {
          'message_id': 1,
          'role': 'ASSISTANT',
          'fragments': [
            {
              'type': 'SEARCH',
              'content': 'x',
              'results': [_result],
            },
            {'type': 'RESPONSE', 'content': 'Fact [citation:1]'},
          ],
        },
      ],
    });
    final citation = history.messages.single.citations.single;
    expect(citation.index, 1);
    expect(ChatCitation.decodeList(ChatCitation.encodeList([citation])), [
      citation,
    ]);
  });

  testWidgets('citation markers render as badges', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MarkdownView(
            data: 'Fact [citation:1][citation:2].',
            inlineSyntaxes: [CitationSyntax.instance],
            builders: {
              CitationSyntax.tag: CitationBuilder(
                citations: [ChatCitation.fromJson(_result)!],
                color: Colors.blue,
              ),
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('[citation:', findRichText: true), findsNothing);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.byType(Tooltip), findsOneWidget);
  });
}
