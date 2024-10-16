import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BLEManager {
  FlutterBluePlus flutterBlue =
      FlutterBluePlus(); // No instance, just direct instantiation
  BluetoothDevice? _connectedDevice;
  List<BluetoothService> _services = [];

  // Singleton pattern for BLE Manager
  static final BLEManager _instance = BLEManager._internal();

  factory BLEManager() {
    return _instance;
  }

  BLEManager._internal();

  // Getter for connected device
  BluetoothDevice? get connectedDevice => _connectedDevice;

  // Getter for services
  List<BluetoothService> get services => _services;

/*
  // Scan and connect to the first available BLE device
  Future<void> scanAndConnect() async {
    if (_connectedDevice != null) {
      // Already connected
      return;
    }

    // listen to scan results
    // Note: `onScanResults` clears the results between scans. You should use
    //  `scanResults` if you want the current scan results *or* the results from a previous scan.
    var subscription = FlutterBluePlus.onScanResults.listen(
      (results) {
        if (results.isNotEmpty) {
          ScanResult r = results.last; // the most recently found device
          print(
              '${r.device.remoteId}: "${r.advertisementData.advName}" found!');
        }
      },
      onError: (e) => print(e),
    );

    // cleanup: cancel subscription when scanning stops
    FlutterBluePlus.cancelWhenScanComplete(subscription);

    // Wait for Bluetooth enabled & permission granted
    // In your real app you should use `FlutterBluePlus.adapterState.listen` to handle all states
    await FlutterBluePlus.adapterState
        .where((val) => val == BluetoothAdapterState.on)
        .first;

    // Start scanning for devices
    await FlutterBluePlus.startScan(
        withServices: [Guid("7065ed39-77d1-48e6-8e7c-7227550243c3")],
        timeout: Duration(seconds: 4));

    // wait for scanning to stop
    await FlutterBluePlus.isScanning.where((val) => val == false).first;

/*
    // Listen to scan results and process them
    flutterBlue.scanResults.listen((results) async {
      if (results.isNotEmpty) {
        // Connect to the first device with a name
        BluetoothDevice device = results.first.device;
        if (device.name.isNotEmpty) {
          await _connectToDevice(device);
          flutterBlue.stopScan(); // Stop scanning after connecting to a device
        }
      }
    });*/
  }
  */

  // Scan and connect to the first available BLE device
  Future<void> scanAndConnect() async {
    if (_connectedDevice != null) {
      // Already connected
      return;
    }

    // Start scanning for devices
    await FlutterBluePlus.startScan(
        withServices: [Guid("4e4cabae-e1d9-44c4-94f4-d2c269d6093b")],
        timeout: Duration(seconds: 4));

    // Listen to scan results and process them
    await for (List<ScanResult> results in FlutterBluePlus.scanResults) {
      if (results.isNotEmpty) {
        // Connect to the first device with a name
        BluetoothDevice device = results.first.device;
        if (device.name.isNotEmpty) {
          await _connectToDevice(device);
          await FlutterBluePlus
              .stopScan(); // Stop scanning after connecting to a device
          break;
        }
      }
    }
  }

  // Connect to a BLE device and discover its services
  Future<void> _connectToDevice(BluetoothDevice device) async {
    await device.connect();
    _connectedDevice = device;

    // Discover services after connection
    _services = await device.discoverServices();
  }

  // Disconnect from the BLE device
  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
      _services.clear();
    }
  }

  // Get the specific characteristic for a given service and characteristic UUID
  Future<BluetoothCharacteristic?> getCharacteristic(
      String serviceUuid, String characteristicUuid) async {
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

  // Read a specific characteristic value from a service
  Future<List<int>?> readCharacteristic(
      String serviceUuid, String characteristicUuid) async {
    for (BluetoothService service in _services) {
      if (service.uuid.toString() == serviceUuid) {
        for (BluetoothCharacteristic characteristic
            in service.characteristics) {
          if (characteristic.uuid.toString() == characteristicUuid &&
              characteristic.properties.read) {
            return await characteristic.read();
          }
        }
      }
    }
    return null;
  }

  // Write to a specific characteristic in a service
  Future<void> writeCharacteristic(
      String serviceUuid, String characteristicUuid, List<int> value) async {
    for (BluetoothService service in _services) {
      if (service.uuid.toString() == serviceUuid) {
        for (BluetoothCharacteristic characteristic
            in service.characteristics) {
          if (characteristic.uuid.toString() == characteristicUuid &&
              characteristic.properties.write) {
            await characteristic.write(value);
          }
        }
      }
    }
  }
}
