import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_controller.dart';

class CalibrateHeadsUpPage extends StatefulWidget {
  @override
  _CalibrateHeadsUpPageState createState() => _CalibrateHeadsUpPageState();
}

class _CalibrateHeadsUpPageState extends State<CalibrateHeadsUpPage> {
  bool _isCalibrating = false;

  @override
  Widget build(BuildContext context) {
    final appController = Provider.of<AppController>(context);
    return Scaffold(
      backgroundColor: Color.fromRGBO(35, 35, 35, 1),
      appBar: AppBar(
        title: Text('Calibrate Heads Up', style: TextStyle(color: Colors.white)),
        backgroundColor: Color.fromRGBO(35, 35, 35, 1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isCalibrating ? 'Follow instructions on your frames' : 'Calibrate Heads Up',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isCalibrating ? null : _startCalibration,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color.fromRGBO(247, 252, 170, 1),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              ),
              child: Text(_isCalibrating ? 'Calibrating...' : 'Start Calibration'),
            ),
          ],
        ),
      ),
    );
  }

  void _startCalibration() async {
    setState(() {
      _isCalibrating = true;
    });

    final appController = Provider.of<AppController>(context, listen: false);
    await appController.calibrateHeadsUp();

    setState(() {
      _isCalibrating = false;
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Calibration Complete'),
        content: Text('The Heads Up display has been calibrated.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: Text('Finish'),
          ),
        ],
      ),
    );
  }
}
