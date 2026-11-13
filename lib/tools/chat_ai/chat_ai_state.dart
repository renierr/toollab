import 'dart:async';
import 'package:tool_lab/helpers/debug_log.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_mlkit_genai_prompt/google_mlkit_genai_prompt.dart';
import 'package:tool_lab/helpers/text_analysis_helper.dart';
import 'package:tool_lab/services/database_service.dart';
import 'chat_ai_db_helper.dart';
import 'chat_models.dart';
import 'config.dart';
import 'deepseek/deepseek_account.dart';
import 'deepseek/deepseek_api.dart';
import 'deepseek/deepseek_stream.dart';

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
  String _streamingText = '';
  String _streamingThinking = '';
  int? _downloadTotalBytes;
  int _downloadedBytes = 0;

  static const String defaultSystemPrompt =
      'You are a helpful, respectful, and honest on-device AI assistant. Respond in the same language as the user (e.g. if the user writes in German, respond in German; if the user writes in English, respond in English).';

  String? _customSystemPrompt;

  String get customSystemPrompt => _customSystemPrompt ?? '';

  String get activeSystemPrompt => _customSystemPrompt ?? defaultSystemPrompt;
  String? _attachedFileName;
  String? _attachedFileContent;
  String? _modelError;

  ChatBackend _backend = ChatBackend.nano;
  DeepSeekAccount? _deepSeekAccount;
  bool _deepSeekThinking = false;
  bool _deepSeekSearch = false;
  DeepSeekErrorKind? _deepSeekError;
  String? _deepSeekErrorDetail;

  static const String _backendKey = 'backend';
  static const String _deepSeekThinkingKey = 'deepseek_thinking';
  static const String _deepSeekSearchKey = 'deepseek_search';

  ChatBackend get backend => _backend;
  DeepSeekAccount? get deepSeekAccount => _deepSeekAccount;
  bool get deepSeekThinking => _deepSeekThinking;
  bool get deepSeekSearch => _deepSeekSearch;
  DeepSeekErrorKind? get deepSeekError => _deepSeekError;
  String? get deepSeekErrorDetail => _deepSeekErrorDetail;

  /// The DeepSeek backend is picked but nobody is signed in.
  bool get needsDeepSeekLogin =>
      _backend == ChatBackend.deepseek && _deepSeekAccount == null;

  /// Thoughts of a thinking model while [isGenerating].
  String get streamingThinking => _streamingThinking;

  List<ChatSession> get sessions => _sessions;

  /// The history of the active backend, for the session drawer.
  List<ChatSession> get backendSessions =>
      _sessions.where((s) => s.backend == _backend).toList();

  bool _syncingHistory = false;
  bool get syncingHistory => _syncingHistory;
  int? get currentSessionId => _currentSessionId;
  List<ChatMessage> get messages => _messages;
  FeatureStatus get featureStatus => _featureStatus;
  bool get isInitializing => _isInitializing;
  bool get isGenerating => _isGenerating;

  /// Partial model reply while [isGenerating]; empty until the first chunk.
  String get streamingText => _streamingText;

  /// Model download progress in 0..1, or null when the size is unknown.
  double? get downloadProgress {
    final total = _downloadTotalBytes;
    if (total == null || total <= 0) return null;
    return (_downloadedBytes / total).clamp(0.0, 1.0);
  }

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

  void clearDeepSeekError() {
    _deepSeekError = null;
    _deepSeekErrorDetail = null;
  }

  /// Switches who answers; a session of the other backend is closed.
  Future<void> setBackend(ChatBackend backend) async {
    if (_backend == backend) return;
    _backend = backend;
    _currentSessionId = null;
    _messages = [];
    await loadSessions();
    if (backend == ChatBackend.deepseek) _selectedImageBytes = null;
    notifyListeners();
    await DatabaseService.instance.setSetting(
      ChatAiTool.config.id,
      _backendKey,
      backend.name,
    );
    if (backend == ChatBackend.deepseek) await refreshDeepSeekHistory();
  }

  /// Pulls the account's conversations, including those from the website.
  Future<void> refreshDeepSeekHistory() async {
    final account = _deepSeekAccount;
    if (account == null || _syncingHistory) return;
    _syncingHistory = true;
    notifyListeners();
    try {
      const pageSize = 100;
      final remote = await DeepSeekApi(
        account.token,
        locale: _locale,
      ).fetchSessions(count: pageSize);
      await ChatAiDbHelper.instance.syncRemoteSessions([
        for (final session in remote)
          (id: session.id, title: session.title, updatedAt: session.updatedAt),
      ], complete: remote.length < pageSize);
      final current = _currentSession;
      await loadSessions();
      if (current != null && _currentSession == null) {
        _currentSessionId = null;
        _messages = [];
      }
    } on DeepSeekException catch (e) {
      _onDeepSeekError(e);
    } finally {
      _syncingHistory = false;
      notifyListeners();
    }
  }

  Future<void> _loadDeepSeekMessages(ChatSession session) async {
    final account = _deepSeekAccount;
    final remoteId = session.remoteId;
    if (account == null || remoteId == null) return;
    try {
      final history = await DeepSeekApi(
        account.token,
        locale: _locale,
      ).history(remoteId);
      if (_isGenerating) return;
      // A reply can carry an earlier timestamp than its question, and the
      // messages are listed by time.
      var lastTime = 0;
      await ChatAiDbHelper.instance.replaceMessages(session.id, [
        for (final message in history.messages)
          (
            role: message.fromUser ? 'user' : 'model',
            content: message.text.trim(),
            thinking: message.thinking.trim().isEmpty
                ? null
                : message.thinking.trim(),
            createdAt: lastTime = message.insertedAt > lastTime
                ? message.insertedAt
                : lastTime + 1,
          ),
      ], remoteParentId: history.currentMessageId);
      _sessions = await ChatAiDbHelper.instance.getSessions();
      if (_currentSessionId == session.id && !_isGenerating) {
        _messages = await ChatAiDbHelper.instance.getMessages(session.id);
        notifyListeners();
      }
    } on DeepSeekException catch (e) {
      _onDeepSeekError(e);
      notifyListeners();
    }
  }

  void _onDeepSeekError(DeepSeekException e) {
    errorLog('[ChatAiState] DeepSeek request failed: $e');
    _deepSeekError = e.kind;
    _deepSeekErrorDetail = e.message;
    if (e.kind == DeepSeekErrorKind.unauthorized) {
      _deepSeekAccount = null;
      unawaited(DeepSeekAccount.clear());
    }
  }

  Future<void> setDeepSeekThinking(bool enabled) async {
    _deepSeekThinking = enabled;
    notifyListeners();
    await DatabaseService.instance.setSetting(
      ChatAiTool.config.id,
      _deepSeekThinkingKey,
      '$enabled',
    );
  }

  Future<void> setDeepSeekSearch(bool enabled) async {
    _deepSeekSearch = enabled;
    notifyListeners();
    await DatabaseService.instance.setSetting(
      ChatAiTool.config.id,
      _deepSeekSearchKey,
      '$enabled',
    );
  }

  /// Checks [token] against the account and keeps it; throws
  /// [DeepSeekException] when DeepSeek rejects it.
  Future<void> signInDeepSeek(String token, {String locale = 'en'}) async {
    final name = await DeepSeekApi(token, locale: locale).currentUser();
    final account = DeepSeekAccount(token: token, name: name);
    await account.save();
    _deepSeekAccount = account;
    notifyListeners();
    await refreshDeepSeekHistory();
  }

  Future<void> signOutDeepSeek() async {
    await DeepSeekAccount.clear();
    _deepSeekAccount = null;
    notifyListeners();
  }

  ChatSession? get _currentSession =>
      _sessions.where((s) => s.id == _currentSessionId).firstOrNull;

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
      final response = await _prompt!.runInference(
        promptText,
        systemInstruction: activeSystemPrompt,
      );
      return response.trim();
    }

    // Offline fallback (no on-device LLM): extractive passage answer.
    final extractive = TextAnalysisHelper.answer(documentText, question);
    return extractive.isNotEmpty
        ? extractive
        : 'No relevant passages found for your question in the extracted text.';
  }

  /// Streams the model's output for a one-shot text task, without chat history.
  Stream<String> streamTextTask({
    required String instruction,
    required String text,
  }) {
    if (!isGenerativeAvailable) {
      return Stream.error(StateError('Gemini Nano is not available'));
    }
    return _prompt!.runInferenceStreaming(
      '$instruction Reply only with the result, without any preamble.\n\n'
      '----- TEXT START -----\n$text\n----- TEXT END -----',
    );
  }

  /// Streams a one-shot description of [imageData], without chat history.
  Stream<String> streamImageTask({
    required String instruction,
    required Uint8List imageData,
  }) {
    if (!isGenerativeAvailable) {
      return Stream.error(StateError('Gemini Nano is not available'));
    }
    return _prompt!.runInferenceStreaming(instruction, imageData: imageData);
  }

  ChatAiState() {
    init();
  }

  Future<void> init() async {
    _isInitializing = true;
    notifyListeners();

    try {
      final db = DatabaseService.instance;
      final id = ChatAiTool.config.id;
      _backend = ChatBackend.fromName(await db.getSetting(id, _backendKey));
      _deepSeekThinking =
          await db.getSetting(id, _deepSeekThinkingKey) == 'true';
      _deepSeekSearch = await db.getSetting(id, _deepSeekSearchKey) == 'true';
      _customSystemPrompt = await db.getSetting(id, 'system_prompt');
      _deepSeekAccount = await DeepSeekAccount.read();
      await loadSessions();
      if (_backend == ChatBackend.deepseek) {
        unawaited(refreshDeepSeekHistory());
      }

      if (Platform.isAndroid) {
        _prompt = Prompt();
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
    _downloadTotalBytes = null;
    _downloadedBytes = 0;
    try {
      await _prompt!.downloadFeature(
        onDownloadStarted: (total) {
          _downloadTotalBytes = total;
          _featureStatus = FeatureStatus.downloading;
          notifyListeners();
        },
        onDownloadProgress: (downloaded) {
          _downloadedBytes = downloaded;
          notifyListeners();
        },
      );
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
      if (_currentSession == null) {
        final last = await _lastSessionId(_backend);
        final own = backendSessions;
        final resume =
            own.where((s) => s.id == last).firstOrNull ?? own.firstOrNull;
        if (resume != null) {
          await selectSession(resume.id);
        } else {
          _currentSessionId = null;
          _messages = [];
        }
      }
      notifyListeners();
    } catch (e) {
      errorLog('[ChatAiState] Load sessions failed: $e');
    }
  }

  static String _lastSessionKey(ChatBackend backend) =>
      'last_session_${backend.name}';

  Future<int?> _lastSessionId(ChatBackend backend) async => int.tryParse(
    await DatabaseService.instance.getSetting(
          ChatAiTool.config.id,
          _lastSessionKey(backend),
        ) ??
        '',
  );

  Future<void> selectSession(int sessionId) async {
    _currentSessionId = sessionId;
    final session = _currentSession;
    if (session != null) {
      unawaited(
        DatabaseService.instance.setSetting(
          ChatAiTool.config.id,
          _lastSessionKey(session.backend),
          '$sessionId',
        ),
      );
    }
    if (session != null && session.backend != _backend) {
      _backend = session.backend;
      unawaited(
        DatabaseService.instance.setSetting(
          ChatAiTool.config.id,
          _backendKey,
          _backend.name,
        ),
      );
    }
    try {
      _messages = await ChatAiDbHelper.instance.getMessages(sessionId);
    } catch (e) {
      errorLog('[ChatAiState] Load messages failed: $e');
      _messages = [];
    }
    notifyListeners();
    if (session != null && session.backend == ChatBackend.deepseek) {
      await _loadDeepSeekMessages(session);
    }
  }

  Future<void> createNewSession({String? initialTitle}) async {
    try {
      final title =
          initialTitle ??
          'Chat ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}';
      final newId = await ChatAiDbHelper.instance.createSession(
        title,
        backend: _backend,
      );
      await loadSessions();
      await selectSession(newId);
    } catch (e) {
      errorLog('[ChatAiState] Create session failed: $e');
    }
  }

  Future<void> deleteSession(int sessionId) async {
    final session = _sessions.where((s) => s.id == sessionId).firstOrNull;
    final remoteId = session?.remoteId;
    final account = _deepSeekAccount;
    if (remoteId != null && account != null) {
      try {
        await DeepSeekApi(
          account.token,
          locale: _locale,
        ).deleteSession(remoteId);
      } on DeepSeekException catch (e) {
        _onDeepSeekError(e);
        notifyListeners();
        return;
      }
    }
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

      if (_backend == ChatBackend.deepseek) {
        await _replyWithDeepSeek(
          sessionId,
          text,
          fileNameToSend,
          fileContentToSend,
        );
      } else if (isGenerativeAvailable) {
        final buffer = StringBuffer();
        await for (final chunk in _prompt!.runInferenceStreaming(
          _buildPromptText(),
          systemInstruction: activeSystemPrompt,
          imageData: imageToSend,
        )) {
          buffer.write(chunk);
          _streamingText = buffer.toString();
          notifyListeners();
        }
        await ChatAiDbHelper.instance.insertMessage(
          sessionId,
          'model',
          buffer.toString().trim(),
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
      _streamingText = '';
      _streamingThinking = '';
      notifyListeners();
    }
  }

  Future<void> _replyWithDeepSeek(
    int sessionId,
    String text,
    String? fileName,
    String? fileContent,
  ) async {
    final account = _deepSeekAccount;
    if (account == null) {
      _deepSeekError = DeepSeekErrorKind.unauthorized;
      return;
    }
    final api = DeepSeekApi(account.token, locale: _locale);
    final session = _currentSession;
    try {
      var remoteId = session?.remoteId;
      var parentId = session?.remoteParentId;
      final firstMessage = remoteId == null;
      if (remoteId == null) {
        remoteId = await api.createSession();
        parentId = null;
      }
      final prompt = StringBuffer();
      final custom = _customSystemPrompt;
      if (firstMessage && custom != null) prompt.writeln('$custom\n');
      if (fileName != null && fileContent != null) {
        prompt
          ..writeln('[Attached File: $fileName]')
          ..writeln(fileContent)
          ..writeln('-----');
      }
      prompt.write(text);

      var reply = const DeepSeekReply();
      await for (final update in api.complete(
        sessionId: remoteId,
        parentMessageId: parentId,
        prompt: prompt.toString(),
        thinking: _deepSeekThinking,
        search: _deepSeekSearch,
      )) {
        reply = update;
        _streamingThinking = update.thinking;
        _streamingText = update.text;
        notifyListeners();
      }
      if (reply.text.trim().isEmpty && reply.notice != null) {
        throw DeepSeekException(DeepSeekErrorKind.server, reply.notice);
      }
      await ChatAiDbHelper.instance.insertMessage(
        sessionId,
        'model',
        reply.text.trim(),
        thinking: reply.thinking.trim().isEmpty ? null : reply.thinking.trim(),
      );
      await ChatAiDbHelper.instance.updateRemote(
        sessionId,
        remoteId: remoteId,
        parentId: reply.responseMessageId ?? parentId,
      );
      final title = reply.title;
      if (title != null && title.isNotEmpty) {
        await ChatAiDbHelper.instance.updateSessionTitle(sessionId, title);
      }
      await loadSessions();
    } on DeepSeekException catch (e) {
      _onDeepSeekError(e);
    }
  }

  String get _locale => Platform.localeName.split(RegExp('[_-]')).first;

  String _buildPromptText() {
    final buffer = StringBuffer();
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
