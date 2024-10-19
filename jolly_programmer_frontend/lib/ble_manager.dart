import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';

class BLEManager {
  static const String TOUCHKEY_SERVICE_UUID =
      "7065ed39-77d1-48e6-8e7c-7227550243c3";
  static const String TOUCHKEY_READ_CHARACTERISTIC_UUID =
      "d55282ce-37ba-4be9-9194-26c89f49b218";

  static const String COBRA_6422_SERVICE_UUID =
      "4e4cabae-e1d9-44c4-94f4-d2c269d6093b";
  static const String C6422_STATUS_CHARACTERISTIC_UUID =
      "4d970ade-6239-4c88-9a1c-2c544df31034";
  static const String EEPROM_CHARACTERISTIC_UUID =
      "8d2d0e29-853d-4c21-929b-b1233e987c60";
  static const String TOUCHKEY_CHARACTERISTIC_UUID =
      "a755d6b7-1605-4eca-bf4c-73de844f82f8";
  static const String IMMOB_CHARACTERISTIC_UUID =
      "76a2563f-5759-4463-87fe-a684e8adcefa";

  static const String COBRA_1984_SERVICE_UUID =
      "eb3df65a-06e3-4a42-b790-73b5caea9dc9";
  static const String C1984_CODE_CHARACTERISTIC_UUID =
      "d0ca177f-e266-4554-9dbb-1a0ca97c90c4";

  BluetoothDevice? _connectedDevice;
  List<BluetoothService> _services = [];

  // Store characteristics
  BluetoothCharacteristic?
      _cobraTouchKeyCharacteristic; // Store cobraTouchKey characteristic
  BluetoothCharacteristic?
      _programmerTouchKeyCharacteristic; // Store programmerTouchKey characteristic

  // State for the cobraTouchKey characteristic (latest value) and programmer touch key list
  String _latestCobraValue = "";
  List<List<int>> _programmerTouchKeys = [];

  // Stream controllers for the cobraTouchKey characteristic and programmerTouchKeys
  final StreamController<String> _latestCobraValueController =
      StreamController<String>.broadcast();
  final StreamController<List<List<int>>> _programmerTouchKeysController =
      StreamController<List<List<int>>>.broadcast();

  // Singleton pattern for BLEManager
  static final BLEManager _instance = BLEManager._internal();
  factory BLEManager() {
    return _instance;
  }

  BLEManager._internal();

  // Getters for streams
  Stream<String> get latestCobraValueStream =>
      _latestCobraValueController.stream;
  Stream<List<List<int>>> get programmerTouchKeysStream =>
      _programmerTouchKeysController.stream;

  // Get current latest cobra value and programmer touch keys (for initial UI state)
  String get latestCobraValue => _latestCobraValue;
  List<List<int>> get programmerTouchKeys => _programmerTouchKeys;

  // Method to start scanning and connect to a BLE device
  Future<void> scanAndConnect() async {
    if (_connectedDevice != null) {
      return; // Already connected
    }

    // Start scanning for BLE devices
    FlutterBluePlus.startScan(
        timeout: Duration(seconds: 4),
        withServices: [Guid(COBRA_6422_SERVICE_UUID)]);
    FlutterBluePlus.scanResults.listen((results) async {
      if (results.isNotEmpty) {
        final device = results.first.device;
        await _connectToDevice(device);
        FlutterBluePlus.stopScan();
      }
    });
  }

  // Connect to a BLE device and discover services
  Future<void> _connectToDevice(BluetoothDevice device) async {
    await device.connect();
    _connectedDevice = device;

    // Discover services and cache characteristics
    _services = await device.discoverServices();
    _cacheCharacteristics();
  }

  // Helper method to find a characteristic by UUID
  BluetoothCharacteristic? _findCharacteristic(
      String serviceUuid, String characteristicUuid) {
    for (BluetoothService service in _services) {
      if (service.uuid.toString() == serviceUuid) {
        for (BluetoothCharacteristic characteristic
            in service.characteristics) {
          if (characteristic.uuid.toString() == characteristicUuid) {
            return characteristic;
          }
        }
      }
    }
    return null;
  }

  // Cache the characteristics for future use
  void _cacheCharacteristics() {
    _programmerTouchKeyCharacteristic = _findCharacteristic(
        TOUCHKEY_SERVICE_UUID, TOUCHKEY_READ_CHARACTERISTIC_UUID);
    _cobraTouchKeyCharacteristic = _findCharacteristic(
        COBRA_6422_SERVICE_UUID, TOUCHKEY_CHARACTERISTIC_UUID);

    // Subscribe to characteristics after caching them
    _subscribeToProgrammerTouchKeyCharacteristic();
    _subscribeToCobraTouchKeyCharacteristic();
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
            .join(' '));
      }
    }

    // Join the lines with a newline separator
    return formattedLines.join('\n');
  }

  // Subscribe to the cobraTouchKey characteristic
  Future<void> _subscribeToCobraTouchKeyCharacteristic() async {
    if (_cobraTouchKeyCharacteristic != null) {
      await _cobraTouchKeyCharacteristic!
          .setNotifyValue(true); // Enable notifications

      _cobraTouchKeyCharacteristic!.lastValueStream.listen((value) {
        if (value.isNotEmpty) {
          _latestCobraValue = formatCobraValue(value);
          _latestCobraValueController
              .add(_latestCobraValue); // Add latest cobra value to stream
        }
      });
    }
  }

  // Subscribe to the programmerTouchKey characteristic
  Future<void> _subscribeToProgrammerTouchKeyCharacteristic() async {
    if (_programmerTouchKeyCharacteristic != null) {
      await _programmerTouchKeyCharacteristic!
          .setNotifyValue(true); // Enable notifications

      _programmerTouchKeyCharacteristic!.lastValueStream.listen((value) {
        if (value.isNotEmpty) {
          // Check if the value differs from the last value
          if (_programmerTouchKeys.isEmpty ||
              _programmerTouchKeys.last.toString() != value.toString()) {
            _programmerTouchKeys.add(
                List.from(value)); // Clone the value to ensure immutability
            if (_programmerTouchKeys.length > 4) {
              _programmerTouchKeys.removeAt(0); // Keep only the last 4 values
            }
            _programmerTouchKeysController.add(List.from(
                _programmerTouchKeys)); // Emit a new instance of the list
          }
        }
      });
    }
  }

  // Write the most recent 4 programmer touch keys to the cobraTouchKey characteristic
  Future<void> programmerTouchKeyWriteToCobra() async {
    if (_cobraTouchKeyCharacteristic != null &&
        _cobraTouchKeyCharacteristic!.properties.write) {
      // Flatten the most recent 4 programmer touch keys into a single list of integers
      List<int> flattenedTouchKeys =
          _programmerTouchKeys.expand((element) => element).toList();

      if (flattenedTouchKeys.isNotEmpty) {
        await _cobraTouchKeyCharacteristic!
            .write(flattenedTouchKeys, withoutResponse: false);
        print(
            'Most recent 4 programmer touch keys written to cobraTouchKey characteristic');
        clearProgrammerTouchKeys();
      } else {
        print('No programmer touch keys available to write.');
      }
    } else {
      print('Write not supported for cobraTouchKey characteristic.');
    }
  }

  // Clear the list of programmer touch keys
  void clearProgrammerTouchKeys() {
    _programmerTouchKeys.clear();
    _programmerTouchKeysController.add(List.from(
        _programmerTouchKeys)); // Notify listeners with a new instance
  }

  // Dispose stream controllers
  void dispose() {
    _latestCobraValueController.close();
    _programmerTouchKeysController.close();
  }
}
