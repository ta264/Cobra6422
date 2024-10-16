import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_manager.dart';

class TouchKeysPage extends StatefulWidget {
  final BLEManager bleManager;

  const TouchKeysPage({Key? key, required this.bleManager}) : super(key: key);

  @override
  _TouchKeysPageState createState() => _TouchKeysPageState();
}

class _TouchKeysPageState extends State<TouchKeysPage> {
  List<List<int>> touchKeys = [];

  @override
  void initState() {
    super.initState();
    _subscribeToCharacteristic();
  }

  Future<void> _subscribeToCharacteristic() async {
    // Replace with your actual service and characteristic UUIDs
    const String serviceUuid =
        '7065ed39-77d1-48e6-8e7c-7227550243c3'; // Touchkey service
    const String characteristicUuid =
        'd55282ce-37ba-4be9-9194-26c89f49b218'; // Touchkey characteristic

    BluetoothCharacteristic? characteristic = await widget.bleManager
        .getCharacteristic(serviceUuid, characteristicUuid);

    if (characteristic != null) {
      // Enable notifications
      await characteristic.setNotifyValue(true);

      // Listen to characteristic value changes
      characteristic.value.listen((value) {
        if (value.isNotEmpty) {
          setState(() {
            touchKeys.add(value);

            // Keep only the last 4 values
            if (touchKeys.length > 4) {
              touchKeys.removeAt(0);
            }
          });
        }
      });
    }
  }

  // Helper method to format the list of integers as hexadecimal
  String formatAsHex(List<int> value) {
    return value
        .map((int byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
  }

  // Clear the list of touch keys
  void _clearTouchKeys() {
    setState(() {
      touchKeys.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Touch keys received:',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: touchKeys.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 0.0), // Adjust the padding as needed
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 8.0), // Reduced padding
                      title: Text(formatAsHex(touchKeys[index])),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _clearTouchKeys,
        child: Icon(Icons.clear),
        tooltip: 'Clear Touch Keys',
      ),
    );
  }
}
