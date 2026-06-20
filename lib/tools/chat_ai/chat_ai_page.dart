import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/sharing_service.dart';
import 'package:tool_lab/widgets/tool_layout.dart';
import 'chat_ai_state.dart';
import 'widgets/chat_message_bubble.dart';
import 'widgets/chat_session_drawer.dart';
import 'widgets/chat_status_banner.dart';
import 'widgets/chat_suggestions.dart';
import 'widgets/chat_input_bar.dart';

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

    onDispose(() {
      state.removeListener(_onStateChanged);
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
      debugPrint('[ChatAiPage] Failed to load shared file: $e');
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
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
      debugPrint('[ChatAiPage] Error picking image: $e');
    }
  }

  void _handleSend(ChatAiState state) {
    final text = _textController.text.trim();
    if (text.isNotEmpty || state.selectedImageBytes != null) {
      state.sendMessage(text);
      _textController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ChatAiState>();
    final l10n = AppLocalizations.of(context);

    final showSuggestions = state.messages.isEmpty;

    return ToolLayout(
      scaffoldKey: _scaffoldKey,
      title: l10n.toolNameChatAi,
      drawer: const ChatSessionDrawer(),
      actions: [
        IconButton(
          icon: const Icon(Icons.history_rounded),
          tooltip: l10n.toolNameChatAi,
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
      ],
      child: Column(
        children: [
          ChatStatusBanner(
            status: state.featureStatus,
            onDownload: state.downloadModel,
          ),
          Expanded(
            child: showSuggestions
                ? ChatSuggestions(
                    onSelectSuggestion: (text) {
                      _textController.text = text;
                      _handleSend(state);
                    },
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: state.messages.length,
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    itemBuilder: (context, index) {
                      final message = state.messages[index];
                      return ChatMessageBubble(message: message);
                    },
                  ),
          ),
          ChatInputBar(
            controller: _textController,
            onSend: () => _handleSend(state),
            isGenerating: state.isGenerating,
            enabled: !state.isInitializing,
            selectedImageBytes: state.selectedImageBytes,
            onPickImage: () => _pickImage(state),
            onRemoveImage: () => state.selectImage(null),
          ),
        ],
      ),
    );
  }
}
