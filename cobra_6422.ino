#include <algorithm>
#include <iterator>
#include <ArduinoBLE.h>
#include <OneWire.h>
#include "Cobra1984.h"
#include "Cobra6422.h"

// Microwire needs four wires (apart from VCC/GND) DO,DI,CS,CLK
// configure them here, note that DO and DI are the pins of the
// EEPROM, so DI is an output of the uC, while DO is an input
const int pCS = 12;
const int pCLK = 13;
const int pDI = 11;
const int pDO = 10;
const int pProg = 8;
Cobra6422 c6422(pCS, pCLK, pDI, pDO, pProg);

// 1wire pin for reading touchkey
const int pTouchKey = 2;
OneWire net(pTouchKey); 

const int pCode = 5;
const int pTest = 6;
Cobra1984 c1984(pCode, pTest);

// a safe rom dump to recover to
const uint16_t eeprom_safe[] = {
    0x55E2, 0x0131, 0x2320, 0xFB6F, 0xB7E2, 0x84C6, 0x3A00, 0x2A0A, 
    0x0202, 0x7838, 0x0505, 0x3800, 0x0909, 0x0900, 0x5074, 0x0218, 
    0x6974, 0x0000, 0x0005, 0x481D, 0x7D29, 0x229A, 0xF5F6, 0x2DE8, 
    0xB5C0, 0x2725, 0xF3F4, 0x5BD1, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 
    0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0x00B4, 
    0xC26F, 0xFA02, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 
    0x0000, 0x0000, 0x0000, 0x0000, 0x0100, 0xFFFF, 0x0021, 0x5F91, 
    0x0909, 0xFF3A, 0x3A00, 0x0000, 0x81F7, 0x7980, 0xFFFF, 0xFFFF
};

/*
// Menu service read / write to perform initial read
const char* MENU_SERVICE_UUID = "c9389729-1cdb-4ef2-9e15-0701e9e8dca6";
const char* MENU_CHARACTERISTIC_UUID = "df5e3ea4-27c6-450d-8c7e-c5c791711b7b";

BLEService menuService(MENU_SERVICE_UUID);
BLEIntCharacteristic menuCharacteristic(MENU_CHARACTERISTIC_UUID, BLERead | BLEWrite | BLENotify);
BLEDescriptor menuDescriptor("2901","Menu");
*/

// Touchkey service to read new touchkeys for writing to cobra
//   Key read
const char* TOUCHKEY_SERVICE_UUID = "7065ed39-77d1-48e6-8e7c-7227550243c3";
const char* TOUCHKEY_READ_CHARACTERISTIC_UUID = "d55282ce-37ba-4be9-9194-26c89f49b218";

BLEService touchkeyService(TOUCHKEY_SERVICE_UUID);
BLECharacteristic touchkeyReadCharacteristic(TOUCHKEY_READ_CHARACTERISTIC_UUID, BLERead | BLENotify, 8);
BLEDescriptor touchkeyReadDescriptor("2901","Programmer Touchkey");

uint8_t key[8];

// 6422 service
//   EEPROM read / write
//   Keys read / write
//   Immob code read / write
const char* COBRA_6422_SERVICE_UUID = "4e4cabae-e1d9-44c4-94f4-d2c269d6093b";
const char* C6422_STATUS_CHARACTERISTIC_UUID = "4d970ade-6239-4c88-9a1c-2c544df31034";
const char* EEPROM_CHARACTERISTIC_UUID = "8d2d0e29-853d-4c21-929b-b1233e987c60";
const char* TOUCHKEY_CHARACTERISTIC_UUID = "a755d6b7-1605-4eca-bf4c-73de844f82f8";
const char* IMMOB_CHARACTERISTIC_UUID = "76a2563f-5759-4463-87fe-a684e8adcefa";

BLEService cobra6422Service(COBRA_6422_SERVICE_UUID);
BLEIntCharacteristic c6422StatusCharacteristic(C6422_STATUS_CHARACTERISTIC_UUID, BLERead | BLEWrite | BLENotify);
BLEDescriptor c6422StatusDescriptor("2901","6422 Status");
BLECharacteristic eepromCharacteristic(EEPROM_CHARACTERISTIC_UUID, BLERead | BLEWrite | BLENotify, 128);
BLEDescriptor eepromDescriptor("2901","6422 EEPROM");
BLECharacteristic cobraTouchkeyCharacteristic(TOUCHKEY_CHARACTERISTIC_UUID, BLERead | BLEWrite | BLENotify, 32);
BLEDescriptor cobraTouchkeyDescriptor("2901","6422 Touchkeys");
BLEIntCharacteristic immobCharacteristic(IMMOB_CHARACTERISTIC_UUID, BLERead | BLEWrite | BLENotify);
BLEDescriptor immobDescriptor("2901","6422 Immobiliser Code");

// 1984 service
//   Trigger brute force / read back value
const char* COBRA_1984_SERVICE_UUID = "eb3df65a-06e3-4a42-b790-73b5caea9dc9";
const char* C1984_CODE_CHARACTERISTIC_UUID = "d0ca177f-e266-4554-9dbb-1a0ca97c90c4";
BLEService cobra1984Service(COBRA_1984_SERVICE_UUID);
BLEIntCharacteristic c1984CodeCharacteristic(C1984_CODE_CHARACTERISTIC_UUID, BLERead | BLEWrite | BLENotify);
BLEDescriptor c1984CodeDescriptor("2901","1984 Immobiliser Code");

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
    while (1);
  }

  BLE.setLocalName("Jovial Programmer");  
  BLE.setEventHandler(BLEConnected, blePeripheralConnectHandler);
  BLE.setEventHandler(BLEDisconnected, blePeripheralDisconnectHandler);

  /*
  // Menu
  BLE.setAdvertisedService(menuService);
  menuCharacteristic.addDescriptor(menuDescriptor);
  menuService.addCharacteristic(menuCharacteristic);
  BLE.addService(menuService);
  menuCharacteristic.writeValue(0);
  menuCharacteristic.setEventHandler(BLEWritten, menuWritten);
  */

  // Programmer touchkey
  touchkeyReadCharacteristic.addDescriptor(touchkeyReadDescriptor);
  touchkeyService.addCharacteristic(touchkeyReadCharacteristic);
  BLE.addService(touchkeyService);
  
  // 6422
  c6422StatusCharacteristic.addDescriptor(c6422StatusDescriptor);
  c6422StatusCharacteristic.writeValue(0);
  c6422StatusCharacteristic.setEventHandler(BLEWritten, statusWritten);

  cobraTouchkeyCharacteristic.addDescriptor(cobraTouchkeyDescriptor);
  cobraTouchkeyCharacteristic.setEventHandler(BLESubscribed, updateDataHandler);
  cobraTouchkeyCharacteristic.setEventHandler(BLEWritten, touchkeyWritten);

  eepromCharacteristic.addDescriptor(eepromDescriptor);
  immobCharacteristic.addDescriptor(immobDescriptor);

  cobra6422Service.addCharacteristic(c6422StatusCharacteristic);
  cobra6422Service.addCharacteristic(eepromCharacteristic);  
  cobra6422Service.addCharacteristic(cobraTouchkeyCharacteristic);
  cobra6422Service.addCharacteristic(immobCharacteristic);
  
  BLE.addService(cobra6422Service);

  // 1984
  c1984CodeCharacteristic.addDescriptor(c1984CodeDescriptor);
  c1984CodeCharacteristic.writeValue(0);
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

void loop() {
  BLE.poll();
  readTouchKey();
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

void updateDataHandler(BLEDevice central, BLECharacteristic)
{
  Serial.println("Subscribed event");
  c6422.read();
  updateData();
}

void statusWritten(BLEDevice central, BLECharacteristic characteristic)
{
  Serial.print("Detected status write: ");
  int value = c6422StatusCharacteristic.value();
  Serial.println(value);

  switch(value)
  {
    case 1:
      c6422.read();
      updateData();
      c6422StatusCharacteristic.writeValue(1);
      break;
  }
}

void touchkeyWritten(BLEDevice central, BLECharacteristic characteristic)
{
  uint8_t buffer[32] = {0};
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
    if (i % 2 == 1) {  // Start from the 2nd byte, every odd index (i.e., pair of bytes)
      keys[row][col] = (buffer[i] << 8) | buffer[i + 1]; // Combine two bytes
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
    for (int i = 0; i < 3; i++)
    { 
      Serial.print(keys[key][i], HEX);  // Print each byte in hex format
    }
    Serial.println();
  }
  Serial.println();

  c6422.writeKeys(keyCount, keys);
  c6422.read();
  updateData();
}

void updateData()
{
  uint8_t eeprom[128];
  for (int addr = 0; addr < 64; addr++)
  {
    eeprom[addr * 2] = c6422.eeprom[addr] >> 8;
    eeprom[addr * 2 + 1] = c6422.eeprom[addr] % 0x100;
  }
  eepromCharacteristic.writeValue(eeprom, 128);

  uint16_t keys[4][3];
  c6422.readKeys(keys);

  uint8_t keys8[4][8];
  for (int key = 0; key < 4; key++)
  {
    keys8[key][0] = 0;
    for (int addr = 0; addr < 3; addr++)
    {
      keys8[key][addr * 2 + 1] = keys[key][addr] >> 8;
      keys8[key][addr * 2 + 2] = keys[key][addr] % 0x100;
    }
    keys8[key][7] = 0;
  } 
  cobraTouchkeyCharacteristic.writeValue(keys8, 32);

  immobCharacteristic.writeValue(c6422.getImmobiliserCode());
}
