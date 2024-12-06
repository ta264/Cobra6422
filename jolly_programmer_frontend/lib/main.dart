import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:jolly_programmer_frontend/backup_page.dart';
import 'package:jolly_programmer_frontend/immobiliser_page.dart';
import 'ble_manager.dart';
import 'touchkeys_page.dart';
import 'loading_screen.dart';

/// Flutter code sample for [NavigationBar].

void main() {
  FlutterBluePlus.setLogLevel(LogLevel.verbose, color: true);
  runApp(const NavigationBarApp());
}

class NavigationBarApp extends StatelessWidget {
  const NavigationBarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: const NavigationExample(),
    );
  }
}

class NavigationExample extends StatefulWidget {
  const NavigationExample({super.key});

  @override
  State<NavigationExample> createState() => _NavigationExampleState();
}

class _NavigationExampleState extends State<NavigationExample> {
  int currentPageIndex = 0;
  final BLEManager _bleManager = BLEManager(); // Instantiate BLEManager

  @override
  void initState() {
    super.initState();
    _bleManager
        .scanAndConnect(); // Start scanning and connecting to a BLE device
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() {
            currentPageIndex = index;
          });
        },
        indicatorColor: Colors.amber,
        selectedIndex: currentPageIndex,
        destinations: const <Widget>[
          NavigationDestination(
            selectedIcon: Icon(Icons.key),
            icon: Icon(Icons.key_outlined),
            label: 'Touchkeys',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.https),
            icon: Icon(Icons.https_outlined),
            label: 'Immobiliser',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.settings_backup_restore),
            icon: Icon(Icons.settings_backup_restore_outlined),
            label: 'Backup',
          ),
        ],
      ),
      body: StreamBuilder<bool>(
        stream: _bleManager.connectionStateStream,
        initialData: false, // Assume initially disconnected
        builder: (context, snapshot) {
          if (snapshot.data == false) {
            // Show loading screen while waiting for BLE connection
            return const LoadingScreen(message: 'Connecting to programmer...');
          } else {
            // Show the main navigation body when connected
            return <Widget>[
              TouchKeysPage(bleManager: _bleManager),
              ImmobiliserPage(bleManager: _bleManager),
              BackupPage(bleManager: _bleManager)
            ][currentPageIndex];
          }
        },
      ),
    );
  }
}
