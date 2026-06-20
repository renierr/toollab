import 'package:flutter/material.dart';
import '../config.dart';

class ChatSuggestions extends StatelessWidget {
  final ValueChanged<String> onSelectSuggestion;

  const ChatSuggestions({super.key, required this.onSelectSuggestion});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = ChatAiTool.config.accentColor;

    final suggestions = [
      'Explain photosynthesis simply.',
      'Write a short poem about space.',
      'Draft a professional sick leave email.',
      'Difference between cloud AI and on-device AI?',
    ];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 64,
                color: accentColor.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'AI Chat (Gemini Nano)',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ask questions, generate text, or practice writing.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: suggestions.map((text) {
                  return InkWell(
                    onTap: () => onSelectSuggestion(text),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.15,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            size: 16,
                            color: accentColor,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              text,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
