import 'package:flutter/material.dart';
import 'available_apps.dart';

class AppStorePage extends StatefulWidget {
  @override
  _AppStorePageState createState() => _AppStorePageState();
}

class _AppStorePageState extends State<AppStorePage> {
  List<String> activatedApps = [];
  Map<String, Map<String, String>> appConfigs = {};

  @override
  void initState() {
    super.initState();
    _loadActivatedApps();
  }

  Future<void> _loadActivatedApps() async {
    final apps = await AvailableApps.getActivatedApps();
    final configs = <String, Map<String, String>>{};
    for (final appUuid in apps) {
      configs[appUuid] = await AvailableApps.getAppConfig(appUuid);
    }
    setState(() {
      activatedApps = apps;
      appConfigs = configs;
    });
  }

  Future<void> _showAppDetailsModal(String appName, AppTool appTool) async {
    final isActivated = activatedApps.contains(appName);
    final hasConfigFields = appTool.configFields != null && appTool.configFields!.isNotEmpty;
    final config = Map<String, String>.from(appConfigs[appName] ?? {});
    bool isConfigComplete = false;
    bool showConfigFields = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Color.fromRGBO(35, 35, 35, 1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  left: 16,
                  right: 16,
                  top: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          appTool.app_title ?? '', // Add null check here
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Color.fromRGBO(42, 42, 42, 1),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Text(
                      appTool.app_description ?? '', // Add null check here
                      style: TextStyle(color: Colors.white),
                    ),
                    SizedBox(height: 16),
                    if (showConfigFields && hasConfigFields) ...[
                      ...appTool.configFields!.map((field) {
                        return Container(
                          margin: EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Color.fromRGBO(42, 42, 42, 1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: TextField(
                            style: TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: field,
                              labelStyle: TextStyle(color: Colors.white70),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(16),
                            ),
                            onChanged: (value) {
                              config[field] = value;
                              setModalState(() {
                                isConfigComplete = config.length == appTool.configFields!.length &&
                                    config.values.every((v) => v.isNotEmpty);
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ],
                    if (!isActivated) // Add this condition to hide the button if the app is already added
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color.fromRGBO(247, 252, 170, 1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () {
                            print("Setup button pressed"); // Debug print
                            if (hasConfigFields && !showConfigFields) {
                              print("Showing config fields"); // Debug print
                              setModalState(() {
                                showConfigFields = true;
                              });
                            } else if (hasConfigFields && !isConfigComplete) {
                              print("Config incomplete"); // Debug print
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Please fill all required fields')),
                              );
                            } else {
                              print("Activating app"); // Debug print
                              _activateApp(appName, config, hasConfigFields);
                            }
                          },
                          child: Text(
                            hasConfigFields ? (showConfigFields ? 'Complete Setup' : 'Setup App') : 'Add App',
                            style: TextStyle(color: Colors.black),
                          ),
                        ),
                      ),
                    if (isActivated)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () async {
                            await AvailableApps.deactivateApp(appName);
                            await _loadActivatedApps();
                            Navigator.of(context).pop();
                          },
                          child: Text(
                            'Remove App',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _activateApp(String appName, Map<String, String> config, bool hasConfigFields) async {
    try {
      if (hasConfigFields) {
        print("Saving config: $config"); // Debug print
        await AvailableApps.setAppConfig(appName, config);
      }
      await AvailableApps.activateApp(appName);
      await _loadActivatedApps();
      Navigator.of(context).pop();
    } catch (e) {
      print("Error in setup button: $e"); // Debug print
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(35, 35, 35, 1),
      appBar: AppBar(
        title: Text('App Store', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: Color.fromRGBO(35, 35, 35, 1),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildAppList(),
    );
  }

  Widget _buildAppList() {
    return AvailableApps.tools.isEmpty
        ? Center(child: Text('No apps available.', style: TextStyle(color: Colors.white)))
        : ListView.builder(
            padding: EdgeInsets.all(8),
            itemCount: AvailableApps.tools.length,
            itemBuilder: (context, index) {
              final appUuid = AvailableApps.tools.keys.elementAt(index);
              final appTool = AvailableApps.tools[appUuid]!;
              final isActivated = activatedApps.contains(appUuid);

              return Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () => _showAppDetailsModal(appUuid, appTool),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color.fromRGBO(42, 42, 42, 1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Color.fromRGBO(51, 51, 51, 1),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  appTool.app_title ?? '',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color.fromRGBO(247, 252, 170, 1),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isActivated)
                                Icon(Icons.check, color: Colors.green, size: 18),
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            appTool.app_description ?? '',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
  }

  // ... existing _showAppDetailsModal method ...
}
