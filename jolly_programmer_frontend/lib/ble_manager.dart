import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';
import 'dart:async';

class BLEManager {
  static const String TOUCHKEY_SERVICE_UUID =
      "7065ed39-77d1-48e6-8e7c-7227550243c3";
  static const String TOUCHKEY_READ_CHARACTERISTIC_UUID =
      "d55282ce-37ba-4be9-9194-26c89f49b218";

  static const String COBRA_6422_SERVICE_UUID =
      "4e4cabae-e1d9-44c4-94f4-d2c269d6093b";
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

  // Reconnection properties
  bool _isReconnecting = false;
  final Duration _reconnectDelay = Duration(seconds: 1);

  BluetoothDevice? _connectedDevice;
  List<BluetoothService> _services = [];

  // Store characteristics
  BluetoothCharacteristic?
      _cobraTouchKeyCharacteristic; // Store cobraTouchKey characteristic
  BluetoothCharacteristic?
      _programmerTouchKeyCharacteristic; // Store programmerTouchKey characteristic
  BluetoothCharacteristic? _eepromCharacteristic; // Full eeprom dump
  BluetoothCharacteristic? _immobiliserCharacteristic; // immobiliser code
  BluetoothCharacteristic? _1984CodeCharacteristic;

  // State for the cobraTouchKey characteristic (latest value) and programmer touch key list
  List<int> _latestCobraValue = [];
  List<List<int>> _programmerTouchKeys = [];
  List<int> _latestEepromValue = [];
  int _latestImmobiliserCode = 0;
  int _latest1984Code = -100000;

  // Stream controllers for the cobraTouchKey characteristic and programmerTouchKeys
  final StreamController<List<int>> _latestCobraValueController =
      StreamController<List<int>>.broadcast();
  final StreamController<List<List<int>>> _programmerTouchKeysController =
      StreamController<List<List<int>>>.broadcast();
  final StreamController<List<int>> _eepromController =
      StreamController<List<int>>.broadcast();
  final StreamController<int> _immobiliserController =
      StreamController<int>.broadcast();
  final StreamController<int> _c1984CodeController =
      StreamController<int>.broadcast();
  // Connection state stream controller
  final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();

  // Singleton pattern for BLEManager
  static final BLEManager _instance = BLEManager._internal();
  factory BLEManager() {
    return _instance;
  }

  BLEManager._internal();

  // Getters for streams
  Stream<List<int>> get latestCobraValueStream =>
      _latestCobraValueController.stream;
  Stream<List<List<int>>> get programmerTouchKeysStream =>
      _programmerTouchKeysController.stream;
  Stream<List<int>> get eepromStream => _eepromController.stream;
  Stream<int> get immobiliserStream => _immobiliserController.stream;
  Stream<int> get c1984CodeStream => _c1984CodeController.stream;
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  // Get current latest cobra value and programmer touch keys (for initial UI state)
  List<int> get latestCobraValue => _latestCobraValue;
  List<List<int>> get programmerTouchKeys => _programmerTouchKeys;
  List<int> get latestEepromValue => _latestEepromValue;
  int get latestImmobiliserCode => _latestImmobiliserCode;

  // Method to start scanning and connect to a BLE device
  Future<void> scanAndConnect() async {
    // wait for bluetooth to turn on & permission granted
    await FlutterBluePlus.adapterState
        .where((state) => state == BluetoothAdapterState.on)
        .first;

    if (_connectedDevice != null) {
      return; // Already connected
    }

    // Start scanning for BLE devices
    FlutterBluePlus.startScan(withServices: [Guid(COBRA_6422_SERVICE_UUID)]);
    FlutterBluePlus.scanResults.listen((results) async {
      if (results.isNotEmpty) {
        final device = results.first.device;
        await _connectToDevice(device);
        FlutterBluePlus.stopScan();
      }
    });
  }

  // Connect to a BLE device and monitor connection state
  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      _connectedDevice = device;

      // Listen for connection state changes
      _connectedDevice!.connectionState.listen((state) {
        if (state == BluetoothConnectionState.connected) {
          _connectionStateController.add(true); // Emit connected state
          _isReconnecting = false;
          _discoverServices();
        } else if (state == BluetoothConnectionState.disconnected) {
          _connectedDevice = null;
          _connectionStateController.add(false); // Emit disconnected state
          _attemptReconnect(); // Attempt to reconnect on disconnection
        }
      });
    } catch (e) {
      print('Failed to connect: $e');
      _connectedDevice = null;
      _connectionStateController.add(false); // Emit disconnected on failure
      _attemptReconnect(); // Attempt to reconnect on connection failure
    }
  }

  // Improved reconnect logic with retry mechanism
  Future<void> _attemptReconnect() async {
    if (_isReconnecting) {
      return; // Prevent overlapping reconnection attempts
    }

    _isReconnecting = true;

    for (int currentReconnectAttempts = 0; true; currentReconnectAttempts++) {
      await Future.delayed(
          _reconnectDelay); // Wait before attempting to reconnect
      print(
          'Attempting to reconnect... (Attempt ${currentReconnectAttempts + 1})');

      try {
        await scanAndConnect();
        // If connection succeeds, exit the loop
        if (_connectedDevice != null) {
          print('Reconnected successfully!');
          _isReconnecting = false;
          return;
        }
      } catch (e) {
        print('Reconnection attempt failed: $e');
      }
    }
  }

  // Discover services and cache characteristics
  Future<void> _discoverServices() async {
    if (_connectedDevice != null) {
      _services = await _connectedDevice!.discoverServices();
      _cacheCharacteristics();
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

  // Cache the characteristics for future use
  void _cacheCharacteristics() {
    _programmerTouchKeyCharacteristic = _findCharacteristic(
        TOUCHKEY_SERVICE_UUID, TOUCHKEY_READ_CHARACTERISTIC_UUID);
    _cobraTouchKeyCharacteristic = _findCharacteristic(
        COBRA_6422_SERVICE_UUID, TOUCHKEY_CHARACTERISTIC_UUID);
    _eepromCharacteristic = _findCharacteristic(
        COBRA_6422_SERVICE_UUID, EEPROM_CHARACTERISTIC_UUID);
    _immobiliserCharacteristic =
        _findCharacteristic(COBRA_6422_SERVICE_UUID, IMMOB_CHARACTERISTIC_UUID);
    _1984CodeCharacteristic = _findCharacteristic(
        COBRA_1984_SERVICE_UUID, C1984_CODE_CHARACTERISTIC_UUID);

    // Subscribe to characteristics after caching them
    _subscribeToProgrammerTouchKeyCharacteristic();
    _subscribeToCobraTouchKeyCharacteristic();
    _subscribeToImmobiliserCharacteristic();
    _subscribeTo1984CodeCharacteristic();
    _subscribeToEepromCharacteristic();
  }

  // Subscribe to the cobraTouchKey characteristic
  Future<void> _subscribeToCobraTouchKeyCharacteristic() async {
    if (_cobraTouchKeyCharacteristic != null) {
      final subscription =
          _cobraTouchKeyCharacteristic!.onValueReceived.listen((value) {
        if (value.isNotEmpty) {
          _latestCobraValue = value;
          _latestCobraValueController
              .add(_latestCobraValue); // Add latest cobra value to stream
        }
      });

      _connectedDevice!.cancelWhenDisconnected(subscription);

      await _cobraTouchKeyCharacteristic!.setNotifyValue(true);
    }
  }

  // Subscribe to the programmerTouchKey characteristic
  Future<void> _subscribeToProgrammerTouchKeyCharacteristic() async {
    if (_programmerTouchKeyCharacteristic != null) {
      final subscription =
          _programmerTouchKeyCharacteristic!.onValueReceived.listen((value) {
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

      _connectedDevice!.cancelWhenDisconnected(subscription);

      await _programmerTouchKeyCharacteristic!.setNotifyValue(true);
    }
  }

  // Subscribe to the cobraTouchKey characteristic
  Future<void> _subscribeToEepromCharacteristic() async {
    if (_eepromCharacteristic != null) {
      final subscription =
          _eepromCharacteristic!.onValueReceived.listen((value) {
        if (value.isNotEmpty) {
          _latestEepromValue = value;
          _eepromController
              .add(_latestEepromValue); // Add latest cobra value to stream
        }
      });

      _connectedDevice!.cancelWhenDisconnected(subscription);

      await _eepromCharacteristic!.setNotifyValue(true);
    }
  }

  // resubscribe to trigger refresh
  Future<void> refreshData() async {
    if (_eepromCharacteristic != null) {
      await _eepromCharacteristic!
          .setNotifyValue(false); // Enable notifications

      _latestCobraValueController.add([]);

      await _subscribeToEepromCharacteristic();
    }
  }

  Future<void> writeEEPROM(List<int> eepromData) async {
    if (_eepromCharacteristic != null &&
        _eepromCharacteristic!.properties.write) {
      await _eepromCharacteristic!.write(eepromData, withoutResponse: false);
    }
  }

  int convertBytesToSignedIntLE(List<int> bytes) {
    // Combine bytes into a 32-bit integer
    int value =
        (bytes[0]) | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24);

    // Apply two's complement correction if the sign bit is set
    if (value & 0x80000000 != 0) {
      value -= 0x100000000;
    }

    return value;
  }

  List<int> convertIntToBytesLE(int value) {
    return [
      value & 0xFF, // Extract least significant byte
      (value >> 8) & 0xFF, // Extract next byte
      (value >> 16) & 0xFF, // Extract next byte
      (value >> 24) & 0xFF, // Extract most significant byte
    ];
  }

  // Subscribe to the cobraTouchKey characteristic
  Future<void> _subscribeToImmobiliserCharacteristic() async {
    if (_immobiliserCharacteristic != null) {
      final subscription =
          _immobiliserCharacteristic!.onValueReceived.listen((value) {
        if (value.isNotEmpty) {
          _latestImmobiliserCode = convertBytesToSignedIntLE(value);
          _immobiliserController
              .add(_latestImmobiliserCode); // Add latest cobra value to stream
        }
      });

      _connectedDevice!.cancelWhenDisconnected(subscription);

      await _immobiliserCharacteristic!.setNotifyValue(true);
    }
  }

  // Write the most recent 4 programmer touch keys to the cobraTouchKey characteristic
  Future<void> writeNewImmobiliserCode(int value) async {
    if (_immobiliserCharacteristic != null &&
        _immobiliserCharacteristic!.properties.write) {
      await _immobiliserCharacteristic!
          .write(convertIntToBytesLE(value), withoutResponse: false);
      // Flatten the most recent 4 programmer touch keys into a single list of integers
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

  // Subscribe to the c1984Code characteristic.
  // The code characteristic will give negative numbers as progress and then
  // show the code as a positive.
  Future<void> _subscribeTo1984CodeCharacteristic() async {
    if (_1984CodeCharacteristic != null) {
      final subscription =
          _1984CodeCharacteristic!.onValueReceived.listen((value) {
        if (value.isNotEmpty) {
          _latest1984Code = convertBytesToSignedIntLE(value);
          print('Got 1984 code: $_latest1984Code');

          _c1984CodeController.add(_latest1984Code);
        }
      });

      _connectedDevice!.cancelWhenDisconnected(subscription);

      await _1984CodeCharacteristic!.setNotifyValue(true);
    }
  }

  Future<void> readImmobiliserCodeFrom1984() async {
    if (_1984CodeCharacteristic != null) {
      await _1984CodeCharacteristic!
          .write(convertIntToBytesLE(-100000), withoutResponse: false);
    }
  }

  Future<void> reset1984ImmobiliserCodeRead() async {
    if (_1984CodeCharacteristic != null) {
      await _1984CodeCharacteristic!
          .write(convertIntToBytesLE(-100001), withoutResponse: false);
    }
  }

  // Dispose stream controllers
  void dispose() {
    _latestCobraValueController.close();
    _programmerTouchKeysController.close();
    _immobiliserController.close();
    _eepromController.close();
    _c1984CodeController.close();
    _connectionStateController.close();
  }
}
