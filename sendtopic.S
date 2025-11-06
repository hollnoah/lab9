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
 ANOTHERTIME	EQU 0x28
	TEMP EQU 0x29


   
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
    BSF ANSEL,0		;SETS AN0 AS INPUT
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
    MOVLW 0xFF
    MOVWF TRISA	    ;CONFIGURES PORTA AS INPUTS
    MOVLW 0x00
    MOVWF ADCON1    ;LEFT JUSTIFIED, VSS & VDD
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
    
    MOVLW 0x41
    MOVWF ADCON0    ;FOSC8, AN0, A/D NOT IN PROGRESS, A/D ENABLED
    
    CLRF PIR1
    BCF PIE1,6	    ;DISABLE AD INTERRUPT
    
    MOVLW 0xC0
    MOVWF INTCON    ;ENABLE GLOBAL & PERIPHERAL INTERRUPTS
    
    BCF STATUS,5
    BCF STATUS,6
    
    BSF RECSTAT,1
    
    MOVLW 0x32
    MOVWF TIME	    ;HALFWAY SERVO POSITION (1.5ms)
    
    ;END INTERRUPT STUFF-----------------------------------------------------------------------------------------
    
    GOTO MAINLOOP
   
MAINLOOP: 
    
    ;BANK 0
    BCF STATUS,5
    BCF STATUS,6
    
    ;BCF INTCON,7	    ;DISABLE GLOBAL INTERRUPTS WHILE TRANSMITTING
    
    BTFSC RECSTAT,1	    ;DID WE GET A $
    CALL TRANSMITSTUFF	    ;IF YES, TRANSMIT IT BACK
    
    ;BSF INTCON,7   ;RENABLE GLOBAL INTERRUPTS AFTER TRANSMITTING
    
    BTFSC RECSTAT,3	    ;DID WE GET A !
    CALL SENDADC	    ;IF YES, SEND ADC DATA

//    ;VERIFY POT WORKS WITH LEDS
//BSF ADCON0,1
//WAITADC:
//    BTFSC ADCON0,1
//    GOTO WAITADC
//
//    MOVF ADRESH, W       ; high 8 bits
//    MOVWF PORTB

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
    BTFSC PIR1,1    ;SKIP IF TIMER2 HAS NOT COUNTED
    CALL TIMEELAP
    
    MOVF SAVESTAT,0
    MOVWF STATUS
    MOVF SAVEW,0
       
    RETFIE

TIMEELAP:
    ;DO TIMER 2 STUFF
    CALL PW
    
     ;BANK 0
    BCF STATUS,5
    BCF STATUS,6
    
    BCF PIR1,1	    ;CLEAR TIMER2 FLAG
    RETURN
    
TRANSMITSTUFF: 
   
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
        ; --- Check for '!' command (start of ADC handshake) ---
    MOVLW 0x21          ; ASCII '!'
    XORWF CHECKFODOLLA,0
    BTFSS STATUS,2
    GOTO NODICEEND
    
    BSF RECSTAT,3	;SET ADC REQUEST FLAG
    GOTO ALLDONE	;DONE
    
    
NODICEEND:
    GOTO STOPTIME
    
STOPTIME:
    ;BANK 0
    BCF STATUS,5
    BCF STATUS,6
    
    MOVF CHECKFODOLLA,0
    MOVWF TIME
    GOTO ALLDONE

PW:
     ;BANK 0
    BCF STATUS,5
    BCF STATUS,6
    MOVF TIME,0
    MOVWF ANOTHERTIME
    BSF PORTB,0
    
PWLOOP:
	NOP		;PADDING FOR ACCURATE DELAY
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	DECFSZ ANOTHERTIME	;DECRAMENT THE AMOUNT OF TIME DETERMINED BY LED AMOUNT
	GOTO PWLOOP	;THIS TIME IS CONVERTED TO THE PW OF THE SERVO
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
    
SENDADC:
    ; --- Start ADC conversion ---
    BSF     ADCON0, 1       ; GO/DONE = 1

WAIT_ADC:
    BTFSC   ADCON0, 1       ; Wait until conversion done
    GOTO    WAIT_ADC

    ; --- Send start marker '~' (0x7E) ---
    MOVLW   0x7E
WAIT_TX_MARK:
    BANKSEL PIR1
    BTFSS   PIR1,4          ; TXIF
    GOTO    WAIT_TX_MARK
    BANKSEL TXREG
    MOVWF   TXREG

    ; --- Send high byte (ADRESH) ---
WAIT_TX_HI:
    BANKSEL PIR1
    BTFSS   PIR1,4
    GOTO    WAIT_TX_HI
    BANKSEL TXREG
    MOVF    ADRESH,0
    MOVWF   TXREG

    ; --- Send low byte (ADRESL) ---
WAIT_TX_LO:
    BANKSEL PIR1
    BTFSS   PIR1,4
    GOTO    WAIT_TX_LO
    BANKSEL TXREG
    MOVF    ADRESL,0
    MOVWF   TXREG

    ; --- Wait for TSR empty (optional) ---
WAIT_TRMT:
    BANKSEL TXSTA
    BTFSC   TXSTA,1          ; TRMT == 1
    GOTO    DONE_TRMT
    GOTO    WAIT_TRMT
DONE_TRMT:

    ; --- Clear the '!' request flag ---
    BANKSEL RECSTAT
    BCF     RECSTAT,3

    RETURN
   
ALLDONE:
    
    RETURN  
   
END
    
   
    
    
 
    
