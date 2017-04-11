; Monitor/Debugger for Spencer Owen's Z80-based RC2014 (http://rc2014.co.uk)
; Source hosted at: https://github.com/ancientcomputing/rc2014
;
; Changes:
; 1. Adapted for zasm v4.0 assembler
; 2. Adapted for use with a modified init32K.asm BIOS by Grant Searle 
; (searle.hostei.com/grant)
; 3. Removed/commented out all non-RS232 code in the original monitor source
; 4. Added H command to set the start of the workspace where we want to load an Intel HEX 
; file. Some assemblers generate hex files that start at address 0000H instead of using 
; the .org value
; 5. Clean up return from command handlers. Use explicit jump to MAIN_MENU
; 6. RST 30H is used as a software breakpoint. Added functionality to display registers
; on breakpoint and resume from breakpoint
; 7. Disable/remove all xmodem stuff for now
; 8. Misc clean up and renames (PUT->PRINT etc)
; 9. Add more verbosity for user-friendliness
; 10. Optimize register listing, and save/restore IR on breakpoint
; 11. Why do we need V(ersion)? Include version info in ? and save some bytes!
; 12. Use a couple of routines in int32K so that we save some bytes!
; 13. Add John Kerr's disassembler. Extracted from UTILITY3 for the Spectrum. Visit John's
; website at: http://mycodehere.blogspot.co.uk/2012/04/my-work-in-print-1987.html
; 14. A User Guide is now available at:
;       https://github.com/ancientcomputing/rc2014/tree/master/docs
; 15. We now save the interrupt enable state (IFF2) during breakpoint handling
; 16. Use 8030H onwards. Part of effort to use a 255 size serial receive buffer
; 
;
; -----------------------------------------------------------------------------
;
; Notes for users of the Serial terminal emulator program on Mac OS X when uploading
; Intel HEX files:
; 1. To use the "Send File" option, you want to enable RTS/CTS in Serial. This allows the 
; Monitor to throttle the serial line rate for reliable transfers.
;
; 2. You can also use the "Send Text File" option. This option will respect the line delay
; configuration. This is my preferred option as there's a "command+T" hotkey to quickly
; upload a test program.
;
; Changes to Josh Bensadon's original code are copyright Ben Chong and freely licensed to 
; the community
;
; -----------------------------------------------------------------------------
;	Acknowledgments
; -----------------------------------------------------------------------------
;
; Based on the monitor that comes with Lee Hart's Z80 Membership Card 
; http://www.sunrise-ev.com/z80.htm
;
; Original Operation, Documentation and Consultation by Herb Johnson
;
; Original Firmware by Josh Bensadon. Date: Feb 10, 2014
;
; Z80 Membership Card Firmware, Beta Version 1.1, Dec 14, 2014
; File: ZMCv11.asm
;
; Operation concepts adapted from the Heathkit H8 computer.
;
; Revision history of the original firmware in the original source code.
;
;
;------------------------------------------------------------------------------
;	Memory Map
;------------------------------------------------------------------------------
; System RAM utilization
; 8000H-802FH - BIOS
; 8030H - Monitor
; ->80FF - Stack
; 8100H-81FFH - Buffer
; 8200H onwards - BASIC

; Routines available in int32K.asm
;BIOS_PRINT	.EQU	0069H
;BIOS_PRINT_CRLF	.EQU	006CH

; John Kerr's Disassembler
; For use in RAM
;DISZ80          .EQU    5000H

; For use in ROM - Int and Mon MUST occupy less than 2304 bytes
; Int+Mon is less than 0B00H so we put the disassembler at 0B00H
DISZ80         .EQU    0B00H

; RST xx vector table (from int32K.asm)
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

bootFlag        .EQU     vecTableEnd+6          ; From int32K.asm

MON_RAM		equ	8030H	; Start of Monitor RAM scratch space

StackTop	equ	80FFH	; Stack = 0x80FF (Next Stack Push Location = 0x80FE)

hex_buffer	equ	MON_RAM		; Offset for Intel HEX uploads
BRKPOINT	equ	MON_RAM+2	; Flag to indicate that we've hit a breakpoint and that the saved registers are valid

; Saved Registers for breakpoint
; Stored in order that they will be printed out

RSAF		equ	MON_RAM+4	; 8104H Value of AF upon breakpoint
RSBC		equ	MON_RAM+6	; Value of BC upon breakpoint
RSDE		equ	MON_RAM+8	; Value of DE upon breakpoint
RSHL		equ	MON_RAM+10	; Value of HL upon breakpoint
RSAF2		equ	MON_RAM+12	; Value of AF' upon breakpoint
RSBC2		equ	MON_RAM+14	; Value of BC' upon breakpoint
RSDE2		equ	MON_RAM+16	; Value of DE' upon breakpoint
RSHL2		equ	MON_RAM+18	; Value of HL' upon breakpoint
RSIX		equ	MON_RAM+20	; Value of IX upon breakpoint
RSIY		equ	MON_RAM+22	; Value of IY upon breakpoint
RSIR		equ	MON_RAM+24	; Value of IR upon breakpoint
RSSP		equ	MON_RAM+26	; Value of SP upon breakpoint
RSPC		equ	MON_RAM+28	; Value of PC upon breakpoint

ECHO_ON		equ	MON_RAM+30	; Echo characters
;XMSEQ		equ	MON_RAM+32	; XMODEM SEQUENCE NUMBER
;XMTYPE		equ	MON_RAM+34	; XMODEM BLOCK TYPE (CRC/CS)
DISZ80_PTR      equ     MON_RAM+36      ; Pointer to code for disassembler
IFF_STATE       equ     MON_RAM+38      ; State of IFF at breakpoint

;String equates
CR		equ	0x0D
LF		equ	0x0A
EOS		equ	0x00
ESC		equ	27

;------------------------------------------------------------------------------
; Same as bas32K.asm. Use this to create a binary that can be burned into ROM
; For ZASM, use the following command: zasm -u mon32K.asm
 		.ORG 150H

; Use this to create a binary that can be uploaded to and run from RAM e.g. for testing
; For ZASM, use the following command: zasm -u -x mon32K.asm
;		.ORG 4000H		; To test monitor in RAM
		
;------------------------------------------------------------------------------
; This part is from bas32K.asm
; int32K.asm is written to jump here

                JP      MON_ENTRY
                JP      MON_WARM    
;COLD:   	JP      MON_COLD	; STARTB          ; Jump for cold start
;WARM:   	JP      MON_WARM	; WARMST          ; Jump for warm start

;------------------------------------------------------------------------------
; Jump tables for use by the BIOS
                JP      PRINT_NEW_LINE
                JP      PRINT

;------------------------------------------------------------------------------
; Monitor entry point

SIGNON2:        .BYTE   CR,LF
		.BYTE	"C/W?",0
		
MON_ENTRY:
                LD       A,(bootFlag)   ; Check if we had previously booted
                CP       'Y'             ; to see if this is power-up
                JR       NZ,COLDSTART    ; If not BASIC started then always do cold start
                LD       HL,SIGNON2      ; Cold/warm message
                CALL     PRINT           ; Output string
CORW:
                RST     10H
                AND      %11011111       ; lower to uppercase
                CP       'C'
                JR       NZ, CHECKWARM
	        CALL	PRINT_NEW_LINE
COLDSTART:     
                LD       A,'Y'           ; Set the BASIC STARTED flag
                LD       (bootFlag),A
                JP       MON_COLD        ; monitor COLD
CHECKWARM:
                CP       'W'
                JR       NZ, CORW
                RST      08H
                CALL     PRINT_NEW_LINE
                JP       MON_WARM

;------------------------------------------------------------------------------
; MAIN MENU

MON_COLD:
		; Initial hex_buffer for Intel HEX uploads
		LD	HL, 0000H
		LD	(hex_buffer), HL	; Clear workspace offset for Intel HEX file
		LD	(BRKPOINT), HL		; Clear breakpoint flag
		LD      (IFF_STATE), HL         ; Clear interrupt enable state
		; Set vector table for breakpoint handling
		LD	HL, HANDLE_BRKPOINT
		LD	(rst30vector+1), HL

MON_WARM:		
MAIN_MENU:	
		LD	SP, StackTop	; Reset Stack = 0xFF80
		EI			; Enable interrupts
		CALL	PRINTI		;Monitor Start, Display Welcome Message
		DB	CR,LF,"Monitor >",EOS

MM_CC:
		LD	A,0xFF
		LD	(ECHO_ON),A	;TURN ON ECHO

		CALL 	GET_CHAR	;get command
		CP	':'
		JP 	Z, GETHEXFILE	; : = START HEX FILE LOAD
		CP 	'?'		; We'll print help only if explicitly asked
		JR	Z, DO_HELP

		; Handle Alpha commands here
		AND 	0x5F		; Convert to upper case
		CP 	'D'		; Branch to Command entered
		JP 	Z, MEM_DUMP	; D = Memory Dump
		CP 	'A'		; Branch to Command entered
		JP 	Z, DISASSEMBLE	; A = Call DISZ80
		CP 	'E'
		JP 	Z, MEM_EDIT	; E = Edit Memory
		CP 	'G'
		JP 	Z, GO_EXEC	; G = Go (Execute at)
		CP 	'H'
		JP 	Z, SET_BUFFER	; H = Set buffer start address for Intel HEX upload
		CP 	'O'
		JP Z, 	PORT_OUT	; O = Output to port
		CP 	'I'
		JP Z, 	PORT_INP	; I = Input from Port
		CP	'R'
		JP	Z, DISPLAY_REG
		CP	'C'
		JP	Z, CONTINUE_BRKPOINT
		JR	MAIN_MENU

;------------------------------------------------------------------------------
; Print out help
DO_HELP:
		CALL 	PRINTI		;Display Help when input is invalid
VERSION:
		DB	CR,LF,"Monitor/Debugger v0.7.1"
		DB	CR,LF,"?              Print this help"
		DB      CR,LF,"A XXXX         Disassemble from XXXX"
		DB	CR,LF,"C              Continue from Breakpoint"
		DB	CR,LF,"D XXXX         Dump memory from XXXX"
		DB	CR,LF,"E XXXX         Edit memory from XXXX; CR to skip"
		DB	CR,LF,"G XXXX         Go execute from XXXX"
		DB	CR,LF,"H XXXX         Set HEX file start address to XXXX"
		DB	CR,LF,"I XX           Input from port XX"
		DB	CR,LF,"O XX YY        Output YY to port XX"
		DB	CR,LF,"R              Display registers from Breakpoint"
		DB	CR,LF,":sHLtD...C     Load Intel HEX file, ':' is part of file"
		DB	CR,LF,EOS
		JP 	MAIN_MENU
		
;------------------------------------------------------------------------------
; MEMORY DUMP
; We will dump until ESC is pressed
MEM_DUMP:
		; out:	c=1	A = non-hex char input	DE = Word
		; out:	c=0	A = non-hex char input (No Word in DE)
		CALL	SPACE_GET_WORD	;Input start address
		JR	NC, MD_END	; If no carry, no word in DE
		LD	HL, DE
MEM_DUMP_0:
		LD	B,16		; 16 lines of 16 bytes = dump 256 bytes
MEM_DUMP_LP:
		CALL	PRINT_NEW_LINE
		CALL	DUMP_LINE	;Dump 16 byte lines (advances HL)
		DJNZ	MEM_DUMP_LP	; Loop if not done with 16 lines

		CALL	PRINTI
		DB	CR,LF,"Press any key to continue, ESC to abort",EOS
		CALL	GET_CHAR_NE
		CP	27
		JR	NZ, MEM_DUMP_0	; Dump next 256 bytes	;LP
		; Otherwise, end
MD_END:
		JP	MAIN_MENU

;-----------------------------------------------------------------------------
; DUMP_LINE -- Dumps a line
; xxxx  XX XX XX XX XX | ....ASCII....
; We save BC 'cos we'll be using B
; HL points to the memory address we are starting at
; Exit: HL points to next byte

DUMP_LINE:
		PUSH	BC		;+1 Save BC because we're using b
		PUSH	HL		;+2 Save H for 2nd part of display
		PUSH	HL		;+3 Start line with xxx0 address
		CALL	PRINT_HL	;Print Address, HL is not changed
		CALL	PRINT_SPACE
		POP	HL		;-3
		LD	B, 16		; Dump 16 bytes per line
		
DL_P1L:		; Start of print byte loop
		LD	A,(HL)		; Read byte
		CALL	SPACE_PRINT_BYTE
		INC	HL		; Next
		DJNZ	DL_P1L		; Loop next byte
;DL_P2:
		CALL	PRINTI		;Print Seperator between part 1 and part 2
		DB	" ; ", EOS

		; Print characters
DL_PSL2:
		POP	HL		;-2	Retrieve HL
		LD	B, 16		; 16 bytes per line
		
		; Print ASCII characters
DL_P2L:		; Start of print ASCII loop
		LD	A, (HL)
		CP	' '		;A - 20h	Test for Valid ASCII characters
		JR	NC, DL_P2K1
		LD	A, '.'				;Replace with . if not ASCII
DL_P2K1:
		CP	7FH		;A - 07Fh
		JR	C, DL_P2K2
		LD	A, '.'
DL_P2K2:
		CALL	PUT_CHARBC
		INC	HL
		DJNZ	DL_P2L		; Loop
		POP	BC		; Restore B
		RET			; HL points to next char

;-----------------------------------------------------------------------------
; EDIT MEMORY
; Edit memory from a starting address until non-hex character is pressed.
; Display mem loc, contents, and results of write.

MEM_EDIT:	CALL	SPACE_GET_WORD	;Input Address
		EX	DE,HL			;HL = Address to edit
ME_LP:
		CALL	PRINT_NEW_LINE
		CALL	PRINT_HL		;Print current contents of memory
		CALL	PRINT_SPACE
		LD	A, ':'
		CALL	PUT_CHARBC
		LD	A, (HL)
		CALL	SPACE_PRINT_BYTE
		; A = Byte (if CY=0)  (last 2 hex characters)  Exit if Space Entered
		; A = non-hex char input (if CY=1)
		CALL	SPACE_GET_BYTE	; Input new value or Exit if invalid
		JR	NC, ME_LP0	; Valid byte
		; Not valid hex character
		CP      A, CR          ; Did we hit a RETURN?
		JR      Z, ME_LP1       ; Yes, skip saving anything and inc hl
		JP	MAIN_MENU	; Invalid byte, C=1 -> exit
ME_LP0:
		LD	(HL), A		; Save new value
		LD	A, (HL)		; Read back value
		CALL	SPACE_PRINT_BYTE
ME_LP1:
		INC	HL		;Advance to next location
		JR	ME_LP		;repeat input

;------------------------------------------------------------------------------
; GO_EXEC - Execute program at XXXX
; Get an address and jump to it
; It would be good to use a CALL then the user routine can just use a RET to
; get back to the Monitor. However, this requires the user routine to maintain the
; integrity of the Monitor stack and will also conflict with breakpoints.

GO_EXEC:
		CALL	SPACE_GET_WORD	;Input address, c=1 if we have a word, c=0 if no word
		JR	C, GE_0		; If c=1 then we have a word to jump to
		JP	MAIN_MENU	; If c=0 then there is no word, abort
GE_0:
		CALL	PRINTI
		DB	' PC=',EOS
		LD	H,D
		LD	L,E
		CALL	PRINT_HL
		LD      HL, MAIN_MENU
		PUSH    HL              ; Save return address so that we can do a RET
		LD	HL, DE
		JP	(HL)		; HL contains the target address	

;------------------------------------------------------------------------------
; Input from port, print contents

PORT_INP:	
		CALL	SPACE_GET_BYTE	; Port address
		LD	C, A
		IN	A,(C)		; Read from port
		CALL	SPACE_PRINT_BYTE
		JP	MAIN_MENU

;------------------------------------------------------------------------------
; Get a port address, write byte out
; Give the user a way to abort and avoid writing to a port

PORT_OUT:	
		CALL	SPACE_GET_BYTE	; Port address
		LD	C, A
		CALL	SPACE_GET_BYTE	; Data to write to port
		JR      C, PO_0         ; Abort if any other keypressed
		OUT	(C),A
PO_0:
		JP	MAIN_MENU

; -------------------------------------------------------------------
; Breakpoint
; Note that this breakpoint implementation will not work if you have stuff on stack
; and you do not use your own application stack space
; This is because we restore the Monitor StackTop to SP
; So Monitor operations will clobber data on your stack when this happens
; Usage recommendation: Use your own stack space

HANDLE_BRKPOINT:
		; We get here after a RST30
		; PC is at SP 
		; We now save all the registers
;		DI		; Optional?

		LD	(RSHL), HL		; Save HL
		POP	HL			; Grab PC & set SP to actual value
		LD	(RSPC), HL		; Save PC
		LD	(RSSP), SP		; Save SP
		LD	SP, StackTop		; Use Monitor stack top
		PUSH	AF
		POP	HL
		LD	(RSAF), HL		; Save AF
		; Some clunky code to capture state of the interrupt enable ff
		LD      L, 0AAH                 ; Flag I enabled
		LD      A, I                    ; Capture IFF state
		                                ; Note P=1 is even, P=0 is odd
		JP      PE, IENB                ; IFF set = enabled
                LD      L, 055H                 ; Flag I disabled
IENB:
                LD      (IFF_STATE), HL         ; Save IFF_STATE
		; Save the rest of the registers
		DI                              ; Disable Interrupts for now
		LD	(RSBC), BC
		LD	(RSDE), DE
		LD	(RSIX), IX
		LD	(RSIY), IY
		LD	A, I			; Save IR
		LD	H, A
		LD	A, R
		LD	L, A
		LD	(RSIR), HL
		EX	AF, AF'                 ; Switch to alternate registers
		EXX
		LD	(RSHL2), HL
		PUSH	AF
		POP	HL
		LD	(RSAF2), HL
		LD	(RSBC2), BC
		LD	(RSDE2), DE
		EX	AF, AF'                 ; Switch back registers
		EXX
		LD	HL, 0A5A5H
		LD	(BRKPOINT), HL		; Indicate we have valid breakpoint info
		EI
		CALL	REG_DISP_ALL		; Display the registers
		CALL	PRINTI
		DB	LF,CR,"Press C to continue or ESC to return to Monitor",CR,LF,EOS
HB_INVKEY:
		CALL	IN_CHARBC	; This is a blocking call, key in A
		CP	27		; ESC?
		JR	NZ, HB_NESC
		JP	MAIN_MENU	; Yes, exit to main menu
HB_NESC:				; No
		AND	05FH		; Check if C
		CP	'C'
		JR	NZ, HB_INVKEY	; No, go and get a valid key, no implicit defaults here
		CALL    PRINT_NEW_LINE
		; Reload registers and continue execution
RELOAD_REG:
		DI
		LD	BC, (RSBC)
		LD	DE, (RSDE)
		LD	IX, (RSIX)
		LD	IY, (RSIY)
		LD	HL, (RSIR)		; Restore IR
		LD	A, L
		LD	R, A
		LD	A, H
		LD	I, A

		EX	AF, AF'                 ; Switch to alternate
		EXX
		LD	BC, (RSBC2)
		LD	DE, (RSDE2)
		LD	HL, (RSAF2)
		PUSH	HL
		POP	AF
		LD	HL, (RSHL2)
		EX	AF, AF'                 ; Switch back to regular registers
		EXX
		; Check if we need to re-enable interrupts
		LD      A, (IFF_STATE)          ; Check saved state
		CP      A, 0AAH                 ; Interrupt enabled
		JR      NZ, LEAVE_DI            ; Not 0AAh
		EI                              ; TODO: can we restore the IFF?
LEAVE_DI:       
		LD	HL, (RSAF)		; Restore AF
		PUSH	HL
		POP	AF
		LD	HL, (RSPC)		; Get PC
		LD	SP, (RSSP)		; Restore SP
		PUSH	HL			; PC to Stack
		LD	HL, (RSHL)		; Restore HL
		RET				; Jump to PC

;------------------------------------------------------------------------------

BRKPOINT_MSG:
		CALL	PRINTI
		DB	LF,CR,"Breakpoint at PC=",EOS
		LD	HL, (RSPC)
		DEC	HL	; Point to the RST 30H instruction
		CALL	PRINT_HL
		RET

;------------------------------------------------------------------------------
; Continue from a previous breakpoint

CONTINUE_BRKPOINT:
		LD	A, (BRKPOINT)
		CP	0A5H
		JR	Z, VALID_BRKPOINT
INVALID_BRKPOINT:
		CALL	PRINTI
		DB	LF,CR,"No breakpoint set",EOS
		JP	MAIN_MENU
VALID_BRKPOINT:
		JP	RELOAD_REG
	
; -----------------------------------------------------------------------------
; Display registers
; Needs optimization

DISPLAY_REG:
		LD	A, (BRKPOINT)		; Make sure that a valid breakpoint was previously set
		CP	0A5H
		JR	NZ, INVALID_BRKPOINT	; Invalid breakpoint
		CALL	REG_DISP_ALL		; Display registers
		JP	MAIN_MENU

; -----------------------------------------------------------------------------
; Display register values
; Breakpoint at PC=xxxx
; AF =xxxx  BC =xxxx  DE =xxxx  HL =xxxx  
; AF'=xxxx  BC'=xxxx  DE'=xxxx  HL'=xxxx
; IX =xxxx  IY =xxxx  IR =xxxx  SP =xxxx

REG_DISP_ALL:
		CALL	BRKPOINT_MSG
		CALL	PRINT_NEW_LINE	;Dump ALL registers
		LD	B, 0		;12 Registers to dump
RM_LP:
		LD	C, B
		CALL	PRINT_REGNAME
		CALL	RM_DUMP_REG
		CALL	PRINTI
		DB	'  ',EOS
		LD	A,3
		CP	B
		JR  	NZ, RM_0
RM_1:
		CALL	PRINT_NEW_LINE
		JR	RM_2
RM_0:
		LD	A,7
		CP	B
		JR	Z, RM_1
RM_2:
		INC	B
		LD	A, 12
		CP	B
		JR	NZ, RM_LP
		RET

;------------------------------------------------------------------------------

RM_DUMP_REG:
		LD	A,'='
		CALL	PUT_CHARBC
		LD	A,C
		CALL	GET_REGISTER
		CALL	PRINT_HL
		RET

; -------------------------------------------------------------------
; Input: C = number of the register

PRINT_REGNAME:
		CALL	GET_REGNAME
		CALL	PRINT
		RET

; -----------------------------------------------------------------------------
; Get the name of the register
; Input: C = Number of the register (0-12)
; Exit: HL = pointer to name of the register

GET_REGNAME:
		LD	A,C		; Multiple by 4
		ADD	A,C
		ADD	A,C
		ADD	A,C
		LD	HL,REGNAMES
		CALL	ADD_HL_A
		RET

REGNAMES	
		DB	'AF ',0
		DB	'BC ',0
		DB	'DE ',0
		DB	'HL ',0
		DB	'AF',27H,0
		DB	'BC',27H,0
		DB	'DE',27H,0
		DB	'HL',27H,0
		DB	'IX ',0
		DB	'IY ',0
		DB	'IR ',0
		DB	'SP ',0

; -----------------------------------------------------------------------------
; Calculate offset to RAM where we store the value of the register
; Input: C = number 0-12 of the register
; Exit: HL = offset

GET_REGISTER:
		PUSH	DE
		LD	HL, RSAF	; Start of register storage area
		LD	A, C
		ADD	A, C		; Multiple by 2
		CALL	ADD_HL_A
		LD	DE, (HL)
		LD	HL, DE
		POP	DE
		RET

;------------------------------------------------------------------------------
; Print a space, then get a byte from the serial console
; in:	Nothing
; out:	A = Byte (if CY=0)  (last 2 hex characters)  Exit if Space Entered
;	A = non-hex char input (if CY=1)

SPACE_GET_BYTE:
		CALL	PRINT_SPACE

;------------------------------------------------------------------------------
; GET_BYTE -- Get byte from console as hex
;
; in:	Nothing
; out:	A = Byte (if CY=0)  (last 2 hex characters)  Exit if Space Entered
;	A = non-hex char input (if CY=1)

GET_BYTE:	CALL	GET_HEX_CHAR	;Get 1st HEX CHAR
		JR  	NC, GB_1
		CP	' '		;Exit if not HEX CHAR (ignoring SPACE)
		JR 	Z, GET_BYTE	;Loop back if first char is a SPACE
		SCF			;Set Carry
		RET			;or EXIT with delimiting char
GB_1		PUSH	DE		;Process 1st HEX CHAR
		RLCA
		RLCA
		RLCA
		RLCA
		AND	0xF0
		LD	D,A
		CALL	GET_HEX_CHAR
		JR  	NC, GB_2		;If 2nd char is HEX CHAR
		CP	' '
		JR Z,	GB_RET1
		SCF			;Set Carry
		POP	DE
		RET			;or EXIT with delimiting char
GB_2		OR	D
		POP	DE
		RET
GB_RET1		LD	A,D
		RRCA
		RRCA
		RRCA
		RRCA
GB_RET		OR	A
		POP	DE
		RET

;------------------------------------------------------------------------------
; Print a space, then input a word
;
; in:	Nothing
; out:	c=1	A = non-hex char input
;		DE = Word
; out:	c=0	A = non-hex char input (No Word in DE)

SPACE_GET_WORD:
		CALL	PRINT_SPACE

;------------------------------------------------------------------------------
; GET_WORD -- Get word from console as hex
;
; in:	Nothing
; out:	c=1	A = non-hex char input
;		DE = Word
; out:	c=0	A = non-hex char input (No Word in DE)

GET_WORD:
		LD	DE,0
		CALL	GET_HEX_CHAR	;Get 1st HEX CHAR
		JR  	NC, GW_LP
					; Not HEX
		CP	' '		; Is it SPACE
		JR 	Z, GET_WORD	; Loop back if first char is a SPACE
		OR	A		; Otherwise, clear Carry and exit
		RET			; 
GW_LP:
		LD	E,A		; HEX
		CALL	GET_HEX_CHAR	; Get next char
		RET 	C		; EXIT when a delimiting char is entered
		EX	DE,HL		; Else, shift new HEX Char Value into DE
		ADD	HL,HL
		ADD	HL,HL
		ADD	HL,HL
		ADD	HL,HL
		EX	DE,HL
		OR	E
		JR	GW_LP

; -----------------------------------------------------------------------------
; Get HEX CHAR
; In:	Nothing
; Out:	A = Value of HEX Char when CY=0
;	A = Received (non-hex) char when CY=1

GET_HEX_CHAR:
		CALL	GET_CHAR
		CP	'0'
		JP M,	GHC_NOT_RET
		CP	'9'+1
		JP	M, GHC_NRET	; Number
		AND	05FH		;
		CP	'A'
		JP M,	GHC_NOT_RET	; Not HEX
		CP	'F'+1
		JP M,	GHC_ARET

GHC_NOT_RET	SCF
		RET
GHC_ARET	SUB	0x07
GHC_NRET	AND	0x0F	; Clear CY
		RET

; -----------------------------------------------------------------------------
; PUT_CHARBC
; Output character to RS232
; Character is in A
; Preserve AF

PUT_CHARBC:	
		PUSH	AF
		RST	08H
		POP	AF
		RET

; -----------------------------------------------------------------------------
; PRINT -- Print A null-terminated string @(HL)
; Original code: HL points to byte past the EOS
; BIOS code: HL points to EOS. But that is okay because EOS = NOP!!
;PRINT:		JP	BIOS_PRINT
;------------------------------------------------------------------------------
; Input: HL points to the string
; Exit; A is changed, HL points to EOS
PRINT:          LD       A,(HL)          ; Get character
                OR       A               ; Is it 00H ?
                RET      Z               ; Then RETurn on terminator
                RST      08H             ; Print it
                INC      HL              ; Next Character
                JR       PRINT           ; Continue until 00H
                RET

; -----------------------------------------------------------------------------
; PRINT IMMEDIATE
; Top of stack (PC) points to string

PRINTI:		EX	(SP),HL	; HL = Top of Stack
		CALL	PRINT
		EX	(SP),HL	; Move updated return address back to stack
		                ; Points to EOS of string which is a NOP
		RET

; -----------------------------------------------------------------------------
; PRINT_HL Prints HL Word as Hex
; Exit: HL is not changed

PRINT_HL:		
		LD	A, H
		CALL	PRINT_BYTE
		LD	A, L
		CALL	PRINT_BYTE
		RET

; -----------------------------------------------------------------------------
; SPACE_PRINT_BYTE -- Output (SPACE) & byte to console as hex
;
; Input: A register contains byte to be output
; Output: Destroys A

SPACE_PRINT_BYTE:
		PUSH	AF
		CALL	PRINT_SPACE
		POP	AF

; -----------------------------------------------------------------------------
; PRINT_BYTE -- Output byte to console as hex
;
; Input: A register contains byte to be output
; Exit: Destroys A

PRINT_BYTE:
		PUSH	AF
		RRCA
		RRCA
		RRCA
		RRCA
		AND	0x0F
		CALL	PRINT_HEX
		POP	AF
		AND	0x0F

;------------------------------------------------------------------------------
; PRINT_HEX -- Convert nibble to ASCII char

PRINT_HEX:
		CALL	TO_HEX
		JP	PUT_CHARBC

;------------------------------------------------------------------------------
;TO_HEX - Convert nibble to ASCII char

TO_HEX:		AND	0xF
		ADD	A,0x30
		CP	0x3A
		RET C
		ADD	A,0x7
		RET

;------------------------------------------------------------------------------
; PRINT_SPACE -- Print a space to the console
;
;pre: none
;post: 0x20 printed to console

PRINT_SPACE:	LD	A, ' '
		JP	PUT_CHARBC

;------------------------------------------------------------------------------
; PRINT_NEW_LINE -- Start a new line on the console
;
;pre: none
;post: 0x0A printed to console

;------------------------------------------------------------------------------
; Exit: A is changed
PRINT_NEW_LINE:
;		JP	BIOS_PRINT_CRLF	;006CH		; Call BIOS
                LD        A, 0DH
		RST       08H
		LD        A, 0AH
		RST       08H
		RET

;------------------------------------------------------------------------------

ADD_HL_A	ADD	A, L
		LD	L, A
		RET     NC
		INC	H
		RET

;------------------------------------------------------------------------------
; Get a starting address to disassemble from
; Press C to disassemble each instruction and ESC to return to main menu
;
DISASSEMBLE:
                CALL	SPACE_GET_WORD	;Input address, c=1 if we have a word, c=0 if no word
		JR	NC, DISZ_0	; If c=0 then there is no word, abort
					; If c=1 then we have a word to load
		LD	(DISZ80_PTR), DE	; Store word
		CALL	PRINTI
		DB	LF,CR,"Disassemble from ",EOS
		LD	HL, DE          ; Address to HL
		CALL	PRINT_HL
		CALL    PRINTI
		DB      CR,LF,"Press any key to step, ESC to abort", EOS
DISZ_LP:
		CALL    PRINT_NEW_LINE
		LD      DE, (DISZ80_PTR)        ; Restore pointer for disassembly
		CALL    DISZ80                  ; Disassemble one line
		                                ; and print output
		LD      (DISZ80_PTR), DE        ; Save pointer
		; Then handle keypress and loop
		CALL	GET_CHAR_NE
		CP	27
		JR      NZ, DISZ_LP     ; Not ESC = loop
DISZ_0:
		JP	MAIN_MENU

;------------------------------------------------------------------------------
; Set the address to the buffer where we want to upload the Intel HEX file
; This is to be used if the Intel HEX file uses 0000h as the start address
; You will want to set this address to somewhere in RAM...

SET_BUFFER:
		CALL	SPACE_GET_WORD	;Input address, c=1 if we have a word, c=0 if no word
		JR	NC, SE_0	; If c=0 then there is no word, abort
					; If c=1 then we have a word to load
		LD	(hex_buffer),DE	; Store word
		CALL	PRINTI
		DB	LF,CR,"HEX file buffer set to ",EOS
		LD	HL, DE
		CALL	PRINT_HL
SE_0:
		JP	MAIN_MENU

;------------------------------------------------------------------------------
; ASCII HEXFILE TRANSFER (INTEL Hex file format)
; Registers:	B= Byte counter per line (initialized at start of line)
;		C= Check sum (initialized at start of line)
;		D= Temp for assembling HEX bytes
;		E= Error counter over the entire transfer
;		HL= Address to save data
;		IX= byte count for the entire transfer
; We are jumping in here with the first character ":" already loaded
; Changes here include making the process more deterministic since we're not
; timing out.
GETHEXFILE:
		LD	E,0		;ZERO ERROR COUNTER
		LD	IX, 0		; Byte counter
		JR	GHDOLINE	; Jump straight to reading in the byte count

GHWAIT:
		CALL	GETCHAR_ESC
		JR  	C, GHENDTO	; Timeout
		CP	27		; ESC
		JR  	Z, GHENDTO	; Abort if ESC
		CP	':'
		JR  	NZ, GHWAIT

		; Handle a line
GHDOLINE:	
                        CALL	TGET_BYTE	;GET BYTE COUNT
		LD	B, A		;BYTE COUNTER
		LD	C, A		;CHECKSUM

		CALL	TGET_BYTE	;GET HIGH ADDRESS
		LD	H, A

		CALL	TGET_BYTE	;GET LOW ADDRESS
		LD	L, A
		; Add buffer start
		PUSH	DE
		LD	DE, (hex_buffer)
		ADD	HL, DE
		POP	DE
		CALL	TGET_BYTE	;GET RECORD TYPE
		JR	C, GHENDTO
		CP	1
		JR 	Z, GHEND	;IF RECORD TYPE IS 01 THEN END
		
		; Assuming everything else is data record...
GHLOOP:
		CALL	TGET_BYTE	;GET DATA
		JR	C, GHENDTO
		LD	(HL),A
		INC	HL
		INC	IX
		DJNZ	GHLOOP		;Repeat for all data in line

		CALL	TGET_BYTE	;GET CHECKSUM
		JR	C, GHENDTO
		XOR	A
		CP	C		;Test Checksum = 0
		JR 	Z, GHWAIT0	; No error
		INC	E
		JR  	NZ, GHWAIT0
		DEC	E
GHWAIT0:
		LD	A, '.'		; Output tick
		CALL	PUT_CHARBC
		JR	GHWAIT
		
GHEND		; We come here on detecting RECORD TYPE = 1 but there are 2 more 
		; characters in this last record
		CALL	TGET_BYTE	; Get the last checksum byte
GHENDTO:
GHEND1:
		CALL	PRINTI
		DB	CR,LF,"HEX TRANSFER COMPLETE ERRORS=",EOS
		LD	A,E
		CALL	PRINT_BYTE
	
		CALL	PRINT_SPACE
		PUSH	IX		; Byte count
		POP	HL
		CALL	PRINT_HL	; Print byte count
		CALL	PRINTI
		DB	" BYTES TRANSFERRED",EOS
		JP	MAIN_MENU
		
;-----------------------------------------------------------------------------
; TGET_BYTE -- Get byte from console as hex
;
; Input: C holds a checksum byte
; Exit:	A = Byte (if CY=0)  (last 2 hex characters)  Exit if Space Entered
;	A = non-hex char input (if CY=1)

TGET_BYTE:	CALL	TGET_HEX_CHAR	; Get 1st HEX CHAR
		JR  	C,  TGB0        ; Received ESC
		RLCA			; Shift 1st HEX CHAR
		RLCA
		RLCA
		RLCA
		AND	0xF0
		LD	D,A
		CALL	TGET_HEX_CHAR	;Get 2nd HEX CHAR
		JR  	C, TGB0         ; Received ESC
		OR	D
		LD	D,A		;Save byte
		ADD	A,C		;Add byte to Checksum
		LD	C,A
		LD	A,D		;Restore byte
		OR	A		; Clear carry
TGB0:
		RET
	
;------------------------------------------------------------------------------
; Get HEX CHAR
; Input: Nothing
; Exit:	CY=0, A = Value of HEX Char
;	CY=1, A = Received (non-hex) char

TGET_HEX_CHAR:
		CALL	GETCHAR_ESC	; C=1, No Char (ESCed)
					; C=0, A = Char
		RET	C		; Timeout. Should probably test for ESC here
		CP	'0'
		JP	M, TGHC_NOT_RET
		CP	'9'+1
		JP	M, TGHC_NRET		; Number
		AND	05FH
		CP	'A'
		JP	M, TGHC_NOT_RET
		CP	'F'+1
		JP	M, TGHC_ARET		; A-F
TGHC_NOT_RET:
		SCF
		RET
TGHC_ARET:
		SUB	0x07
TGHC_NRET:
		AND	0x0F
		RET

; -----------------------------------------------------------------------------
;GET_CHAR -- Get a char from the console NO ECHO

GET_CHAR_NE:

; -----------------------------------------------------------------------------
; Get A byte
; Exit:	C=0, A=Byte from Buffer

IN_CHARBC:
		RST 	10H
		OR	A		; Exit with C=0
		RET

; -----------------------------------------------------------------------------
; GET_CHAR -- Get a char from the console

GET_CHAR:	
		LD	A,(ECHO_ON)
		OR	A
		JR	Z, GET_CHAR_NE
GET_CHAR_LP:
		CALL	GET_CHAR_NE
		CP	' '	; Do not echo control chars
		RET	M
		JP	PUT_CHARBC

; -----------------------------------------------------------------------------
; GETCHAR_ESC - Gets a character with ESC detection
; In:	Nothing
; Out: 	C=1, No Char (ESC pressed)
;	C=0, A = Character

GETCHAR_ESC:
		CALL	IN_CHARBC	; This is a blocking call
		CP	A, 27		; ESC
		JR	Z, TGC_TOBC
		OR	A		; C=0
		RET
TGC_TOBC:
		SCF			; C=1
		RET

; Set of end of mon32K.asm so that we end up with a 4KB Int+Mon+DISZ80 binary
; Comment these 2 lines out if compiling for running in RAM
; Also comment these out if the size of the Monitor runs big otherwise ZASM will
; throw an error fit
                .ORG    0AFFH
                DB      0AAH

