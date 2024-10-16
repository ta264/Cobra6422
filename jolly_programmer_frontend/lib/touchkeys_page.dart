import 'package:flutter/material.dart';
import 'ble_manager.dart';

class TouchKeysPage extends StatefulWidget {
  final BLEManager bleManager;

  const TouchKeysPage({Key? key, required this.bleManager}) : super(key: key);

  @override
  _TouchKeysPageState createState() => _TouchKeysPageState();
}

class _TouchKeysPageState extends State<TouchKeysPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Touchkeys'),
      ),
      body: Column(
        children: [
          // Top half as a Card: Display the most recent value of a characteristic
          SizedBox(
            width: double
                .infinity, // Make the card take the full width of the screen
            child: Card(
              margin: const EdgeInsets.all(10),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: StreamBuilder<String>(
                  stream: widget.bleManager.latestValueStream,
                  initialData: widget.bleManager.latestValue,
                  builder: (context, snapshot) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Stored touchkeys:',
                          style: TextStyle(fontSize: 18),
                        ),
                        SizedBox(height: 10),
                        Text(
                          snapshot.data!.isNotEmpty
                              ? snapshot.data!
                              : 'No data yet',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),

          // Bottom half as a Card: Display the list of touch keys or a placeholder if empty
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
                    child: StreamBuilder<List<List<int>>>(
                      stream: widget.bleManager.touchKeysStream,
                      initialData: widget.bleManager.touchKeys,
                      builder: (context, snapshot) {
                        final touchKeys = snapshot.data!;
                        return touchKeys.isNotEmpty
                            ? ListView.builder(
                                itemCount: touchKeys.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 2.0),
                                    child: Container(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 8.0),
                                      child: Text(
                                        touchKeys[index]
                                            .map((byte) => byte
                                                .toRadixString(16)
                                                .padLeft(2, '0')
                                                .toUpperCase())
                                            .join(' '),
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
                                      fontSize: 16,
                                      fontStyle: FontStyle.italic),
                                ),
                              );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: widget.bleManager.clearTouchKeys,
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
              onPressed: () {
                //widget.bleManager._writeToCharacteristic(); // Write operation triggered from BLEManager
              },
              child: Text('Write'),
            ),
          ),
        ],
      ),
    );
  }
}
