import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_controller.dart';
import 'ai_tool_functions.dart'; // Add this import
import 'strings.dart'; // Add this import
import 'package:uuid/uuid.dart'; // Add this import

class AvailableApps {
  static const String _activatedAppsKey = 'activatedApps';

  static final Map<String, AppTool> tools = {
    'weather': AppTool(
      name: 'weather',
      description: 'Get weather information for a location.',
      app_title: 'Weather',
      app_description: 'Give Miles access to realtime weather data using the Weather API.',
      parameters: {
        "type": "object",
        "properties": {
          "location": {
            "type": "string",
            "description": "The location to get weather information for"
          }
        },
        "required": ["location"]
      },
      configFields: ['api_key'],
      function: (AppController controller, Map<String, dynamic> params, Map<String, String> config) async {
        final apiKey = config['api_key'] ?? '';
        return await AIToolFunctions.getWeather(params['location'] ?? '', controller, apiKey);
      },
    ),
    'notes': AppTool(
      name: 'notes',
      description: 'Create, retrieve, and update notes. When adding a note, ensure you do not tell the user you will remind them as you are unable to do this. Instead let the user know youve added a note for <your quick summary>.',
      app_title: 'Notes',
      app_description: 'Give Miles access to create and manage your notes.',
      parameters: {
        "type": "object",
        "properties": {
          "action": {
            "type": "string",
            "enum": ["get_notes", "add_note", "update_note", "get_individual_note", "delete_note"],
            "description": "The action to perform"
          },
          "note_content": {
            "type": "string",
            "description": "The note content, used when updating or creating a note."
          },
          "note_id": {
            "type": "number",
            "description": "The ID of the note. Used when updating a note, deleting a note or getting its full details."
          },
          "note_title": {
            "type": "string",
            "description": "The Title of the note. Used when updating a note."
          }
        },
        "required": ["action"]
      },
      configFields: [],
      function: (AppController controller, Map<String, dynamic> params, Map<String, String> config) async {
        return await AIToolFunctions.handleNotes(params, controller);
      },
    ),
    // Add more tools here
    'search': AppTool(
      name: 'search',
      description: 'Perform a web search using Serpapi',
      app_title: 'Web search',
      app_description: 'Give Miles access to the web to assist you with research.',
      parameters: {
        "type": "object",
        "properties": {
          "query": {
            "type": "string",
            "description": "The search query"
          },
          "search_type": {
            "type": "string",
            "description": "The type of search to perform"
          }
        },
        "required": ["query", "search_type"]
      },
      configFields: ['api_key'],
      function: (AppController controller, Map<String, dynamic> params, Map<String, String> config) async {
        return await AIToolFunctions.serpapiSearch(params['query'], params['search_type'], controller, config['api_key']);
      },
    ),
    'pushover': AppTool(
      name: 'pushover',
      description: 'Send a push notification to a user',
      app_title: 'Pushover notifications',
      app_description: 'Give Miles access to sending you Pushover notifications.',
      parameters: {
        "type": "object",
        "properties": {
          "message": {
            "type": "string",
            "description": "The message to send"
          },
          "title": {
            "type": "string",
            "description": "The title of the notification"
          },
          "url": {
            "type": "string",
            "description": "The URL to send with the notification"
          }
        },
        "required": ["message", "title"]
      },
      configFields: ['token', 'user'],
      function: (AppController controller, Map<String, dynamic> params, Map<String, String> config) async {
        return await AIToolFunctions.sendPushoverNotification(
          params['message'],
          params['title'],
          params['url'],
          controller,
          config['token'],
          config['user']
        );
      },
    ),
    'energy_price': AppTool(
      name: 'energy_price',
      description: 'Get the current energy price from Amber',
      app_title: 'Amber Electric',
      app_description: 'Allow Miles to get the latest, realtime energy prices from Amber.',
      parameters: {
        "type": "object",
        "properties": {
          "api_key": {
            "type": "string",
            "description": "The API key for Amber"
          },
          "site_id": {
            "type": "string",
            "description": "The site ID for Amber"
          }
        },
        "required": ["api_key", "site_id"]
      },
      configFields: ['api_key', 'site_id'],
      function: (AppController controller, Map<String, dynamic> params, Map<String, String> config) async {
        return await AIToolFunctions.getCurrentEnergyPrice(controller, config['api_key'], config['site_id']);
      },
    ),
    'perplexity_search': AppTool(
      name: 'perplexity_search',
      description: 'Perform a search using Perplexity AI',
      app_title: 'Perplexity AI',
      app_description: 'Give Miles access to perform a search using Perplexity AI.',
      parameters: {
        "type": "object",
        "properties": {
          "query": {
            "type": "string",
            "description": "The search query"
          }
        },
        "required": ["query"]
      },
      configFields: ['api_key'],
      function: (AppController controller, Map<String, dynamic> params, Map<String, String> config) async {
        return await AIToolFunctions.perplexitySearch(params['query'], controller, config['api_key']);
      },
    ),
  };

  static Future<List<String>> getActivatedApps() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_activatedAppsKey) ?? [];
  }

  static Future<void> setActivatedApps(List<String> apps) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_activatedAppsKey, apps);
  }

  static Future<void> activateApp(String appUuid) async {
    final prefs = await SharedPreferences.getInstance();
    final activatedApps = prefs.getStringList('activatedApps') ?? [];
    if (!activatedApps.contains(appUuid)) {
      activatedApps.add(appUuid);
      await prefs.setStringList('activatedApps', activatedApps);
    }
    // Remove this line: AppController().updateAssistantTools();
  }

  static Future<void> deactivateApp(String appUuid) async {
    final prefs = await SharedPreferences.getInstance();
    final activatedApps = prefs.getStringList('activatedApps') ?? [];
    activatedApps.remove(appUuid);
    await prefs.setStringList('activatedApps', activatedApps);
    // Remove this line: AppController().updateAssistantTools();
  }

  static Future<List<Map<String, dynamic>>> getActivatedAppTools() async {
    final activatedApps = await getActivatedApps();
    List<Map<String, dynamic>> activatedTools = [];

    for (String appName in activatedApps) {
      final tool = tools[appName];
      if (tool == null) {
        print("Warning: Tool not found for app: $appName");
        continue;
      }

      activatedTools.add({
        "type": "function",
        "function": {
          "name": appName,  // Use the full appName here
          "description": tool.description,
          "parameters": tool.parameters,
        }
      });
    }

    return activatedTools;
  }

  static Future<String> callFunction(String functionName, Map<String, dynamic> arguments, AppController controller) async {
    final tool = tools[functionName];
    if (tool == null) {
      throw Exception('Function not found: $functionName');
    }
    final config = await getAppConfig(functionName);
    final result = await tool.function(controller, arguments, config);
    return jsonEncode(result);
  }

  static Future<Map<String, String>> getAppConfig(String appName) async {
    Map<String, String> config = {};
    AppTool? tool = tools[appName];
    if (tool != null && tool.configFields != null) {
      for (String field in tool.configFields!) {
        String? value = Strings.getAppConfig(appName, field);
        if (value != null) {
          config[field] = value;
        }
      }
    }
    return config;
  }

  static Future<void> setAppConfig(String appName, Map<String, String> config) async {
    for (var entry in config.entries) {
      await Strings.saveAppConfig(appName, entry.key, entry.value);
    }
  }

  static Future<Map<String, dynamic>> weatherFunction(Map<String, String> params, AppController controller) async {
    final config = await getAppConfig('weather');
    final apiKey = config['api_key'] ?? '';
    return await AIToolFunctions.getWeather(params['location'] ?? 'auto:ip', controller, apiKey);
  }
}

class AppTool {
  final String name;
  final String description;
  final String? app_title;
  final String? app_description;
  final Map<String, dynamic> parameters;
  final List<String>? configFields;
  final Future<dynamic> Function(AppController, Map<String, dynamic>, Map<String, String>) function;

  AppTool({
    required this.name,
    required this.description,
    this.app_title,
    this.app_description,
    required this.parameters,
    this.configFields,
    required this.function,
  });
}
