;==================================================================================
; Modifications:
; 1. Fixed for ZASM assembler
; 2. Add support for all RST instructions and NMI
; 3. Use RAM-based vector table for interrupts and RST instructions for better
; flexibility for developers
; 4. Shift original RAM use up 20h to leave space for the vector table
; 5. Shorten messages etc and squeeze everything in under original 150h code length      
; 
; All mods to original code are copyright Ben Chong and freely licensed to the community
; Developed for the RC2014 (rc2014.co.uk)
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

vecTableStart	.EQU	$8000
rst08vector	.EQU	vecTableStart
rst10vector	.EQU	vecTableStart+3
rst18vector	.EQU	vecTableStart+6
rst20vector	.EQU	vecTableStart+9
rst28vector	.EQU	vecTableStart+12
rst30vector	.EQU	vecTableStart+15
rst38vector	.EQU	vecTableStart+18
nmivector	.EQU	vecTableStart+21
vecTableLength	.EQU	24	; 8x3
vecTableEnd	.EQU	$8020

; Minimum 6850 ACIA interrupt driven serial I/O to run modified NASCOM Basic 4.7
; Full input buffering with incoming data hardware handshaking
; Handshake shows full before the buffer is totally filled to allow run-on from the sender

SER_BUFSIZE     .EQU     3FH
SER_FULLSIZE    .EQU     30H
SER_EMPTYSIZE   .EQU     5

RTS_HIGH        .EQU     0D6H
RTS_LOW         .EQU     096H

serBuf          .EQU     vecTableEnd	; $8000
serInPtr        .EQU     serBuf+SER_BUFSIZE
serRdPtr        .EQU     serInPtr+2
serBufUsed      .EQU     serRdPtr+2
basicStarted    .EQU     serBufUsed+1
TEMPSTACK       .EQU     serBuf+$ED	; $80ED ; Top of BASIC line input buffer so is "free ram" when BASIC resets

CR              .EQU     0DH
LF              .EQU     0AH
CS              .EQU     0CH             ; Clear screen

                .ORG $0000
;------------------------------------------------------------------------------
; Reset

RST00           DI                       ;Disable interrupts
                JP       INIT            ;Initialize Hardware and go

;------------------------------------------------------------------------------
; TX a character over RS232 

                .ORG     0008H
RST08            JP      rst08vector	; TXA

;------------------------------------------------------------------------------
; RX a character over RS232 Channel A [Console], hold here until char ready.

                .ORG 0010H
RST10            JP      rst10vector	; RXA

;------------------------------------------------------------------------------
; Check serial status
; Check if serial receive buffer is empty

                .ORG 0018H
RST18            JP      rst18vector	; CKINCHAR

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
RST38            JP      rst38vector	; serialInt       

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
		.BYTE	"Z80",CR,LF,0
;               .BYTE     "Z80 SBC By Grant Searle",CR,LF,0
SIGNON2:       .BYTE     CR,LF
		.BYTE	"C/W?",0
;               .BYTE     "Cold or warm start (C or W)? ",0		
;------------------------------------------------------------------------------
; NMI
                .ORG 0066H
                JP	nmivector
				
;------------------------------------------------------------------------------
serialInt:      PUSH     AF
                PUSH     HL

                IN       A,($80)
                AND      $01             ; Check if interupt due to read buffer full
                JR       Z,rts0          ; if not, ignore

                IN       A,($81)
                PUSH     AF
                LD       A,(serBufUsed)
                CP       SER_BUFSIZE     ; If full then ignore
                JR       NZ,notFull
                POP      AF
                JR       rts0

notFull:        LD       HL,(serInPtr)
                INC      HL
                LD       A,L             ; Only need to check low byte becasuse buffer<256 bytes
                CP       lo(serBuf+SER_BUFSIZE)	; bc & $FF
                JR       NZ, notWrap
                LD       HL,serBuf
notWrap:        LD       (serInPtr),HL
                POP      AF
                LD       (HL),A
                LD       A,(serBufUsed)
                INC      A
                LD       (serBufUsed),A
                CP       SER_FULLSIZE
                JR       C,rts0
                LD       A,RTS_HIGH
                OUT      ($80),A
rts0:           POP      HL
                POP      AF
                EI
handle_nmi:
                RETI

;------------------------------------------------------------------------------
; RST 10H
RXA:
waitForChar:    LD       A,(serBufUsed)
                CP       $00
                JR       Z, waitForChar
                PUSH     HL
                LD       HL,(serRdPtr)
                INC      HL
                LD       A,L             ; Only need to check low byte becasuse buffer<256 bytes
                CP       lo(serBuf+SER_BUFSIZE)	; bc & $FF
                JR       NZ, notRdWrap
                LD       HL,serBuf
notRdWrap:      DI
                LD       (serRdPtr),HL
                LD       A,(serBufUsed)
                DEC      A
                LD       (serBufUsed),A
                CP       SER_EMPTYSIZE
                JR       NC,rts1
                LD       A,RTS_LOW
                OUT      ($80),A
rts1:
                LD       A,(HL)
                EI
                POP      HL
FIXME:
                RET                      ; Char ready in A

;------------------------------------------------------------------------------
; Output character to 68B50
; Note that this is a blocking call
TXA:            PUSH     AF              ; Store character
conout1:        IN       A,($80)         ; Status byte       
                BIT      1,A             ; Set Zero flag if still transmitting character       
                JR       Z,conout1       ; Loop until flag signals ready
                POP      AF              ; Retrieve character
                OUT      ($81),A         ; Output the character
                RET

;------------------------------------------------------------------------------
; Check if a character is available
; Z=1 if buffer is empty
CKINCHAR        LD       A,(serBufUsed)
                CP       A, $0
                RET

;------------------------------------------------------------------------------
PRINT:          LD       A,(HL)          ; Get character
                OR       A               ; Is it $00 ?
                RET      Z               ; Then RETurn on terminator
                RST      08H             ; Print it
                INC      HL              ; Next Character
                JR       PRINT           ; Continue until $00
                RET
;------------------------------------------------------------------------------
INIT:
               ; Set up vector table first
               LD	HL, vecTabProto
               LD	DE, vecTableStart
               LD	BC, 24
               LDIR		
               
               LD        HL,TEMPSTACK    ; Temp stack
               LD        SP,HL           ; Set up a temporary stack
               LD        HL,serBuf
               LD        (serInPtr),HL
               LD        (serRdPtr),HL
               XOR       A               ;0 to accumulator
               LD        (serBufUsed),A
               LD        A,RTS_LOW
               OUT       ($80),A         ; Initialise ACIA
               IM        1
               EI
               LD        HL,SIGNON1      ; Sign-on message
               CALL      PRINT           ; Output string
               LD        A,(basicStarted); Check the BASIC STARTED flag
               CP        'Y'             ; to see if this is power-up
               JR        NZ,COLDSTART    ; If not BASIC started then always do cold start
               LD        HL,SIGNON2      ; Cold/warm message
               CALL      PRINT           ; Output string
CORW:
               CALL      RXA
               AND       %11011111       ; lower to uppercase
               CP        'C'
               JR        NZ, CHECKWARM
               RST       08H
               LD        A,$0D
               RST       08H
               LD        A,$0A
               RST       08H
COLDSTART:     LD        A,'Y'           ; Set the BASIC STARTED flag
               LD        (basicStarted),A
               JP        $0150           ; Start BASIC COLD
CHECKWARM:
               CP        'W'
               JR        NZ, CORW
               RST       08H
               LD        A,$0D
               RST       08H
               LD        A,$0A
               RST       08H
               JP        $0153           ; Start BASIC WARM
              
		.ORG 0150H
              
.END
