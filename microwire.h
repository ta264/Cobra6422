class MicrowireEEPROM {
  private:
  // Microwire needs four wires (apart from VCC/GND) DO,DI,CS,CLK
  // configure them here, note that DO and DI are the pins of the
  // EEPROM, so DI is an output of the uC, while DO is an input
  int CS;
  int CLK;
  int DI;
  int DO;
  int PROG;

  // an EEPROM can have a varying pagesize, usually 8 or 16 bit per page
  const int PAGESIZE = 16;
  // an EEPROM can have a varying address width (depending on its storage size)
  const int ADDRWIDTH = 6;
  // (half of) the clock period in us
  const int HALF_CLOCK_PERIOD = 20;

  uint16_t transmit(uint16_t data, int bits);
  void send_opcode(char op);

  public:
  MicrowireEEPROM(int cs_pin, int clk_pin, int di_pin, int do_pin, int prog_pin);
  ~MicrowireEEPROM();
  uint16_t read(int addr);
  void writeEnable(void);
  void writeDisable(void);
  void write(int addr, uint16_t data);
};

MicrowireEEPROM::MicrowireEEPROM(int cs_pin, int clk_pin, int di_pin, int do_pin, int prog_pin)
{
  this->CS = cs_pin;
  this->CLK = clk_pin;
  this->DI = di_pin;
  this->DO = do_pin;
  this->PROG = prog_pin;

  // make CS, CLK, DI outputs
  pinMode(CS, OUTPUT);
  pinMode(CLK, OUTPUT);
  pinMode(DI, OUTPUT);
  
  // make DO an input
  pinMode(DO, INPUT);

  // put the cobra into programming mode
  Serial.println("Entering programming mode.");
  digitalWrite(PROG, LOW);
  pinMode(PROG, OUTPUT);
}

MicrowireEEPROM::~MicrowireEEPROM()
{
  // set outputs back to input
  Serial.println("Exiting programming mode.");
  pinMode(CS, INPUT);
  pinMode(CLK, INPUT);
  pinMode(DI, INPUT);
  pinMode(PROG, INPUT);
}

uint16_t MicrowireEEPROM::transmit(uint16_t data, int bits)
{
  uint16_t dout = 0;
  for (int i=(bits-1); i>=0; i--) {
    dout |= ((uint16_t) digitalRead(DO)) << i;
    if ((1 << i) & data) digitalWrite(DI, HIGH);
    else digitalWrite(DI, LOW);
    delayMicroseconds(HALF_CLOCK_PERIOD);
    digitalWrite(CLK, HIGH);
    delayMicroseconds(HALF_CLOCK_PERIOD);
    digitalWrite(CLK, LOW);
  }
  digitalWrite(DI, LOW);
  return dout;
}

void MicrowireEEPROM::send_opcode(char op)
{
  digitalWrite(CLK, HIGH);
  delayMicroseconds(HALF_CLOCK_PERIOD);
  digitalWrite(CLK, LOW);
  digitalWrite(CS, HIGH);
  digitalWrite(DI, HIGH);
  // transmit start bit and two bit opcode
  transmit((1 << 2) | op, 3);
}


uint16_t MicrowireEEPROM::read(int addr)
{
  send_opcode(2);
  transmit(addr, ADDRWIDTH);

  // when reading, a leading zero is returned
  long data = transmit(0, PAGESIZE+1);
  digitalWrite(CS, LOW);
  return data;
}

void MicrowireEEPROM::writeEnable(void)
{
  send_opcode(0);
  transmit(0xFF, ADDRWIDTH);
  digitalWrite(CS, LOW);
}

void MicrowireEEPROM::writeDisable(void)
{
  send_opcode(0);
  transmit(0x00, ADDRWIDTH);
  digitalWrite(CS, LOW);
}

void MicrowireEEPROM::write(int addr, uint16_t data)
{
  send_opcode(1);
  transmit(addr, ADDRWIDTH);
  transmit(data, PAGESIZE);
  digitalWrite(CS, LOW);
  delay(250);
}