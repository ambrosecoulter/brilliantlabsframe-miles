import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_controller.dart';
import 'package:intl/intl.dart';

class MilesHistory extends StatelessWidget {
  const MilesHistory({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print("Building MilesHistory widget");
    final ScrollController scrollController = ScrollController();

    return Consumer<AppController>(
      builder: (context, appController, child) {
        print("MilesHistory consumer rebuilding");
        print("Interaction history length: ${appController.interactionHistory.length}");
        print("Is initialized: ${appController.isInitialized}");

        return Scaffold(
          backgroundColor: Color.fromRGBO(35, 35, 35, 1),
          appBar: AppBar(
            title: const Text('Interaction History', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Colors.white,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                color: Color.fromRGBO(35, 35, 35, 1),
              ),
            ),
          ),
          body: !appController.isInitialized
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text("Initializing...", style: TextStyle(color: Colors.white)),
                    ],
                  ),
                )
              : appController.groupedInteractionHistory.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: appController.groupedInteractionHistory.length,
                      itemBuilder: (context, index) {
                        final group = appController.groupedInteractionHistory[index];
                        final DateTime timestamp = group.timestamp;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 40, left: 42, right: 42),
                              child: Row(
                                children: [
                                  Text(
                                    DateFormat('HH:mm').format(timestamp),
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                  const Flexible(
                                    child: Divider(
                                      indent: 10,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ...group.interactions.map((interaction) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 10, left: 65, right: 42),
                                  child: Text(
                                    '${interaction['prompt']}',
                                    style: const TextStyle(color: Color.fromRGBO(247, 252, 170, 1)),
                                  ),
                                ),
                                Container(
                                  margin: const EdgeInsets.only(top: 10, left: 65, right: 42),
                                  child: Text(
                                    '${interaction['response']}',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            )).toList(),
                          ],
                        );
                      },
                      padding: const EdgeInsets.only(bottom: 40),
                    ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.white70),
          SizedBox(height: 16),
          Text(
            'No interactions yet',
            style: TextStyle(fontSize: 18, color: Colors.white70),
          ),
          SizedBox(height: 8),
          Text(
            'Start interacting with Miles',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}