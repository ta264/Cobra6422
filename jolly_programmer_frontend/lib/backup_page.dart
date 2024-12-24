import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'ble_manager.dart';

class BackupPage extends StatefulWidget {
  final BLEManager bleManager;

  const BackupPage({Key? key, required this.bleManager}) : super(key: key);

  @override
  BackupPageState createState() => BackupPageState();
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

class BackupPageState extends State<BackupPage> {
  Future<void> _refreshData() async {
    await widget.bleManager.refreshData();
  }

  Future<void> _saveEEPROMToFile(List<int> eepromData) async {
    try {
      final String isoTimestamp =
          DateTime.now().toIso8601String().replaceAll(':', '-');

      String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Choose backup file location',
          fileName: '6422_backup_$isoTimestamp.bin',
          bytes: Uint8List.fromList(eepromData));

      if (outputFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Save cancelled')),
        );
        return;
      }

      if (!Platform.isAndroid) {
        File file = File(outputFile);
        await file.writeAsBytes(eepromData);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('EEPROM data saved to $outputFile')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save file: $e')),
      );
    }
  }

  Future<void> _loadAndWriteEEPROM() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['bin'],
      );

      if (result != null && result.files.single.path != null) {
        final String filePath = result.files.single.path!;
        File file = File(filePath);

        List<int> fileBytes = await file.readAsBytes();

        if (verifyEEPROMData(fileBytes)) {
          widget.bleManager.writeEEPROM(fileBytes);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('EEPROM data written from $filePath')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Invalid EEPROM data. Must be 128 bytes.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File selection canceled.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load file: $e')),
      );
    }
  }

  bool verifyEEPROMData(List<int> eepromData) {
    return eepromData.length == 128 &&
        eepromData.every((element) => element >= 0 && element <= 255);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup'),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: ListView(
          children: [
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
                          const Text(
                            'EEPROM contents',
                            style: TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            snapshot.data!.isNotEmpty
                                ? formatCobraValue(snapshot.data!)
                                : 'Reading data...',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      final eepromData = widget.bleManager.latestEepromValue;
                      if (eepromData.isNotEmpty) {
                        _saveEEPROMToFile(eepromData);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('No EEPROM data to save.')),
                        );
                      }
                    },
                    child: const Text('Save EEPROM to File'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _loadAndWriteEEPROM,
                    child: const Text('Load EEPROM from File and Write'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
