import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';

class BLEManager {
  FlutterBluePlus flutterBlue = FlutterBluePlus(); // Instance for managing BLE
  BluetoothDevice? _connectedDevice;
  List<BluetoothService> _services = [];

  // State for the top characteristic (latest value) and touch key list
  String _latestValue = "";
  List<List<int>> _touchKeys = [];

  // Stream controllers for the top characteristic and touch keys
  final StreamController<String> _latestValueController =
      StreamController<String>.broadcast();
  final StreamController<List<List<int>>> _touchKeysController =
      StreamController<List<List<int>>>.broadcast();

  // Singleton pattern for BLEManager
  static final BLEManager _instance = BLEManager._internal();
  factory BLEManager() {
    return _instance;
  }

  BLEManager._internal();

  // Getters for streams
  Stream<String> get latestValueStream => _latestValueController.stream;
  Stream<List<List<int>>> get touchKeysStream => _touchKeysController.stream;

  // Get current latest value and touch keys (for initial UI state)
  String get latestValue => _latestValue;
  List<List<int>> get touchKeys => _touchKeys;

  // Method to start scanning and connect to a BLE device
  Future<void> scanAndConnect() async {
    if (_connectedDevice != null) {
      return; // Already connected
    }

    // Start scanning for BLE devices
    FlutterBluePlus.startScan(
        timeout: Duration(seconds: 4),
        withServices: [Guid("4e4cabae-e1d9-44c4-94f4-d2c269d6093b")]);
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

    // Discover services
    _services = await device.discoverServices();

    // Subscribe to characteristics
    _subscribeToTopCharacteristic();
    _subscribeToTouchKeyCharacteristic();
  }

  // Subscribe to the top characteristic
  Future<void> _subscribeToTopCharacteristic() async {
    final String serviceUuid =
        '7065ed39-77d1-48e6-8e7c-7227550243c3'; // Example service UUID
    final String characteristicUuid =
        '12345678-1234-5678-1234-567812345678'; // Example characteristic UUID

    BluetoothCharacteristic? characteristic =
        _findCharacteristic(serviceUuid, characteristicUuid);

    if (characteristic != null) {
      await characteristic
          .setNotifyValue(true); // Ensure notifications are enabled

      characteristic.lastValueStream.listen((value) {
        if (value.isNotEmpty) {
          _latestValue = value
              .map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase())
              .join(' ');
          _latestValueController
              .add(_latestValue); // Add latest value to stream
        }
      });
    }
  }

  // Subscribe to the touch keys characteristic
  Future<void> _subscribeToTouchKeyCharacteristic() async {
    final String serviceUuid =
        '7065ed39-77d1-48e6-8e7c-7227550243c3'; // Touchkey service UUID
    final String characteristicUuid =
        'd55282ce-37ba-4be9-9194-26c89f49b218'; // Touchkey characteristic UUID

    BluetoothCharacteristic? characteristic =
        _findCharacteristic(serviceUuid, characteristicUuid);

    if (characteristic != null) {
      await characteristic
          .setNotifyValue(true); // Ensure notifications are enabled

      characteristic.lastValueStream.listen((value) {
        if (value.isNotEmpty) {
          // Check if the value differs from the last value
          if (_touchKeys.isEmpty ||
              _touchKeys.last.toString() != value.toString()) {
            _touchKeys.add(
                List.from(value)); // Clone the value to ensure immutability
            if (_touchKeys.length > 4) {
              _touchKeys.removeAt(0); // Keep only the last 4 values
            }
            _touchKeysController
                .add(List.from(_touchKeys)); // Emit a new instance of the list
          }
        }
      });
    }
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

  // Clear the list of touch keys
  void clearTouchKeys() {
    _touchKeys.clear();
    _touchKeysController
        .add(List.from(_touchKeys)); // Notify listeners with a new instance
  }

  // Dispose stream controllers
  void dispose() {
    _latestValueController.close();
    _touchKeysController.close();
  }
}
