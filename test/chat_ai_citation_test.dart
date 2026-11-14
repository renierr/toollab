import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/chat_ai/chat_models.dart';
import 'package:tool_lab/tools/chat_ai/deepseek/deepseek_history.dart';
import 'package:tool_lab/tools/chat_ai/deepseek/deepseek_stream.dart';
import 'package:tool_lab/tools/chat_ai/widgets/chat_citation.dart';
import 'package:tool_lab/tools/chat_ai/widgets/chat_message_bubble.dart';
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

  test('history reads attached file names from file fragments', () {
    final history = DeepSeekHistory.fromJson({
      'chat_messages': [
        {
          'message_id': 1,
          'role': 'USER',
          'fragments': [
            {
              'type': 'FILE',
              'files': [
                {
                  'id': 'file-1',
                  'file_name': 'receipt.png',
                  'is_image': true,
                  'signed_path': '/file?file_id=1&state=a',
                },
                {'id': 'file-2', 'file_name': 'report.pdf', 'is_image': false},
              ],
            },
            {'type': 'REQUEST', 'content': 'Read these'},
          ],
        },
      ],
    });
    final message = history.messages.single;
    expect(message.files.map((f) => f.name), ['receipt.png', 'report.pdf']);
    expect(message.files.first.isImage, isTrue);
    expect(message.files.first.signedPath, '/file?file_id=1&state=a');
    expect(message.files.last.signedPath, isNull);
    expect(message.text, 'Read these');
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
    expect(find.text('Open website'), findsNothing);
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();
    expect(find.text('Example title'), findsOneWidget);
    expect(find.text('Open website'), findsOneWidget);
  });

  for (final width in [320.0, 1400.0]) {
    testWidgets('bubble with files and actions lays out at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ListView(
              children: [
                ChatMessageBubble(
                  modelName: 'DeepSeek',
                  message: ChatMessage(
                    id: 1,
                    sessionId: 1,
                    role: 'user',
                    content: 'Hi',
                    createdAt: 0,
                    files: [
                      ChatFile(name: 'a-very-long-file-name-for-a-report.pdf'),
                      ChatFile(name: 'receipt.png'),
                    ],
                  ),
                ),
                ChatMessageBubble(
                  modelName: 'DeepSeek',
                  message: const ChatMessage(
                    id: 2,
                    sessionId: 1,
                    role: 'model',
                    content: 'Answer [citation:1]',
                    createdAt: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.copy_rounded), findsNWidgets(2));
      expect(
        find.byIcon(Icons.share_outlined),
        findsNWidgets(Platform.isLinux ? 0 : 2),
      );
      expect(find.text('receipt.png'), findsOneWidget);
    });
  }
}
