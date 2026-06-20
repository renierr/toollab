import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
// ignore: implementation_imports
import 'package:google_mlkit_genai_prompt/src/prompt.dart';
import 'chat_ai_db_helper.dart';

class ChatAiState extends ChangeNotifier {
  List<Map<String, dynamic>> _sessions = [];
  int? _currentSessionId;
  List<Map<String, dynamic>> _messages = [];
  FeatureStatus _featureStatus = FeatureStatus.unavailable;
  bool _isInitializing = false;
  bool _isGenerating = false;
  Timer? _statusPollingTimer;
  Prompt? _prompt;

  List<Map<String, dynamic>> get sessions => _sessions;
  int? get currentSessionId => _currentSessionId;
  List<Map<String, dynamic>> get messages => _messages;
  FeatureStatus get featureStatus => _featureStatus;
  bool get isInitializing => _isInitializing;
  bool get isGenerating => _isGenerating;

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
        await updateFeatureStatus();

        if (_featureStatus == FeatureStatus.downloading) {
          _startStatusPolling();
        }
      } else {
        _featureStatus = FeatureStatus.unavailable;
      }
    } catch (e) {
      debugPrint('[ChatAiState] Initialization failed: $e');
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
        debugPrint('[ChatAiState] Check feature status failed: $e');
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
    try {
      await _prompt!.downloadFeature();
      await updateFeatureStatus();
      _startStatusPolling();
    } catch (e) {
      debugPrint('[ChatAiState] Model download trigger failed: $e');
    }
  }

  Future<void> loadSessions() async {
    try {
      _sessions = await ChatAiDbHelper.instance.getSessions();
      if (_sessions.isNotEmpty && _currentSessionId == null) {
        await selectSession(_sessions.first['id'] as int);
      } else if (_sessions.isEmpty) {
        _currentSessionId = null;
        _messages = [];
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[ChatAiState] Load sessions failed: $e');
    }
  }

  Future<void> selectSession(int sessionId) async {
    _currentSessionId = sessionId;
    try {
      _messages = await ChatAiDbHelper.instance.getMessages(sessionId);
    } catch (e) {
      debugPrint('[ChatAiState] Load messages failed: $e');
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
      debugPrint('[ChatAiState] Create session failed: $e');
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
      debugPrint('[ChatAiState] Delete session failed: $e');
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    if (_currentSessionId == null) {
      await createNewSession(
        initialTitle: text.length > 20 ? '${text.substring(0, 17)}...' : text,
      );
    }

    final sessionId = _currentSessionId!;
    try {
      // Save user message
      await ChatAiDbHelper.instance.insertMessage(sessionId, 'user', text);
      _messages = await ChatAiDbHelper.instance.getMessages(sessionId);
      notifyListeners();

      // Update session title if default
      final currentSession = _sessions.firstWhere((s) => s['id'] == sessionId);
      if (currentSession['title'].startsWith('Chat ')) {
        final newTitle = text.length > 25
            ? '${text.substring(0, 22)}...'
            : text;
        await ChatAiDbHelper.instance.updateSessionTitle(sessionId, newTitle);
        await loadSessions();
      }

      // Generate response
      _isGenerating = true;
      notifyListeners();

      if (Platform.isAndroid &&
          _featureStatus == FeatureStatus.available &&
          _prompt != null) {
        final promptText = _buildPromptText();
        final response = await _prompt!.runInference(promptText);
        await ChatAiDbHelper.instance.insertMessage(
          sessionId,
          'model',
          response.trim(),
        );
      } else {
        // Fallback for non-Android platforms or if model is not ready
        await Future.delayed(const Duration(seconds: 1));
        String response = 'This is a simulated AI response. ';
        if (!Platform.isAndroid) {
          response +=
              'On-device Gemini Nano is only supported on Android. For other platforms, please use a cloud model or simulate.';
        } else {
          response +=
              'Please ensure the Gemini Nano model is fully downloaded and available on your Android device.';
        }
        await ChatAiDbHelper.instance.insertMessage(
          sessionId,
          'model',
          response,
        );
      }
    } catch (e) {
      debugPrint('[ChatAiState] Send message failed: $e');
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
    buffer.writeln(
      'You are a helpful, respectful, and honest on-device AI assistant.',
    );
    buffer.writeln('Below is the history of the conversation so far.');
    buffer.writeln();

    // Use only the last 10 messages to avoid token limit issues
    final history = _messages.length > 10
        ? _messages.sublist(_messages.length - 10)
        : _messages;
    for (final msg in history) {
      final roleName = msg['role'] == 'user' ? 'User' : 'Model';
      buffer.writeln('$roleName: ${msg['content']}');
    }
    buffer.writeln('Model:');
    return buffer.toString();
  }

  @override
  void dispose() {
    _statusPollingTimer?.cancel();
    _prompt?.close();
    super.dispose();
  }
}
