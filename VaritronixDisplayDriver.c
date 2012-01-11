/* This program uses the PIC18F4550 microcontroller to
   accept incoming RS-232 display commands from the host
   computer and drive the Varitronix 3.5" monochrome display
   accordingly.
   
   5.4V --> 4V
   4.6V --> 3.3V
   4.2V --> 2.6V
*/

// Includes
#include "CCSUSB.H"
#use delay(internal=1,000,000)//(clock=20000000)//48000000)
#use rs232(uart1, baud=9600)
#include "stdlib.h"
#include "input.c"
#include "stdlibm.h"

// Defines
#define SCL PIN_E0
#define SDA PIN_E1
#define CSX PIN_A1
#define RESET PIN_A2

// Constants
const unsigned int8 RDDIDCommand = 4;//0x04
const unsigned int8 RDDSTCommand = 9;//0x09
const unsigned int8 RDDMADCTRCommand = 11;//0x0B
const unsigned int8 SLPOUTCommand = 17;//0x11
const unsigned int8 INVOFFCommand = 32;//0x20
const unsigned int8 INVONCommand = 33;//0x21
const unsigned int8 DISPONCommand = 41;//0x29
const unsigned int8 CASETCommand = 42;//0x2A
const unsigned int8 RASETCommand = 43;//0x2B
const unsigned int8 RAMWRCommand = 44;//0x2C
const unsigned int8 MADCTRCommand = 54;//0x36

// Global variables
int1 verbosity = 1;

// Function to send a 1 + 8 bit command
void sendCommand(int1 commandBit, int8 commandByte, char *commandString[]){
   int8 ii;
   // Initialize serial interface
   output_low(CSX);
   // Send commandBit
   if(commandBit==1){output_high(SDA);} else {output_low(SDA);}
   output_high(SCL);
   // Send commandByte
   for(ii=7;ii!=255;ii--){
      output_low(SCL);
      if(verbosity){
         printf("%s Command bit %u is %u\n",commandString,ii,bit_test(commandByte,ii));}
      if(bit_test(commandByte,ii)==1){output_high(SDA);} else{output_low(SDA);}
      output_high(SCL);}
  output_low(SCL);
}

// Function to write a byte
void writeByte(int1 DCX, int8 byteToWrite, char *commandString[]){
   int8 ii;
   // Send DCX bit
   if(DCX==1){output_high(SDA);} else {output_low(SDA);} output_high(SCL);
   // Send byteToWrite
   for(ii=7;ii!=255;ii--){
      output_low(SCL);
      if(verbosity){
         printf("%s write bit %u is %u\n",commandString,ii,bit_test(byteToWrite,ii));}
      if(bit_test(byteToWrite,ii)==1){output_high(SDA);} else{output_low(SDA);}
      output_high(SCL);}
   output_low(SCL);
}
void writeLong(int1 DCX, int16 longToWrite, char *commandString[]){
   int8 ii;
   // Send DCX bit
   if(DCX==1){output_high(SDA);} else {output_low(SDA);}
      output_high(SCL); output_low(SCL);
   // Write to register
   for(ii=15;ii!=65535;ii--){
      if(ii==7){if(DCX==1){output_high(SDA);} else {output_low(SDA);} //D/CX #2
         output_high(SCL); output_low(SCL);}
      if(bit_test(longToWrite,ii)==1){output_high(SDA);} else{output_low(SDA);}
      output_high(SCL);
      output_low(SCL);}
}

// Function to read bits
void readBits(int8 numberOfDummyBits, int8 numberOfReadBits, char *commandString[]){
   int8 ii;
   set_tris_e(2); //Set tri-state for incoming data
   // Pump dummy bits
   for(ii=0;ii<numberOfDummyBits;ii++){
      output_high(SCL); delay_cycles(5); output_low(SCL);} //Dummy clock cycle
   // Read bits
   for(ii=numberOfReadBits;ii>=1;ii--){
      output_high(SCL);
      if(verbosity){
         printf("%s read bit %2u is %u\n",commandString,ii,input(SDA));}
      output_low(SCL);}
}

// Function to write a block of black or white data.  Faster than writeByte()for large blocks
void writeBlock(int1 bitToWrite, int32 blockSize){
   int32 ii; int8 jj;
   if(bitToWrite==1){ // D/CX == white == 1
      blockSize = blockSize*9;
      output_high(SDA);
      for(ii=0;ii<blockSize;ii++){
         output_high(SCL); output_low(SCL);
      }
   }else{
      for(ii=0;ii<blockSize;ii++){
         // D/CX == 1
         output_high(SDA); output_high(SCL); output_low(SCL);
         // Black == 0
         output_low(SDA);
         for(jj=0;jj<8;jj++){
            output_high(SCL); output_low(SCL);}
      }
   }
}

// Function to draw all-black screen
void allBlack(void){
   char commandName[7];
   //Send RAMWR Command
   strcpy(commandName,"RAMWR");
   sendCommand(0,RAMWRCommand,commandName);
   // Write "Black" to each pixel in RAM -- incrememtation done automatically
   writeBlock(0,320*240*3);
   //Test response
   if(verbosity){printf("Screen Drawn Black\n");}
   output_high(CSX); //End of transmission signaled by CSX going high
}

int16 * getNewAperture(){
   int8 ii;
   int16 *newAperture;
   char pixelString[5];
   newAperture = malloc(sizeof(int16)*4);
   for (ii=0;ii<4;ii++){
      gets(pixelString);
      newAperture[ii] = atol(pixelString);
      if(verbosity){printf("Recovered integer is: %Lu\n",newAperture[ii]);}}
   return newAperture;
}

// Function to draw a black or white rectangle
void openOrCloseAperture(int1 openOrClose, int16 * newAperture){
   char commandName[7];
   char actionString[7];
   //RASET
   strcpy(commandName,"RASET");
   sendCommand(0,RASETCommand,commandName);
   writeLong(1,newAperture[0],commandName);
   writeLong(1,newAperture[2],commandName);
   output_high(CSX); //End of transmission signaled by CSX going high
   //CASET
   strcpy(commandName,"CASET");
   sendCommand(0,CASETCommand,commandName);
   writeLong(1,newAperture[1],commandName);
   writeLong(1,newAperture[3],commandName);
   output_high(CSX); //End of transmission signaled by CSX going high
   //Send RAMWR Command
   strcpy(commandName,"RAMWR");
   sendCommand(0,RAMWRCommand,commandName);
   // Open aperture
   writeBlock(openOrClose,((newAperture[2]-newAperture[0])+1)*((newAperture[3]-newAperture[1])+1)*3);
   output_high(CSX); //End of transmission signaled by CSX going high
   //Test response
   if(verbosity){
      if(openOrClose){strcpy(actionString,"Opened");}
      else{strcpy(actionString,"Closed");}
      printf("Aperture (%Lu,%Lu) --> (%Lu,%Lu) %s\n", newAperture[0],
      newAperture[1], newAperture[2], newAperture[3], actionString);}
}

// Main function to poll RS-232 port for commands
void main(void){
   // Declare variables
   char commandType;
   char commandName[7];
   int16 * currentAperture; //int16[4]
   int16 * newAperture; //int16[4]
   int8 delayTime=5; //ms delay time
  
   // Set status LEDs
   LED_ON(GREEN_LED);
   LED_OFF(YELLOW_LED);
   LED_ON(RED_LED);
   
   // Initialize Data Lines
   set_tris_e(0); //Set bus E to all outputs
   output_high(CSX);
   output_low(SCL);
   output_low(SDA);
   output_high(RESET);
   delay_ms(200);
   
   // Initialize display by holding RESET low for 200ms
   output_low(RESET);
   delay_ms(200);
   output_high(RESET);
   
   // Chill for a bit
   delay_ms(200);
 
   // SLPOUT
   strcpy(commandName,"SLPOUT");
   sendCommand(0,SLPOUTCommand,commandName);
   output_high(CSX); //End of transmission signaled by CSX going high
   delay_ms(200);
   
   // DISPON
   strcpy(commandName,"DISPON");
   sendCommand(0,DISPONCommand,commandName);
   output_high(CSX); //End of transmission signaled by CSX going high
   
   // Turn screen all black
   // allBlack();
   
   // RDDST
   strcpy(commandName,"RDDST");
   sendCommand(0,RDDSTCommand,commandName);
   readBits(1,31,commandName);
   output_high(CSX); //End of transmission signaled by CSX going high

   // Signal end of setup
   LED_OFF(RED_LED);

   // Begin indefinite polling
   while(TRUE){
      
      // Poll RS-232 port
      if(kbhit()){
         LED_ON(RED_LED);
         commandType = getc(); getc();//clear terminator
         
         // Execute commands
         switch(commandType){
            case 'B': //Turn screen black
               allBlack();
               break;
            case 'O': //Open new aperture (and close current)
               newAperture = getNewAperture();
               openOrCloseAperture(0,currentAperture);
               openOrCloseAperture(1,newAperture);
               currentAperture = newAperture;
               break;
            case 'I': //Invert display
               // INVON
               strcpy(commandName,"INVON");
               sendCommand(0,INVONCommand,commandName);
               output_high(CSX); //End of transmission signaled by CSX going high
               if(verbosity){printf("Display is inverted");}
               break;
            case 'U': //Un-Invert display
               // INVOFF
               strcpy(commandName,"INVOFF");
               sendCommand(0,INVOFFCommand,commandName);
               output_high(CSX); //End of transmission signaled by CSX going high
               if(verbosity){printf("Display is not inverted");}
               break;
            case 'v': //Set verbosity. 1 == verbose
               if(getc()=='1'){verbosity=1; getc(); printf("Verbose Mode\n");}
               else{verbosity=0; getc();}//clear terminator
               break;
            case 't': //test
               newAperture = getNewAperture();
               if(verbosity){printf("New Aperture: %Lu x %Lu x %Lu x %Lu\n",
                  newAperture[0],newAperture[1],newAperture[2],newAperture[3]);}
               break;
            case 'd': //RDDST
               // RDDST
               strcpy(commandName,"RDDST");
               sendCommand(0,RDDSTCommand,commandName);
               readBits(1,31,commandName);
               output_high(CSX); //End of transmission signaled by CSX going high
               break;
         }
         LED_OFF(RED_LED);
         
         // Signal 'S'uccessful completion to host
         putc('S');
      }
      // Processor pause
      delay_ms(delayTime);
   }
}

//
//Code Pasture
//
/*

   // RDDMADCTR
   strcpy(commandName,"RDDMADCTR");
   sendCommand(0,RDDMADCTRCommand,commandName);
   readBits(0,8,commandName);
   output_high(CSX); //End of transmission signaled by CSX going high
 
   // MADCTR
   strcpy(commandName,"MADCTR");
   sendCommand(0,MADCTRCommand,commandName);
   // Write to register, starting with D/CX = 1
   writeByte(1,255,commandName);
   output_high(CSX); //End of transmission signaled by CSX going high

   // RDDMADCTR
   strcpy(commandName,"RDDMADCTR");
   sendCommand(0,RDDMADCTRCommand,commandName);
   readBits(0,8,commandName);
   output_high(CSX); //End of transmission signaled by CSX going high
   
   // RDDID
   strcpy(commandName,"RDDID");
   sendCommand(0,RDDIDCommand,commandName);
   // Read Display ID: Start by setting tristate and pumping dummy bit
   set_tris_e(2); output_low(SCL); //High-Z for incoming data
   output_high(SCL); output_low(SCL); //Dummy clock cycle
   // Read ID1
   for(ii=7;ii!=255;ii--){
      output_high(SCL);
      if(input(SDA)){bit_set(ID1,ii); printf("ID1, bit %u is 1\n",ii);} else{bit_clear(ID1,ii);}
      output_low(SCL);}
   // Read ID2
   for(ii=7;ii!=255;ii--){
      output_high(SCL);
      if(input(SDA)){bit_set(ID2,ii); printf("ID2, bit %u is 1\n",ii);} else{bit_clear(ID2,ii);}
      output_low(SCL);}
   // Read ID3
   for(ii=7;ii!=255;ii--){
      output_high(SCL);
      if(input(SDA)){bit_set(ID3,ii); printf("ID3, bit %u is 1\n",ii);} else{bit_clear(ID3,ii);}
      output_low(SCL);}
   output_high(CSX); //End of transmission signaled by CSX going high
   // Print display information to RS-232
   printf("Display ID Information: ID1=%x ID2=%x ID3=%x\n", ID1, ID2, ID3);



*/
