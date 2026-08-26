import 'dart:async';
import 'package:tool_lab/helpers/debug_log.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
// ignore: implementation_imports
import 'package:google_mlkit_genai_prompt/src/prompt.dart';
import 'package:tool_lab/helpers/text_analysis_helper.dart';
import 'package:tool_lab/services/database_service.dart';
import 'chat_ai_db_helper.dart';
import 'chat_models.dart';
import 'config.dart';

class ChatAiState extends ChangeNotifier {
  List<ChatSession> _sessions = [];
  int? _currentSessionId;
  List<ChatMessage> _messages = [];
  FeatureStatus _featureStatus = FeatureStatus.unavailable;
  bool _isInitializing = false;
  bool _isGenerating = false;
  Timer? _statusPollingTimer;
  Prompt? _prompt;
  Uint8List? _selectedImageBytes;

  static const String defaultSystemPrompt =
      'You are a helpful, respectful, and honest on-device AI assistant. Respond in the same language as the user (e.g. if the user writes in German, respond in German; if the user writes in English, respond in English).';

  String? _customSystemPrompt;

  String get customSystemPrompt => _customSystemPrompt ?? '';

  String get activeSystemPrompt => _customSystemPrompt ?? defaultSystemPrompt;
  String? _attachedFileName;
  String? _attachedFileContent;
  String? _modelError;

  List<ChatSession> get sessions => _sessions;
  int? get currentSessionId => _currentSessionId;
  List<ChatMessage> get messages => _messages;
  FeatureStatus get featureStatus => _featureStatus;
  bool get isInitializing => _isInitializing;
  bool get isGenerating => _isGenerating;
  Uint8List? get selectedImageBytes => _selectedImageBytes;
  String? get attachedFileName => _attachedFileName;
  String? get attachedFileContent => _attachedFileContent;
  String? get modelError => _modelError;

  /// True only when real on-device generative inference is usable. The single
  /// source of truth for the Android + Gemini-Nano gating condition; when
  /// false the tools fall back to offline extractive text analysis.
  bool get isGenerativeAvailable =>
      Platform.isAndroid &&
      _featureStatus == FeatureStatus.available &&
      _prompt != null;

  void clearModelError() {
    _modelError = null;
    notifyListeners();
  }

  Future<void> updateSystemPrompt(String? newPrompt) async {
    if (newPrompt == null ||
        newPrompt.trim().isEmpty ||
        newPrompt.trim() == defaultSystemPrompt) {
      _customSystemPrompt = null;
      await DatabaseService.instance.deleteSetting(
        ChatAiTool.config.id,
        'system_prompt',
      );
    } else {
      _customSystemPrompt = newPrompt.trim();
      await DatabaseService.instance.setSetting(
        ChatAiTool.config.id,
        'system_prompt',
        _customSystemPrompt!,
      );
    }
    notifyListeners();
  }

  void selectImage(Uint8List? bytes) {
    _selectedImageBytes = bytes;
    if (bytes != null) {
      _attachedFileName = null;
      _attachedFileContent = null;
    }
    notifyListeners();
  }

  void selectFile(String? name, String? content) {
    _attachedFileName = name;
    _attachedFileContent = content;
    if (name != null) {
      _selectedImageBytes = null;
    }
    notifyListeners();
  }

  /// Max characters of document context fed into a one-shot [askAboutDocument]
  /// call. Gemini Nano has a small context window, so longer text is truncated.
  static const int maxDocumentContextChars = 4000;

  /// Session-less one-shot question about a block of document text. Unlike
  /// [sendMessage] this does not touch chat sessions/history/DB — it is meant
  /// for embedding AI Q&A inside other tools (e.g. the PDF text extractor).
  Future<String> askAboutDocument({
    required String documentText,
    required String question,
  }) async {
    if (isGenerativeAvailable) {
      final truncated = documentText.length > maxDocumentContextChars
          ? '${documentText.substring(0, maxDocumentContextChars)}... [Truncated]'
          : documentText;
      final promptText =
          (StringBuffer()
                ..writeln(activeSystemPrompt)
                ..writeln()
                ..writeln(
                  'The user provided the following document text. Answer the '
                  'question based only on this text.',
                )
                ..writeln('----- DOCUMENT START -----')
                ..writeln(truncated)
                ..writeln('----- DOCUMENT END -----')
                ..writeln()
                ..writeln('Question: $question'))
              .toString();
      final response = await _prompt!.runInference(promptText);
      return response.trim();
    }

    // Offline fallback (no on-device LLM): extractive passage answer.
    final extractive = TextAnalysisHelper.answer(documentText, question);
    return extractive.isNotEmpty
        ? extractive
        : 'No relevant passages found for your question in the extracted text.';
  }

  ChatAiState() {
    init();
  }

  Future<void> init() async {
    _isInitializing = true;
    notifyListeners();

    try {
      await loadSessions();

      if (Platform.isAndroid) {
        _prompt = Prompt();
        _customSystemPrompt = await DatabaseService.instance.getSetting(
          ChatAiTool.config.id,
          'system_prompt',
        );
        await updateFeatureStatus();

        if (_featureStatus == FeatureStatus.downloading) {
          _startStatusPolling();
        }
      } else {
        _featureStatus = FeatureStatus.unavailable;
      }
    } catch (e) {
      errorLog('[ChatAiState] Initialization failed: $e');
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> updateFeatureStatus() async {
    if (_prompt != null && Platform.isAndroid) {
      try {
        _featureStatus = await _prompt!.checkFeatureStatus();
      } catch (e) {
        errorLog('[ChatAiState] Check feature status failed: $e');
        _modelError = e.toString();
        _featureStatus = FeatureStatus.unavailable;
      }
    } else {
      _featureStatus = FeatureStatus.unavailable;
    }
    notifyListeners();
  }

  void _startStatusPolling() {
    _statusPollingTimer?.cancel();
    _statusPollingTimer = Timer.periodic(const Duration(seconds: 3), (
      timer,
    ) async {
      await updateFeatureStatus();
      if (_featureStatus != FeatureStatus.downloading) {
        timer.cancel();
      }
    });
  }

  Future<void> downloadModel() async {
    if (!Platform.isAndroid || _prompt == null) return;
    _modelError = null;
    notifyListeners();
    try {
      await _prompt!.downloadFeature();
      await updateFeatureStatus();
      _startStatusPolling();
    } catch (e) {
      errorLog('[ChatAiState] Model download trigger failed: $e');
      _modelError = e.toString();
      notifyListeners();
    }
  }

  void onEnterTool() {
    if (_featureStatus == FeatureStatus.downloading) {
      _startStatusPolling();
    }
  }

  void onLeaveTool() {
    _statusPollingTimer?.cancel();
    _statusPollingTimer = null;
    _selectedImageBytes = null;
    _attachedFileName = null;
    _attachedFileContent = null;
    notifyListeners();
  }

  Future<void> loadSessions() async {
    try {
      _sessions = await ChatAiDbHelper.instance.getSessions();
      if (_sessions.isNotEmpty && _currentSessionId == null) {
        await selectSession(_sessions.first.id);
      } else if (_sessions.isEmpty) {
        _currentSessionId = null;
        _messages = [];
      }
      notifyListeners();
    } catch (e) {
      errorLog('[ChatAiState] Load sessions failed: $e');
    }
  }

  Future<void> selectSession(int sessionId) async {
    _currentSessionId = sessionId;
    try {
      _messages = await ChatAiDbHelper.instance.getMessages(sessionId);
    } catch (e) {
      errorLog('[ChatAiState] Load messages failed: $e');
      _messages = [];
    }
    notifyListeners();
  }

  Future<void> createNewSession({String? initialTitle}) async {
    try {
      final title =
          initialTitle ??
          'Chat ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}';
      final newId = await ChatAiDbHelper.instance.createSession(title);
      await loadSessions();
      await selectSession(newId);
    } catch (e) {
      errorLog('[ChatAiState] Create session failed: $e');
    }
  }

  Future<void> deleteSession(int sessionId) async {
    try {
      await ChatAiDbHelper.instance.deleteSession(sessionId);
      if (_currentSessionId == sessionId) {
        _currentSessionId = null;
      }
      await loadSessions();
    } catch (e) {
      errorLog('[ChatAiState] Delete session failed: $e');
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty &&
        _selectedImageBytes == null &&
        _attachedFileName == null) {
      return;
    }
    if (_currentSessionId == null) {
      final initialTitle = text.trim().isNotEmpty
          ? (text.length > 20 ? '${text.substring(0, 17)}...' : text)
          : (_attachedFileName ?? 'Image Prompt');
      await createNewSession(initialTitle: initialTitle);
    }

    final sessionId = _currentSessionId!;
    final imageToSend = _selectedImageBytes;
    final fileNameToSend = _attachedFileName;
    final fileContentToSend = _attachedFileContent;

    _selectedImageBytes = null;
    _attachedFileName = null;
    _attachedFileContent = null;
    notifyListeners();

    try {
      // Save user message
      await ChatAiDbHelper.instance.insertMessage(
        sessionId,
        'user',
        text,
        imageData: imageToSend,
        fileName: fileNameToSend,
        fileContent: fileContentToSend,
      );
      _messages = await ChatAiDbHelper.instance.getMessages(sessionId);
      notifyListeners();

      // Update session title if default
      final currentSession = _sessions
          .where((s) => s.id == sessionId)
          .firstOrNull;
      if (currentSession != null && currentSession.title.startsWith('Chat ')) {
        final titleSource = text.isNotEmpty ? text : (fileNameToSend ?? 'Chat');
        final newTitle = titleSource.length > 25
            ? '${titleSource.substring(0, 22)}...'
            : titleSource;
        await ChatAiDbHelper.instance.updateSessionTitle(sessionId, newTitle);
        await loadSessions();
      }

      // Generate response
      _isGenerating = true;
      notifyListeners();

      if (isGenerativeAvailable) {
        final promptText = _buildPromptText();
        final response = await _prompt!.runInference(
          promptText,
          imageData: imageToSend,
        );
        await ChatAiDbHelper.instance.insertMessage(
          sessionId,
          'model',
          response.trim(),
        );
      } else {
        // Offline fallback (no on-device LLM). With an attached document we can
        // still give a real extractive answer; otherwise explain the situation.
        await Future.delayed(const Duration(seconds: 1));
        final String response;
        if (fileContentToSend != null) {
          final extractive = TextAnalysisHelper.answer(fileContentToSend, text);
          response = extractive.isNotEmpty
              ? extractive
              : 'No relevant passages found in the attached document "$fileNameToSend" for your question.';
        } else if (imageToSend != null) {
          response =
              'On-device image analysis (Gemini Nano) is only available on supported Android devices. Attach a text or PDF document to use offline text analysis on this platform.';
        } else if (!Platform.isAndroid) {
          response =
              'On-device AI is only available on supported Android devices. Attach a text or PDF document and ask about it to use offline text analysis instead.';
        } else {
          response =
              'The Gemini Nano model is not ready yet. Please ensure it is fully downloaded and available on your device.';
        }
        await ChatAiDbHelper.instance.insertMessage(
          sessionId,
          'model',
          response,
        );
      }
    } catch (e) {
      errorLog('[ChatAiState] Send message failed: $e');
      await ChatAiDbHelper.instance.insertMessage(
        sessionId,
        'model',
        'Error generating response: $e',
      );
    } finally {
      _messages = await ChatAiDbHelper.instance.getMessages(sessionId);
      _isGenerating = false;
      notifyListeners();
    }
  }

  String _buildPromptText() {
    final buffer = StringBuffer();
    buffer.writeln(activeSystemPrompt);
    buffer.writeln('Below is the history of the conversation so far.');
    buffer.writeln();

    // Use only the last 10 messages to avoid token limit issues
    final history = _messages.length > 10
        ? _messages.sublist(_messages.length - 10)
        : _messages;
    for (final msg in history) {
      buffer.write('${msg.isUser ? 'User' : 'Model'}: ');
      if (msg.hasAttachedFile) {
        final content = msg.fileContent!;
        final truncatedContent = content.length > 2500
            ? '${content.substring(0, 2500)}... [Truncated]'
            : content;
        buffer.writeln('[Attached File: ${msg.fileName}]');
        buffer.writeln(truncatedContent);
        buffer.writeln('-----');
      }
      buffer.writeln(msg.content);
    }
    buffer.writeln('Model:');
    return buffer.toString();
  }

  Future<void> clearCurrentSessionHistory() async {
    if (_currentSessionId == null) return;
    try {
      await ChatAiDbHelper.instance.clearSessionMessages(_currentSessionId!);
      _messages = [];
      notifyListeners();
    } catch (e) {
      errorLog('[ChatAiState] Clear session history failed: $e');
    }
  }

  @override
  void dispose() {
    _statusPollingTimer?.cancel();
    _prompt?.close();
    super.dispose();
  }
}
