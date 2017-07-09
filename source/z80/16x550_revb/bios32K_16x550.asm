;==================================================================================
; Modifications:
; 1. Fixed for ZASM assembler
; 2. Add support for all RST instructions and NMI
; 3. Use RAM-based vector table for interrupts and RST instructions for better
; flexibility for developers
; 4. Shift original RAM use up 20h to leave space for the vector table
; 5. Shorten messages etc and squeeze everything in under original 150h code length
; 6. 256-char buffer
; 7. Move stuff into mon32K.asm so that we'll have more space to handle different types
; of UART
; 8. Adapted for use with Bernd Ulmann's Z80_mini. Some of the UART code is based on
; Bernd's own monitor. Comment out serial interrupt code. We'll make it simple and just
; use polling.
; 9. Working interrupts
; 10. Tested on 16550 board for RC2014
; 11. Assemble-time option for 8080
; 12. Assemble-time option for polled mode UART
; 
; All mods to original code are copyright Ben Chong and freely licensed to the community
; This version is developed for the RC2014 16550 board.
;
;==================================================================================
;
; The original contents of this file are copyright Grant Searle
;
; You have permission to use this for NON COMMERCIAL USE ONLY
; If you wish to use it elsewhere, please include an acknowledgement to myself.
;
; http://searle.hostei.com/grant/index.html
;
; eMail: home.micros01@btinternet.com
;
; If the above don't work, please perform an Internet search to see if I have
; updated the web page hosting service.
;
;==================================================================================

#define CPU8080 0

#if CPU8080
#define POLLED 1
#else
#define POLLED 0
#endif

;
; 16C550 registers:
;

uart_base       .EQU     0C0H
uart_register_0 .EQU     uart_base + 0
uart_register_1 .EQU     uart_base + 1
uart_register_2 .EQU     uart_base + 2
uart_register_3 .EQU     uart_base + 3
uart_register_4 .EQU     uart_base + 4
uart_register_5 .EQU     uart_base + 5
uart_register_6 .EQU     uart_base + 6
uart_register_7 .EQU     uart_base + 7

; Monitor code that we want to access
MON_PRINT_NEWLINE       .EQU    0156H
MON_PRINT               .EQU    0159H 

; Non-memory, non-IO port defines
SER_BUFSIZE     .EQU     0FFH   ; Size of buffer
SER_FULLSIZE    .EQU     0C0H   ; Trigger for RTS deassertion
SER_EMPTYSIZE   .EQU     010H   ; Trigger for RTS assertion

RTS_HIGH        .EQU     0D6H
RTS_LOW         .EQU     096H

CR              .EQU     0DH
LF              .EQU     0AH
CS              .EQU     0CH             ; Clear screen

; System RAM utilization
; 8000H-802FH - BIOS
; 8030H - Monitor
; ->80FF - Stack
; 8100H-81FFH - Buffer
; 8200H onwards - BASIC

vecTableStart	.EQU	8000H
rst08vector	.EQU	vecTableStart		; Actual vector is at +1
rst10vector	.EQU	vecTableStart+3		; Actual vector is at +4
rst18vector	.EQU	vecTableStart+6		; Actual vector is at +7
rst20vector	.EQU	vecTableStart+9		; Actual vector is at +10
rst28vector	.EQU	vecTableStart+12	; Actual vector is at +13
rst30vector	.EQU	vecTableStart+15	; Actual vector is at +16
rst38vector	.EQU	vecTableStart+18	; Actual vector is at +19
nmivector	.EQU	vecTableStart+21	; Actual vector is at +22
vecTableLength	.EQU	24	; 8x3
vecTableEnd	.EQU	8020H


serInPtr        .EQU     vecTableEnd
serRdPtr        .EQU     vecTableEnd+2
serBufUsed      .EQU     vecTableEnd+4
bootFlag        .EQU     vecTableEnd+6
serErrCount     .EQU     vecTableEnd+8          ; Count number of serial overflow errors
TEMPSTACK       .EQU     80FFH	; serBuf+$ED	; $80ED ; Top of BASIC line input buffer so is "free ram" when BASIC resets

serBuf          .EQU     8100H  ; vecTableEnd	; 8020H (was $8000)

monStart        .EQU    0150H
;monCold         .EQU    0150H
;monWarm         .EQU    0153H

                .ORG $0000
;------------------------------------------------------------------------------
; Reset

RST00           DI                       ;Disable interrupts
                JP       INIT            ;Initialize Hardware and go

;------------------------------------------------------------------------------
; TX a character over RS232 

                .ORG     0008H
RST08:
#if CPU8080
		JP      TXA
#else
		JP      rst08vector
#endif

;------------------------------------------------------------------------------
; RX a character over RS232 Channel A [Console], hold here until char ready.

                .ORG 0010H
RST10:
#if CPU8080
                JP      RXA
#else
		JP      rst10vector
#endif

;------------------------------------------------------------------------------
; Check serial status
; Check if serial receive buffer is empty

                .ORG 0018H
RST18:
#if CPU8080
                JP      CKINCHAR
#else
		JP      rst18vector
#endif

;------------------------------------------------------------------------------
; RST20
                .ORG 0020H
RST20            JP      rst20vector	; 

;------------------------------------------------------------------------------
; RST28
                .ORG 0028H
RST28            JP      rst28vector	; 

;------------------------------------------------------------------------------
; RST30
                .ORG 0030H
RST30            JP      rst30vector	; 

;------------------------------------------------------------------------------
; RST 38 - INTERRUPT VECTOR [ for IM 1 ]

                .ORG     0038H
RST38:
#if CPU8080
            	JP      serialInt
#else
            	JP      rst38vector
#endif

;------------------------------------------------------------------------------
; vector table prototype. to be copied to RAM on reset
vecTabProto	JP	TXA			; RST 08
		JP	RXA			; RST 10
		JP	CKINCHAR		; RST 18
		JP	FIXME			; RST 20
		JP	FIXME			; RST 28
		JP	FIXME			; RST 30
		JP	serialInt		; RST 38
		JP	handle_nmi		; NMI		

;------------------------------------------------------------------------------

SIGNON1:
                .BYTE     CS
#if CPU8080
		.BYTE	CR,LF,"8080 BIOS",0
#else
		.BYTE	CR,LF,"Z80 BIOS",0
#endif
		
;------------------------------------------------------------------------------
; NMI
                .ORG 0066H
                JP	nmivector

;------------------------------------------------------------------------------
; Serial interrupt handler
serialInt:      
                PUSH     AF
                PUSH     HL
recheck_data:
                ; Check if data available
                ; We're not enabling any other interupt
                IN      A, (uart_register_5)
#if CPU8080
                AND      A, 1
#else
                BIT     0, A
#endif

#if CPU8080
                JP      Z, rts0
#else
                JR       Z,rts0          ; if not, ignore
#endif
                ; Read character from UART
                in      a, (uart_register_0)    ; Read character from UART
                PUSH     AF             ; Save it first
                LD       A,(serBufUsed) ; Get # of bytes in buffer
                CP       SER_BUFSIZE    ; If full then ignore
#if CPU8080
                JP       NZ,notFull
#else
                JR       NZ,notFull
#endif
                POP      AF
                ; Insert code to increment serial error count
                LD       A, (serErrCount)
                CP       0FFH
#if CPU8080
                JP       Z, rts0           ; Just quit if we've maxed out # of errors
#else
                JR       Z, rts0           ; Just quit if we've maxed out # of errors
#endif
                INC      A
                LD       (serErrCount), A
#if CPU8080
                JP      rts0
#else
                JR       rts0
#endif

notFull:
                INC     A               ; Increase # of bytes in buffer
                LD      (serBufUsed),A ; Save it
                LD      A, (serInPtr)   ; Load LSB of pointer to A
                INC     A               ; If this rolls over, it's okay
                LD      L, A
                LD      H, hi(serBuf)
                ; Now HL points to next location in buffer

                LD       (serInPtr),HL  ; Save pointer
                POP      AF             ; Get character
                LD       (HL),A         ; Save it in buffer
                LD       A,(serBufUsed)
                CP       SER_FULLSIZE
#if CPU8080
                jp      c, recheck_data ; See if anymore data in buffer
#else
                jr      c, recheck_data ; See if anymore data in buffer
#endif
                ; High water mark
                call    deassert_rts_16C550

rts0:
                POP      HL
                POP      AF
                EI
#if CPU8080
                RET
#else
                RETI
#endif
handle_nmi:
#if CPU8080
                RET
#else
		RETN
#endif

;------------------------------------------------------------------------------
; RST 10H
; Get a character from buffer. 
; Blocking call
RXA:
#if POLLED
RX_LOOP:
                IN      A, (uart_register_5)
#if CPU8080
                AND      A, 1
#else
                BIT     0, A
#endif
#if CPU8080
                JP      Z, RX_LOOP         ; Wait until there is a character
#else
                JR      Z, RX_LOOP         ; Wait until there is a character
#endif
                IN      A, (uart_register_0)
                RET
#else
waitForChar:    LD       A, (serBufUsed)
                OR      A       ; test if zero
#if CPU8080
                JP       Z, waitForChar
#else
                JR       Z, waitForChar
#endif
                PUSH     HL
                LD      A, (serRdPtr)
                INC     A
                LD      L, A
                LD      H, hi(serBuf)

                LD       (serRdPtr),HL
                DI
                LD       A,(serBufUsed)
                DEC      A
                LD       (serBufUsed),A
                CP       SER_EMPTYSIZE
#if CPU8080
                JP       NC,rts1
#else
                JR       NC,rts1
#endif
                ; Reset RTS
                call    assert_rts_16C550
rts1:
                LD       A,(HL)
                EI
                POP      HL
#endif
FIXME:
                RET                      ; Char ready in A

;------------------------------------------------------------------------------
; Output character to 68B50
; Note that this is a blocking call
TXA:
                PUSH    AF              ; Store character
CONOUT1:
                IN      A, (uart_register_5)    ; Line status register
#if CPU8080
                AND      A, 20H
#else
                BIT     5, A            ; Set Zero flag if still transmitting character
#endif
#if CPU8080
                JP      Z, CONOUT1      ; Loop until flag signals ready
#else
                JR      Z, CONOUT1      ; Loop until flag signals ready        
#endif
                POP     AF              ; Retrieve character
                OUT     (uart_register_0), A    ; Output the character
                RET

;------------------------------------------------------------------------------
; Check if a character is available
; Z=1 if buffer is empty
CKINCHAR:
#if POLLED
                IN      A, (uart_register_5)
#if CPU8080
                AND      A, 1
#else
                BIT     0, A
#endif
                RET
#else
                LD       A,(serBufUsed)
                CP       A, 00H
                RET
#endif
          
;------------------------------------------------------------------------------
INIT:
                ; Set up vector table first
                LD	HL, vecTabProto
                LD	DE, vecTableStart
                LD	BC, 24
#if CPU8080
                ; Don't use a redirect vector table for 8080
#else
                LDIR		
#endif    
                LD       HL, TEMPSTACK  ; Temp stack
                LD       SP, HL         ; Set up a temporary stack
                LD       HL, serBuf
                LD       (serInPtr), HL
                LD       (serRdPtr), HL
                XOR      A              ;0 to accumulator
                LD       (serBufUsed), A
                LD       (serErrCount), A
                ; Initialize UART
                call    INIT_16C550
                
                ; Initialize Interrupt mode
#if CPU8080
#else
                IM       1
#endif
                ; Enable Interrupt
                EI
                LD       HL, SIGNON1    ; Sign-on message
                CALL     MON_PRINT      ; Output string
                JP       0150H          ; Jump to monitor

;------------------------------------------------------------------------------
; Initialize UART
INIT_16C550:
                LD      L, 01H  ; 115200 with 1.8432MHz;  OSC / (16 * Baudrate)
                ; Call this routine with a value in L to set the baudrate
SETBAUD_16C550:
                LD      A, 80H                  ; Line control register, Set DLAB=1
                OUT     (uart_register_3), A
                LD      A, L
                OUT     (uart_register_0), A    ; Divisor latch
                XOR     A
                OUT     (uart_register_1), A    ; Divisor latch
                LD      A, 03H                  ; Line control register, 8N1, DLAB=0
                OUT     (uart_register_3), A
                LD      A, 02H                  ; Modem control register
                OUT     (uart_register_4), A    ; Enable RTS
                LD      A, 87H                  ; FIFO enable, reset RCVR/XMIT FIFO
                OUT     (uart_register_2), A
#if POLLED
                ; Don't enable interrupts...
#else
                ld      a, 01h                  ; Enable receiver interrupt
                out     (uart_register_1), a
#endif
                RET
 
;------------------------------------------------------------------------------
; This is the UART-specific call to bring RTS high to disable transmit from terminal
; We can use A
deassert_rts_16C550:
                ld      a, 00h
                out     (uart_register_4), a
                ret

;------------------------------------------------------------------------------
; This is the UART-specific call to bring RTS low to re-enable transmit

assert_rts_16C550:
                ld      a, 02h
                out     (uart_register_4), a
                ret

;------------------------------------------------------------------------------
; Enable autoflow control

AFE_16C550:
                LD      A, 87H                  ; Trigger level, FIFO enable, reset FIFO
                OUT     (uart_register_2), A
                ; Use this to enable autoflow control
                LD      A, 22H                  ; Modem control register
                OUT     (uart_register_4), A    ; Enable AFE
                RET


		.ORG 0150H
              
;        .END
