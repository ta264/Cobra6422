import 'package:flutter/material.dart';
import 'ble_manager.dart';

class BackupPage extends StatefulWidget {
  final BLEManager bleManager;

  const BackupPage({Key? key, required this.bleManager}) : super(key: key);

  @override
  _BackupPageState createState() => _BackupPageState();
}

String formatCobraValue(List<int> hexBytes) {
  // Split the latestCobraValue into a list of hex byte strings (2 chars per byte)
  List<String> formattedLines = [];

  // Iterate over the hexBytes in chunks of 32 bytes
  for (int i = 0; i < hexBytes.length; i += 32) {
    // Get a chunk of 32 bytes
    List<int> chunk = hexBytes.sublist(
        i, i + 32 > hexBytes.length ? hexBytes.length : i + 32);

    // Convert chunk into hex string with space after every 2 pairs of hex digits
    String formattedChunk = chunk
        .map((e) =>
            e.toRadixString(16).padLeft(2, '0').toUpperCase()) // Convert to hex
        .join('') // Join hex bytes without spaces
        .replaceAllMapped(
            RegExp(r'([A-F0-9]{4})'),
            (match) =>
                '${match[1]} '); // Add space after every 4 characters (2 hex pairs)

    formattedLines.add(formattedChunk.trim()); // Trim to remove trailing space
  }

  // Join the lines with a newline separator
  return formattedLines.join('\n');
}

class _BackupPageState extends State<BackupPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Backup'),
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
                  stream: widget.bleManager.eepromStream,
                  initialData: widget.bleManager.latestEepromValue,
                  builder: (context, snapshot) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'EEPROM contents:',
                          style: TextStyle(fontSize: 18),
                        ),
                        SizedBox(height: 10),
                        Text(
                          snapshot.data!.isNotEmpty
                              ? formatCobraValue(snapshot.data!)
                              : 'No data yet',
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

          // "Write" button at the bottom
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () {
                widget.bleManager
                    .programmerTouchKeyWriteToCobra(); // Write operation triggered from BLEManager
              },
              child: Text('Write'),
            ),
          ),
        ],
      ),
    );
  }
}
