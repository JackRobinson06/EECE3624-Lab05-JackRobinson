/**************************************************************************
 *	    File: Lab05.asm
 *  Lab Name: Pardon the Interruption...
 *    Author: Dr. Greg Nordstrom
 *   Created: 02/19/2021
 * Processor: ATmega128A (on the ReadyAVR board)
 *
 * Modified by: <Jack Robinson>
 * Modified on: <9/22/2026>
 *
 * This program blinks the "BOOT" LED (PORTA.7) at about 1 to 15 Hz, in 15
 * steps. Moving the joystick up makes it faster and down makes it slower.
 * The rate only changes when the joystick is released. The current rate is
 * shown in 4-bit binary on LEDs 0-3 (PORTC.0 = LSB, PORTC.3 = MSB).
 **************************************************************************/

.def BlinkFreq      = R20       ; holds current blink rate (1-15 Hz)
.equ BlinkFreqMin   = 1
.equ BlinkFreqMax   = 15
.equ InitialBlinkFreq = BlinkFreqMin

 /*********
 * Interrupt Jump Table
 *********/
.org 0x0000                 ; next instruction address is 0x0000
                            ; (the location of the reset vector)
rjmp main

.org 0x0004
RJMP int1_isr               ; INT1 (PD1) = joystick down

.org 0x0008	
RJMP int3_isr               ; INT3 (PD3) = joystick up

/**********
* Main code
**********/
.org 0x0020					; Move the "main" to 0x0020 to make room for ISRs
main:                       ; jump here on reset
    ldi R16, HIGH(RAMEND)   ; initialize stack (default RAMEND = 0x10FF)
    out SPH, R16
    ldi R16, low(RAMEND)
    out SPL, R16

	/* Additional Setup before Main Loop */
	LDI  R16,(1<<DDA7)		; Set the mask to make Port A.7 an output
    OUT  DDRA,R16		; Load bitmask to PORTA register
    
	LDI R16, 0x0F           ; PC3:0 are outputs (rate LEDs)
	OUT DDRC, R16

	LDI R16, 0x00           ; all of Port B and Port D are inputs
	OUT DDRB, R16
	OUT DDRD, R16

	LDI R16, 0x0A           ; pull-ups on PB1 and PB3 (joystick)
	OUT PORTB, R16

	
	LDI R16, 0x0E           ; show rate 1 at start (LEDs are active low)
	OUT PORTC, R16
	

	LDI R16, 0xCC           ; INT1 and INT3 trigger on rising edge
	STS EICRA, R16

	LDI R16, (1<<INT1 | 1<<INT3)    ; turn on INT1 and INT3
	OUT EIMSK, R16

	SEI                     ; allow interrupts

	LDI BlinkFreq, InitialBlinkFreq     ; start at 1 Hz
mainLoop:
    CBI  PORTA, PORTA7       ; turn BOOT LED on (active low) by clearing PORTA.7

    ; kill some time
    ldi R16, 16
	SUB R16, BlinkFreq             ; R16 is outer loop counter (16 - BlinkFreq)
outer_loop1:
    ldi R24, low(0xFFFF)     ; load low and high parts of R25:R24 pair with
    ldi R25, high(0xFFFF)    ; loop count by loading registers separately
    inner_loop1:
        sbiw R24, 1         ; decrement inner loop counter (R25:R24 pair)
        brne inner_loop1    ; loop back if R25:R24 isn't zero
    dec R16                 ; decrement the outer loop counter (R16)
    brne outer_loop1        ; loop back if R16 isn't zero

    sbi PORTA, PORTA7       ; turn BOOT LED off (active low) by setting PORTA.7

    ; kill some more time
    ldi R16, 16
	SUB R16, BlinkFreq            ; R16 is outer loop counter (16 - BlinkFreq)
outer_loop2:
    ldi R24, low(0xFFFF)     ; load low and high parts of R25:R24 pair with
    ldi R25, high(0xFFFF)    ; loop count by loading registers separately
    inner_loop2:
        sbiw R24, 1         ; decrement inner loop counter (R25:R24 pair)
        brne inner_loop2    ; loop back if R25:R24 isn't zero
    dec R16                 ; decrement the outer loop counter (R16)
    brne outer_loop2        ; loop back if R16 isn't zero

    rjmp mainLoop           ; play it again, Sam...

/**********
* ISR code
**********/
.org 0x0200							; Load the ISR code higher than main code

int1_isr:                   ; joystick down: slow the blink
PUSH R16                    ; save R16 and the flags
IN R16, SREG
PUSH R16

CPI BlinkFreq, BlinkFreqMin ; already at the minimum?
BREQ down                   ; if so, change nothing
DEC BlinkFreq
COM BlinkFreq               ; flip bits because LEDs are active low
OUT PORTC, BlinkFreq        ; show new rate
COM BlinkFreq               ; flip back to the real value

down:
POP R16                     ; restore the flags and R16
OUT SREG, R16
POP R16

reti

int3_isr:                   ; joystick up: speed up the blink

PUSH R16                    ; save R16 and the flags
IN R16, SREG
PUSH R16

CPI BlinkFreq, BlinkFreqMax ; already at the maximum?
BREQ up                     ; if so, change nothing
INC BlinkFreq
COM BlinkFreq               ; flip bits because LEDs are active low
OUT PORTC, BlinkFreq        ; show new rate
COM BlinkFreq               ; flip back to the real value

up:
POP R16                     ; restore the flags and R16
OUT SREG, R16
POP R16
reti