import 'dart:convert';
import 'package:http/http.dart' as http;
import 'strings.dart';
import 'app_controller.dart';
import 'assistant_api.dart';
import 'available_apps.dart';

class AIToolFunctions {
  static Future<String> perplexitySearch(String query, AppController appController, String? apiKey) async {
    if (apiKey == null) {
      throw Exception('Perplexity API key is not set');
    }
    await appController.displayText('Searching...');
    final url = Uri.parse('https://api.perplexity.ai/chat/completions');
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };
    final body = jsonEncode({
      'model': 'llama-3.1-sonar-huge-128k-online',
      'messages': [
        {'role': 'user', 'content': query}
      ],
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return jsonResponse['choices'][0]['message']['content'];
      } else {
        throw Exception('Failed to get response from Perplexity API');
      }
    } catch (e) {
      print('Error in perplexitySearch: $e');
      return 'Error occurred while searching';
    }
  }

  static Future<Map<String, dynamic>> getWeather(String location, AppController appController, String apiKey) async {
    if (apiKey.isEmpty) {
      throw Exception('Weather API key is not set');
    }
    await appController.displayText('Getting weather...');
    final url = Uri.parse('https://api.weatherapi.com/v1/current.json?key=$apiKey&q=$location&aqi=no');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get weather data');
      }
    } catch (e) {
      print('Error in getWeather: $e');
      return {'error': 'Failed to get weather data'};
    }
  }

  static Future<String> getCurrentEnergyPrice(AppController appController, String? apiKey, String? siteId) async {
    if (apiKey == null || siteId == null) {
      throw Exception('Amber API key or site ID is not set');
    }
    await appController.displayText('Getting energy price...');
    final url = Uri.parse('https://api.amber.com.au/v1/sites/$siteId/prices/current?resolution=30');
    final headers = {
      'accept': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };
    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        for (var interval in data) {
          double cost = interval['perKwh'] ?? 0;
          if (cost >= 100) {
            return '\$${(cost / 100).toStringAsFixed(2)}';
          } else {
            return '${cost.toStringAsFixed(2)}c';
          }
        }
        return 'No price data available';
      } else {
        throw Exception('Failed to get energy price');
      }
    } catch (e) {
      print('Error in getCurrentEnergyPrice: $e');
      return 'Error occurred while getting energy price';
    }
  }

  static Future<Map<String, dynamic>> sendPushoverNotification(String message, String title, String? url, AppController appController, String? token, String? user) async {
    if (token == null || user == null) {
      throw Exception('Pushover token or user is not set');
    }
    await appController.displayText('Sending notification...');
    final apiUrl = Uri.parse('https://api.pushover.net/1/messages.json');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'token': token,
      'user': user,
      'message': message,
      'title': title,
      if (url != null) 'url': url,
    });

    try {
      final response = await http.post(apiUrl, headers: headers, body: body);
      if (response.statusCode == 200) {
        return {'success': 'Notification sent successfully'};
      } else {
        throw Exception('Failed to send Pushover notification');
      }
    } catch (e) {
      print('Error in sendPushoverNotification: $e');
      return {'error': 'Failed to send notification'};
    }
  }

  static Future<Map<String, dynamic>> serpapiSearch(String query, String searchType, AppController appController, String? apiKey) async {
    if (apiKey == null) {
      throw Exception('Serpapi API key is not set');
    }
    await appController.displayText('Searching...');
    final url = Uri.parse('https://google.serper.dev/$searchType');
    final headers = {
      'X-API-KEY': apiKey,
      'Content-Type': 'application/json',
    };
    final body = jsonEncode({
      'q': query,
      'gl': 'au',
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (searchType == 'search') {
          if (data.containsKey('answerBox')) {
            final answerBox = data['answerBox'];
            return {
              'title': answerBox['title'] ?? '',
              'answer': answerBox['answer'] ?? '',
              'source': answerBox['source'] ?? '',
              'sourceLink': answerBox['sourceLink'] ?? '',
            };
          } else if (data.containsKey('organic')) {
            return {
              'organic': (data['organic'] as List).take(3).map((result) => {
                'title': result['title'] ?? '',
                'link': result['link'] ?? '',
                'snippet': result['snippet'] ?? '',
              }).toList(),
            };
          }
        } else if (searchType == 'shopping' && data.containsKey('shopping')) {
          return {
            'shopping': (data['shopping'] as List).take(3).map((result) => {
              'title': result['title'] ?? '',
              'source': result['source'] ?? '',
              'link': result['link'] ?? '',
              'price': result['price'] ?? '',
            }).toList(),
          };
        }
        return {'error': 'No relevant results found'};
      } else {
        throw Exception('API request failed');
      }
    } catch (e) {
      print('Error in serpapiSearch: $e');
      return {'error': 'Error occurred while searching'};
    }
  }

  static Future<String> createNote(String title, {String? content, required AppController appController}) async {
    try {
      // Create a new note with the given title and content
      Note newNote = Note(title: title, content: content ?? '');
      await appController.startNewNote(newNote);

      return "Note created successfully with title: $title";
    } catch (e) {
      print("Error creating note: $e");
      return "Failed to create note: $e";
    }
  }

  static Future<String> handleNotes(Map<String, dynamic> params, AppController appController) async {
    String action = params['action'];
    switch (action) {
      case 'get_notes':
        return await getNotes(appController: appController);
      case 'add_note':
        return await createNote(params['note_content'], appController: appController);
      case 'update_note':
        return await updateNote(params['note_id'], content: params['note_content'], appController: appController);
      case 'get_individual_note':
        return await getIndividualNote(id: params['note_id'], appController: appController);
      case 'delete_note':
        return await deleteIndividualNote(id: params['note_id'], appController: appController);
      default:
        return 'Invalid action for notes tool';
    }
  }

  static Future<String> getNotes({required AppController appController}) async {
    try {
      List<Map<String, dynamic>> notesData = appController.notes.map((note) => {
        'id': note.id,
        'title': note.title,
      }).toList();
      return jsonEncode(notesData);
    } catch (e) {
      print("Error getting notes: $e");
      return 'Failed to get notes: $e';
    }
  }

  static Future<String> getIndividualNote({required int id, required AppController appController}) async {
    try {
      Note? note = appController.notes.firstWhere((note) => note.id == id);
      return jsonEncode(note);
    } catch (e) {
      print("Error getting note: $e");
      return 'Failed to get note: $e';
    }
  }

  static Future<String> deleteIndividualNote({required int id, required AppController appController}) async {
    try {
      Note? note = appController.notes.firstWhere((note) => note.id == id);
      await appController.deleteNote(note);
      return "Note deleted successfully: ID $id";
    } catch (e) {
      print("Error getting note: $e");
      return 'Failed to get note: $e';
    }
  }

  static Future<String> updateNote(int id, {required String content, required AppController appController}) async {
    try {
      Note? note = appController.notes.firstWhere((note) => note.id == id);
      note.content = content;
      await appController.updateNote(note);
      return "Note updated successfully: ID $id";
    } catch (e) {
      print("Error updating note: $e");
      return "Failed to update note: $e";
    }
  }
}
