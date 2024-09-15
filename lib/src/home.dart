import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_controller.dart';
import 'package:flutter/services.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'miles_history.dart';
import 'notes.dart';
import 'strings_settings_page.dart';
import 'tune.dart';
import 'setup_page.dart'; // Add this import
import 'app_store.dart'; // Add this import

class HomePage extends StatefulWidget {
  final AppController appController;

  HomePage({required this.appController});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _rotation = 0;
  String _selectedColor = 'Smokey black';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
    );
    _controller.forward().then((_) {
      _controller.dispose();
    });
    _loadSavedColor();
  }

  void _loadSavedColor() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedColor = prefs.getString('selectedColor') ?? 'Smokey black';
    });
  }

  void _saveSelectedColor(String color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedColor', color);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _rotation += details.primaryDelta! * 0.5;
    });
  }

  String _getModelFile(String color) {
    String modelFile;
    switch (color) {
      case 'Cool gray':
        modelFile = 'assets/models/3dframemodel_coolGray.glb';
        break;
      case 'H20':
        modelFile = 'assets/models/3dframemodel_h20.glb';
        break;
      case 'Smokey black':
      default:
        modelFile = 'assets/models/3dframemodel_smokeyBlack.glb';
        break;
    }
    return modelFile;
  }

  @override
  Widget build(BuildContext context) {
    final appController = Provider.of<AppController>(context);

    return Scaffold(
      backgroundColor: Color.fromRGBO(35, 35, 35, 1),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Image.asset(
                  'assets/images/miles_logo.png',
                  width: 110,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 24),
              Expanded(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: 250),
                  child: _buildFullWidthTile(appController),
                ),
              ),
              SizedBox(height: 10),
              GridView.count(
                physics: NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.43,
                children: [
                  _buildTile(context, 'Miles', 'View your past interactions with Miles.', Icons.question_answer),
                  _buildTile(context, 'Tune', 'Tune your experience with Miles.', Icons.tune),
                  _buildTile(context, 'Notes', 'Create and manage your notes.', Icons.note),
                  _buildTile(context, 'App Store', 'Browse and manage apps.', Icons.store), // Add this line
                  _buildTile(context, 'App Settings', 'Manage Miles app settings.', Icons.settings),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullWidthTile(AppController appController) {
    return GestureDetector(
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      child: Container(
        constraints: BoxConstraints(maxHeight: 400),
        decoration: BoxDecoration(
          color: Color.fromRGBO(42, 42, 42, 1),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Your Frames', 
                    style: TextStyle(
                      fontFamily: 'Pixelify Sans',
                      fontSize: 17, 
                      fontVariations: [
                          FontVariation('wght', 450)
                      ],
                      color: Colors.white,
                    )
                  ),
                  GestureDetector(
                    onTap: () => _showColorOptionsModal(context),
                    child: Icon(Icons.settings, size: 24, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _animation,
                        builder: (context, child) {
                          return ModelViewer(
                            key: ValueKey(_selectedColor),
                            scale: "2 2 2",
                            src: _getModelFile(_selectedColor),
                            alt: "Frame 3d model",
                            ar: true,
                            autoRotate: true,
                            autoRotateDelay: 0,
                            rotationPerSecond: "30deg",
                            cameraControls: true,
                            disableZoom: true,
                            minCameraOrbit: "auto 90deg auto",
                            maxCameraOrbit: "auto 90deg auto",
                            cameraOrbit: "${_rotation}deg 75deg 105%",
                            interpolationDecay: 200,
                            orbitSensitivity: 1,
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            appController.isFrameConnected ? 'Connected' : 'Disconnected',
                            style: TextStyle(
                              fontFamily: 'Pixelify Sans',
                              fontSize: 14,
                              fontVariations: [
                                FontVariation('wght', 400)
                              ],
                              color: appController.isFrameConnected ? Colors.green : Colors.red,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                '${appController.batteryLevel}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 5),
                              Transform.rotate(
                                angle: 90 * 3.14159 / 180, // 90 degrees in radians
                                child: _buildBatteryIcon(appController.batteryLevel),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatteryIcon(int batteryLevel) {
    IconData iconData;
    Color color;

    if (batteryLevel >= 90) {
      iconData = Icons.battery_full;
      color = Colors.green;
    } else if (batteryLevel >= 70) {
      iconData = Icons.battery_6_bar;
      color = Colors.green;
    } else if (batteryLevel >= 50) {
      iconData = Icons.battery_4_bar;
      color = Colors.orange;
    } else if (batteryLevel >= 30) {
      iconData = Icons.battery_3_bar;
      color = Colors.orange;
    } else if (batteryLevel >= 15) {
      iconData = Icons.battery_2_bar;
      color = Colors.red;
    } else {
      iconData = Icons.battery_1_bar;
      color = Colors.red;
    }

    return Icon(iconData, color: color, size: 20);
  }

  void _showColorOptionsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Color.fromRGBO(35, 35, 35, 1),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 20.0),
                child: Text(
                  'Customize your Frame',
                  style: TextStyle(
                    fontFamily: 'Pixelify Sans',
                    fontSize: 22,
                    fontVariations: [
                      FontVariation('wght', 450),
                    ],
                    color: Colors.white,
                  ),
                ),
              ),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: 0.8,
                children: [
                  _buildColorOption('Smokey black', 'assets/images/frameSelector_smokeyBlack.png'),
                  _buildColorOption('Cool gray', 'assets/images/frameSelector_coolGray.png'),
                  _buildColorOption('H20', 'assets/images/frameSelector_h20.png'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildColorOption(String color, String imagePath) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedColor = color;
        });
        _saveSelectedColor(color);
        Navigator.pop(context);
        // Force a rebuild of the ModelViewer
        setState(() {});
      },
      child: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Color.fromRGBO(42, 42, 42, 1),
          borderRadius: BorderRadius.circular(0),
          border: Border.all(
            color: _selectedColor == color ? Colors.white : Colors.transparent,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                color,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: _selectedColor == color ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(BuildContext context, String title, String subtitle, IconData icon) {
    return GestureDetector(
      onTap: () {
        if (title == 'Miles') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MilesHistory()),
          );
        } else if (title == 'Notes') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => NotesPage()),
          );
        } else if (title == 'App Settings') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => StringsSettingsPage()),
          );
        } else if (title == 'Tune') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => TunePage()),
          );
        } else if (title == 'App Store') { // Add this block
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AppStorePage()),
          );
        } else {
          // Placeholder for other navigation options
          print('Navigating to $title page');
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Color.fromRGBO(42, 42, 42, 1),
          borderRadius: BorderRadius.circular(0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Icon(icon, color: Colors.white, size: 25),
              ),
              Spacer(),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Pixelify Sans',
                  color: Colors.white, 
                  fontSize: 17, 
                  fontVariations: [
                    FontVariation('wght', 450),
                  ],
                ),
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: Colors.white, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}