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
  String latestValue = ""; // Store the latest value for the top half
  final String topCharacteristicUuid =
      '12345678-1234-5678-1234-567812345678'; // Example UUID for top half
  final String bottomTouchKeyCharacteristicUuid =
      'd55282ce-37ba-4be9-9194-26c89f49b218'; // Touchkey characteristic UUID
  final String writeCharacteristicUuid =
      '9abcdef0-1234-5678-1234-56789abcdef0'; // Example UUID for write characteristic

  @override
  void initState() {
    super.initState();
    _subscribeToTopCharacteristic();
    _subscribeToTouchKeyCharacteristic();
  }

  // Subscribe to the characteristic for the top half (most recent value only)
  Future<void> _subscribeToTopCharacteristic() async {
    final String serviceUuid =
        '7065ed39-77d1-48e6-8e7c-7227550243c3'; // Example service UUID for top

    BluetoothCharacteristic? characteristic = await widget.bleManager
        .getCharacteristic(serviceUuid, topCharacteristicUuid);

    if (characteristic != null) {
      // Enable notifications
      await characteristic.setNotifyValue(true);

      // Listen to the characteristic's most recent value
      characteristic.lastValueStream.listen((value) {
        if (value.isNotEmpty) {
          setState(() {
            latestValue = value
                .map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase())
                .join(' ');
          });
        }
      });
    }
  }

  // Subscribe to the touch keys characteristic (bottom half)
  Future<void> _subscribeToTouchKeyCharacteristic() async {
    final String serviceUuid =
        '7065ed39-77d1-48e6-8e7c-7227550243c3'; // Touchkey service

    BluetoothCharacteristic? characteristic = await widget.bleManager
        .getCharacteristic(serviceUuid, bottomTouchKeyCharacteristicUuid);

    if (characteristic != null) {
      // Enable notifications
      await characteristic.setNotifyValue(true);

      // Listen to characteristic value changes using valueChanges stream
      characteristic.lastValueStream.listen((value) {
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

  // Write to the write characteristic when "Write" button is pressed
  Future<void> _writeToCharacteristic() async {
    final String serviceUuid =
        '7065ed39-77d1-48e6-8e7c-7227550243c3'; // Example service UUID for write

    BluetoothCharacteristic? characteristic = await widget.bleManager
        .getCharacteristic(serviceUuid, writeCharacteristicUuid);

    if (characteristic != null && characteristic.properties.write) {
      await characteristic
          .write([0x01, 0x02, 0x03, 0x04]); // Example data to write
      print('Data written to characteristic');
    } else {
      print('Write not supported for this characteristic.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Touch Keys'),
      ),
      body: Column(
        children: [
          SizedBox(
            width: double
                .infinity, // Make the card take the full width of the screen
            child: Card(
              margin: const EdgeInsets.all(10),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Stored touchkeys:',
                      style: TextStyle(fontSize: 18),
                    ),
                    SizedBox(height: 10),
                    Text(
                      latestValue.isNotEmpty ? latestValue : 'No data yet',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom half as a Card: Display the list of touch keys
          Expanded(
            child: Card(
              margin: const EdgeInsets.all(10),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'New touchkeys:',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                  Expanded(
                    child: touchKeys.isNotEmpty
                        ? ListView.builder(
                            itemCount: touchKeys.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2.0),
                                child: Container(
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 8.0),
                                  child: Text(
                                    formatAsHex(touchKeys[index]),
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ),
                              );
                            },
                          )
                        : Center(
                            child: Text(
                              'Touch new key to reader',
                              style: TextStyle(
                                  fontSize: 16, fontStyle: FontStyle.italic),
                            ),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: _clearTouchKeys,
                      child: Text('Clear'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // "Write" button at the bottom
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: _writeToCharacteristic,
              child: Text('Write'),
            ),
          ),
        ],
      ),
    );
  }
}
