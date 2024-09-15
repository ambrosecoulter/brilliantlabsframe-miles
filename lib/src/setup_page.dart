import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_controller.dart';
import 'home.dart';

class SetupPage extends StatefulWidget {
  final AppController appController;

  SetupPage({required this.appController});

  @override
  _SetupPageState createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final PageController _pageController = PageController();
  final _openAIApiKeyController = TextEditingController();
  final _deepgramApiKeyController = TextEditingController();
  int _currentStep = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(35, 35, 35, 1),
      appBar: AppBar(
        title: Text('Setup', style: TextStyle(color: Colors.white)),
        backgroundColor: Color.fromRGBO(35, 35, 35, 1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentStep = index;
          });
        },
        children: [
          _buildStep(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset('assets/images/miles_logo.png', width: 140),
                SizedBox(height: 30),
                Text('Hi there!', style: TextStyle(color: Colors.white, fontSize: 50)),
              ],
            ),
            content: Text('Welcome to Miles, your smart AI assistant. Miles can help you with getting answers and more with the Miles App Store. Let\'s get you setup.', style: TextStyle(color: Colors.white, fontSize: 17)),
          ),
          _buildStep(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('OpenAI', style: TextStyle(color: Colors.white, fontSize: 50)),
                SizedBox(height: 30),
                Text('Enter your OpenAI API Key below, this is how Miles will process your requests.', style: TextStyle(color: Colors.white, fontSize: 17)),
              ],
            ),
            content: _buildTextField(_openAIApiKeyController, 'Enter OpenAI API Key'),
          ),
          _buildStep(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Deepgram', style: TextStyle(color: Colors.white, fontSize: 50)),
                SizedBox(height: 30),
                Text('Enter your Deepgram API Key below, this is how Miles will understand your voice.', style: TextStyle(color: Colors.white, fontSize: 17)),
              ],
            ),
            content: _buildTextField(_deepgramApiKeyController, 'Enter Deepgram API Key'),
          ),
        ],
      ),
    );
  }

  Widget _buildStep({required Widget title, required Widget content}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            SizedBox(height: 16),
            content,
            SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentStep != 0)
                  ElevatedButton(
                    onPressed: _previousStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromRGBO(247, 252, 170, 1),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    ),
                    child: Text('Back'),
                  ),
                ElevatedButton(
                  onPressed: _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromRGBO(247, 252, 170, 1),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  ),
                  child: Text(_currentStep == 2 ? 'Finish' : 'Next'),
                ),
              ],
            ),
          ],
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
      ),
    );
  }

  void _nextStep() {
    if (_currentStep == 1 && _openAIApiKeyController.text.isEmpty) {
      _showError('OpenAI API Key cannot be blank');
      return;
    }
    if (_currentStep == 2 && _deepgramApiKeyController.text.isEmpty) {
      _showError('Deepgram API Key cannot be blank');
      return;
    }
    if (_currentStep < 2) {
      _pageController.nextPage(duration: Duration(milliseconds: 300), curve: Curves.ease);
    } else {
      _completeSetup();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(duration: Duration(milliseconds: 300), curve: Curves.ease);
    }
  }

  void _completeSetup() {
    final openAIApiKey = _openAIApiKeyController.text;
    final deepgramApiKey = _deepgramApiKeyController.text;

    if (openAIApiKey.isEmpty) {
      _showError('OpenAI API Key cannot be blank');
      return;
    }
    if (deepgramApiKey.isEmpty) {
      _showError('Deepgram API Key cannot be blank');
      return;
    }

    widget.appController.completeSetup(openAIApiKey, deepgramApiKey);
  
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => HomePage(appController: widget.appController)),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
