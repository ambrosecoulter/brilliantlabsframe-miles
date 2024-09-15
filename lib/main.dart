import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'src/app_controller.dart';
import 'src/home.dart';
import 'src/setup_page.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AppController())
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Consumer<AppController>(
        builder: (context, appController, child) {
          if (!appController.isInitialized) {
            return _buildLoadingScreen(appController);
          }
          if (!appController.isSetupComplete) {
            return SetupPage(appController: appController);
          }
          return HomePage(appController: appController);
        },
      ),
    );
  }

  Widget _buildLoadingScreen(AppController appController) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(35, 35, 35, 1),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color.fromRGBO(247, 252, 170, 1),
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              appController.isSetupComplete
                  ? 'Initialising Miles and connecting to your Frames...'
                  : 'Initialising Miles...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}