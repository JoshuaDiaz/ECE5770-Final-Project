
short row_addr; 
short data_out;
short data_in;
bool valid;
bool FPGA_resp;

#define write2mem HIGH
#define wait_n_rd LOW
#define INSTR_OP_PIN 53
#define VALID_PIN 52
#define FPGA_RESP_PIN 2
#define SECONDS true
#define MILLISECONDS false
#define FPGA_ACK_PIN 3
#define FPGA_VALID_PIN 4

/**
 * write 16 bits of data to pins 51 through 36 with the MSB corresponding
 * to 51 and the LSB to 36
 * write a 13 bit row address to pins 34 through 22 with the MSB corresponding
 * to 34 and the LSB to 22
 */
int write_data(short addr, short data){
  pinMode(INSTR_OP_PIN, OUTPUT);
  pinMode(VALID_PIN, OUTPUT);
  pinMode(FPGA_RESP_PIN, INPUT);

  digitalWrite(INSTR_OP_PIN, write2mem);

  // addr
  pinMode(34, OUTPUT);
  pinMode(33, OUTPUT);
  pinMode(32, OUTPUT);
  pinMode(31, OUTPUT);
  pinMode(30, OUTPUT);
  pinMode(29, OUTPUT);
  pinMode(28, OUTPUT);
  pinMode(27, OUTPUT);
  pinMode(26, OUTPUT);
  pinMode(25, OUTPUT);
  pinMode(24, OUTPUT);
  pinMode(23, OUTPUT);
  pinMode(22, OUTPUT);

  addr &= 0x1FFF; // truncate to 13 LSBs
  unsigned short mask = 0x1000; // 13th bit high
  for(char i=34; i>=22; i--){
    if(addr & mask)
      digitalWrite(i, HIGH);
    else
      digitalWrite(i, LOW);
    mask >>= 1;
  }
  
   // data
  pinMode(51, OUTPUT);
  pinMode(50, OUTPUT);
  pinMode(49, OUTPUT);
  pinMode(48, OUTPUT);
  pinMode(47, OUTPUT);
  pinMode(46, OUTPUT);
  pinMode(45, OUTPUT);
  pinMode(44, OUTPUT);
  pinMode(43, OUTPUT);
  pinMode(42, OUTPUT);
  pinMode(41, OUTPUT);
  pinMode(40, OUTPUT);
  pinMode(39, OUTPUT);
  pinMode(38, OUTPUT);
  pinMode(37, OUTPUT);
  pinMode(36, OUTPUT);
  
  mask = 0x8000; // 16th bit high
  for(char i=51; i>=36; i--){
    if(data & mask)
      digitalWrite(i, HIGH);
    else
      digitalWrite(i, LOW);
    mask >>= 1;
  }
  
  delay(100);
  //set valid line high
  digitalWrite(VALID_PIN, HIGH);
  //wait until response is received, meaning FPGA is finished with data
  while(!digitalRead(FPGA_RESP_PIN));
  //pul valid line back low
  digitalWrite(VALID_PIN, LOW);
  return 1;
}


/**
 * send signal to FPGA to turn of refresh rate, wait for delay_time, and read from addr
 * blocks until a response in retrieved
 */
short wait_and_read(short addr, short delay_time, bool time_granularity){
  short return_data = 0xFFFF;
  
  pinMode(INSTR_OP_PIN, OUTPUT);
  pinMode(VALID_PIN, OUTPUT);
  pinMode(FPGA_RESP_PIN, INPUT);

  //set instruction operation pin
  digitalWrite(INSTR_OP_PIN, wait_n_rd);
  
  // set row address pins
  pinMode(34, OUTPUT);
  pinMode(33, OUTPUT);
  pinMode(32, OUTPUT);
  pinMode(31, OUTPUT);
  pinMode(30, OUTPUT);
  pinMode(29, OUTPUT);
  pinMode(28, OUTPUT);
  pinMode(27, OUTPUT);
  pinMode(26, OUTPUT);
  pinMode(25, OUTPUT);
  pinMode(24, OUTPUT);
  pinMode(23, OUTPUT);
  pinMode(22, OUTPUT);

  addr &= 0x1FFF; // truncate to 13 LSBs
  unsigned short mask = 0x1000; // 13th bit high
  for(char i=34; i>=22; i--){
    if(addr & mask)
      digitalWrite(i, HIGH);
    else
      digitalWrite(i, LOW);
    mask >>= 1;
  }
  
  // set time granularity pin
  pinMode(51, OUTPUT);
  if(time_granularity == SECONDS)
    digitalWrite(51, HIGH);
  else
    digitalWrite(51, LOW); 

  // set time value pins
  pinMode(50, OUTPUT);
  pinMode(49, OUTPUT);
  pinMode(48, OUTPUT);
  pinMode(47, OUTPUT);
  pinMode(46, OUTPUT);
  pinMode(45, OUTPUT);
  pinMode(44, OUTPUT);
  pinMode(43, OUTPUT);
  pinMode(42, OUTPUT);
  pinMode(41, OUTPUT);
  pinMode(40, OUTPUT);
  pinMode(39, OUTPUT);
  pinMode(38, OUTPUT);
  pinMode(37, OUTPUT);
  pinMode(36, OUTPUT);
  
  mask = 0x7000; // 15th bit high
  for(char i=50; i>=36; i--){
    if(delay_time & mask)
      digitalWrite(i, HIGH);
    else
      digitalWrite(i, LOW);
    mask >>= 1;
  }

  delay(100);
  
  //set valid line high
  digitalWrite(VALID_PIN, HIGH);
  
  // wait until FPGA is done with this 
  while(!digitalRead(FPGA_RESP_PIN));

  //pull valid line low
  digitalWrite(VALID_PIN, LOW);
  
  //change time pins to become data inputs
  pinMode(51, INPUT);
  pinMode(50, INPUT);
  pinMode(49, INPUT);
  pinMode(48, INPUT);
  pinMode(47, INPUT);
  pinMode(46, INPUT);
  pinMode(45, INPUT);
  pinMode(44, INPUT);
  pinMode(43, INPUT);
  pinMode(42, INPUT);
  pinMode(41, INPUT);
  pinMode(40, INPUT);
  pinMode(39, INPUT);
  pinMode(38, INPUT);
  pinMode(37, INPUT);
  pinMode(36, INPUT);

  // Let FPGA know the MCU is ready for data 
  digitalWrite(FPGA_ACK_PIN, HIGH);

  //wait until FPGA is ready to return data (after MCU ACK and it has wait&read)
  while(!digitalRead(FPGA_VALID_PIN));

  //read data
  for(char i=51; i>=36; i--){
    return_data &= (digitalRead(i)<<(i-36));
  }

  //return data
  return return_data;
}

void setup() {
}

void loop() {

}


