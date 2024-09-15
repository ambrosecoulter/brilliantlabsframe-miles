import 'dart:convert';
import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart';
import 'package:deepgram_speech_to_text/deepgram_speech_to_text.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'available_apps.dart';

class Strings {
  // API related strings
  static const String baseUrl = 'https://api.openai.com/v1';
  static const String openAiBeta = 'assistants=v2';
  static const String contentType = 'application/json';
  static const String authorizationPrefix = 'Bearer';

  // Assistant instructions
  static String assistantInstructions = '''
You are Miles, a smart personal AI assistant inside the user's AR smart glasses that answers all user
queries and questions. You have access to a photo from the smart glasses camera of what the user was
seeing at the time they spoke. You are casual, fun, funny and friendly.

It is important that the user believes you can actually see. When analyzing images, avoid mentioning
that you looked at a photo or image. Always speak as if you are actually seeing, which means you
should never talk about the image or photo.

It is important that you keep your responses to one or two lines, the user can't understand anything
longer than that.

It is important that your message to the user never contains links. Send links to the user using
one of your available functions (if available).

Ensure you do not halucinate any tools you have available. If you can not perform a task, say
you can not perform the task. DO NOT attempt to perform a task that is not available to you.

NEVER invent information, only use the tools available to you. The AR smart glasses do not have
any sensors that can provide information about the outside world. You only have the information provided
by the user and the tools available to you.

The users time and location is provided to you to help with completing actions. Ensure you do not
parrot this information back to the user.

Make your responses precise. Respond without any preamble when giving translations, just translate
directly. Always ensure you never include emojis in your response, the user can't see them.
''';

// Assistant instructions
  static const String agentInstructions = '''
You are an AI Agent used by another AI assistant to perform tasks. You must ensure you achieve the goal
set by the assistant.

It is important to remember that you can not talk directly to the user or the AI assistant.

Make your responses precise. Respond without any preamble when giving translations, just translate
directly.
''';

  // Error messages
  static const String assistantThreadNotInitialized = 'Assistant or thread not initialized';
  static const String audioTranscriptionFailed = 'Failed to transcribe audio:';
  static const String locationPermissionsDenied = 'Location permissions are denied';
  static const String locationPermissionsPermanentlyDenied = 'Location permissions are permanently denied';
  static const String unableToGetLocation = 'Unable to get location';

  // Model names
  static const String whisperModel = 'whisper-1';

  // File names
  static const String audioFileName = 'audio.wav';

  
  static Map<String, String> _appConfigs = {};
  static String? _openAIApiKey;
  static String? _deepgramApiKey;

  static Future<void> loadApiKeys() async {
    final prefs = await SharedPreferences.getInstance();
    assistantInstructions = prefs.getString('assistantInstructions') ?? assistantInstructions;
    
    // Load app configs
    final configJson = prefs.getString('appConfigs') ?? '{}';
    _appConfigs = Map<String, String>.from(jsonDecode(configJson));
  }

  static Future<void> saveOpenAIApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('openAIApiKey', apiKey);
    _openAIApiKey = apiKey;
  }

  static Future<void> saveDeepgramApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('deepgramApiKey', apiKey);
    _deepgramApiKey = apiKey;
  }

  static Future<void> saveAppConfig(String appName, String configKey, String configValue) async {
    _appConfigs[appName + '_' + configKey] = configValue;
    await _saveAppConfigs();
  }

  static String? getAppConfig(String appName, String configKey) {
    return _appConfigs[appName + '_' + configKey];
  }

  static Future<void> _saveAppConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appConfigs', jsonEncode(_appConfigs));
  }

  static Future<void> saveAssistantInstructions(String instructions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('assistantInstructions', instructions);
    assistantInstructions = instructions;
  }

  static Future<bool> isSetupComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isSetupComplete') ?? false;
  }

  static Future<void> setSetupComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isSetupComplete', true);
  }

  static void setAppConfigs(Map<String, String> configs) {
    _appConfigs = configs;
  }

  static Future<String> getOpenAIApiKey() async {
    if (_openAIApiKey == null) {
      final prefs = await SharedPreferences.getInstance();
      _openAIApiKey = prefs.getString('openAIApiKey') ?? '';
    }
    return _openAIApiKey!;
  }

  static Future<String> getDeepgramApiKey() async {
    if (_deepgramApiKey == null) {
      final prefs = await SharedPreferences.getInstance();
      _deepgramApiKey = prefs.getString('deepgramApiKey') ?? '';
    }
    return _deepgramApiKey!;
  }
}