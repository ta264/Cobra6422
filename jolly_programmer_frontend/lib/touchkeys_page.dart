import 'package:flutter/material.dart';
import 'ble_manager.dart';

class TouchKeysPage extends StatefulWidget {
  final BLEManager bleManager;

  const TouchKeysPage({Key? key, required this.bleManager}) : super(key: key);

  @override
  _TouchKeysPageState createState() => _TouchKeysPageState();
}

String formatCobraValue(List<int> hexBytes) {
  // Split the latestCobraValue into a list of hex byte strings (2 chars per byte)
  List<String> formattedLines = [];

  // Iterate over the hexBytes in chunks of 8 bytes
  for (int i = 0; i < hexBytes.length; i += 8) {
    // Get a chunk of 8 bytes
    List<int> chunk = hexBytes.sublist(i, i + 8);

    // Check if all bytes in the chunk are '00'
    bool allZeroes = chunk.every((byte) => byte == 0);

    // Only add the line if not all 6 bytes are zero
    if (!allZeroes) {
      // Join the chunk back into a line and add to the result
      formattedLines.add(chunk
          .sublist(1, 7)
          .map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join('')
          .replaceAllMapped(
              RegExp(r'([A-F0-9]{4})'), (match) => '${match[1]} '));
    }
  }

  // Join the lines with a newline separator
  return formattedLines.join('\n');
}

class _TouchKeysPageState extends State<TouchKeysPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Touch Keys'),
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
                child: StreamBuilder<List<int>>(
                  stream: widget.bleManager.latestCobraValueStream,
                  initialData: widget.bleManager.latestCobraValue,
                  builder: (context, snapshot) {
                    String text = snapshot.data!.isNotEmpty
                        ? formatCobraValue(snapshot.data!)
                        : 'No data yet';
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Stored Touch Keys',
                          style: TextStyle(fontSize: 18),
                        ),
                        SizedBox(height: 10),
                        Text(
                          text,
                          textAlign: TextAlign.center,
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
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'New Touch Keys',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                    Expanded(
                      child: StreamBuilder<List<List<int>>>(
                        stream: widget.bleManager.programmerTouchKeysStream,
                        initialData: widget.bleManager.programmerTouchKeys,
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
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 8.0),
                                        child: Text(
                                          formatCobraValue(touchKeys[index]),
                                          textAlign: TextAlign.center,
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
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: widget.bleManager.clearProgrammerTouchKeys,
                          child: Text('Clear'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            // Write the new touch keys
                            widget.bleManager.programmerTouchKeyWriteToCobra();
                          },
                          child: Text('Write'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
