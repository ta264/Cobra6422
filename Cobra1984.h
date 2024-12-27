enum Status1984 {
  STANDARD,
  RUNNING,
  CODE_FOUND,
  CODE_NOT_FOUND
};

class Cobra1984 {
  private:
    int pCode;
    int pTest;
    Status1984 status;


    void getBits(uint8_t code[], bool bits[]);
    void emitCode(bool bits[]);

  public:
    // the maximum immobiliser code value, codes are computed modulo this number
    const static int MAX_CODE = 0x3342;
    int currentCode;

    Cobra1984(int code_pin, int test_pin);
    Status1984 get_status() {
      return status;
    }
    bool prepare();
    bool run_brute_force();
    void reset_brute_force();
    bool test_code(int32_t code);
    bool test_next_code();
    static void encode_arg1(int32_t arg1, uint8_t result[]);
    static int32_t decode_result(const uint8_t result[]);
};

Cobra1984::Cobra1984(int code_pin, int test_pin) {
  this->pCode = code_pin;
  this->pTest = test_pin;
  this->currentCode = MAX_CODE;
}

// Function to encode arg1 into the result array
void Cobra1984::encode_arg1(int32_t arg1, uint8_t result[]) {
  int32_t byte_index = 0;
  int32_t bit_position = 0;

  // Modulo operation
  arg1 = arg1 % MAX_CODE;

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
int32_t Cobra1984::decode_result(const uint8_t result[]) {
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
      remainder = -1;  // This shouldn't happen

    // Add the contribution of this part to arg1
    arg1 += remainder * multiplier;
    multiplier *= 3;

    // Update bit_position
    bit_position = (bit_position + 1) % 4;

    // Move to the next byte if bit_position loops back to 0
    if (bit_position == 0)
      byte_index += 1;
  }

  return arg1 + MAX_CODE;
}

void Cobra1984::getBits(uint8_t code[], bool bits[]) {
  for (int i = 0; i < 8; i++) {
    bits[i] = (code[0] >> i) & 1;
  }
  for (int i = 0; i < 8; i++) {
    bits[8 + i] = (code[1] >> i) & 1;
  }
  for (int i = 0; i < 2; i++) {
    bits[16 + i] = (code[2] >> i) & 1;
  }
}

void Cobra1984::emitCode(bool bits[]) {
  for (int i = 0; i < 18; i++) {
    if (bits[i]) {
      digitalWrite(pCode, LOW);
      delayMicroseconds(263);  // measured 276, shortened by 13
      digitalWrite(pCode, HIGH);
      delayMicroseconds(77);  // measured 88, shortened 5
    } else {
      digitalWrite(pCode, LOW);
      delayMicroseconds(39);  // measured 42, shortened 4
      digitalWrite(pCode, HIGH);
      delayMicroseconds(301);  // measured 317, shortened 18
    }
  }
}

bool Cobra1984::test_code(int32_t code) {
  uint8_t data[3] = { 0, 0, 0 };
  encode_arg1(code, data);

  bool bits[18];
  getBits(data, bits);

  // the code needs to be sent 3 times for the 1984 to recognise it, with a 1ms delay between each
  for (int p = 0; p < 3; p++) {
    emitCode(bits);
    delayMicroseconds(1000);
  }

  delayMicroseconds(5000);

  // check if the relay has activated
  PinStatus test = digitalRead(pTest);
  if (test == LOW) {
    status = CODE_FOUND;
    return true;
  }

  return false;
}

bool Cobra1984::test_next_code() {
  currentCode++;
  if (currentCode > 2 * MAX_CODE) {
    status = CODE_NOT_FOUND;
    return false;
  }

  return test_code(currentCode);
}

bool Cobra1984::prepare() {
  digitalWrite(pCode, LOW);
  pinMode(pCode, OUTPUT);
  pinMode(pTest, INPUT_PULLUP);

  PinStatus test = digitalRead(pTest);
  if (test == LOW) {
    Serial.println("Error: 1984 already mobilised.  Power cycle it and try again.");
    return false;
  }
}

bool Cobra1984::run_brute_force() {
  if (!prepare()) {
    return false;
  }

  Serial.println("Beginning 1984 code brute force");

  status = RUNNING;
  return true;
}

void Cobra1984::reset_brute_force() {
  currentCode = MAX_CODE;
  status = STANDARD;
}
