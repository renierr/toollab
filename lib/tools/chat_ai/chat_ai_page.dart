import 'dart:io';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart' show XTypeGroup;
import 'package:tool_lab/helpers/pdf_engine_helper.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/sharing_service.dart';
import 'package:tool_lab/widgets/readable_width.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';
import 'package:tool_lab/widgets/tool_layout.dart';
import 'package:tool_lab/widgets/tv_file_picker_dialog.dart';
import 'chat_ai_state.dart';
import 'chat_models.dart';
import 'widgets/chat_message_bubble.dart';
import 'widgets/chat_session_drawer.dart';
import 'package:tool_lab/widgets/genai_status_banner.dart';
import 'widgets/chat_suggestions.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/chat_thinking_bubble.dart';
import 'widgets/chat_system_prompt_dialog.dart';
import 'widgets/chat_backend_switch.dart';
import 'widgets/deepseek_account_menu.dart';
import 'widgets/deepseek_login_view.dart';
import 'widgets/deepseek_options_bar.dart';
import 'deepseek/deepseek_login_actions.dart';

class ChatAiPage extends StatefulWidget {
  final SharedFile? sharedFile;

  const ChatAiPage({super.key, this.sharedFile});

  @override
  State<ChatAiPage> createState() => _ChatAiPageState();
}

class _ChatAiPageState extends State<ChatAiPage> with DisposeCleanup {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final state = context.read<ChatAiState>();
    state.addListener(_onStateChanged);
    state.onEnterTool();

    onDispose(() {
      state.removeListener(_onStateChanged);
      state.onLeaveTool();
      _textController.dispose();
      _scrollController.dispose();
    });

    if (widget.sharedFile != null) {
      _loadSharedFile(widget.sharedFile!);
    }

    final sharingSub = SharingService.instance.onSharedFile.listen((file) {
      _loadSharedFile(file);
    });
    onDispose(sharingSub.cancel);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _onStateChanged() {
    if (mounted) {
      final state = context.read<ChatAiState>();
      if (state.modelError != null) {
        _showError(state.modelError!);
        state.clearModelError();
      }
      final deepSeekError = state.deepSeekError;
      if (deepSeekError != null) {
        _showError(
          DeepSeekLoginActions.errorText(
            AppLocalizations.of(context),
            deepSeekError,
            state.deepSeekErrorDetail,
          ),
        );
        state.clearDeepSeekError();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  Future<void> _loadSharedFile(SharedFile file) async {
    try {
      final diskFile = File(file.path);
      if (await diskFile.exists()) {
        final text = await diskFile.readAsString();
        setState(() {
          _textController.text = text;
        });
      }
    } catch (e) {
      errorLog('[ChatAiPage] Failed to load shared file: $e');
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // Per-chunk animations would pile up while a reply streams in.
    final state = context.read<ChatAiState>();
    if (state.streamingText.isNotEmpty || state.streamingThinking.isNotEmpty) {
      _scrollController.jumpTo(position.maxScrollExtent);
      return;
    }
    _scrollController.animateTo(
      position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _pickImage(ChatAiState state) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        state.selectImage(bytes);
      }
    } catch (e) {
      errorLog('[ChatAiPage] Error picking image: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _pickFile(ChatAiState state) async {
    try {
      final l10n = AppLocalizations.of(context);
      final typeGroup = XTypeGroup(
        label: l10n.chatAiDocumentsLabel,
        extensions: ['txt', 'md', 'markdown', 'pdf'],
      );
      final file = await TvFilePickerDialog.openSingleFile(
        context,
        acceptedTypeGroups: [typeGroup],
      );
      if (file == null) return;

      if (file.name.toLowerCase().endsWith('.pdf')) {
        final document = await PdfEngineHelper.openPdf(file.path);
        try {
          final buffer = StringBuffer();
          for (final page in document.pages) {
            final pageText = await page.loadText();
            if (pageText != null) {
              buffer.writeln(pageText.fullText);
            }
          }
          state.selectFile(file.name, buffer.toString());
        } finally {
          await document.dispose();
        }
      } else {
        final text = await File(file.path).readAsString();
        state.selectFile(file.name, text);
      }
    } catch (e) {
      errorLog('[ChatAiPage] Error picking or parsing file: $e');
      _showError('Failed to parse file: $e');
    }
  }

  void _handleSend(ChatAiState state) {
    if (state.isInitializing || state.isGenerating) return;
    final text = _textController.text.trim();
    if (text.isNotEmpty ||
        state.selectedImageBytes != null ||
        state.attachedFileName != null) {
      state.sendMessage(text);
      _textController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ChatAiState>();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final showSuggestions = state.messages.isEmpty;
    final deepSeek = state.backend == ChatBackend.deepseek;
    final modelName = ChatBackendSwitch.modelName(state.backend);

    return ToolLayout(
      scaffoldKey: _scaffoldKey,
      title: l10n.toolNameChatAi,
      drawer: const ChatSessionDrawer(),
      actions: [
        if (deepSeek) const DeepSeekAccountMenu(),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: l10n.chatAiSystemPromptTitle,
          onPressed: () async {
            final newPrompt = await showDialog<String?>(
              context: context,
              builder: (context) => ChatSystemPromptDialog(
                currentPrompt: state.customSystemPrompt,
                defaultPrompt: ChatAiState.defaultSystemPrompt,
              ),
            );
            if (newPrompt != null) {
              await state.updateSystemPrompt(newPrompt);
            }
          },
        ),
        // A DeepSeek chat lives on the account; it is deleted from the history.
        if (!deepSeek && state.messages.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: l10n.chatAiClearHistory,
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => ResponsiveAlertDialog(
                  title: Text(l10n.chatAiClearHistory),
                  content: Text(l10n.chatAiClearHistoryConfirm),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(l10n.commonCancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                      child: Text(l10n.commonClear),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await state.clearCurrentSessionHistory();
              }
            },
          ),
        IconButton(
          icon: const Icon(Icons.history_rounded),
          tooltip: l10n.toolNameChatAi,
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
            if (deepSeek) state.refreshDeepSeekHistory();
          },
        ),
      ],
      child: Column(
        children: [
          const ChatBackendSwitch(),
          if (state.needsDeepSeekLogin)
            const Expanded(child: DeepSeekLoginView())
          else ...[
            if (!deepSeek)
              GenAiStatusBanner(
                status: state.featureStatus,
                downloadProgress: state.downloadProgress,
                onDownload: state.downloadModel,
              ),
            Expanded(
              child: showSuggestions
                  ? ReadableWidth(
                      child: ChatSuggestions(
                        backend: state.backend,
                        onSelectSuggestion: (text) {
                          _textController.text = text;
                          _handleSend(state);
                        },
                      ),
                    )
                  : ReadableScrollPadding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      builder: (context, padding) => ListView.builder(
                        controller: _scrollController,
                        itemCount:
                            state.messages.length +
                            (state.isGenerating ? 1 : 0),
                        padding: padding,
                        itemBuilder: (context, index) {
                          if (index == state.messages.length) {
                            if (state.streamingText.isEmpty &&
                                state.streamingThinking.isEmpty) {
                              return ChatThinkingBubble(modelName: modelName);
                            }
                            return ChatMessageBubble(
                              modelName: modelName,
                              live: true,
                              message: ChatMessage(
                                id: -1,
                                sessionId: state.currentSessionId ?? -1,
                                role: 'model',
                                content: state.streamingText,
                                thinking: state.streamingThinking,
                                createdAt: 0,
                              ),
                            );
                          }
                          final message = state.messages[index];
                          return ChatMessageBubble(
                            modelName: modelName,
                            message: message,
                          );
                        },
                      ),
                    ),
            ),
            ReadableWidth(
              child: ChatInputBar(
                controller: _textController,
                onSend: () => _handleSend(state),
                isGenerating: state.isGenerating,
                enabled: !state.isInitializing,
                selectedImageBytes: state.selectedImageBytes,
                onPickImage: deepSeek ? null : () => _pickImage(state),
                options: deepSeek ? const DeepSeekOptionsBar() : null,
                onRemoveImage: () => state.selectImage(null),
                attachedFileName: state.attachedFileName,
                onPickFile: () => _pickFile(state),
                onRemoveFile: () => state.selectFile(null, null),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
