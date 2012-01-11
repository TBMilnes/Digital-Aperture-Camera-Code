#include <18F4550.h>
#fuses HSPLL,NOWDT,NOPROTECT,NOLVP,NODEBUG,USBDIV,PLL5,CPUDIV1,VREGEN
//#use delay(clock=48000000)

#define GREEN_LED PIN_A5
#define YELLOW_LED PIN_B4
#define RED_LED PIN_B5
#define BUTTON PIN_A4
#define LED_ON output_low
#define LED_OFF output_high
