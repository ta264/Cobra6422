import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'ble_manager.dart';

class TouchKeysPage extends StatefulWidget {
  final BLEManager bleManager;

  const TouchKeysPage({Key? key, required this.bleManager}) : super(key: key);

  @override
  TouchKeysPageState createState() => TouchKeysPageState();
}

String formatCobraValue(List<int> hexBytes) {
  List<String> formattedLines = [];
  for (int i = 0; i < hexBytes.length; i += 8) {
    List<int> chunk = hexBytes.sublist(i, i + 8);
    bool allZeroes = chunk.every((byte) => byte == 0);
    if (!allZeroes) {
      formattedLines.add(chunk
          .sublist(1, 7)
          .map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join('')
          .replaceAllMapped(
              RegExp(r'([A-F0-9]{4})'), (match) => '${match[1]} '));
    }
  }
  return formattedLines.join('\n');
}

class TouchKeysPageState extends State<TouchKeysPage> {
  Future<void> _refreshData() async {
    // Simulate refreshing data (replace this with actual BLE refresh logic)
    await widget.bleManager.refreshData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Touch Keys'),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData, // Refresh logic
        child: ListView(
          children: [
            // Top half as a Card: Display the most recent value of a characteristic
            SizedBox(
              width: double.infinity,
              child: Card(
                margin: const EdgeInsets.all(10),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: StreamBuilder<List<int>>(
                    stream: widget.bleManager.latestCobraValueStream,
                    initialData: widget.bleManager.latestCobraValue,
                    builder: (context, snapshot) {
                      String text = 'Reading data...';
                      TextStyle style = const TextStyle(fontSize: 16);
                      if (snapshot.data!.isNotEmpty) {
                        text = formatCobraValue(snapshot.data!);
                        style = GoogleFonts.robotoMono(fontSize: 16);
                      }
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Stored Touch Keys',
                            style: TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 10),
                          Text(text, textAlign: TextAlign.center, style: style),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),

            // Bottom half as a Card: Display the list of touch keys or a placeholder if empty
            Card(
              margin: const EdgeInsets.all(10),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'New Touch Keys',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                    SizedBox(
                      //height: 200,
                      child: StreamBuilder<List<List<int>>>(
                        stream: widget.bleManager.programmerTouchKeysStream,
                        initialData: widget.bleManager.programmerTouchKeys,
                        builder: (context, snapshot) {
                          final touchKeys = snapshot.data!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: touchKeys.isNotEmpty
                                ? touchKeys.map((key) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 2.0),
                                      child: Text(
                                        formatCobraValue(key),
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.robotoMono(
                                            fontSize: 16),
                                      ),
                                    );
                                  }).toList()
                                : [
                                    const Center(
                                      child: Text(
                                        'Touch new key to reader',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontStyle: FontStyle.italic),
                                      ),
                                    ),
                                  ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: widget.bleManager.clearProgrammerTouchKeys,
                          child: const Text('Clear'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            widget.bleManager.programmerTouchKeyWriteToCobra();
                          },
                          child: const Text('Write'),
                        ),
                      ],
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
}
