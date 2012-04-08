// hrmshield v0.1: Arduino heart rate logger
//    http://www.element14.com/community/blogs/pdp7
//
// Code included and modified from:
//    HeartSpark http://sensebridge.net/projects/heart-spark/
//    OpenHeart http://jimmieprodgers.com/kits/openheart/
//    Adafruit Logger Shield http://www.ladyada.net/make/logshield/index.html

#include <avr/pgmspace.h>
#include <avr/sleep.h>
#include <avr/power.h>
#include <SD.h>
#include <Wire.h>
#include "RTClib.h" // https://github.com/adafruit/RTClib


/***********************************/
/********* DATA LOGGING ************/
/***********************************/
// number of bpm readings to buffer before writing to SD card
// must not exceed 256 since WriteBufeIndex is a byte
#define NBUF 32

// buffer of bpm readings to be written to SD card .csv file as one line
byte WriteBuf[NBUF];

// epoch timestamp of the first bpm reading in the write buffer
unsigned long WriteBufTime;

// write buffer index  is incremented on each CollectDate() call until buffer is full & written
byte WriteBufIndex = 0;

// real time clock object
RTC_DS1307 RTC; 

// for the data logging shield, we use digital pin 10 for the SD cs line
const int chipSelect = 10;

// CSV file on SD to write heart rate data too
File logfile;


/*********************************/
/********* LED MATRIX ************/
/*********************************/
// Open Heart pin assignments
int pin1 =3;
int pin2 =4;
int pin3 =5;
int pin4 =6;
int pin5 =7;
int pin6 =8;
const int pins[] = { pin1, pin2, pin3, pin4, pin5, pin6 };
const int heartpins[27][2] = {
  { pin3, pin1 },
  { pin1, pin3 },
  { pin2, pin1 },
  { pin1, pin2 },
  { pin3, pin4 },
  { pin4, pin1 },
  { pin1, pin4 },
  { pin1, pin5 },
  { pin6, pin1 },
  { pin1, pin6 },
  { pin6, pin2 },
  { pin4, pin3 },
  { pin3, pin5 },
  { pin5, pin3 },
  { pin5, pin1 },
  { pin2, pin5 },
  { pin5, pin2 },
  { pin2, pin6 },
  { pin4, pin5 },
  { pin5, pin4 },
  { pin3, pin2 },
  { pin6, pin5 },
  { pin5, pin6 },
  { pin4, pin6 },
  { pin2, pin3 },
  { pin6, pin4 },
  { pin4, pin2 }
};

// Controls brightness of Open Heart; lower is dimmer
byte blinkdelay = 200;

// Open Heart animation speed; smaller is faster
byte runspeed = 5;

// beating heart aninmation for Open Heart
byte heart[][27] PROGMEM = {
  { 0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,1,0,0,0,0,1,0,0,0,0,0,0 },
  { 0,0,0,0,0,1,1,0,1,1,0,0,1,1,1,1,1,0,0,1,1,1,0,0,1,0,0 },
  { 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1 },
  { 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1 },
  { 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1 },  
  { 0,0,0,0,0,1,1,0,1,1,0,0,1,1,1,1,1,0,0,1,1,1,0,0,1,0,0 },
  { 0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,1,0,0,0,0,1,0,0,0,0,0,0 },
  { 2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 }
};


/*********************************/
/********* HEART RATE ************/
/*********************************/
// Arduino input pin connected the Polar receiver module's HR pin
byte POLARout = 2;

// values modified inside the interrupt function
// must be declared as volatile
volatile boolean PolarIRQ = false;

// Additional global variables for heart rate calculation
unsigned long PolarTime;
unsigned long LastTime = 0;
byte HeartRate = 0;
byte setblink = 0;
byte NoSecondSkip = 0;


/**********************************/
/************ SETUP ***************/
/**********************************/
void setup() {
  Serial.begin(57600);

  // Polar reciever HR pin which pulses for each heart beat
  pinMode(POLARout, INPUT);

  // power settings, leaves the clock running
  set_sleep_mode(SLEEP_MODE_IDLE);
  
  // enables the sleep bit in the mcucr register so sleep is possible
  sleep_enable(); 

  // initialize the SD card
  Serial.print("Initializing SD card...");
  
  // see if the SD card is present (via SPI) and can be initialized
  pinMode(chipSelect, OUTPUT);
  if (!SD.begin(chipSelect)) {
    Serial.println("Card failed, or not present");
  }
  Serial.println("card initialized.");

  // create a new file on SD card
  char filename[] = "HRM00.CSV";
  // TODO: modify to allow for more than 100 files
  for (uint8_t i = 0; i < 100; i++) {
    filename[3] = i/10 + '0';
    filename[4] = i%10 + '0';
    if (!SD.exists(filename)) {
      // only open a new file if it doesn't exist
      logfile = SD.open(filename, FILE_WRITE); 
      break;
    }
  }

  if (!logfile) {
    Serial.println("couldnt create file");
  }

  Serial.print("Logging to: ");
  Serial.println(filename);

  // initialiaze the Real Time Clock
  Wire.begin();  
  if (!RTC.begin()) {
    logfile.println("RTC failed");
    Serial.println("RTC failed");
  }

}


/**********************************************************
 MAIN LOOP
 
 (based on HeartSpark code comments)
 This program is almost entirely interrupt driven, that
 makes it harder to understand.  Basically, we wait for pulses
 from the Polar reciever.  They trigger PolarInterrupt() which
 just sets PolarIRQ flag.  We fall out of the interrupt and 
 back into loop(), which checks PolarIRQ flag and does some
 heart rate calculations if set.  If it was a valid beat, then
 setblink flag is set.  If setblink is set, then the loop()
 will call fucntion to log the heart rate data & play the
 Open Heart LED matrix "beat" animation.
 
*************************************************************/
void loop() {

  // call PolarInterrupt() whenever a heart beat is detected from Polar receiver
  attachInterrupt(0, PolarInterrupt, RISING);

  // sleep until timer interrupt or input pin interrupt from Polar Receiver
  // TODO: determine exactly which timer interrupts cause sleep_mode to return
  //       because sleep_mode() doesn't seem to execute for more than about 1 ms
  //       so there is something other than the Polar pin interrupt waking it up.
  sleep_mode();

  // disable interrupt while processing
  detachInterrupt(0);
  
  // Polar receiver input pin triggered interrupt
  if (PolarIRQ)
  {
    PolarIRQ = false;
    PolarCalcs(); // calculate heart rate BPM reading
  }

  // Play animation & collect BPM reading if a valid heart beat was detected
  if (setblink)
  {
    setblink = 0;
    play(); // play beating heart animation once on the Open Heart LED Matrix
    CollectData(); // add BPM reading to write buffer and write to SD card when full
  }

}


/*********************************/
/********* HEART RATE ************/
/*********************************/

// set interrupt flag and let main loop handle it
void PolarInterrupt(void) {
  PolarIRQ = true;  
}

// do heart rate calculations if Polar interrupt occurred
void PolarCalcs(void) {
  
  unsigned long time;
  unsigned long NewPolar = 0;
  // this function is called when Polar input pin interrupt has just occurred
  // the Polar module outputs a 3V 1ms pulse on that pin for each heart beat
  // make sure input pin interrupt was a RISING edge
  // TODO: understand if this rising edge test is really needed (it was from HeartSpark code)
  if (digitalRead(POLARout)) {
    
    time = millis();

    // skip initial beat after startup
    if(LastTime == 0) {
      LastTime = time;
      return;
    }

    NewPolar = time - LastTime; 

    if (
        // process beat if new beat duration is at least 60% of the previous duration
        (NewPolar > 0.60*PolarTime)
        // process beat anyways if new duration or old duration was more than 1 sec
        || (NewPolar > 1000) || (PolarTime > 1000)
        // or previous beat was invalid        
        || NoSecondSkip
    ) { 
      // TODO: determine if all filtering should just be handled in csv parsing script
      // Comment from HeartSpark code: 
      // filtering, kill "half" beats, but don't want to make
      // any additional "false negatives" by being too agressive
      // NOTE: must have (PolarTime > 1000) argument, because it prevents the
      // horrible case where the previous time took forever and you get trapped
      // in a cycle of VERY LOW BMP, discarding every other heart beat
      // note that we can still get into that kind of mode if the user has
      // an elevated heart-beat, we should probably write a detector
      // for that kind of situation, but I am too lazy to do i for now.
      
      NoSecondSkip = 0;
      PolarTime = NewPolar;
      
      // convert duration between beats to BPM
      int HeartRateInt = 60000/PolarTime;

      // HeartRate is just a byte, so BPM was stored in temp int first for this bounds check
      if (HeartRateInt > 255) {
          HeartRate = 255; // TODO: use this opportunity to set a realistic upper bound?
      } else {
          HeartRate = HeartRateInt;
      }
          
      Serial.print("beat: ");
      Serial.print(HeartRate, DEC);
      Serial.print(" BPM\t");
      Serial.print(PolarTime);
      Serial.println(" ms");

      LastTime = time;
      
      // this was a valid beat so trigger animation & date logging code in the main loop
      setblink = 1;
      
    } else  {
      
      // flag to indicate that this was an invalid beat
      NoSecondSkip = 1; 
      
      Serial.println("beat: false positive");     
    } 
  }
}


/***********************************/
/********* DATA LOGGING ************/
/***********************************/

// print out the buffer to both SD card file & serial debug
void PrintBuffer() {  
  
  logfile.print(WriteBufTime, DEC);
  Serial.print(WriteBufTime, DEC);
  logfile.print("\t");
  Serial.print("\t");

  for (byte i=0; i<NBUF; i++)
  {
    logfile.print(WriteBuf[i], DEC);
    Serial.print(WriteBuf[i], DEC);
    if(i<NBUF-1) {
      logfile.print(",");
      Serial.print(","); 
    } 
    else {
      logfile.print("\n");
      Serial.print("\n");
    }
  }
}

// store BPM into write buffer & flush to SD card file when full
void CollectData() {

  if (WriteBufIndex == 0)
  {
    WriteBufIndex = 0;  // where the first data will land
    DateTime now = RTC.now();    
    WriteBufTime = now.unixtime();      
    for (byte i = 0; i<NBUF; i++) {
      WriteBuf[i] = 0;  // clear the buffer of old data
    }
  }
  
  // append the new heart rate data, increment pointer
  WriteBuf[WriteBufIndex] = HeartRate;
  WriteBufIndex++;

  // write to SD card file if write buffer is full
  if (WriteBufIndex == NBUF)
  {
    WriteBufIndex = 0; 
    Serial.println("SD card write: ");
    PrintBuffer();
    Serial.print("SD card flush...");
    logfile.flush();
    Serial.println("done");
  }
}


/*********************************/
/********* LED MATRIX ************/
/*********************************/

// Open Heart LED matrix function to turn on LED
void turnon(int led) {
  int pospin = heartpins[led][0];
  int negpin = heartpins[led][1];
  pinMode (pospin, OUTPUT);
  pinMode (negpin, OUTPUT);
  digitalWrite (pospin, HIGH);
  digitalWrite (negpin, LOW);
}

// Open Heart LED matrix function to turn off all LEDs
void alloff() {
  for(byte i = 0; i < 6; i++)   {
    pinMode (pins[i], INPUT);
  }
}

// Open Heart LED matrix function to play the anitmation once
void play() {
  boolean run = true;
  byte k;
  int t = 0;
  while(run == true)   {
    for(byte i = 0; i < runspeed; i++)     {
      for(byte j = 0; j < 27; j++)       {
        k = pgm_read_byte(&(heart[t][j]));
        if (k == 2) {
          t = 0;
          run = false;
        } 
        else if(k == 1) {
          turnon(j);
          delayMicroseconds(blinkdelay);
          alloff();
        } 
        else if(k == 0)         {
          delayMicroseconds(blinkdelay);
        }
      }
    } 
    t++;
  }
}
