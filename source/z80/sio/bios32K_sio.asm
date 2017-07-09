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
; 
; All mods to original code are copyright Ben Chong and freely licensed to the community
; This version is developed for the Z80_mini
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

;
; Z80 SIO registers:
;

sio_base        .EQU     20H
SIO_A_DATA      .equ    sio_base
SIO_A_CMDS      .equ    sio_base+2
SIO_B_DATA      .equ    sio_base+1
SIO_B_CMDS      .equ    sio_base+3

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

                .ORG 0000H
;------------------------------------------------------------------------------
; Reset

RST00:
                DI                       ;Disable interrupts
                JP       INIT            ;Initialize Hardware and go

;------------------------------------------------------------------------------
; TX a character over RS232 

                .ORG     0008H
RST08:
		JP      rst08vector	; TXA

;------------------------------------------------------------------------------
; RX a character over RS232 Channel A [Console], hold here until char ready.

                .ORG 0010H
RST10:
		JP      rst10vector	; RXA

;------------------------------------------------------------------------------
; Check serial status
; Check if serial receive buffer is empty

                .ORG 0018H
RST18:
		JP      rst18vector	; CKINCHAR

;------------------------------------------------------------------------------
; RST20
;                .ORG 0020H
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
            	JP      rst38vector	; serialInt
            	DW      serialInt
    

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

SIGNON1:       .BYTE     CS
		.BYTE	CR,LF,"Z80 BIOS",0
		
;------------------------------------------------------------------------------
; NMI
                .ORG 0066H
                JP	nmivector

;------------------------------------------------------------------------------
; Serial interrupt handler
serialInt:      
                PUSH     AF
                PUSH     HL

                ; Check if data available
                ; We're not enabling any other interupt
;                xor     a
;                out     (SIO_A_CMDS), a 
;                in      a, (SIO_A_CMDS) 
;                bit     0, a
;                JR       Z, rts0        ; if not, ignore

                ; Read character from UART
                in      a, (SIO_A_DATA)
                PUSH     AF             ; Save it first
                LD       A,(serBufUsed) ; Get # of bytes in buffer
                CP       SER_BUFSIZE    ; If full then ignore
                JR       NZ,notFull
                POP      AF
                ; Insert code to increment serial error count
                LD       A, (serErrCount)
                CP       0FFH
                JR       Z, rts0           ; Just quit if we've maxed out # of errors
                INC      A
                LD       (serErrCount), A
                JR       rts0

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
                jr      c, rts0
                ; High water mark
                call    deassert_rts_sio

rts0:
                POP      HL
                POP      AF
                EI
                RETI
handle_nmi:
		RETN

;------------------------------------------------------------------------------
; RST 10H
; Get a character from buffer. 
; Blocking call
RXA:
#if 0
RX_LOOP:
                xor     a
                out     (SIO_A_CMDS), a 
                in      a, (SIO_A_CMDS) 
                bit     0, a
                JR      Z, RX_LOOP         ; Wait until there is a character
                in      a, (SIO_A_DATA)
                RET
#else
waitForChar:    LD       A, (serBufUsed)
                OR      A       ; test if zero
                JR       Z, waitForChar
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
                JR       NC,rts1
                ; Reset RTS
                call    assert_rts_sio
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
                ld      a, 01H
                out     (SIO_A_CMDS), a ; Read register 1
                in      a, (SIO_A_CMDS)
                bit     0, a            ; Check all sent
                JR      Z, CONOUT1      ; Loop until flag signals ready        
                POP     AF              ; Retrieve character
                OUT     (SIO_A_DATA), A    ; Output the character
                RET

;------------------------------------------------------------------------------
; Check if a character is available
; Z=1 if buffer is empty
CKINCHAR:
#if 0
                xor     a
                out     (SIO_A_CMDS), a 
                in      a, (SIO_A_CMDS) 
                bit     0, a
                RET
#else
                LD       A,(serBufUsed)
                CP       A, $0
                RET
#endif
          
;------------------------------------------------------------------------------
INIT:
                ; Set up vector table first
                LD	HL, vecTabProto
                LD	DE, vecTableStart
                LD	BC, 24
                LDIR		
               
                LD       HL, TEMPSTACK  ; Temp stack
                LD       SP, HL         ; Set up a temporary stack
                LD       HL, serBuf
                LD       (serInPtr), HL
                LD       (serRdPtr), HL
                XOR      A              ;0 to accumulator
                ld      i, a
                LD       (serBufUsed), A
                LD       (serErrCount), A
                ; Initialize UART
                call    INIT_SIO

;init_loop:
;                ld      a, '#'
;                call    TXA

                ; Initialize Interrupt mode
;                xor     a
;                ld      i, a
                IM       2
                ; Enable Interrupt
                EI
;               LD       HL, SIGNON1    ; Sign-on message
;               CALL     MON_PRINT      ; Output string
                JP       0150H          ; Jump to monitor

;------------------------------------------------------------------------------
; Initialize UART
INIT_SIO:
                ; Set up TX and RX:
                ld      a, 00110000b 
                out     (SIO_A_CMDS), a     ; Error reset, Select WR0
                ld      a, 018h
                out     (SIO_A_CMDS), a     ; Channel reset
                ld      a, 004h
                out     (SIO_A_CMDS), a     ; Select WR4
                ld      a, 44h
                out     (SIO_A_CMDS), a     ; 16x, 1 stop, no parity
                ld      a, 005h
                out     (SIO_A_CMDS), a     ; Select WR5
                ld      a, 068h              ; TX 8bit, TX on, RTS inactive
                out     (SIO_A_CMDS), a

                ld      a, 01h
                out     (SIO_B_CMDS), a         ; WR1
                ld      a, 0 ; 00000100b        ; Vector is ad verbatim
                out     (SIO_B_CMDS), a
                ld      a, 02h                  ; Select WR2
                out     (SIO_B_CMDS), a
                ld      a, 3bh       ; 0h
                out     (SIO_B_CMDS), a         ; Interrupt vector
                ld      a,01h
                out     (SIO_A_CMDS), a         ; Select WR1
                ld      a, 00011000b            ; Interrupt on all RX
                out     (SIO_A_CMDS), a

                ; Enable SIO channel A RX
                ld      A, 003h
                out     (SIO_A_CMDS), A         ; Select WR3
                ld      A, 0C1h                 ; 8 bit, RX on
                out     (SIO_A_CMDS), A
;                jr      assert_rts_sio        
;                RET

;------------------------------------------------------------------------------
; This is the UART-specific call to bring RTS low to re-enable transmit

assert_rts_sio:
                ld      a, 005h
                out     (SIO_A_CMDS), a 
                ld      a, 06Ah
                jr      writeout
;                out     (SIO_A_CMDS), a
;                ret
 
 
;------------------------------------------------------------------------------
; This is the UART-specific call to bring RTS high to disable transmit from terminal
; We can use A
deassert_rts_sio:
                ld      a, 005h
                out     (SIO_A_CMDS), a 
                ld      a, 068h
writeout:
                out     (SIO_A_CMDS), a
                ret


        .ORG 150H
              
              
;        .END
