import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'strings.dart';
import 'app_controller.dart';
import 'package:provider/provider.dart';
import 'calibrate_heads_up.dart';

class StringsSettingsPage extends StatefulWidget {
  @override
  _StringsSettingsPageState createState() => _StringsSettingsPageState();
}

class _StringsSettingsPageState extends State<StringsSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _deepgramController;
  late TextEditingController _openAIController;
  String _headsUpSensitivity = 'Normal';

  @override
  void initState() {
    super.initState();
    _deepgramController = TextEditingController();
    _openAIController = TextEditingController();
    _loadApiKeys();
    _loadHeadsUpSensitivity();
  }
 
  Future<void> _loadApiKeys() async {
    _deepgramController.text = await Strings.getDeepgramApiKey();
    _openAIController.text = await Strings.getOpenAIApiKey();
    setState(() {});
  }

  Future<void> _loadHeadsUpSensitivity() async {
    final appController = Provider.of<AppController>(context, listen: false);
    setState(() {
      _headsUpSensitivity = appController.headsUpSensitivity;
    });
  }

  @override
  void dispose() {
    _deepgramController.dispose();
    _openAIController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    print("_saveSettings method called"); // Debug print

    if (_formKey.currentState!.validate()) {
      try {
        final appController = Provider.of<AppController>(context, listen: false);

        await Strings.saveDeepgramApiKey(_deepgramController.text);
        await Strings.saveOpenAIApiKey(_openAIController.text);
        await appController.updateHeadsUpSensitivity(_headsUpSensitivity);

        await appController.updateApiKeys(
          deepgramApiKey: _deepgramController.text,
          openAIApiKey: _openAIController.text,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Settings saved successfully', style: TextStyle(color: Colors.black)),
            backgroundColor: Color.fromRGBO(247, 252, 170, 1),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: Duration(seconds: 2),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.black,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );

        print("Settings saved. Heads up sensitivity: ${appController.headsUpSensitivity}");
      } catch (e) {
        print("Error saving settings: $e"); // Debug print
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      print("Form validation failed"); // Debug print
    }
  }

  @override
  Widget build(BuildContext context) {
    final appController = Provider.of<AppController>(context);
    return Scaffold(
      backgroundColor: Color.fromRGBO(35, 35, 35, 1),
      appBar: AppBar(
        title: Text('App Settings', style: TextStyle(color: Colors.white)),
        backgroundColor: Color.fromRGBO(35, 35, 35, 1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildTextField(_deepgramController, 'Deepgram API Key'),
                      SizedBox(height: 16),
                      _buildTextField(_openAIController, 'OpenAI API Key'),
                      SizedBox(height: 16),
                      _buildHeadsUpSensitivitySelector(),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => CalibrateHeadsUpPage()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromRGBO(247, 252, 170, 1),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                        ),
                        child: Text('Calibrate Heads Up'),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color.fromRGBO(247, 252, 170, 1),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                ),
                child: Text('Save Settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return Container(
      decoration: BoxDecoration(
        color: Color.fromRGBO(42, 42, 42, 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextFormField(
        controller: controller,
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          labelText: label,
          labelStyle: TextStyle(color: Colors.white70),
          contentPadding: EdgeInsets.all(16),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return '$label cannot be empty';
          }
          if (label == 'Pitch Threshold (-40 to 0)') {
            double? pitch = double.tryParse(value);
            if (pitch == null || pitch < -1000 || pitch > 0) {
              return 'Pitch must be between -100 and 0';
            }
          }
          return null;
        },
      ),
    );
  }

  Widget _buildHeadsUpSensitivitySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Heads Up Sensitivity',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
        SizedBox(height: 12),
        Container(
          height: 50, // Increased height
          decoration: BoxDecoration(
            color: Color.fromRGBO(42, 42, 42, 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final buttonWidth = constraints.maxWidth / 3;
              return Stack(
                children: [
                  Row(
                    children: ['Low', 'Normal', 'High'].map((String value) {
                      return SizedBox(
                        width: buttonWidth,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _headsUpSensitivity = value;
                            });
                          },
                          child: Center(
                            child: Text(
                              value,
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  AnimatedPositioned(
                    duration: Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    left: _headsUpSensitivity == 'Low'
                        ? 0
                        : _headsUpSensitivity == 'Normal'
                            ? buttonWidth
                            : buttonWidth * 2,
                    child: Container(
                      width: buttonWidth,
                      height: 50, // Increased height
                      decoration: BoxDecoration(
                        color: Color.fromRGBO(247, 252, 170, 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}