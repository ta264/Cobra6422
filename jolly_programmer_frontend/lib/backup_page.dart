import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'ble_manager.dart';

class BackupPage extends StatefulWidget {
  final BLEManager bleManager;

  const BackupPage({Key? key, required this.bleManager}) : super(key: key);

  @override
  _BackupPageState createState() => _BackupPageState();
}

String formatCobraValue(List<int> hexBytes) {
  List<String> formattedLines = [];
  for (int i = 0; i < hexBytes.length; i += 32) {
    List<int> chunk = hexBytes.sublist(
        i, i + 32 > hexBytes.length ? hexBytes.length : i + 32);
    String formattedChunk = chunk
        .map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join('')
        .replaceAllMapped(RegExp(r'([A-F0-9]{4})'), (match) => '${match[1]} ');
    formattedLines.add(formattedChunk.trim());
  }
  return formattedLines.join('\n');
}

class _BackupPageState extends State<BackupPage> {
  // Method to get the directory for Android's Downloads folder
  Future<String> _getDownloadsDirectory() async {
    Directory? downloadsDir = await getExternalStorageDirectory();
    return downloadsDir!.path;
  }

  // Method to save EEPROM data to a file in a user-accessible location
  Future<void> _saveEEPROMToFile(List<int> eepromData) async {
    try {
      final path = await _getDownloadsDirectory();
      final filePath = '$path/eeprom_backup.bin';

      File file = File(filePath);
      await file.writeAsBytes(eepromData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('EEPROM data saved to $filePath')),
      );

      // If on iOS, trigger the share functionality using share_plus
      //if (Platform.isIOS) {
      await Share.shareXFiles([XFile(filePath)], text: 'Backup of EEPROM data');
      //
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save file: $e')),
      );
    }
  }

  // Method to load and write EEPROM data from the user-accessible file
  Future<void> _loadAndWriteEEPROMFromFile() async {
    try {
      final path = await _getDownloadsDirectory();
      final filePath = '$path/eeprom_backup.bin';
      File file = File(filePath);

      if (await file.exists()) {
        List<int> fileBytes = await file.readAsBytes();

        // Write the file bytes to the EEPROM characteristic
        await widget.bleManager.writeEEPROM(fileBytes);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('EEPROM data written from $filePath')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No backup file found.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load file: $e')),
      );
    }
  }

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
            width: double.infinity,
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

          // "Save" button to save EEPROM contents to a binary file
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () {
                final eepromData = widget.bleManager.latestEepromValue;
                if (eepromData.isNotEmpty) {
                  _saveEEPROMToFile(eepromData);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('No EEPROM data to save.')),
                  );
                }
              },
              child: Text('Save EEPROM to File'),
            ),
          ),

          // "Load and Write" button to load a binary file and write to the EEPROM
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: _loadAndWriteEEPROMFromFile,
              child: Text('Load EEPROM from File and Write'),
            ),
          ),
        ],
      ),
    );
  }
}
