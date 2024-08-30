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

// a safe rom dump to recover to
uint16_t eeprom[] = {
    0x55E2, 0x0131, 0x2320, 0xFB6F, 0xB7E2, 0x84C6, 0x3A00, 0x2A0A, 
    0x0202, 0x7838, 0x0505, 0x3800, 0x0909, 0x0900, 0x5074, 0x0218, 
    0x6974, 0x0000, 0x0005, 0x481D, 0x7D29, 0x229A, 0xF5F6, 0x2DE8, 
    0xB5C0, 0x2725, 0xF3F4, 0x5BD1, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 
    0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0x00B4, 
    0xC26F, 0xFA02, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 
    0x0000, 0x0000, 0x0000, 0x0000, 0x0100, 0xFFFF, 0x0021, 0x5F91, 
    0x0909, 0xFF3A, 0x3A00, 0x0000, 0x81F7, 0x7980, 0xFFFF, 0xFFFF
};

void setup() {
  Serial.begin(9600);

  // Make sure nothing is yet in output mode (especially the prog pin)
  pinMode(pCS, INPUT);
  pinMode(pCLK, INPUT);
  pinMode(pDI, INPUT);
  pinMode(pProg, INPUT);
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
  Serial.print(n + 1);
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
  String answer = Serial.readString();
  answer.trim();
  return min(max(answer.toInt(), 0), 4);
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

// Function to encode arg1 into the result array
void encode_arg1(int32_t arg1, uint8_t result[]) {
  int32_t byte_index = 0;
  int32_t bit_position = 0;
  
  // Modulo operation
  arg1 = arg1 % 0x3342;
  
  while (arg1 != 0) {
    uint32_t remainder = arg1 % 3;
    char encoded_value;
    
    // Map remainder to encoded_value
    if (remainder == 0)
      encoded_value = 0;
    else if (remainder == 1)
      encoded_value = 3;
    else if (remainder == 2)
      encoded_value = 1;
    
    // Pack encoded_value into the appropriate byte in the result array
    if (bit_position >= 0 && bit_position <= 3) {
      switch (bit_position) {
        case 0:
          result[byte_index] = (result[byte_index] & 0xfc) | ((encoded_value & 3) & 3);
          break;
        case 1:
          result[byte_index] = (result[byte_index] & 0xf3) | (((encoded_value & 3) << 2) & 0xc);
          break;
        case 2:
          result[byte_index] = (result[byte_index] & 0xcf) | (((encoded_value & 3) << 4) & 0x30);
          break;
        case 3:
          result[byte_index] = (result[byte_index] & 0x3f) | (((encoded_value & 3) << 6) & 0xc0);
          break;
      }
    }
    
    // Update arg1 and bit_position
    arg1 = arg1 / 3;
    bit_position = (bit_position + 1) % 4;
    
    // Move to the next byte if bit_position loops back to 0
    if (bit_position == 0)
      byte_index += 1;
  }
}

// Function to decode result array back into arg1
int32_t decode_result(const uint8_t result[]) {
  int32_t arg1 = 0;
  int32_t multiplier = 1;
  int32_t byte_index = 0;
  int32_t bit_position = 0;
  
  while (byte_index < 3 && (byte_index != 3 || result[byte_index] != 0)) {
    char extracted_value;
    
    // Extract the relevant bits from the current byte
    if (bit_position >= 0 && bit_position <= 3) {
      switch (bit_position) {
        case 0:
          extracted_value = result[byte_index] & 0x3;
          break;
        case 1:
          extracted_value = (result[byte_index] >> 2) & 0x3;
          break;
        case 2:
          extracted_value = (result[byte_index] >> 4) & 0x3;
          break;
        case 3:
          extracted_value = (result[byte_index] >> 6) & 0x3;
          break;
      }
    }
    
    // Map extracted_value back to its original modulo 3 result
    int32_t remainder;
    if (extracted_value == 0)
      remainder = 0;
    else if (extracted_value == 3)
      remainder = 1;
    else if (extracted_value == 1)
      remainder = 2;
    else
      remainder = -1; // This shouldn't happen
    
    // Add the contribution of this part to arg1
    arg1 += remainder * multiplier;
    multiplier *= 3;
    
    // Update bit_position
    bit_position = (bit_position + 1) % 4;
    
    // Move to the next byte if bit_position loops back to 0
    if (bit_position == 0)
      byte_index += 1;
  }
  
  return arg1 + 0x3342;
}

void readImmobiliserCode()
{
  uint8_t data[3];
  MicrowireEEPROM ME(pCS, pCLK, pDI, pDO, pProg);

  uint16_t immob = ME.read(IMMOB_ADDR);
  uint16_t addr12 = ME.read(ADDR12);

  Serial.print("Current immobiliser data: \n");
  Serial.print("Addr 0x01: ");
  Serial.println(immob, HEX);
  Serial.print("Addr 0x12: ");
  Serial.println(addr12, HEX);

  // first element of data is the low half of immob
  data[0] = immob & 0xff;
  // second element is the high half of immob
  data[1] = (immob >> 8);
  // the last two bytes are stored in addr 12
  data[2] = (addr12 & 0x30) >> 4;

  int32_t code = decode_result(data);
  Serial.print("Current paired immobiliser code is: ");
  Serial.println(code);
}

void getNewImmobiliserData(int code, uint16_t memory[])
{
  uint8_t data[3] = {0, 0, 0};
  encode_arg1(code, data);

  Serial.print("Encoded: ");
  Serial.print(data[1], HEX);
  Serial.print(data[0], HEX);
  Serial.print(" ");
  Serial.println(data[2], HEX);

  Serial.print("New immobiliser code: ");
  Serial.println(code);

  MicrowireEEPROM ME(pCS, pCLK, pDI, pDO, pProg);

  memory[0] = (data[1] << 8) | data[0];
  memory[1] =  (ME.read(ADDR12) & 0xffcf) | (data[2] << 4);
  Serial.print("New values: \n");
  Serial.print("Addr 0x01: ");
  Serial.println(memory[0], HEX);
  Serial.print("Addr 0x12: ");
  Serial.println(memory[1], HEX);
}

void writeImmobiliserCode()
{
  Serial.println("Enter new immobiliser code:");
  while (Serial.available() <= 0) {}
  String answer = Serial.readString();
  answer.trim();
  int code = answer.toInt();

  uint16_t data[2];
  getNewImmobiliserData(code, data);

  if (okToWrite())
  {
    MicrowireEEPROM ME(pCS, pCLK, pDI, pDO, pProg);
    ME.writeEnable();

    ME.write(IMMOB_ADDR, data[0]);
    ME.write(ADDR12, data[1]);

    ME.writeDisable();
  }
}

void recoverEEPROM()
{
  MicrowireEEPROM ME(pCS, pCLK, pDI, pDO, pProg);

  ME.writeEnable();

  for (int addr = 0; addr < 64; addr++)
  {
    ME.write(addr, eeprom[addr]);
    Serial.println(addr);
  }

  ME.writeDisable();
}

void loop()
{
  Serial.println("Choose an option.");
  Serial.println("1) Dump memory.");
  Serial.println("2) Program touch keys.");
  Serial.println("3) Read stored immobiliser code.");
  Serial.println("4) Write immobiliser code.");
  Serial.println("9) Recover EEPROM to a known good dump. [DANGER]");

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
    case '3':
      readImmobiliserCode();
      break;
    case '4':
      writeImmobiliserCode();
      break;
    case '9':
      recoverEEPROM();
      break;
    default:
      Serial.println("Option not recognised.");
  }
}
