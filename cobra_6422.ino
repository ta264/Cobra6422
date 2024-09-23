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

// Menu service read / write to perform initial read / 1984 brute force
const char* MENU_SERVICE_UUID = "c9389729-1cdb-4ef2-9e15-0701e9e8dca6";
const char* MENU_CHARACTERISTIC_UUID = "df5e3ea4-27c6-450d-8c7e-c5c791711b7b";

BLEService menuService(MENU_SERVICE_UUID);
BLEIntCharacteristic menuCharacteristic(MENU_CHARACTERISTIC_UUID, BLERead | BLEWrite | BLENotify);

// Touchkey service to read new touchkeys for writing to cobra
//   Key read
const char* TOUCHKEY_SERVICE_UUID = "7065ed39-77d1-48e6-8e7c-7227550243c3";
const char* TOUCHKEY_READ_CHARACTERISTIC_UUID = "d55282ce-37ba-4be9-9194-26c89f49b218";

BLEService touchkeyService(TOUCHKEY_SERVICE_UUID);
BLECharacteristic touchkeyReadCharacteristic(TOUCHKEY_READ_CHARACTERISTIC_UUID, BLERead | BLENotify, 8);
uint8_t key[8];

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
BLECharacteristic cobraTouchkeyCharacteristic(TOUCHKEY_CHARACTERISTIC_UUID, BLERead | BLEWrite | BLENotify, 32);
BLEIntCharacteristic immobCharacteristic(IMMOB_CHARACTERISTIC_UUID, BLERead | BLEWrite | BLENotify);

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

  BLE.setAdvertisedService(menuService);
  menuService.addCharacteristic(menuCharacteristic);
  BLE.addService(menuService);
  menuCharacteristic.writeValue(0);
  menuCharacteristic.setEventHandler(BLEWritten, menuWritten);

  BLE.setAdvertisedService(touchkeyService);
  touchkeyService.addCharacteristic(touchkeyReadCharacteristic);
  BLE.addService(touchkeyService);
  
  BLE.setAdvertisedService(cobra6422Service);
  cobra6422Service.addCharacteristic(eepromCharacteristic);
  cobra6422Service.addCharacteristic(cobraTouchkeyCharacteristic);
  cobra6422Service.addCharacteristic(immobCharacteristic);
  BLE.addService(cobra6422Service);

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

  if(!std::equal(std::begin(addr), std::end(addr), std::begin(key)))
  {
    memcpy(key, addr, 8);
    touchkeyReadCharacteristic.writeValue(key, 8);
  }
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

void menuWritten(BLEDevice central, BLECharacteristic characteristic)
{
  Serial.print("Characteristic event, written: ");
  int value = menuCharacteristic.value();
  Serial.println(value);

  switch(value)
  {
    case 1:
      c6422.read();
      updateData();
      break;
  }

  menuCharacteristic.writeValue(0);
}

void updateData()
{
  for (int addr = 0; addr < 64; addr++)
  {
    eeprom[addr * 2] = c6422.eeprom[addr] >> 8;
    eeprom[addr * 2 + 1] = c6422.eeprom[addr] % 0x100;
  }
  eepromCharacteristic.writeValue(eeprom, 128);

  immobCharacteristic.writeValue(c6422.getImmobiliserCode());
}
