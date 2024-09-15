import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:frame_sdk/camera.dart';
import 'package:frame_sdk/display.dart';
import 'package:frame_sdk/frame_sdk.dart';
import 'package:frame_sdk/bluetooth.dart';
import 'package:frame_sdk/motion.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_background/flutter_background.dart';
import 'bytes_to_wave.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'assistant_api.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'strings.dart';
import 'package:deepgram_speech_to_text/deepgram_speech_to_text.dart';
import 'package:web_socket_channel/io.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/web_socket_channel.dart'; // Add this import
import 'package:audioplayers/audioplayers.dart'; // Add this import
import 'available_apps.dart';
import 'voice_activity_check.dart';
import 'dart:math' as math;

enum AppState { idle, dashboard, listening, thinking, response }
enum TapType { single, double }

class AppController with ChangeNotifier {
  late final Frame frame;
  bool _isFrameConnected = false;
  bool get isFrameConnected => _isFrameConnected;
  int _batteryLevel = 0;
  int _tapCount = 0;
  Timer? _tapTimer;
  AppState _currentState = AppState.idle;
  int _totalTapCount = 0;
  Timer? _responseTimer;

  static const String _batteryLevelKey = 'batteryLevel';

  late final AssistantAPI _assistantAPI;

  Database? _database;
  List<Map<String, dynamic>> _interactionHistory = [];
  List<InteractionGroup> _groupedInteractionHistory = [];
  List<InteractionGroup> get groupedInteractionHistory => _groupedInteractionHistory;

  List<Note> notes = [];

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  late Deepgram _deepgram;

  bool _isTranscribing = false;
  bool get isTranscribing => _isTranscribing;

  final AudioPlayer _audioPlayer = AudioPlayer(); // Add this line

  StreamSubscription<DeepgramSttResult>? _transcriptionSubscription;
  DeepgramLiveTranscriber? _transcriber;

  StreamController<Uint8List>? _audioStreamController;
  Stream<Uint8List>? _audioStream;
  bool _isRecording = false;

  String get assistantInstructions => Strings.assistantInstructions;

  Future<void> updateAssistantInstructions(String newInstructions) async {
    await Strings.saveAssistantInstructions(newInstructions);
    await _assistantAPI.updateAssistant(instructions: newInstructions);
    notifyListeners();
  }

  bool _isSetupComplete = false;
  bool get isSetupComplete => _isSetupComplete;

  Timer? _batteryUpdateTimer;

  // Add these new properties
  double _pitchThreshold = -600.0;
  double _rollThreshold = 0.0;
  double _amplitudeThreshold = 5.0;
  bool _isDashboardShown = false;
  Timer? _motionCheckTimer;

  double _forwardPitch = 0.0;
  double _upwardPitch = 0.0;

  String _headsUpSensitivity = 'Normal';
  String get headsUpSensitivity => _headsUpSensitivity;

  late String _deepgramApiKey; // Add this line

  // Add getters and setters for the new thresholds
  double get pitchThreshold => _pitchThreshold;
  set pitchThreshold(double value) {
    _pitchThreshold = value;
    _saveMotionThresholds();
    notifyListeners();
  }

  double get rollThreshold => _rollThreshold;
  set rollThreshold(double value) {
    _rollThreshold = value;
    _saveMotionThresholds();
    notifyListeners();
  }

  double get amplitudeThreshold => _amplitudeThreshold;
  set amplitudeThreshold(double value) {
    _amplitudeThreshold = value;
    _saveMotionThresholds();
    notifyListeners();
  }

  // Update this method to save all thresholds
  Future<void> _saveMotionThresholds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('pitchThreshold', _pitchThreshold);
    await prefs.setDouble('rollThreshold', _rollThreshold);
    await prefs.setDouble('amplitudeThreshold', _amplitudeThreshold);
  }

  // Update this method to load all thresholds
  Future<void> _loadMotionThresholds() async {
    final prefs = await SharedPreferences.getInstance();
    _pitchThreshold = prefs.getDouble('pitchThreshold') ?? -20.0;
    _rollThreshold = prefs.getDouble('rollThreshold') ?? 1.0;
    _amplitudeThreshold = prefs.getDouble('amplitudeThreshold') ?? 20.0;
    _headsUpSensitivity = prefs.getString('headsUpSensitivity') ?? 'Normal';
  }

  Timer? _showDashboardTimer;
  Timer? _hideDashboardTimer;
  bool _isLookingUp = false;

  // Update this method to use different timers for showing and hiding the dashboard
  void _startMotionDetection() {
    _motionCheckTimer?.cancel();
    _motionCheckTimer = Timer.periodic(Duration(milliseconds: 200), (_) async {
      try {
        Direction direction = await frame.motion.getDirection();
        bool currentlyLookingUp = _checkIfLookingUp(direction);
        
        if (currentlyLookingUp && !_isDashboardShown) {
          if (!_isLookingUp) {
            _isLookingUp = true;
            _showDashboardTimer?.cancel();
            _showDashboardTimer = Timer(Duration(milliseconds: 200), () {
              if (_isLookingUp) {
                _isDashboardShown = true;
                _showDashboard();
              }
            });
          }
          _hideDashboardTimer?.cancel();
        } else if (!currentlyLookingUp) {
          if (_isLookingUp) {
            _isLookingUp = false;
            _showDashboardTimer?.cancel();
          }
          if (_isDashboardShown) {
            _hideDashboardTimer?.cancel();
            _hideDashboardTimer = Timer(Duration(milliseconds: 700), () {
              if (!_isLookingUp) {
                _isDashboardShown = false;
                _clearDisplay();
              }
            });
          }
        }
      } catch (e) {
        print("Error in _startMotionDetection: $e");
      }
    });
  }

  // Renamed method to avoid conflict with the boolean variable
  bool _checkIfLookingUp(Direction direction) {
    if (_forwardPitch == 0.0 || _upwardPitch == 0.0) {
      print("Cannot determine without calibration");
      return false; // Cannot determine without calibration
    }

    double midPoint = (_forwardPitch + _upwardPitch) / 2;
    double range = _upwardPitch - _forwardPitch;
    
    switch (_headsUpSensitivity) {
      case 'Low':
        return direction.pitch >= (_forwardPitch + range / 4);
      case 'High':
        return direction.pitch >= (_upwardPitch - range / 4);
      case 'Normal':
      default:
        double lowerBound = midPoint;
        double upperBound = _upwardPitch + (range / 2);
        return direction.pitch >= lowerBound && direction.pitch <= upperBound;
    }
  }

  // Update the constructor to load motion thresholds
  AppController() {
    print("AppController constructor called");
    _initializeController();
  }

  Future<void> _initializeController() async {
    print("Starting AppController initialization");
    try {
      await _loadSetupStatus();
      
      if (_isSetupComplete) {
        await _fullInitialization();
      } else {
        _isInitialized = true;
      }
    } catch (e, stackTrace) {
      print("Error during AppController initialization: $e");
      print("Stack trace: $stackTrace");
    } finally {
      notifyListeners();
    }
  }

  Future<void> _fullInitialization() async {
    frame = Frame();
    _assistantAPI = AssistantAPI(this);

    await _initializeFrame();
    await _initializeBackgroundExecution();
    await _initializeAssistant();
    await _initializeDatabase();
    await _loadInteractionHistory();
    await _loadNotes();

    await Strings.loadApiKeys();
    _deepgramApiKey = await Strings.getDeepgramApiKey();
    _initializeDeepgram();

    await updateAssistantTools();

    await _loadMotionThresholds();
    await _loadCalibrationData();
    _startMotionDetection();

    _isInitialized = true;
  }

  Future<void> _loadSetupStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _isSetupComplete = prefs.getBool('isSetupComplete') ?? false;
    print("Loaded setup status: $_isSetupComplete");
  }

  Future<void> completeSetup(String openAIApiKey, String deepgramApiKey) async {
    try {
      await Strings.saveOpenAIApiKey(openAIApiKey);
      await Strings.saveDeepgramApiKey(deepgramApiKey);
      await Strings.setSetupComplete();
      _isSetupComplete = true;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isSetupComplete', true);
      
      await _fullInitialization();
      
      print("Setup complete, full initialization done");
    } catch (e) {
      print("Error during setup: $e");
      throw e; // Rethrow the error to be caught in SetupPage
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _initializeBackgroundExecution() async {
    try {
      bool hasPermissions = await FlutterBackground.hasPermissions;
      if (!hasPermissions) {
        hasPermissions = await FlutterBackground.initialize();
      }

      if (hasPermissions) {
        await FlutterBackground.enableBackgroundExecution();
      }
    } catch (e) {
      print("Error initializing background execution: $e");
      print("Continuing without background execution...");
    }
  }

  int get batteryLevel => _batteryLevel;
  AppState get currentState => _currentState;
  int get totalTapCount => _totalTapCount;
  List<Map<String, dynamic>> get interactionHistory => _interactionHistory;

  Future<void> initializeApp() async {
    await loadSavedBatteryLevel();
    await _connectToFrame();
    _setupTapDetection();
    await _initializeDatabase();
    await _loadInteractionHistory();
  }

  Future<void> _initializeFrame() async {
    try {
      await BrilliantBluetooth.requestPermission();
      await _connectToFrame(timeout: Duration(seconds: 3));
      _startConnectionCheck();
      _startBatteryUpdateTimer();
    } catch (e) {
      print("Error initializing frame: $e");
    }
  }

  Timer? _connectionCheckTimer;
  Timer? _reconnectionTimer;

  Future<void> _connectToFrame({Duration? timeout}) async {
    if (_isFrameConnected) return;

    try {
      bool didConnect = await frame.connect().timeout(timeout ?? Duration(seconds: 30));
      if (didConnect) {
        _isFrameConnected = true;
        _addLogMessage("Connected to device");
        await _updateBatteryLevel();
        await _clearDisplay();
        _setupTapDetection();
        _reconnectionTimer?.cancel();
      } else {
        _addLogMessage("Failed to connect to device");
      }
    } on TimeoutException {
      _addLogMessage("Connection attempt timed out");
    } catch (e) {
      _addLogMessage("Error connecting to device: $e");
    }
    notifyListeners();
  }

  void _startConnectionCheck() {
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = Timer.periodic(Duration(seconds: 5), (_) async {
      bool currentStatus = frame.isConnected;
      if (currentStatus != _isFrameConnected) {
        _isFrameConnected = currentStatus;
        if (!_isFrameConnected) {
          _batteryLevel = 0;
          _startReconnectionAttempts();
        } else {
          await _updateBatteryLevel();
        }
        notifyListeners();
      }
    });
  }

  void _startReconnectionAttempts() {
    _reconnectionTimer?.cancel();
    _reconnectionTimer = Timer.periodic(Duration(seconds: 3), (_) {
      if (!_isFrameConnected) {
        _connectToFrame(timeout: Duration(seconds: 3));
      } else {
        _reconnectionTimer?.cancel();
      }
    });
  }

  Future<void> _clearDisplay() async {
    try {
      await frame.display.showText("", align: Alignment2D.topLeft);
      await frame.sleep();
      _addLogMessage("Display cleared");
    } catch (e) {
      _addLogMessage("Failed to clear display: $e");
    }
  }

  Future<void> _updateBatteryLevel() async {
    if (_isFrameConnected) {
      _batteryLevel = await frame.getBatteryLevel();
      await _saveBatteryLevel(_batteryLevel);
      notifyListeners();
    }
  }

  Future<void> _saveBatteryLevel(int level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_batteryLevelKey, level);
  }

  Future<void> loadSavedBatteryLevel() async {
    final prefs = await SharedPreferences.getInstance();
    _batteryLevel = prefs.getInt(_batteryLevelKey) ?? 0;
    notifyListeners();
  }

  void _addLogMessage(String message) {
    print(message);
    // You can implement a logging mechanism here if needed
  }

  Future<void> checkConnectionStatus() async {
    bool currentStatus = frame.isConnected;
    if (currentStatus != _isFrameConnected) {
      _isFrameConnected = currentStatus;
      if (!_isFrameConnected) {
        _batteryLevel = 0;
        _connectToFrame();
      } else {
        await _updateBatteryLevel();
      }
      notifyListeners();
    }
  }

  void startConnectionCheck() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 5));
      await checkConnectionStatus();
      return true; // Continue the loop indefinitely
    });
  }

  Future<void> _setupTapDetection() async {
    await frame.motion.runOnTap(callback: _handleTap);
  }

  void _handleTap() {
    _tapCount++;
    if (_tapTimer == null) {
      _tapTimer = Timer(const Duration(milliseconds: 300), () {
        if (_tapCount == 1) {
          _handleIdleToListening(); // Start listening directly on single tap
        } else if (_tapCount == 2) {
          // Handle double tap if needed
        }
        _tapCount = 0;
        _tapTimer = null;
      });
    }
  }

  Future<void> _showDashboard() async {
    _isDashboardShown = true;
    _currentState = AppState.dashboard;
    notifyListeners();

    DateTime now = DateTime.now();
    String date = DateFormat('E, MMM d').format(now);
    String time = DateFormat('h:mm a').format(now);

    // Set smaller line height for the date
    frame.display.lineHeight = 40;
    int dateWidth = frame.display.getTextWidth(date);
    int dateHeight = frame.display.getTextHeight(date);

    // Write the date one line down from the top
    await frame.display.writeText(
      date,
      x: 10,
      y: 50, // Changed from 10 to 50 to move it down
      maxWidth: dateWidth,
      maxHeight: dateHeight,
      align: Alignment2D.topLeft
    );

    // Set larger line height for the time
    frame.display.lineHeight = 80;
    int timeWidth = frame.display.getTextWidth(time);
    int timeHeight = frame.display.getTextHeight(time);

    // Write the time directly underneath the date
    await frame.display.writeText(
      time,
      x: 10,
      y: 50 + dateHeight + 5, // Adjusted to account for the new date position
      maxWidth: timeWidth,
      maxHeight: timeHeight,
      align: Alignment2D.topLeft
    );

    // Add battery level display in the top right corner
    frame.display.lineHeight = 40; // Set appropriate line height for battery level
    String batteryText = "$_batteryLevel%";
    int batteryWidth = frame.display.getTextWidth(batteryText);
    int batteryHeight = frame.display.getTextHeight(batteryText);
    int screenWidth = 600; // Use the known screen width

    await frame.display.writeText(
      batteryText,
      x: screenWidth - batteryWidth - 10,
      y: 50, // Changed from 10 to 50 to align with the date
      maxWidth: batteryWidth,
      maxHeight: batteryHeight,
      align: Alignment2D.topRight
    );

    await frame.display.show();

    // Clear the display after 5 seconds
    await Future.delayed(const Duration(seconds: 5));
    await frame.display.clear();

    // Set state back to idle
    _currentState = AppState.idle;
    notifyListeners();
  }

  Future<void> _startListening() async {
    _currentState = AppState.listening;
    notifyListeners();
    // ... existing code for starting listening ...
  }

  Future<void> _handleIdleToListening() async {
    _currentState = AppState.listening;
    await frame.display.showText("Listening...", align: Alignment2D.middleCenter);
    notifyListeners();
    print("Listening...");
    try {
      // Record audio using recordAudio function
      Uint8List audioData = await frame.microphone.recordAudio(
        silenceCutoffLength: const Duration(seconds: 1),
        maxLength: const Duration(seconds: 30),
      );

      // Check if the state has changed to idle during recording
      if (_currentState == AppState.idle) {
        print("Listening cancelled");
        return;
      }

      // Check for voice activity
      bool hasVoiceActivity = checkVoiceActivity(audioData, frame.microphone.sampleRate);
      if (!hasVoiceActivity) {
        print("No voice activity detected");
        _setStateToIdle();
        return;
      }

      double length = audioData.length / (frame.microphone.bitDepth ~/ 8) / frame.microphone.sampleRate;
      print("Audio recorded successfully. Length: ${length.toStringAsFixed(1)} seconds");

      // Convert PCM to WAV
      Uint8List wavData = _bytesToWav(audioData, frame.microphone.bitDepth, frame.microphone.sampleRate);

      _currentState = AppState.thinking;
      await frame.display.showText("Thinking...", align: Alignment2D.middleCenter);
      notifyListeners();
      print("Processing query...");
      
      // Process audio data using AssistantAPI
      var response = await _assistantAPI.processUserQuery(wavData);
      
      // Handle the response
      await _handleAssistantResponse(response);
    } catch (e) {
      print("Error in _handleIdleToListening: $e");
      _currentState = AppState.idle;
      await frame.display.showText("Error processing", align: Alignment2D.middleCenter);
      await Future.delayed(const Duration(seconds: 3));
      await frame.display.showText("", align: Alignment2D.middleCenter);
      _currentState = AppState.idle;
      await frame.sleep();
    } finally {
      notifyListeners();
    }
  }

  Future<void> _initializeAssistant() async {
    try {
      await _assistantAPI.createAssistant();
      await _assistantAPI.createThread();
      
      if (_assistantAPI.assistantId == null || _assistantAPI.threadId == null) {
        throw Exception('Failed to initialize assistant or thread');
      }
      
      print("Assistant initialized successfully. AssistantID: ${_assistantAPI.assistantId}, ThreadID: ${_assistantAPI.threadId}");
    } catch (e) {
      print("Error initializing assistant: $e");
      // You might want to set a flag or state to indicate initialization failure
      // For example: _isAssistantInitialized = false;
    }
  }

  Future<void> _handleAssistantResponse(Map<String, dynamic> response) async {
    try {
      print("Handling Assistant response: $response");
      final status = response['status'] as String?;
      final message = response['response'] as String?;

      _currentState = AppState.response;
      
      if (status == 'completed' && message != null && message.isNotEmpty) {
        await frame.display.showText(message, align: Alignment2D.middleCenter);
        _startResponseTimer();
        
        // Add the interaction to history
        await _addInteractionToHistory(response['prompt'] ?? '', message);
      } else {
        await frame.display.showText("No response from Assistant", align: Alignment2D.middleCenter);
        await Future.delayed(const Duration(seconds: 3));
        _setStateToIdle();
      }

    } catch (e) {
      print('Error handling Assistant response: $e');
      await _handleApiError('Error processing response');
    }
    notifyListeners();
  }

  void _startResponseTimer() {
    _responseTimer?.cancel();
    _responseTimer = Timer(const Duration(seconds: 10), () {
      if (_currentState == AppState.response) {
        _setStateToIdle();
      }
    });
  }

  void _setStateToIdle() async {
    _currentState = AppState.idle;
    await frame.display.showText("Idle", align: Alignment2D.middleCenter);
    await frame.sleep();
    notifyListeners();
  }

  Future<void> _handleApiError(String errorMessage) async {
    _currentState = AppState.idle;
    await frame.display.showText(errorMessage, align: Alignment2D.middleCenter);
    await Future.delayed(const Duration(seconds: 3));
    await frame.display.showText("", align: Alignment2D.middleCenter);
    await frame.sleep();
    notifyListeners();
  }

  void _performActionBasedOnState(TapType tapType) async {
    switch (_currentState) {
      case AppState.idle:
        if (tapType == TapType.single) {
          await _showDashboard();
        } else if (tapType == TapType.double) {
          Direction direction = await frame.motion.getDirection();
          if (direction.amplitude() < 20) { // Assuming amplitude < 20 means "straight ahead"
            await _handleIdleToListening();
          }
        }
        break;
      case AppState.dashboard:
        if (tapType == TapType.single) {
          await _handleIdleToListening(); // Changed this line
        }
        break;
      case AppState.listening:
        if (tapType == TapType.single) {
          await _cancelListeningAndReturnToIdle();
        }
        break;
      case AppState.thinking:
        if (tapType == TapType.single) {
          await _cancelThinkingAndReturnToIdle();
        }
        break;
      case AppState.response:
        if (tapType == TapType.single) {
          _responseTimer?.cancel();
          await _handleIdleToListening();
        }
        break;
    }
    notifyListeners();
  }

  Future<void> _cancelListeningAndReturnToIdle() async {
    // Cancel any ongoing listening processes here
    // For example, you might need to stop the audio recording

    _currentState = AppState.idle;
    await frame.display.showText("Listening cancelled", align: Alignment2D.middleCenter);
    await Future.delayed(const Duration(seconds: 2));
    await frame.display.clear();
    await frame.sleep();
    notifyListeners();
  }

  Future<void> _cancelThinkingAndReturnToIdle() async {
    // Cancel any ongoing API requests or processing here
    _assistantAPI.cancelOngoingRequests(); // You'll need to implement this method in AssistantAPI

    _currentState = AppState.idle;
    await frame.display.clear();
    await frame.sleep();
    notifyListeners();
  }

  void setState(AppState newState) {
    _currentState = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    _responseTimer?.cancel();
    _batteryUpdateTimer?.cancel(); // Add this line
    _motionCheckTimer?.cancel();
    _showDashboardTimer?.cancel();
    _hideDashboardTimer?.cancel();
    FlutterBackground.disableBackgroundExecution();
    _tapTimer?.cancel();
    super.dispose();
  }

  // Add these helper functions to your AppController class

  Uint8List _bytesToWav(Uint8List pcmData, int bitDepth, int sampleRate) {
    final output = BytesBuilder();
    
    output.add(utf8.encode('RIFF'));
    output.add(_uint32to8(36 + pcmData.length));
    output.add(utf8.encode('WAVE'));
    output.add(utf8.encode('fmt '));
    output.add(_uint32to8(16));
    output.add(_uint16to8(1));
    output.add(_uint16to8(1));
    output.add(_uint32to8(sampleRate));
    output.add(_uint32to8((sampleRate * bitDepth) ~/ 8));
    output.add(_uint16to8(bitDepth ~/ 8));
    output.add(_uint16to8(bitDepth));
    output.add(utf8.encode('data'));
    output.add(_uint32to8(pcmData.length));
    output.add(pcmData);
    
    return output.toBytes();
  }

  Uint8List _uint32to8(int value) =>
      Uint8List.fromList([
        value & 0xFF,
        (value >> 8) & 0xFF,
        (value >> 16) & 0xFF,
        (value >> 24) & 0xFF,
      ]);

  Uint8List _uint16to8(int value) =>
      Uint8List.fromList([value & 0xFF, (value >> 8) & 0xFF]);

  Future<void> _initializeDatabase() async {
    print("Initializing database");
    if (_database != null) {
      print("Database already initialized");
      return;
    }

    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, 'miles_history.db');

      print("Opening database at path: $path");
      _database = await openDatabase(
        path,
        onCreate: (db, version) async {
          print("Creating database tables");
          await db.execute(
            'CREATE TABLE interactions(id INTEGER PRIMARY KEY AUTOINCREMENT, prompt TEXT, response TEXT, timestamp TEXT)',
          );
          await db.execute(
            'CREATE TABLE notes(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, content TEXT)',
          );
        },
        version: 1,
      );
      print("Database initialized successfully");
    } catch (e) {
      print("Error initializing database: $e");
    }
  }

  Future<void> _loadInteractionHistory() async {
    print("Loading interaction history");
    if (_database == null) {
      print("Database is null, initializing");
      await _initializeDatabase();
    }
    try {
      _interactionHistory = await _database!.query('interactions', orderBy: 'timestamp DESC');
      print("Loaded ${_interactionHistory.length} interactions");
      _groupInteractionHistory();
    } catch (e) {
      print("Error loading interaction history: $e");
      _interactionHistory = [];
      _groupedInteractionHistory = [];
    }
    notifyListeners();
  }

  void _groupInteractionHistory() {
    final groups = groupBy<Map<String, dynamic>, DateTime>(
      _interactionHistory,
      (interaction) {
        final timestamp = DateTime.parse(interaction['timestamp']);
        return DateTime(
          timestamp.year,
          timestamp.month,
          timestamp.day,
          timestamp.hour,
          timestamp.minute ~/ 5 * 5,
        );
      },
    );

    _groupedInteractionHistory = groups.entries.map((entry) {
      return InteractionGroup(
        timestamp: entry.key,
        interactions: entry.value,
      );
    }).toList();

    _groupedInteractionHistory.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> _addInteractionToHistory(String prompt, String response) async {
    if (_database == null) await _initializeDatabase();
    final timestamp = DateTime.now().toIso8601String();
    await _database!.insert('interactions', {
      'prompt': prompt,
      'response': response,
      'timestamp': timestamp,
    });
    await _loadInteractionHistory();
  }

  Future<void> _displayTextOnFrame(String text) async {
    await frame.display.showText(text, align: Alignment2D.middleCenter);
  }

  Future<void> _loadNotes() async {
    if (_database == null) await _initializeDatabase();
    final List<Map<String, dynamic>> notesMap = await _database!.query('notes');
    notes = notesMap.map((noteMap) => Note.fromMap(noteMap)).toList();
    notifyListeners();
  }

  Future<void> startNewNote(Note newNote) async {
    final id = await _database!.insert('notes', newNote.toMap());
    newNote.id = id;
    notes.add(newNote);
    notifyListeners();
  }

  Future<void> updateNote(Note note) async {
    await _database!.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
    final index = notes.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      notes[index] = note;
    }
    notifyListeners();
  }

  Future<void> displayText(String text) async {
    await _displayTextOnFrame(text);
  }

  Future<void> deleteNote(Note note) async {
    if (_database == null) await _initializeDatabase();
    
    try {
      await _database!.delete(
        'notes',
        where: 'id = ?',
        whereArgs: [note.id],
      );
      
      notes.removeWhere((n) => n.id == note.id);
      notifyListeners();
      
      print('Note deleted successfully: ${note.title}');
    } catch (e) {
      print('Error deleting note: $e');
      // You might want to throw an exception here or handle the error in some way
    }
  }

  Future<void> updateApiKeys({
    String? openAIApiKey,
    String? deepgramApiKey,
  }) async {
    if (openAIApiKey != null) {
      await Strings.saveOpenAIApiKey(openAIApiKey);
      _assistantAPI.updateApiKey(openAIApiKey);
    }
    if (deepgramApiKey != null) {
      await Strings.saveDeepgramApiKey(deepgramApiKey);
      _deepgramApiKey = deepgramApiKey;
      _initializeDeepgram();
    }
    notifyListeners();
  }

  void _initializeDeepgram() {
    Map<String, dynamic> params = {
      'language': 'en',
      'encoding': 'linear16', // Ensure this matches the frame microphone encoding
      'sample_rate': 8000,
      'punctuate': true,
      'smart_format': true,
    };
    _deepgram = Deepgram(_deepgramApiKey, baseQueryParams: params);
  }

  Future<void> startTranscription(Note note) async {
    if (_isTranscribing) return;
    _isTranscribing = true;
    notifyListeners();

    try {
      print("Starting transcription");

      Stream<Uint8List> audioStream = await startRecordingStream();

      _transcriber = _deepgram.createLiveTranscriber(
        audioStream.cast<List<int>>(),
      );
      _transcriber!.start();

      String currentLine = '';
      List<String> transcriptLines = note.content.isEmpty ? [] : note.content.split('\n');

      _transcriptionSubscription = _transcriber!.stream.listen((result) {
        print(result);
        if (result.transcript != null && result.transcript!.isNotEmpty) {
          // If the new transcript is shorter, it's likely a new line
          if (result.transcript!.length < currentLine.length) {
            if (currentLine.isNotEmpty) {
              transcriptLines.add(currentLine.trim());
            }
            currentLine = result.transcript!;
          } else {
            currentLine = result.transcript!;
          }

          // Update the note content
          if (transcriptLines.isEmpty) {
            note.content = currentLine.trim();
          } else {
            note.content = transcriptLines.join('\n') + (transcriptLines.isNotEmpty ? ' ' : '') + currentLine.trim();
          }
          updateNoteContent(note);
          notifyListeners();
        } else if (result.transcript != null && result.transcript!.isEmpty && currentLine.isNotEmpty) {
          // Empty transcript might indicate end of a line
          transcriptLines.add(currentLine.trim());
          currentLine = '';
          
          // Update the note content
          note.content = transcriptLines.join('\n').trim();
          updateNoteContent(note);
          notifyListeners();
        }
      });

    } catch (e) {
      print("Error during transcription: $e");
      if (e is WebSocketChannelException) {
        print("WebSocketChannelException: ${e.message}");
      } else if (e is WebSocketException) {
        print("WebSocketException: ${e.message}");
      } else {
        print("Exception: ${e.toString()}");
      }
      await stopTranscription();
    }
  }

  Future<void> stopTranscription() async {
    if (!_isTranscribing) return; // Prevent stopping if not transcribing

    try {
      // Stop the audio stream
      await stopRecordingStream();

      // Cancel the transcription subscription
      await _transcriptionSubscription?.cancel();
      _transcriptionSubscription = null;

      // Close the transcriber
      await _transcriber?.close();
      _transcriber = null;

    } catch (e) {
      print("Error stopping transcription: $e");
    } finally {
      _isTranscribing = false;
      notifyListeners();
    }
  }

  Future<void> updateNoteContent(Note note) async {
    if (_database == null) await _initializeDatabase();
    await _database!.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
    final index = notes.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      notes[index] = note;
    }
    notifyListeners();
  }

  /// Starts the microphone recording stream
  /// Returns a Stream<Uint8List> of audio data
  Future<Stream<Uint8List>> startRecordingStream() async {
    if (_isRecording) {
      throw StateError('Recording is already in progress');
    }

    _audioStreamController = StreamController<Uint8List>();
    _isRecording = true;

    // Set up the frame for recording
    await frame.runLua('frame.microphone.stop()', checked: true);
    await frame.runLua(
      'microphoneRecordAndSend(8000,16,nil)',
    );

    // Listen to the Bluetooth data stream and add it to our StreamController
    frame.bluetooth
        .getDataOfType(FrameDataTypePrefixes.micData)
        .listen((data) {
      if (_audioStreamController != null && !_audioStreamController!.isClosed) {
        _audioStreamController!.add(data);
      }
    });

    _audioStream = _audioStreamController!.stream.asBroadcastStream();
    return _audioStream!;
  }

  /// Stops the microphone recording stream
  Future<void> stopRecordingStream() async {
    if (!_isRecording) {
      return;
    }

    _isRecording = false;
    await frame.bluetooth.sendBreakSignal();
    await frame.runLua('frame.microphone.stop()');
    await Future.delayed(const Duration(milliseconds: 100));
    await frame.runLua('frame.microphone.stop()');

    await _audioStreamController?.close();
    _audioStreamController = null;
    _audioStream = null;
  }

  // Add this method
  void _startBatteryUpdateTimer() {
    _batteryUpdateTimer?.cancel();
    _batteryUpdateTimer = Timer.periodic(const Duration(minutes: 3), (_) async {
      await _updateBatteryLevel();
    });
  }

  Future<void> updateAssistantTools() async {
    await _assistantAPI.updateAssistant(instructions: Strings.assistantInstructions);
    notifyListeners();
  }

  Future<void> deactivateApp(String appUuid) async {
    await AvailableApps.deactivateApp(appUuid);
    notifyListeners();
  }

  Future<void> updatePitchThreshold(double newValue) async {
    _pitchThreshold = newValue;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('pitchThreshold', _pitchThreshold);
    notifyListeners();
    print("Pitch threshold updated and saved: $_pitchThreshold"); // Debug print
  }

  // Add this method to update all motion thresholds at once
  Future<void> updateMotionThresholds({
    double? newPitchThreshold,
    double? newRollThreshold,
    double? newAmplitudeThreshold,
  }) async {
    if (newPitchThreshold != null) _pitchThreshold = newPitchThreshold;
    if (newRollThreshold != null) _rollThreshold = newRollThreshold;
    if (newAmplitudeThreshold != null) _amplitudeThreshold = newAmplitudeThreshold;
    
    await _saveMotionThresholds();
    notifyListeners();
    print("Motion thresholds updated: Pitch: $_pitchThreshold, Roll: $_rollThreshold, Amplitude: $_amplitudeThreshold");
  }

  Future<void> calibrateHeadsUp() async {
    const int countdownDuration = 3;
    const int holdDuration = 3;
    const int sampleInterval = 100;

    List<double> forwardPitches = [];
    List<double> upwardPitches = [];

    // Look forward
    await _showCountdown("Please look forward", countdownDuration);
    await _recordPitches(forwardPitches, holdDuration, sampleInterval, "Hold for");

    // Look up
    await _showCountdown("Look up", countdownDuration);
    await _recordPitches(upwardPitches, holdDuration, sampleInterval, "Please hold");

    // Calculate averages
    _forwardPitch = _calculateAverage(forwardPitches);
    _upwardPitch = _calculateAverage(upwardPitches);

    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('forwardPitch', _forwardPitch);
    await prefs.setDouble('upwardPitch', _upwardPitch);

    print("Calibration saved: Forward: $_forwardPitch, Upward: $_upwardPitch");

    // Show completion message
    await frame.display.showText("Calibration complete, please check phone", align: Alignment2D.middleCenter);
    await Future.delayed(const Duration(seconds: 3));
    await frame.display.clear();

    notifyListeners();
  }

  Future<void> _showCountdown(String message, int seconds) async {
    for (int i = seconds; i > 0; i--) {
      await frame.display.showText("$message $i", align: Alignment2D.middleCenter);
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  Future<void> _recordPitches(List<double> pitches, int duration, int interval, String message) async {
    int samples = (duration * 1000) ~/ interval;
    for (int i = samples; i > 0; i--) {
      Direction direction = await frame.motion.getDirection();
      pitches.add(direction.pitch);
      await frame.display.showText("$message ${(i * interval / 1000).toStringAsFixed(1)}", align: Alignment2D.middleCenter);
      await Future.delayed(Duration(milliseconds: interval));
    }
  }

  double _calculateAverage(List<double> values) {
    return values.reduce((a, b) => a + b) / values.length;
  }

  Future<void> updateHeadsUpSensitivity(String newSensitivity) async {
    _headsUpSensitivity = newSensitivity;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('headsUpSensitivity', _headsUpSensitivity);
    notifyListeners();
    print("Heads up sensitivity updated and saved: $_headsUpSensitivity"); // Debug print
  }

  Future<void> _loadCalibrationData() async {
    final prefs = await SharedPreferences.getInstance();
    _forwardPitch = prefs.getDouble('forwardPitch') ?? 0.0;
    _upwardPitch = prefs.getDouble('upwardPitch') ?? 0.0;
    print("Loaded calibration data: Forward: $_forwardPitch, Upward: $_upwardPitch");
  }

  double get forwardPitch => _forwardPitch;
  double get upwardPitch => _upwardPitch;
}



class Note {
  int? id;
  String title;
  String content;

  Note({this.id, required this.title, required this.content});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as int?,
      title: map['title'] as String,
      content: map['content'] as String,
    );
  }
}

class InteractionGroup {
  final DateTime timestamp;
  final List<Map<String, dynamic>> interactions;

  InteractionGroup({required this.timestamp, required this.interactions});
}