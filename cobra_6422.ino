#include <OneWire.h>
#include "microwire.h"

// Microwire needs four wires (apart from VCC/GND) DO,DI,CS,CLK
// configure them here, note that DO and DI are the pins of the
// EEPROM, so DI is an output of the uC, while DO is an input
const int pCS = 12;
const int pCLK = 13;
const int pDI = 11;
const int pDO = 10;
const int pProg = 8;

// 1wire pin for reading touchkey
const int pTouchKey = 2;
OneWire net(pTouchKey); 

// array to store touchkey Ids
int keyCount = 0;
uint16_t keys[4][3];

// start address of keys in 6422
const int KEY_ADDR = 0x28;

// stores part of immob code and also key count
const int ADDR12 = 0x12;

// stores most of immob code
const int IMMOB_ADDR = 0x01;

void setup() {
  Serial.begin(9600);
}

void dumpMemory()
{
  MicrowireEEPROM ME(pCS, pCLK, pDI, pDO, pProg);

  for (int addr=0; addr < 64; addr++)
  {
    // read the value back
    uint16_t r = ME.read(addr);
    
    // give some debug output
    Serial.print(addr, HEX);
    Serial.print(" data ");
    Serial.println(r, HEX);
  }
}

int getKeyCount(uint16_t addr12)
{
  return ((addr12 & 0xff) >> 6) + 1;
}

void readExistingKeys()
{
  MicrowireEEPROM ME(pCS, pCLK, pDI, pDO, pProg);

  int keyCount = getKeyCount(ME.read(ADDR12));

  for (int key = 0; key < keyCount; key++)
  {
    int addr = KEY_ADDR + (key * 3);
    for (int i = 0; i < 3; i++)
      keys[key][i] = ME.read(addr + i);
  }

  Serial.println("\n");
  Serial.print(keyCount);
  Serial.println(" existing Keys:");
  for (int i = 0; i < keyCount; i++) printKey(i);
}

void printKey(int n)
{
  Serial.print("Key ");
  Serial.print(n);
  Serial.print(": ");
  
  for (int i = 0; i < 3; i++)
  {
    Serial.print(keys[n][i], HEX);
    Serial.print(" ");
  }

  Serial.print("\n");
}

uint16_t encodeKeyCount(uint16_t addr12, uint16_t keyCount)
{
  if (keyCount == 0)
    keyCount++;
  return (addr12 & 0xff3f) | ((keyCount - 1) << 6);
}

void writeKeys(int keyCount)
{
  MicrowireEEPROM ME(pCS, pCLK, pDI, pDO, pProg);

  ME.writeEnable();
  ME.write(ADDR12, encodeKeyCount(ME.read(ADDR12), keyCount));

  for (int key = 0; key < 4; key++)
  {
    int start = KEY_ADDR + (key * 3);
    for (int i = 0; i < 3; i++)
    {
      int addr = start + i;
      int data = keys[key][i];
      Serial.print("Writing address: ");
      Serial.print(addr, HEX);
      Serial.print(" data: ");
      Serial.print(data, HEX);
      Serial.print("\n");

      ME.write(addr, data);
    }
  }

  ME.writeDisable();
}

int readNewTouchKey(int key) {
  byte addr[8];
  while (!net.search(addr)) {
    if (Serial.available() > 0 && Serial.readString()[0] == '1')
      return 2;
    net.reset_search();
    delay(100);
  }

  if (OneWire::crc8(addr, 7) != addr[7]) {
    Serial.print("CRC is not valid!\n");
    return 1;
  }

  if (addr[0] != 0x01) {
    Serial.print("Not a Cobra touch key.\n");
    return 1;
  }

  for (int i = 0; i < 8; i++)
  {
    Serial.print(addr[i]>>4, HEX);
    Serial.print(addr[i]&0x0f, HEX);
  }
  Serial.println();

  for (int i = 0; i < 3; i++)
    keys[key][i] = ((uint16_t)addr[2*i+1]) << 8 | addr[2*i+2];
  
  return 0;
}

int getKeyCount()
{
  Serial.println("How many keys do you want to code?");
  while (Serial.available() <= 0) {}
  int answer = Serial.parseInt();
  return min(max(answer, 0), 4);
}

int readNewKeys()
{
  int keyCount = getKeyCount();
  for (int key = 0; key < keyCount; key++)
    for (int i = 0; i < 3; i++)
      keys[key][i] = 0;
  
  for (int i = 0; i < keyCount; i++)
  {
    Serial.print("Touch key ");
    Serial.print(i + 1);
    Serial.println(" to reader");
    int result = readNewTouchKey(i);
    if (result == 2) break;
    if (result == 1) i--;
    delay(2000);
  }

  Serial.println("\n\New Keys:");
    for (int i = 0; i < keyCount; i++) printKey(i);

  return keyCount;
}

bool okToWrite()
{
  Serial.println("OK to write? Enter 'yes' to proceed.");
  while (Serial.available() <= 0) {}
  String answer = Serial.readString();
  answer.trim();

  if (answer == "yes")
    return true;

  Serial.println("Aborting.");
  return false;
}

void programKeys()
{
  readExistingKeys();
  int keyCount = readNewKeys();
  if (okToWrite())
    writeKeys(keyCount);
}

void loop()
{
  Serial.println("Choose an option.");
  Serial.println("1) Dump memory.");
  Serial.println("2) Program touch keys.");

  while (Serial.available() <= 0) {}
  String option = Serial.readString();
  Serial.print("Read option: ");
  Serial.println(option[0]);

  switch (option[0]) 
  {
    case '1':
      dumpMemory();
      break;
    case '2':
      programKeys();
      break;
    default:
      Serial.println("Option not recognised.");
  }
}
