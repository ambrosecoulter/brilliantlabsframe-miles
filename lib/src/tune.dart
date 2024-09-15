import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_controller.dart';

class TunePage extends StatefulWidget {
  @override
  _TunePageState createState() => _TunePageState();
}

class _TunePageState extends State<TunePage> {
  late TextEditingController _instructionsController;

  @override
  void initState() {
    super.initState();
    _instructionsController = TextEditingController(
      text: context.read<AppController>().assistantInstructions,
    );
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(35, 35, 35, 1),
      appBar: AppBar(
        title: Text('Tune Assistant', style: TextStyle(color: Colors.white)),
        backgroundColor: Color.fromRGBO(35, 35, 35, 1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Color.fromRGBO(42, 42, 42, 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _instructionsController,
                  maxLines: null,
                  expands: true,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    labelText: 'Assistant Instructions',
                    labelStyle: TextStyle(color: Colors.white70),
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final appController = context.read<AppController>();
                await appController.updateAssistantInstructions(_instructionsController.text);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Instructions updated successfully')),
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
              child: Text('Update Instructions'),
            ),
          ],
        ),
      ),
    );
  }
}