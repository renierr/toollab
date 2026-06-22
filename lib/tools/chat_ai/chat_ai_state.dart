import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
// ignore: implementation_imports
import 'package:google_mlkit_genai_prompt/src/prompt.dart';
import 'package:tool_lab/services/database_service.dart';
import 'chat_ai_db_helper.dart';
import 'config.dart';

class ChatAiState extends ChangeNotifier {
  List<Map<String, dynamic>> _sessions = [];
  int? _currentSessionId;
  List<Map<String, dynamic>> _messages = [];
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

  List<Map<String, dynamic>> get sessions => _sessions;
  int? get currentSessionId => _currentSessionId;
  List<Map<String, dynamic>> get messages => _messages;
  FeatureStatus get featureStatus => _featureStatus;
  bool get isInitializing => _isInitializing;
  bool get isGenerating => _isGenerating;
  Uint8List? get selectedImageBytes => _selectedImageBytes;
  String? get attachedFileName => _attachedFileName;
  String? get attachedFileContent => _attachedFileContent;
  String? get modelError => _modelError;

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
      debugPrint('[ChatAiState] Model download trigger failed: $e');
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
      final currentSession = _sessions.firstWhere((s) => s['id'] == sessionId);
      if (currentSession['title'].startsWith('Chat ')) {
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

      if (Platform.isAndroid &&
          _featureStatus == FeatureStatus.available &&
          _prompt != null) {
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
        // Fallback for non-Android platforms or if model is not ready
        await Future.delayed(const Duration(seconds: 1));
        String response = 'This is a simulated AI response. ';
        if (imageToSend != null) {
          response +=
              '\n\n[Simulated Image Analysis]: The model detected a multimodal input image (bytes size: ${imageToSend.length}). On supported Android devices, this image is processed locally on-device by Gemini Nano.';
        } else if (fileNameToSend != null) {
          response +=
              '\n\n[Simulated Document Analysis]: The model detected an attached file "$fileNameToSend". On supported Android devices, the file content is processed locally along with your prompt.';
        } else if (!Platform.isAndroid) {
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
    buffer.writeln(activeSystemPrompt);
    buffer.writeln('Below is the history of the conversation so far.');
    buffer.writeln();

    // Use only the last 10 messages to avoid token limit issues
    final history = _messages.length > 10
        ? _messages.sublist(_messages.length - 10)
        : _messages;
    for (final msg in history) {
      final roleName = msg['role'] == 'user' ? 'User' : 'Model';
      buffer.write('$roleName: ');
      if (msg['file_name'] != null && msg['file_content'] != null) {
        final content = msg['file_content'] as String;
        final truncatedContent = content.length > 2500
            ? '${content.substring(0, 2500)}... [Truncated]'
            : content;
        buffer.writeln('[Attached File: ${msg['file_name']}]');
        buffer.writeln(truncatedContent);
        buffer.writeln('-----');
      }
      buffer.writeln(msg['content']);
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
      debugPrint('[ChatAiState] Clear session history failed: $e');
    }
  }

  @override
  void dispose() {
    _statusPollingTimer?.cancel();
    _prompt?.close();
    super.dispose();
  }
}
