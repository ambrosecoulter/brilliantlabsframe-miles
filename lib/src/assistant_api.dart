import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'strings.dart';
import 'ai_tool_functions.dart';
import 'package:deepgram_speech_to_text/deepgram_speech_to_text.dart';
import 'available_apps.dart';
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AssistantAPI {
  final String baseUrl = Strings.baseUrl;
  String? assistantId;
  String? threadId;
  String? runId;
  final dynamic appController;

  AssistantAPI(this.appController) {
    _initializeApiKey();
  }

  Future<void> _initializeApiKey() async {
    await Strings.loadApiKeys();
  }

  bool _isCancelled = false;

  void cancelOngoingRequests() {
    _isCancelled = true;
  }

  Future<void> createAssistant() async {
    var url = '$baseUrl/assistants';
    var headers = {
      'Content-Type': Strings.contentType,
      'Authorization': '${Strings.authorizationPrefix} ${await Strings.getOpenAIApiKey()}',
      'OpenAI-Beta': Strings.openAiBeta
    };
    
    // Get activated app tools
    List<Map<String, dynamic>> activatedAppTools = await AvailableApps.getActivatedAppTools();

    print('Activated app tools: $activatedAppTools');
    
    var body = jsonEncode({
      'model': 'gpt-4',
      'name': 'MilesFrameAi3',
      'instructions': Strings.assistantInstructions,
      'tools': [
        ...activatedAppTools,
      ],
    });
    var response = await http.post(Uri.parse(url), headers: headers, body: body);
    var responseBody = jsonDecode(response.body);
    assistantId = responseBody['id'];

    // Save the assistantId
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('assistantId', assistantId!);
  }

  Future<void> loadAssistantId() async {
    final prefs = await SharedPreferences.getInstance();
    assistantId = prefs.getString('assistantId');
  }

  Future<void> initialize() async {
    await loadAssistantId();
    if (assistantId == null) {
      await createAssistant();
    }
  }

  Future<void> createThread() async {
    var url = '$baseUrl/threads';
    var headers = {
      'Content-Type': Strings.contentType,
      'Authorization': '${Strings.authorizationPrefix} ${await Strings.getOpenAIApiKey()}',
      'OpenAI-Beta': Strings.openAiBeta
    };
    var response = await http.post(Uri.parse(url), headers: headers);
    var responseBody = jsonDecode(response.body);
    print(responseBody);
    threadId = responseBody['id'];
  }

  Future<Map<String, dynamic>> addMessage(String content, String role) async {
    var url = '$baseUrl/threads/$threadId/messages';
    var headers = {
      'Content-Type': Strings.contentType,
      'Authorization': '${Strings.authorizationPrefix} ${await Strings.getOpenAIApiKey()}',
      'OpenAI-Beta': Strings.openAiBeta
    };

    String updatedContent = content;

    if (role == 'user') {
      // Get current location and time only for user messages
      String location = await _getCurrentAddress();
      String currentTime = DateTime.now().toLocal().toString();

      // Append location and time to the message content
      updatedContent = '$content\n\nUsers current location: $location\nUsers current time: $currentTime';
    }

    var body = jsonEncode({
      'role': role,
      'content': updatedContent,
    });
    var response = await http.post(Uri.parse(url), headers: headers, body: body);
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> runThread() async {
    // Implementation for running a thread
    var url = '$baseUrl/threads/$threadId/runs';
    var headers = {
      'Content-Type': Strings.contentType,
      'Authorization': '${Strings.authorizationPrefix} ${await Strings.getOpenAIApiKey()}',
      'OpenAI-Beta': Strings.openAiBeta
    };
    var body = jsonEncode({
      'assistant_id': assistantId,
    });
    var response = await http.post(Uri.parse(url), headers: headers, body: body);
    var responseBody = jsonDecode(response.body);
    runId = responseBody['id'];
    return responseBody;
  }

  Future<Map<String, dynamic>> getRunStatus(String? runId) async {
    if (runId == null) {
      throw Exception('runId is null');
    }
    var url = '$baseUrl/threads/$threadId/runs/$runId';
    var headers = {
      'Content-Type': Strings.contentType,
      'Authorization': '${Strings.authorizationPrefix} ${await Strings.getOpenAIApiKey()}',
      'OpenAI-Beta': Strings.openAiBeta
    };
    
    print('Fetching run status...');
    print('URL: $url');
    print('Headers: $headers');
    
    var response = await http.get(Uri.parse(url), headers: headers);
    
    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');
    
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> submitToolOutputs(List<Map<String, dynamic>> toolOutputs) async {
    // Implementation for submitting tool outputs
    var url = '$baseUrl/threads/$threadId/runs/$runId/submit_tool_outputs';
    var headers = {
      'Content-Type': Strings.contentType,
      'Authorization': '${Strings.authorizationPrefix} ${await Strings.getOpenAIApiKey()}',
      'OpenAI-Beta': Strings.openAiBeta,
    };
    var body = jsonEncode({
      'tool_outputs': toolOutputs,
    });
    var response = await http.post(Uri.parse(url), headers: headers, body: body);
    return jsonDecode(response.body);
  }

  Future<List<Map<String, dynamic>>> listMessages() async {
    var url = '$baseUrl/threads/$threadId/messages';
    var headers = {
      'Content-Type': Strings.contentType,
      'Authorization': '${Strings.authorizationPrefix} ${await Strings.getOpenAIApiKey()}',
      'OpenAI-Beta': Strings.openAiBeta,
    };
    var response = await http.get(Uri.parse(url), headers: headers);
    var decodedResponse = jsonDecode(response.body);
    
    if (decodedResponse is Map && decodedResponse.containsKey('data')) {
      List<dynamic> data = decodedResponse['data'];
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Unexpected response format from listMessages');
    }
  }

  Future<Map<String, dynamic>> processUserQuery(Uint8List audioData) async {
    _isCancelled = false;
    
    if (assistantId == null || threadId == null) {
      throw Exception('Assistant or thread not initialized. Please ensure initialization is complete before processing queries.');
    }
    
    // Ensure assistant and thread are initialized
    if (assistantId == null) {
      await createAssistant();
    }
    if (threadId == null) {
      await createThread();
    }
    // Check again after initialization attempts
    if (assistantId == null || threadId == null) {
      throw Exception(Strings.assistantThreadNotInitialized);
    }

    // Transcribe the audio
    String transcription = await transcribeAudio(audioData);

    // Add transcribed message to the thread
    await addMessage(transcription, 'user');

    // Run the thread
    var run = await runThread();
    String? runId = run['id'];

    if (runId == null) {
      throw Exception('Failed to get runId');
    }

    while (true) {
      // Add null check here
      if (runId == null) {
        throw Exception('runId became null during processing');
      }

      var runStatus = await getRunStatus(runId);
      String? status = runStatus['status'];

      if (status == null) {
        throw Exception('Failed to get run status');
      }

      if (status == 'completed') {
        // Get the latest message as the assistant's response
        var messages = await listMessages();
        var assistantResponse = messages.first['content'][0]['text']['value'];
        
        if (assistantResponse == null) {
          throw Exception('Failed to get assistant response');
        }

        // Add the assistant's response to the thread
        await addMessage(assistantResponse, 'assistant');

        return {
          'status': 'completed',
          'response': assistantResponse,
          'prompt': transcription,
        };
      } else if (status == 'requires_action') {
        var requiredAction = runStatus['required_action'];
        if (requiredAction['type'] == 'submit_tool_outputs') {
          var toolCalls = requiredAction['submit_tool_outputs']['tool_calls'];
          List<Map<String, dynamic>> toolOutputs = [];
          
          for (var toolCall in toolCalls) {
            String output = await callFunction(
              toolCall['function']['name'],
              json.decode(toolCall['function']['arguments'])
            );
            toolOutputs.add({
              'tool_call_id': toolCall['id'],
              'output': output,
            });
          }

          // Submit tool outputs
          run = await submitToolOutputs(toolOutputs);
          runId = run['id'];
        }
      } else if (status == 'failed') {
        return {
          'status': 'failed',
          'error': runStatus['last_error'] ?? 'Unknown error'
        };
      } else {
        // Wait for a short time before polling again
        await Future.delayed(Duration(seconds: 1));
      }

      if (_isCancelled) {
        return {'status': 'cancelled', 'response': ''};
      }
    }
  }

  Future<String> callFunction(String functionName, Map<String, dynamic> arguments) async {
    // Get the app configuration
    Map<String, String> appConfig = await AvailableApps.getAppConfig(functionName);

    // Check if the function exists in the AvailableApps tools
    if (AvailableApps.tools.containsKey(functionName)) {
      var tool = AvailableApps.tools[functionName]!;
      
      // Call the function with the appController, arguments, and app configuration
      var result = await tool.function(appController, arguments, appConfig);
      
      // Convert the result to a string if it's not already
      return result is String ? result : json.encode(result);
    }

    // If the function is not found, throw an exception
    throw Exception('Unknown function: $functionName');
  }

  Future<String> transcribeAudio(Uint8List audioData) async {
    print('Transcribing audio using OpenAI Whisper');
    
    var url = 'https://api.openai.com/v1/audio/transcriptions';
    var request = http.MultipartRequest('POST', Uri.parse(url));
    
    request.headers.addAll({
      'Authorization': 'Bearer ${await Strings.getOpenAIApiKey()}',
    });
    
    request.fields['model'] = 'whisper-1';
    
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      audioData,
      filename: 'audio.mp3',
      contentType: MediaType('audio', 'mpeg'),
    ));

    try {
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        return jsonResponse['text'];
      } else {
        throw Exception('Failed to transcribe audio: ${response.body}');
      }
    } catch (e) {
      print('Error transcribing audio with OpenAI Whisper: $e');
      throw Exception('${Strings.audioTranscriptionFailed} $e');
    }
  }

  Future<String> _getCurrentAddress() async {
    try {
      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return Strings.locationPermissionsDenied;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        return Strings.locationPermissionsPermanentlyDenied;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );

      // Use reverse geocoding to get address
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return '${place.street}, ${place.locality}, ${place.postalCode}, ${place.country}';
      } else {
        return '${position.latitude}, ${position.longitude}';
      }
    } catch (e) {
      print('Error getting location: $e');
      return Strings.unableToGetLocation;
    }
  }

  Future<void> updateAssistant({required String instructions}) async {
    if (assistantId == null) {
      await createAssistant();
    } else {
      print('assistantId: $assistantId');
      var url = '$baseUrl/assistants/$assistantId';
      var headers = {
        'Content-Type': Strings.contentType,
        'Authorization': '${Strings.authorizationPrefix} ${await Strings.getOpenAIApiKey()}',
        'OpenAI-Beta': Strings.openAiBeta
      };
      
      // Get activated app tools
      List<Map<String, dynamic>> activatedAppTools = await AvailableApps.getActivatedAppTools();
      
      var body = jsonEncode({
        'instructions': instructions,
        'tools': [
          ...activatedAppTools,
        ],
      });

      var response = await http.post(Uri.parse(url), headers: headers, body: body);
      
      if (response.statusCode != 200) {
        throw Exception('Failed to update assistant: ${response.body}');
      }
    }
  }

  void updateApiKey(String newApiKey) async {
    await Strings.saveOpenAIApiKey(newApiKey);
  }
}