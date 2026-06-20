import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'chat_ai_page.dart';
import 'chat_ai_state.dart';

class ChatAiTool {
  ChatAiTool._();

  static ToolModel get config => ToolModel(
    id: 'chat-ai',
    name: 'AI Chat',
    description: 'Chat with on-device AI model Gemini Nano using ML Kit',
    icon: Icons.chat_bubble_outline,
    route: '/chat-ai',
    accentColor: AppTheme.accentBlue,
    sectionId: 'utilities',
    nameL10n: (l10n) => l10n.toolNameChatAi,
    descriptionL10n: (l10n) => l10n.toolDescChatAi,
    createPage: (sd) => ChatAiPage(sharedFile: sd?.firstFile),
    stateProviders: () => [
      ChangeNotifierProvider<ChatAiState>(create: (_) => ChatAiState()),
    ],
  );
}
