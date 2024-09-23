#include "microwire.h"

class Cobra6422
{
  private:
    int pCS = 12;
    int pCLK = 13;
    int pDI = 11;
    int pDO = 10;
    int pProg = 8;

    uint16_t encodeKeyCount(uint16_t keyCount);
    void getNewImmobiliserData(int code, uint16_t memory[]);

  public:
    // start address of keys in 6422
    const int KEY_ADDR = 0x28;
    // stores part of immob code and also key count
    const int ADDR12 = 0x12;
    // stores most of immob code
    const int IMMOB_ADDR = 0x01;

    uint16_t eeprom[64];

    Cobra6422(int cs_pin, int clk_pin, int di_pin, int do_pin, int prog_pin);
    void read();
    int getKeyCount();
    void readKeys(uint16_t keys[][3]);
    void writeKeys(int keyCount, uint16_t keys[][3]);
    int32_t getImmobiliserCode();
    void writeImmobiliserCode(int code);
    void writeEEPROM(uint16_t eeprom[]);
};

Cobra6422::Cobra6422(int cs_pin, int clk_pin, int di_pin, int do_pin, int prog_pin)
{
  this->pCS = cs_pin;
  this->pCLK = clk_pin;
  this->pDI = di_pin;
  this->pDO = do_pin;
  this->pProg = prog_pin;

  //read();
}

void Cobra6422::read()
{
  MicrowireEEPROM ME(pCS, pCLK, pDI, pDO, pProg);

  for (int addr = 0; addr < 64; addr++)
    eeprom[addr] = ME.read(addr);
}

int Cobra6422::getKeyCount()
{
  return ((eeprom[ADDR12] & 0xff) >> 6) + 1;
}

uint16_t Cobra6422::encodeKeyCount(uint16_t keyCount)
{
  if (keyCount == 0)
    keyCount++;
  return (eeprom[ADDR12] & 0xff3f) | ((keyCount - 1) << 6);
}

void Cobra6422::readKeys(uint16_t keys[][3])
{
  int keyCount = getKeyCount();

  for (int key = 0; key < keyCount; key++)
  {
    int addr = KEY_ADDR + (key * 3);
    for (int i = 0; i < 3; i++)
      keys[key][i] = eeprom[addr + i];
  }
}

void Cobra6422::writeKeys(int keyCount, uint16_t keys[][3])
{
  MicrowireEEPROM ME(pCS, pCLK, pDI, pDO, pProg);

  ME.writeEnable();
  ME.write(ADDR12, encodeKeyCount(keyCount));

  for (int key = 0; key < 4; key++)
  {
    int start = KEY_ADDR + (key * 3);
    for (int i = 0; i < 3; i++)
    {
      int addr = start + i;
      int data = keys[key][i];

      ME.write(addr, data);
    }
  }

  ME.writeDisable();
}

void Cobra6422::getNewImmobiliserData(int code, uint16_t memory[])
{
  uint8_t data[3] = {0, 0, 0};
  Cobra1984::encode_arg1(code, data);

  memory[0] = (data[1] << 8) | data[0];
  memory[1] =  (eeprom[ADDR12] & 0xffcf) | (data[2] << 4);
}

int32_t Cobra6422::getImmobiliserCode()
{
  uint8_t data[3];

  uint16_t immob = eeprom[IMMOB_ADDR];
  uint16_t addr12 = eeprom[ADDR12];

  // first element of data is the low half of immob
  data[0] = immob & 0xff;
  // second element is the high half of immob
  data[1] = (immob >> 8);
  // the last two bytes are stored in addr 12
  data[2] = (addr12 & 0x30) >> 4;

  int32_t code = Cobra1984::decode_result(data);
  return code;
}

void Cobra6422::writeImmobiliserCode(int code)
{
  uint16_t data[2];
  getNewImmobiliserData(code, data);

  MicrowireEEPROM ME(pCS, pCLK, pDI, pDO, pProg);
  ME.writeEnable();

  ME.write(IMMOB_ADDR, data[0]);
  ME.write(ADDR12, data[1]);

  ME.writeDisable();
}

void Cobra6422::writeEEPROM(uint16_t eeprom[])
{
  MicrowireEEPROM ME(pCS, pCLK, pDI, pDO, pProg);

  ME.writeEnable();

  for (int addr = 0; addr < 64; addr++)
    ME.write(addr, eeprom[addr]);

  ME.writeDisable();
}