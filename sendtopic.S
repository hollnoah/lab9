;NAME Noah Holloway
;COURSE 3371
;SEMESTER 5
;Program: SEND TO PIC
;Git URL
    
;Devices
;Configuration
    
    ; PIC16F883 Configuration Bit Settings

; Assembly source line config statements

; CONFIG1
  CONFIG  FOSC = XT		; Oscillator Selection bits (XT oscillator: Crystal/resonator on RA6/OSC2/CLKOUT and RA7/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = OFF           ; Power-up Timer Enable bit (PWRT disabled)
  CONFIG  MCLRE = ON            ; RE3/MCLR pin function select bit (RE3/MCLR pin function is MCLR)
  CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
  CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
  CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
  CONFIG  LVP = OFF             ; Low Voltage Programming Enable bit (RB3 pin has digital I/O, HV on MCLR must be used for programming)

; CONFIG2
  CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
  CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)
 
  
;Include Statements
  #include <xc.inc>
 ; #include <pic16f883.inc>
;Register/Variable Setup
  ;SOMEVALUE EQU 0x5f ;assign value to a variable
  
    SAVEW	    EQU	0x20
    SAVESTAT	    EQU 0x21
    CHECKFODOLLA    EQU 0x22
    RECSTAT	    EQU 0x23
    SERVOPOS	    EQU 0x24
    TIME	    EQU 0x25
    ADDEDBITS	    EQU 0x26
	    MAILOUT EQU 0x27


   
 ;Start of Program
 ;Reset vector address
 PSECT resetVect,class=CODE,delta=2 ;-Wl,-presetVect=00h
 GOTO Start
 
 PSECT isrVect,class=CODE,delta=2 ;-Wl,-pisrVect=04h
 GOTO INTERRUPT

 ;Setup Code that runs once at power up and at reset
 PSECT code,class=CODE,delta=2 ;-Wl,-pcode=08h
 
Start:
 
;BANK 3
    BSF STATUS,5    ;GO TO BANK 3
    BSF STATUS,6    ;GO TO BANK 3
    CLRF TRISB	    ;SETS PORTB AS OUTPUT
    CLRF ANSELH	    ;DIGITAL I/O
    MOVLW 0x80
    MOVWF OPTION_REG	;DISABLE PULL UPS
    MOVLW 0x00
    MOVWF ANSEL	;SETS AN0 AS INPUT
    MOVLW 0x40
    MOVWF BAUDCTL    ;BAUD RATE CONTROL REGISTER
    
;BANK 2
    BSF STATUS,6    ;GO TO BANK 2
    BCF STATUS,5    ;GO TO BANK 2
    CLRF CM2CON1    ;SET ALL BITS TO 0
    
;BANK 1
    BSF STATUS,5    ;GO TO BANK 1
    BCF STATUS,6    ;GO TO BANK 1
    CLRF IOCB	    ;CLEARS INTERRUPTION CHANGE 
    CLRF PSTRCON
    MOVLW 0x00
    MOVWF TRISC	    ;CONFIGURES PORTC AS OUTPUTS
    CLRF ADCON1	    ;LEFT JUSTIFIED, VSS & VDD
    CLRF CCP1CON   
    MOVLW 25
    MOVWF SPBRG	    ;MOVES DECIMAL 25
    CLRF SPBRGH	    ;MSB BITE OF SPBRG ALL ZEROS
    MOVLW 0xA6	    ;TRANSMIT ENABLE, ASYNCH, SYNC BREAK COMPLETE, HIGH SPEED, TSR EMPTY
    MOVWF TXSTA	    ;TRANSMIT STATUS & CONTROL REGISTSER
    
;BANK 0
    BCF STATUS,5    ;GO TO BANK 0
    BCF STATUS,6    ;GO TO BANK 0
    CLRF PORTC	    ;PUTS PORT C INTO A KNOWN STATE
    CLRF PORTB	    ;PUTS PORT B INTO A KNOWN STATE
    CLRF CCPR1L     ;START WITH 0 DUTY
    MOVLW 0x90	    ;SERIAL PORT ENABLED & CONTINUOUS RECEIVE ENABLED
    MOVWF RCSTA	    ;RECIEVE STATUS & CONTROL REGISTER
    
    
    ;INTERRUPT STUFF----------------------------------------------------------------------------------------------
    
    BSF STATUS,5   ;BANK 1
    BCF STATUS,6
    
    BSF PIE1, 1	    ;ENABLES TIMER2 TO MATCH PR2 INTERRUPT
    BSF PIE1, 5	    ;ENABLES EUSART RECIEVE INTERRUPT BIT
    
    MOVLW 0xFF
    MOVWF PR2	    ;LOADING FF FOR MAX COUNT
    
    BCF STATUS,5
    BCF STATUS,6   ;BANK 0
    
    MOVLW 0x26
    MOVWF T2CON	    ;TMR 2 ON, 1:16 PRE, 1:5 POST
    
;    MOVLW 0x41
;    MOVWF ADCON0    ;FOSC8, AN0, A/D NOT IN PROGRESS, A/D ENABLED
    
    CLRF PIR1
    
    MOVLW 0xC0
    MOVWF INTCON    ;ENABLE GLOBAL & PERIPHERAL INTERRUPTS
    
    BCF STATUS,5
    BCF STATUS,6
    
    MOVLW 0x55
    MOVWF MAILOUT
    
    BSF RECSTAT,1
    
    ;END INTERRUPT STUFF-----------------------------------------------------------------------------------------
    
    GOTO MAINLOOP
   
MAINLOOP: 
    ;BANK 0
    BCF STATUS,5
    BCF STATUS,6
    
    BCF INTCON,7	    ;DISABLE GLOBAL INTERRUPTS WHILE TRANSMITTING
    
    BTFSC RECSTAT,1
    CALL TRANSMITSTUFF
    
    BSF INTCON,7   ;RENABLE GLOBAL INTERRUPTS AFTER TRANSMITTING
    
    GOTO MAINLOOP
    
INTERRUPT: 
    ;BANK 0
    BCF STATUS,5
    BCF STATUS,6
    
    MOVWF SAVEW
    MOVF STATUS,0
    MOVWF SAVESTAT

    BTFSC PIR1,5    ;BIT TEST RECEIVE INTERRUPT FLAG, SKIP IF 0
    CALL RECEIVE
    ;FUTURE CHECKS FOR OTHER INTERRUPTS
    
    MOVF SAVESTAT,0
    MOVWF STATUS
    MOVF SAVEW,0
    
    BSF PIE1,1	    ;RENABLE TIMER2 INTERRUPT
    
    RETFIE
 
TRANSMITSTUFF: 
//    BCF STATUS,5
//    BCF STATUS,6
//    
    BANKSEL TXSTA
    BTFSS TXSTA,1	;WAITS UNTIL TRANSMIT STATUS BIT IS EMPTY
    GOTO $-1
    
    ;BANK 0
    BCF STATUS,5
    BCF STATUS,6
    
    MOVF MAILOUT,0
    MOVWF TXREG
    
    ;BANK 0
    BCF STATUS,5
    BCF STATUS,6
    
    BCF RECSTAT,1	;NO LONGER HAVE STUFF TO TRANSMIT
    RETURN
    
RECEIVE:
    
    ;BTFSC RECSTAT,0	;IF SET, DONT SKIP
    BCF PIE1,1		;DISABLE TIMER2 INTERRUPT
    MOVF RCREG,0	;MOVES RECIEVED BYTE INTO W
    MOVWF CHECKFODOLLA	;MOVES TARGET INTO CHECKFODOLLA
    GOTO CHECKDOLLAR
    
CHECKDOLLAR:
   MOVLW 0x24		;SETS $ AS PRIMARY TARGET
   XORWF CHECKFODOLLA,0 ;XOR'S PRIMARY TARGET WITH CHECKFODOLLA
   BTFSS STATUS,2	;CHECKS IF ZERO FLAG IS SET (IF THEY MATCH)
   GOTO NODICE		;IF NO MATCH, NOT $
   GOTO DOLLABILL	;IF $, GOTO DOLLABILL SUB
    
    
DOLLABILL:
    MOVF CHECKFODOLLA,0
    MOVWF MAILOUT		;SEND $ BACK TO VB
    BSF RECSTAT,0	;IF $, SET BIT 0 ($ HAS BEEN RECEIVED)
    BSF RECSTAT,1
    GOTO ALLDONE
    
    
NODICE:
    BTFSS RECSTAT,0	;IF 0 DO NOTHING
    GOTO STOPTIME
    ;GOTO ECHO		;THE NEXT BYTE THATS NOT A $
    GOTO SPECIAL	;IF 1,GOTO SPECAIL

STOPTIME:
    MOVLW 0x8D
    MOVWF TIME
    BSF PORTB,0
    GOTO PW

PW:
	NOP		;PADDING FOR ACCURATE DELAY
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	DECFSZ TIME	;DECRAMENT THE AMOUNT OF TIME DETERMINED BY LED AMOUNT
	GOTO PW		;THIS TIME IS CONVERTED TO THE PW OF THE SERVO
	BCF RECSTAT,1	;NOTHING TO TRANSMIT
	BCF PORTB,0
	GOTO ALLDONE	
    
ECHO:
    MOVF CHECKFODOLLA,0
    MOVWF MAILOUT
    BCF RECSTAT,0
    BSF RECSTAT,1
    GOTO ALLDONE
    
SPECIAL:
    MOVLW 0x23		;HEX FOR #
    MOVWF MAILOUT	;IF NO $ SENT, PIC SENDS # BACK TO VB
    BCF RECSTAT,0
    BSF RECSTAT,1
    GOTO ALLDONE

ALLDONE:
    ;BCF PIR1,5		;CLEARS INTERRUPT RECEIVE FLAG
    RETURN  
    
  
 

END
    
   
    
    
 
    
