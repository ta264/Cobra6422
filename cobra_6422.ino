#include <algorithm>
#include <iterator>
#include <ArduinoBLE.h>
#include <OneWire.h>
#include "Cobra1984.h"
#include "Cobra6422.h"

enum Command1984 {
  START = -100000,
  RESET = -100001,
  ALREADY_MOBILISED = -100002,
  CHECKED_ALL_CODES = -100003
};

// Microwire needs four wires (apart from VCC/GND) DO,DI,CS,CLK
// configure them here, note that DO and DI are the pins of the
// EEPROM, so DI is an output of the uC, while DO is an input

const int pCLK = 13;
const int pProg = 12;
const int pCS = 11;
const int pDI = 10;
const int pDO = 9;

Cobra6422 c6422(pCS, pCLK, pDI, pDO, pProg);

// 1wire pin for reading touchkey
const int pTouchKey = 2;
OneWire net(pTouchKey);

const int pCode = 5;
const int pTest = 6;
Cobra1984 c1984(pCode, pTest);

// Touchkey service to read new touchkeys for writing to cobra
//   Key read
const char* TOUCHKEY_SERVICE_UUID = "7065ed39-77d1-48e6-8e7c-7227550243c3";
const char* TOUCHKEY_READ_CHARACTERISTIC_UUID = "d55282ce-37ba-4be9-9194-26c89f49b218";

BLEService touchkeyService(TOUCHKEY_SERVICE_UUID);
BLECharacteristic touchkeyReadCharacteristic(TOUCHKEY_READ_CHARACTERISTIC_UUID, BLERead | BLENotify, 8);
BLEDescriptor touchkeyReadDescriptor("2901", "Programmer Touchkey");

// 6422 service
//   EEPROM read / write
//   Keys read / write
//   Immob code read / write
const char* COBRA_6422_SERVICE_UUID = "4e4cabae-e1d9-44c4-94f4-d2c269d6093b";
const char* EEPROM_CHARACTERISTIC_UUID = "8d2d0e29-853d-4c21-929b-b1233e987c60";
const char* TOUCHKEY_CHARACTERISTIC_UUID = "a755d6b7-1605-4eca-bf4c-73de844f82f8";
const char* IMMOB_CHARACTERISTIC_UUID = "76a2563f-5759-4463-87fe-a684e8adcefa";

BLEService cobra6422Service(COBRA_6422_SERVICE_UUID);
BLECharacteristic eepromCharacteristic(EEPROM_CHARACTERISTIC_UUID, BLERead | BLEWrite | BLENotify, 128);
BLEDescriptor eepromDescriptor("2901", "6422 EEPROM");
BLECharacteristic cobraTouchkeyCharacteristic(TOUCHKEY_CHARACTERISTIC_UUID, BLERead | BLEWrite | BLENotify, 32);
BLEDescriptor cobraTouchkeyDescriptor("2901", "6422 Touchkeys");
BLEIntCharacteristic immobCharacteristic(IMMOB_CHARACTERISTIC_UUID, BLERead | BLEWrite | BLENotify);
BLEDescriptor immobDescriptor("2901", "6422 Immobiliser Code");

// 1984 service
//   Trigger brute force / read back value
const char* COBRA_1984_SERVICE_UUID = "eb3df65a-06e3-4a42-b790-73b5caea9dc9";
const char* C1984_CODE_CHARACTERISTIC_UUID = "d0ca177f-e266-4554-9dbb-1a0ca97c90c4";
BLEService cobra1984Service(COBRA_1984_SERVICE_UUID);
BLEIntCharacteristic c1984CodeCharacteristic(C1984_CODE_CHARACTERISTIC_UUID, BLERead | BLEWrite | BLENotify);
BLEDescriptor c1984CodeDescriptor("2901", "1984 Immobiliser Code");

void setup() {
  Serial.begin(9600);
  Serial.println("hello");

  // Make sure nothing is yet in output mode (especially the prog pin)
  pinMode(pCS, INPUT);
  pinMode(pCLK, INPUT);
  pinMode(pDI, INPUT);
  pinMode(pProg, INPUT);

  // Initialise BLE
  if (!BLE.begin()) {
    Serial.println("- Starting Bluetooth® Low Energy module failed!");
    while (1)
      ;
  }

  BLE.setLocalName("Jovial Programmer");
  BLE.setEventHandler(BLEConnected, blePeripheralConnectHandler);
  BLE.setEventHandler(BLEDisconnected, blePeripheralDisconnectHandler);

  // Programmer touchkey
  touchkeyReadCharacteristic.addDescriptor(touchkeyReadDescriptor);
  touchkeyService.addCharacteristic(touchkeyReadCharacteristic);
  BLE.addService(touchkeyService);

  // 6422
  cobraTouchkeyCharacteristic.addDescriptor(cobraTouchkeyDescriptor);
  cobraTouchkeyCharacteristic.setEventHandler(BLEWritten, touchkeyWritten);

  eepromCharacteristic.addDescriptor(eepromDescriptor);
  eepromCharacteristic.setEventHandler(BLESubscribed, updateDataHandler);
  eepromCharacteristic.setEventHandler(BLEWritten, eepromWritten);

  immobCharacteristic.addDescriptor(immobDescriptor);
  immobCharacteristic.setEventHandler(BLEWritten, immobWritten);

  cobra6422Service.addCharacteristic(eepromCharacteristic);
  cobra6422Service.addCharacteristic(cobraTouchkeyCharacteristic);
  cobra6422Service.addCharacteristic(immobCharacteristic);

  BLE.addService(cobra6422Service);

  // 1984
  c1984CodeCharacteristic.addDescriptor(c1984CodeDescriptor);
  c1984CodeCharacteristic.setEventHandler(BLEWritten, c1984CodeWritten);
  cobra1984Service.addCharacteristic(c1984CodeCharacteristic);

  BLE.addService(cobra1984Service);

  BLE.setAdvertisedService(cobra6422Service);
  BLE.advertise();

  Serial.println("setup done");
}

void readTouchKey() {
  byte addr[8];
  if (!net.search(addr)) {
    net.reset_search();
    delay(100);
    return;
  }

  if (OneWire::crc8(addr, 7) != addr[7]) {
    Serial.println("CRC is not valid!");
    return;
  }

  if (addr[0] != 0x01) {
    Serial.println("Not a Cobra touch key.");
    return;
  }

  touchkeyReadCharacteristic.writeValue(addr, 8);
}

void do6422loop() {
  if (!c6422.getHasData() && millis() - c6422.getPreviousRead() >= 5000)
    updateData();
}

void do1984loop() {
  if (c1984.get_status() == RUNNING) {
    for (int i = 0; i < 10; i++) {
      if (c1984.test_next_code()) {
        c1984CodeCharacteristic.writeValue(c1984.currentCode);
        return;
      }
    }

    float progress = c1984.currentCode * -100 / (float)c1984.MAX_CODE;
    c1984CodeCharacteristic.writeValue(progress);
    Serial.print(progress);
    Serial.print("% ");
    Serial.println(c1984.currentCode);
  }

  if (c1984.get_status() == CODE_NOT_FOUND) {
    c1984CodeCharacteristic.writeValue(CHECKED_ALL_CODES);
  }
}

void loop() {
  BLE.poll();
  readTouchKey();
  do6422loop();
  do1984loop();
}

void blePeripheralConnectHandler(BLEDevice central) {
  // central connected event handler
  Serial.print("Connected event, central: ");
  Serial.println(central.address());
}

void blePeripheralDisconnectHandler(BLEDevice central) {
  // central disconnected event handler
  Serial.print("Disconnected event, central: ");
  Serial.println(central.address());
}

void updateDataHandler(BLEDevice central, BLECharacteristic) {
  Serial.println("Subscribed event, updating data");
  updateData();
}

void touchkeyWritten(BLEDevice central, BLECharacteristic characteristic) {
  uint8_t buffer[32] = { 0 };
  characteristic.readValue(buffer, sizeof(buffer));

  // Counter to track position in the result array
  uint16_t keys[4][3];
  int row = 0;
  int col = 0;
  int keyCount = 0;

  // Loop through the input array, omitting the 1st and 8th bytes
  for (int i = 0; i < 32; ++i) {
    // if first byte is 01 we have a key, if it's zero it's a blank
    if (i % 8 == 0 && buffer[i] != 0) {
      keyCount++;
    }

    // Omit the 1st and 8th bytes
    if (i % 8 == 0 || i % 8 == 7) {
      continue;
    }

    // Take pairs of bytes and combine them into uint16_t
    if (i % 2 == 1) {                                     // Start from the 2nd byte, every odd index (i.e., pair of bytes)
      keys[row][col] = (buffer[i] << 8) | buffer[i + 1];  // Combine two bytes
      ++col;

      if (col == 3) {
        col = 0;
        ++row;
      }
    }
  }

  Serial.println("Detected key write:");
  Serial.println(keyCount);
  for (int key = 0; key < keyCount; key++) {
    for (int i = 0; i < 3; i++) {
      Serial.print(keys[key][i], HEX);  // Print each byte in hex format
    }
    Serial.println();
  }
  Serial.println();

  c6422.writeKeys(keyCount, keys);
  updateData();
}

void immobWritten(BLEDevice central, BLECharacteristic characteristic) {
  Serial.print("Detected immob write: ");
  int value = immobCharacteristic.value();
  Serial.println(value);

  c6422.writeImmobiliserCode(value);
  updateData();
}

void c1984CodeWritten(BLEDevice central, BLECharacteristic characteristic) {
  int value = c1984CodeCharacteristic.value();
  Serial.print("Detected immob code write: ");
  Serial.println(value);

  Command1984 command = static_cast<Command1984>(value);
  Serial.print("Cast to: ");
  Serial.println(command);

  switch (command) {
    case START:
      if (!c1984.run_brute_force()) {
        c1984CodeCharacteristic.writeValue(ALREADY_MOBILISED);
      }
      break;
    case RESET:
      c1984.reset_brute_force();
      c1984CodeCharacteristic.writeValue(START);
      break;
    default:
      Serial.println("Unknown 1984 command");
  }
}

void eepromWritten(BLEDevice central, BLECharacteristic characteristic) {
  uint8_t buffer[128] = { 0 };
  characteristic.readValue(buffer, sizeof(buffer));

  Serial.println("Detected EEPROM write");

  uint16_t eeprom[64] = { 0 };
  for (int i = 0; i < 64; i++) {
    eeprom[i] = buffer[i * 2] << 8 | buffer[i * 2 + 1];
  }

  c6422.writeEEPROM(eeprom);

  Serial.println("EEPROM written");

  updateData();
}

void updateData() {
  c6422.read();
  if (!c6422.getHasData())
    return;

  uint8_t eeprom[128];
  for (int addr = 0; addr < 64; addr++) {
    eeprom[addr * 2] = c6422.eeprom[addr] >> 8;
    eeprom[addr * 2 + 1] = c6422.eeprom[addr] % 0x100;
  }
  eepromCharacteristic.writeValue(eeprom, 128);

  uint16_t keys[4][3];
  c6422.readKeys(keys);

  uint8_t keys8[4][8];
  for (int key = 0; key < 4; key++) {
    keys8[key][0] = 0;
    for (int addr = 0; addr < 3; addr++) {
      keys8[key][addr * 2 + 1] = keys[key][addr] >> 8;
      keys8[key][addr * 2 + 2] = keys[key][addr] % 0x100;
    }
    keys8[key][7] = 0;
  }
  cobraTouchkeyCharacteristic.writeValue(keys8, 32);

  immobCharacteristic.writeValue(c6422.getImmobiliserCode());
}
