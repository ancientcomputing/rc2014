; Changes:
; 1. Adapted for zasm assembler including making things case sensitive
; 2. Adapted for RC2014 and modified init32K.asm
; 3. Removed/commented out all non-RS232 code
; 4. Added W command to set the start of the workspace where we want to load the Intel HEX file. This is needed for
; hex files that start at address 0000H instead of somewhere in RAM.
; 5. Clean up return from command handlers. Use explicit jump to MAIN_MENU
;
;
; Notes:
; 1. Intel HEX file uploads: If you are using Serial on Mac, you want to enable RTS/CTS. This will allow you to send
; the HEX file over using the "Send File" option. If you don't do this, the data rate is too high for the monitor to handle
; even with the Z80 running at 7+MHz on the RC2014.
; 2. If you don't enable RTS/CTS or if you serial terminal program doesn't work well with an RTS/CTS option, you want to 
; use a "Send Text File" option. This option is available on Serial and will respect the line delay set up.
;
; Changes to Josh's original code are copyright Ben Chong and freely licensed to the community
;
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;	Acknowledgments
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;
; Assemble using ZASM ver 4.0
;
; Based on the monitor that comes with Lee Hart's Z80 Membership Card
;
; Original Operation, Documentation and Consultation by Herb Johnson
;
; Original Firmware by Josh Bensadon. Date: Feb 10, 2014
;
; Z80 Membership Card Firmware, Beta Version 1.1, Dec 14, 2014
; File: ZMCv11.asm
;
;
; Operation concepts adapted from the Heathkit H8 computer.
;
;Revision.
;0.1 	- RS-232 Full duplex operational. June 15
;0.2 	- LED Put_Char routine operational
;	- Keyboard Scanning operational
;	- Demo Keyboard or RS-232 input Displays on both LED & RS-232 output
;0.3	- Added a modified version of my IMSAI 8080 monitor
;	- Modified Dump routine to output "M"
;	- Added "M" function to enter Memory bytes
;	- Fixed code to assemble using ASMX.
;0.4	- First Beta Version.
;	- Added Rest of Keyboard functionality (Alter Register, Memory, I/O, GO)
;0.5	- Halt reset working
;	- Single Step working
;0.6	- Rewrote Register Save
;	- F-0 Reset detection working
;	- Fixed Display mode after Step
;	- Removed "Test Code"
;0.7	- Repurposed LED x7 to activate beeper on key down events
;0.8	- Corrected bug introduced in v0.7 with lights
;0.9	- Documentation improvements
;	- UiVec now a Subroutine, terminate with RET
;1.0	- Documentation improvements
;	- Get Hexfile routine modified to timeout if bad data or if end-of-file record not received
;	- X-Modem send & receive timeout values increased to allow more time to open/send or receive files
;1.1	- Added Single Step to RS-232 Menu
;
;Note.  Some assemblers might choose to substitute Long Jumps (JP) with Relative Jumps (JR) when possible.
;	These two instructions have different execution times.  Generally, this would not be an issue, however,
;	within the RS-232 bit banging routines, timing is critical and it may not tolerate the substitution.
;	The ASMX assembler supported by Herb Johnson's web site works great and does not substitute.
;
;
;
;
;
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;	Preface ii - Description, Operation
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;- - - The Terminal interface - - -
;
;Through a Terminal, there are more features you can use.  Entering a question mark (?) or another unrecognized command will display a list of available commands.
;Most commands are easy to understand, given here are the few which could use a better explaination.
;
; X - Xmodem Transfers	Transfers a binary file through the XModem protocol.  Enter the command, then configure your PC to receive or send a file.
;			eg. X U 8000<CR> will transfer a file from your PC to the RAM starting at 8000 for the length of the file (rounded up to the next 128 byte block).
;			eg. X D 8000 0010 will transfer a file from RAM to your PC, starting at 8000 for 10 (16 decimal) blocks, hence file size = 2K.
; : - ASCII HEX Upload	The ":" character is not entered manually, it is part of the Intel HEX file you can upload through ASCII upload.
;			eg. While at the prompt, just instruct your PC's terminal program to ASCII upload a .HEX file.
;
;

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;	Preface iii- Memory Mapping, I/O Mapping
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

; System RAM utilization
; 8000H-80FFH - BIOS
; 8100H-81FFH - Monitor
; 8200H onwards - BASIC

MON_RAM		equ	8100H	; Start of Monitor RAM scratch space

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;Reserve space from 0xFF60 to FF7F for Stack
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
StackTop	equ	81FFH	; Stack = 0x81FF (Next Stack Push Location = 0x81FE)

;*** BEGIN COLD_BOOT_INIT (RAM that is to be initialized upon COLD BOOT) ***
#if 0
RAMSIGNATURE	equ	0xFF60	;RAM signature
				;WARNING, Following 19 bytes must be consecutive in this order
RC_TYPE		equ	0xFF68	;Type of Reset (WARNING, Next 7 RC counters must end with lsb bits = 001,010,011,100,101,110,111)
RC_SOFT		equ	0xFF69	;Count of Resets by SOFT F-E SWITCH
RC_STEP		equ	0xFF6A	;Count of Resets by SINGLE STEP
RC_CC		equ	0xFF6B	;Count of Resets by CTRL-C
RC_HALT		equ	0xFF6C	;Count of Resets by HALT INSTRUCTION
RC_F0		equ	0xFF6D	;Count of Resets by pressing F & 0 keys
RC_RST0		equ	0xFF6E	;Count of Resets by RST 0 INSTRUCTION
RC_HARD		equ	0xFF6F	;Count of Resets by UNKNOWN RESET LINE

UiVec		equ	0xFF70	;User Interrupt Vector
;		equ	0xFF72	;
ABUSS		equ	0xFF74	;
IoPtr		equ	0xFF76	; I/O Ptr
RX_ERR_LDRT	equ	0xFF77	;Counts False Start Bits (Noise Flag)
RX_ERR_STOP	equ	0xFF78	;Counts Missing Stop Bits (Framing Error)
RX_ERR_OVR	equ	0xFF79	;Counts Overrun Errors
BEEP_TO		equ	0xFF7A	;Count down the beep (beep duration)
#endif

hex_buffer	equ	MON_RAM		; Offset for Intel HEX uploads
RegPtr		equ	MON_RAM+2	; Ptr to Registers

;*** END COLD_BOOT_INIT (RAM that is to be initialized upon COLD BOOT) ***

;Saved Registers
RSSP		equ	MON_RAM+4	;Value of SP upon REGISTER SAVE
RSAF		equ	MON_RAM+6	;0xFF82	;Value of AF upon REGISTER SAVE
RSBC		equ	MON_RAM+8	;0xFF84	;Value of BC upon REGISTER SAVE
RSDE		equ	MON_RAM+10	;0xFF86	;Value of DE upon REGISTER SAVE
RSHL		equ	MON_RAM+12	;0xFF88	;Value of HL upon REGISTER SAVE
RPC		equ	MON_RAM+14	;0xFF8A	;Value of PC upon REGISTER SAVE
RSIX		equ	MON_RAM+16	;0xFF8C	;Value of IX upon REGISTER SAVE
RSIY		equ	MON_RAM+18	;0xFF8E	;Value of IY upon REGISTER SAVE
RSIR		equ	MON_RAM+20	;0xFF90	;Value of IR upon REGISTER SAVE
RSAF2		equ	MON_RAM+22	;0xFF92	;Value of AF' upon REGISTER SAVE
RSBC2		equ	MON_RAM+24	;0xFF94	;Value of BC' upon REGISTER SAVE
RSDE2		equ	MON_RAM+26	;0xFF96	;Value of DE' upon REGISTER SAVE
RSHL2		equ	MON_RAM+28	;0xFF98	;Value of HL' upon REGISTER SAVE

ECHO_ON		equ	MON_RAM+30	;0xFFF2	;Echo characters
XMSEQ		equ	MON_RAM+32	;0xFFF3	;XMODEM SEQUENCE NUMBER
XMTYPE		equ	MON_RAM+34	;0xFFF4	;XMODEM BLOCK TYPE (CRC/CS)

#if 0
;*** BEGIN WARM_BOOT_INIT (RAM that is to be initialized on every boot) ***
				;WARNING, Following 33 bytes must be consecutive in this order
ANBAR_DEF	equ	0xFFA1	;Base setting for the Annunciator LED's (after current function times out)
GET_REG		equ	0xFFA2	;Get Reg Routine (in monitor mode, registers fetched from RAM)
PUT_REG		equ	0xFFA4	;Put Reg Routine
CTRL_C_CHK	equ	0xFFA6	;Vector for CTRL-C Checking
LDISPMODE	equ	0xFFA8	;Last Display Mode (Holds DISPMODE while in HEX Entry)
DISPMODE	equ	0xFFAA	;Display Routine
KEY_EVENT	equ	0xFFAC	;
IK_TIMER	equ	0xFFAE	;IMON TIMEOUT
KEYBFMODE	equ	0xFFAF	;KEY INPUT MODE. 8F=HEX INPUT, 90=Shiftable
DISPLABEL	equ	0xFFB0	;Display Label Refresh
IK_HEXST	equ	0xFFB1	;IMON HEX Input State
HEX_CURSOR	equ	0xFFB2	;HEX Input Cursor location
HEX_READY	equ	0xFFB4	;HEX Input Ready
LED_CURSOR	equ	0xFFB6	;Cursor location for LED Put_Char
PUTCHAR_EXE	equ	0xFFB8	;PutChar Execution (Set for PC_LED or PC_RS232)
RXBHEAD		equ	0xFFBA	;RS-232 RX BUFFER HEAD
RXBTAIL		equ	0xFFBC	;RS-232 RX BUFFER TAIL
INT_VEC		equ	0xFFBE	;Vector to Interrupt ISR
SCAN_PTR	equ	0xFFC0	;SCAN_PTR points to next LED_DISPLAY byte to output (will always be 1 more
				;than the current hardware column because hardware automatically advances)

;*** END WARM_BOOT_INIT (RAM that is to be initialized on every boot) ***

SDISPMODE	equ	0xFFC2

CLEARED_SPACE	equ	0xFFC2	;Bytes here and later are cleared upon init (some initialized seperately)
CLEARED_LEN	equ	0xFFFF - CLEARED_SPACE + 1
CTRL_C_TIMER	equ	0xFFDE	;Count down the CTRL-C condition
SOFT_RST_FLAG	equ	0xFFDF	;Flag a Soft Reset (F-E Keys, Single Step)

				;Display/Serial Comms
LED_DISPLAY	equ	0xFFE0	;8 Bytes of LED Output bytes to Scan to hardware
;8 Bytes			;Warning, LED_DISPLAY must be nibble aligned at E0 (XXE0)
LED_ANBAR	equ	0xFFE7	;LED Annunciator Bar (Part of LED_DISPLAY Buffer)

IK_HEXL		equ	0xFFE8	;IMON HEX INPUT
IK_HEXH		equ	0xFFE9	;IMON HEX INPUT

KBHEXSAMPLE	equ	0xFFEA	;KEY SAMPLER Input HEX format
KBOCTSAMPLE	equ	0xFFEB	;KEY SAMPLER Input Octal Format (Upper-Row/Lower-Row)
KEY_OCTAL	equ	0xFFEC	;KEY Input Octal Format (Upper-Row/Lower-Row)
KEYBSCANPV	equ	0xFFED	;KEY Input HEX format
KEYBSCANTIMER	equ	0xFFEE	;KEY Input TIMER
KEY_PRESSED	equ	0xFFEF	;KEY INPUT LAST & Currently Processing

TicCnt		equ	0xFFF0	;Tic Counter
;TicCnt		equ	0xFFF1	;

SCAN_LED	equ	0xFFF5	;Holds the next LED output
LED_DISPLAY_SB	equ	0xFFF6	;10 Bytes FFF6=Start BIT, 7,8,9,A,B,C,D,E=Data bits, F=Stop BIT
;10 bytes	equ	0xFFFF	;Warning, LED_DISPLAY_TBL must be at this address (XXF6)

#endif

;String equates
CR		equ	0x0D
LF		equ	0x0A
EOS		equ	0x00
ESC		equ	27

 		.ORG 150H		; Same as bas32K.asm
;		.ORG 9000H		; To test monitor in RAM
		
		; This part is from bas32K.asm
		; int32K.asm is written to jump here
COLD:   	JP      MON_COLD	; STARTB          ; Jump for cold start
WARM:   	JP      MON_WARM	; WARMST          ; Jump for warm start

;----------------------------------------------------------------------------------------------------
; MAIN MENU

MON_COLD:
		; Initial hex_buffer for Intel HEX uploads
		LD	HL, 0000H
		LD	(hex_buffer), HL

MON_WARM:		
MAIN_MENU:	
		LD	SP, StackTop	; Reset Stack = 0xFF80
		EI			; Enable interrupts
		CALL	PRINTI		;Monitor Start, Display Welcome Message
		DB	CR,LF,"Monitor >",EOS

MM_PURGE:
		LD	A,0xFF
		LD	(ECHO_ON),A	;TURN ON ECHO

		CALL 	GET_CHAR	;get command
		CP	':'
		JP 	Z, GETHEXFILE	; : = START HEX FILE LOAD
		CP	3
		JR 	Z, MM_PURGE
		CP 	'?'
		JR	Z, DO_HELP
		; Handle Alpha commands here
		AND 	0x5F		;to upper case
		CP 	'D'		;Branch to Command entered
		JP 	Z, MEM_DUMP	; D = Memory Dump
		CP 	'E'
		JP 	Z, MEM_EDIT	; E = Edit Memory
		CP 	'G'
		JP 	Z, MEM_EXEC	; G = Go (Execute at)
		CP 	'W'
		JP 	Z, SET_BUFFER	; W = Set buffer start address for Intel HEX upload
		CP 	'O'
		JP Z, 	PORT_OUT	; O = Output to port
		CP 	'I'
		JP Z, 	PORT_INP	; I = Input from Port
		CP 	'X'
		JP Z, 	XMODEM		; X = XMODEM
#if 0
		CP 	'R'
		JP Z,	REG_MENU	; R = REGISTER OPERATIONS
#endif

		CP 	'V'
		JP	Z, VERSION		; V = Version

		JR	MAIN_MENU

;=============================================================================
DO_HELP:
		CALL 	PRINTI		;Display Help when input is invalid
		DB	CR,LF,"HELP"
		DB	CR,LF,"?              Print this help"
		DB	CR,LF,"D XXXX         Dump memory from XXXX"
		DB	CR,LF,"E XXXX         Edit memory starting at XXXX"
		DB	CR,LF,"G XXXX         Go execute from XXXX"
		DB	CR,LF,"I XX           Input from I/O"
		DB	CR,LF,"O XX YY        Output to I/O"
		DB	CR,LF,"V              Version"
		DB	CR,LF,"W XXXX         Set workspace XXXX"
		DB	CR,LF,":sHLtD...C     UPLOAD Intel HEX file, ':' is part of file"
		DB	CR,LF,"X U XXXX       XMODEM Upload to memory at XXXX"
		DB	CR,LF,"X D XXXX CCCC  XMODEM Download from XXXX for CCCC #of 128 byte blocks"
		DB	CR,LF,EOS
		JP 	MAIN_MENU

;=============================================================================
;Display Version
;-----------------------------------------------------------------------------
VERSION		CALL	PRINTI
		DB	CR,LF,"RC2014 Monitor v0.3",CR,LF,EOS
		JP	MAIN_MENU
		
;=============================================================================
;Register Display/Set
;-----------------------------------------------------------------------------
#if 0
REG_MENU	CALL	PUT_SPACE
		CALL	GET_CHAR
		CP	CR
		JP  	NZ,	RM_NOTALL

;12345678901234567890123456789012345678901234567890123456789012345678901234567890  80 COLUMNS
;AF=xxxx  BC=xxxx  DE=xxxx  HL=xxxx  AF'=xxxx  BC'=xxxx  DE'=xxxx  HL'=xxxx
;IX=xxxx  IY=xxxx  IR=xxxx  PC=xxxx  SP=xxxx

REG_DISP_ALL	CALL	PUT_NEW_LINE	;Dump ALL registers
		LD	B,13		;13 Registers to dump
RM_LP		LD	HL,REGORDER
		LD	A,B
		DEC	A
		CALL	ADD_HL_A
		LD	C,(HL)
		CALL	PUT_REGNAME
		CALL	RM_DUMP_REG
		CALL	PRINTI
		DB	'  ',EOS
		LD	A,6
		CP	B
		JR  NZ,	RM_1
		CALL	PUT_NEW_LINE
RM_1		DJNZ	RM_LP
		RET

RM_NOTALL	CALL	IS_LETTER
		JR  C,	RM_ERR
		LD	E,A
		CALL	GET_CHAR
		CALL	IS_LETTER
		JR  C,	RM_ERR
		LD	D,A
		LD	L,0
RM_2		CALL	GET_CHAR
		CP	0x27		;Apostrophe Char
		JR  NZ,	RM_3
		LD	L,1		;L=1 if Alternate Register
		JR	RM_2
RM_3		RR	L		;Put Alternate flag into CARRY
		PUSH	AF		;Save last key input before proceeding to decode Register
		LD	B,13
RM_4		LD	C,B
		DEC	C
		CALL	GET_REGNAME	;HL=PTR TO NAME
		CALL	LD_HL_HL
		OR	A		;CLEAR CARRY
		SBC	HL,DE
		JP  Z,	RM_5		;Jump if NAME FOUND
		DJNZ	RM_4
		POP	AF
RM_ERR		LD	A,'?'		;Register Name not found
		CALL	PUT_CHARBC
		RET
RM_5		POP	AF
		LD	D,A
		JR  C,	RM_6		;Jump if Alternate (Selection would be correct)
		LD	A,C
		CP	9
		JR  C,	RM_6		;Jump if NOT Registers AF,BC,DE or HL
		SUB	8
		LD	C,A
RM_6		LD	A,D		;RESUME Decoding command line
		CP	CR
		JR  Z,	RM_DUMP_REG
		CP	'='
		JR  NZ,	RM_ERR

		CALL	GET_WORD	;DE = Word from Command
		LD	A,C
		CALL	PUT_REGISTER

RM_DUMP_REG	LD	A,'='
		CALL	PUT_CHARBC
		LD	A,C
		CALL	GET_REGISTER
		CALL	PUT_HL
		RET

REGORDER	DB	0
		DB	5
		DB	8
		DB	7
		DB	6
		DB	12
		DB	11
		DB	10
		DB	9
		DB	4
		DB	3
		DB	2
		DB	1
#endif

;=============================================================================
;MEMORY DUMP - Continous
;-----------------------------------------------------------------------------
; MEM_DUMP:	LD	B,0xFF		;Continuous Dump, No pausing
MEM_DUMP_0	CALL	SPACE_GET_WORD	;Input start address
		EX	DE,HL			;HL = Start
		LD	DE, 0FFFFH	; Auto to end of RAM

MEM_DUMP_LP:	CALL	PUT_NEW_LINE
		CALL	DUMP_LINE	;Dump 16 byte lines (advances HL)
		RET Z			;RETURN WHEN HL=DE
		LD	A,L
		OR	B
		JR  	NZ,	MEM_DUMP_LP	;Dump 1 Page, then prompt for continue
		CALL	PRINTI
		DB	CR,LF,"Press any key to continue, ESC to abort",EOS
		CALL	GET_CHAR
		CP	27
		JR	NZ, MEM_DUMP_LP
		JP	MAIN_MENU

;=============================================================================
; MEMORY DUMP - Paged
; Changing behavior so that we don't need to type in end address
; We will dump until ESC is pressed
;-----------------------------------------------------------------------------
MEM_DUMP	LD	B,0		;Paused Dump
		JR	MEM_DUMP_0

;-----------------------------------------------------------------------------
#if 0
GET_CONTINUE	CALL	PUT_NEW_LINE
		CALL	PRINTI
		DB	"Press any key to continue",EOS
		CALL	GET_CHAR
		CP	27		; Escape to abort
		RET 	NZ
		POP	HL		;Scrap return address
		RET
#endif
;-----------------------------------------------------------------------------
;DUMP_LINE -- Dumps a line
;xxx0:  <pre spaces> XX XX XX XX XX After spaces | ....ASCII....
;-----------------------------------------------------------------------------
DUMP_LINE:	PUSH	BC		;+1
		PUSH	HL		;+2 Save H for 2nd part of display
		PUSH	HL		;+3 Start line with xxx0 address
		LD	A,'M'
		CALL	Put_CharBC
		CALL	PUT_HL		;Print Address
		CALL	PUT_SPACE
		POP	HL		;-3
		LD	A,L
		AND	0x0F		;Fetch how many prespaces to print
		LD	C,A
		LD	B,A		;Save count of prespaces for part 2 of display
		CALL	PUT_3C_SPACES

DL_P1L		LD	A,(HL)
		CALL	SPACE_PUT_BYTE
		CALL	CP_HL_DE
		JR Z,	DL_P1E
		INC	HL
		LD	A,L
		AND	0x0F
		JR  NZ,	DL_P1L
		JR	DL_P2

DL_P1E		LD	A,L
		CPL
		AND	0x0F
		LD	C,A
		CALL	PUT_3C_SPACES

DL_P2		CALL	PRINTI		;Print Seperator between part 1 and part 2
		DB	" ; ",EOS

DL_PSL2		LD	A,B		;Print prespaces for part 2
		OR	A
		JR Z,	DL_PSE2
		CALL	PUT_SPACE
		DEC	B
		JR	DL_PSL2
DL_PSE2
		POP	HL		;-2
		POP	BC		;-1
DL_P2L		LD	A,(HL)
		CP	' '		;A - 20h	Test for Valid ASCII characters
		JR NC,	DL_P2K1
		LD	A,'.'				;Replace with . if not ASCII
DL_P2K1		CP	0x7F		;A - 07Fh
		JR C,	DL_P2K2
		LD	A,'.'
DL_P2K2		CALL	Put_CharBC

		CALL	CP_HL_DE
		RET Z
		INC	HL
		LD	A,L
		AND	0x0F
		JR  	NZ,	DL_P2L

;-----------------------------------------------------------------------------
;Compare HL with DE
;Exit:		Z=1 if HL=DE
;		M=1 if DE > HL
CP_HL_DE	LD	A,H
		CP	D		;H-D
		RET NZ			;M flag set if D > H
		LD	A,L
		CP	E		;L-E
		RET


PUT_3C_SPACES	INC	C		;Print 3C Spaces
PUT_3C_SPACES_L	DEC	C		;Count down Prespaces
		RET Z
		CALL	PRINTI		;Print pre spaces
		DB "   ",EOS
		JR	PUT_3C_SPACES_L


;-----------------------------------------------------------------------------
;EDIT MEMORY
;Edit memory from a starting address until X is pressed.
;Display mem loc, contents, and results of write.
;-----------------------------------------------------------------------------
MEM_EDIT:	CALL	SPACE_GET_WORD	;Input Address
		EX	DE,HL			;HL = Address to edit
ME_LP		CALL	PUT_NEW_LINE
		CALL	PUT_HL		;Print current contents of memory
		CALL	PUT_SPACE
		LD	A, ':'
		CALL	Put_CharBC
		LD	A, (HL)
		CALL	SPACE_PUT_BYTE
		; A = Byte (if CY=0)  (last 2 hex characters)  Exit if Space Entered
		; A = non-hex char input (if CY=1)
		CALL	SPACE_GET_BYTE	;Input new value or Exit if invalid
		JR	NC, ME_LP0	; value byte
		JP	MAIN_MENU	; C=1 -> exit
;		RET C			;Exit to Command Loop
ME_LP0:
		LD	(HL), A		;or Save new value
		LD	A, (HL)
		CALL	SPACE_PUT_BYTE
		INC	HL		;Advance to next location
		JR	ME_LP		;repeat input


;=============================================================================
;	MEM_EXEC - Execute at
;	Get an address and jump to it
; 	Note: right now, we actually push the address on stack and return
;	We're ignoring all the single step stuff for now
;-----------------------------------------------------------------------------
MEM_EXEC:	CALL	SPACE_GET_WORD	;Input address, c=1 if we have a word, c=0 if no word
		JR	C, ME_0		; If c=1 then we have a word to jump to
;		JP	NC, ME_1	
		JP	MAIN_MENU	; If c=0 then there is no word, abort
;		CP	27		; 
;		RET Z			; Exit if <ESC> pressed
ME_0
		LD	(RPC),DE	; Store word in RPC

		PUSH	AF
		CALL	PRINTI
		DB	' PC=',EOS
		LD	H,D
		LD	L,E
		CALL	PUT_HL
		POP	AF

;ME_1		
;		CP	27
;		RET 	Z		; Abort and exit if <ESC> pressed
		PUSH	DE
		RET			; Push DE to stack and return from there

#if 0
GO_EXEC		CALL	WRITE_BLOCK	;17 + 137 + 21 * 7 = 301   	;Note, timing is critical in this routine for the Single Step function to work
		DW	ANBAR_DEF	;Where to write			;You may change the timing, but the single step waste count must be adjusted
		DW	7		;# Bytes to write		;so that an interrupt occurs after a single instruction is executed.
		DB	0x82		;(ANBAR_DEF) = RUN MODE
		DW	GET_REG_RUN	;(GET_REG)
		DW	PUT_REG_RUN	;(PUT_REG)
		DW	CTRL_C_TEST	;(CTRL_C_CHK)

		LD	A,(ANBAR_DEF)	;13 Refresh Display
		LD	(LED_ANBAR),A	;13

		EX	AF,AF'		;4  Fetch Alternate register set
		LD	SP,RSAF2	;10 Set Stack to get register AF'
		POP	AF		;10
		EX	AF,AF'		;4
		EXX			;4  Fetch Alternate register set
		LD	BC,(RSBC2)	;20
		LD	DE,(RSDE2)	;20
		LD	HL,(RSHL2)	;20
		EXX			;4

		LD	BC,(RSIR)	;20 Fetch IR
		LD	A,C		;4
		LD	R,A		;9
		LD	A,B		;4
		LD	I,A		;9

		LD	SP,RSAF		;10 Set Stack to Fetch register AF
		POP	AF		;10

		LD	SP,(RSSP)	;20 Fetch SP
		LD	HL,(RPC)	;16 Fetch PC
		PUSH	HL		;11 & Put on stack

		LD	BC,(RSBC)	;20
		LD	DE,(RSDE)	;20
		LD	HL,(RSHL)	;20
		LD	IX,(RSIX)	;20
		LD	IY,(RSIY)	;20

		EI			;4  Enable Interrupts (for the benefit of Single Step)
		RET			;10 PC=(STACK)   Total = 650
#endif
;===============================================
;Input from port, print contents
PORT_INP:	CALL	SPACE_GET_BYTE
		LD	C, A
		IN	A,(C)
		CALL	SPACE_PUT_BYTE
		JP	MAIN_MENU
;		RET

;Get a port address, write byte out
PORT_OUT:	CALL	SPACE_GET_BYTE
		LD	C, A
		CALL	SPACE_GET_BYTE
		OUT	(C),A
		JP	MAIN_MENU
;		RET

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;	Chapter 5	Supporting routines. GET_BYTE, GET_WORD, PUT_BYTE, PUT_WORD
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
#if 0
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
					;Critical Timing in effect for GO_EXEC
WRITE_BLOCK	EX	(SP),HL		;19 HL=PC Total = 137 + 21 * BC
		PUSH	DE		;11
		PUSH	BC		;11
		LD	E,(HL)		;7
		INC	HL		;6
		LD	D,(HL)		;7
		INC	HL		;6
		LD	C,(HL)		;7
		INC	HL		;6
		LD	B,(HL)		;7
		INC	HL		;6
		LDIR			;21/16  21*BC-5
		POP	BC		;10
		POP	DE		;10
		EX	(SP),HL		;19 PC=HL
		RET			;10

CLEAR_BLOCK	LD	(HL),0
		INC	HL
		DJNZ	CLEAR_BLOCK
		RET

PUT_REGNAME	CALL	GET_REGNAME
		CALL	PRINT
		LD	A,C		;Test for alternate register
		CP	9
		RET C			;Exit C set if NOT an alternate register (LED OUTPUT, PRINT SPACE)
		LD	A,0x27		;Apostrophe Char
		CALL	PUT_CHARBC
		SCF
		RET

GET_REGNAME	LD	A,C
		ADD	A,C
		ADD	A,C
		LD	HL,REGNAMES
		CALL	ADD_HL_A
		RET

REGNAMES	DB	'SP',0		;0
		DB	'AF',0		;1
		DB	'BC',0		;2
		DB	'DE',0		;3
		DB	'HL',0		;4
		DB	'PC',0		;5
		DB	'IX',0		;6
		DB	'IY',0		;7
		DB	'IR',0		;8
		DB	'AF',0		;9
		DB	'BC',0		;10
		DB	'DE',0		;11
		DB	'HL',0		;12

GET_REGISTER	LD	HL,(GET_REG)	;16
		JP	(HL)		;4

GET_REG_MON	LD	HL,RSSP		;
		RLCA
		CALL	ADD_HL_A	;17+18 HL=Where to find Register
		CALL	LD_HL_HL	;HL=(HL)
		RET

GET_REG_RUN	LD	HL,GRR_TBL	;10
		JP	SHORTNWAY	;10

PUT_REGISTER	LD	HL,(PUT_REG)
		JP	(HL)

PUT_REG_MON	LD	HL,RSSP
		RLCA
		CALL	ADD_HL_A	;HL=Where to find Register
PURRS_RET	LD	(HL),E
		INC	HL
		LD	(HL),D
		RET

PUT_REG_RUN	LD	HL,PURR_TBL
					;40 to get here
SHORTNWAY	AND	0xF		;7
		CALL	ADD_HL_A	;14+18
		LD	A,(HL)		;7
		LD	HL,GRR_SUB	;10
		CALL	ADD_HL_A	;17+18
		JP	(HL)		;4  st=138

GRR_TBL		DB	0
		DB	GRR_SUB_AF - GRR_SUB
		DB	GRR_SUB_BC - GRR_SUB
		DB	GRR_SUB_DE - GRR_SUB
		DB	GRR_SUB_HL - GRR_SUB
		DB	GRR_SUB_PC - GRR_SUB
		DB	GRR_SUB_IX - GRR_SUB
		DB	GRR_SUB_IY - GRR_SUB
		DB	GRR_SUB_IR - GRR_SUB
		DB	GRR_SUB_AFA - GRR_SUB
		DB	GRR_SUB_BCA - GRR_SUB
		DB	GRR_SUB_DEA - GRR_SUB
		DB	GRR_SUB_HLA - GRR_SUB
		DB	0
		DB	0
		DB	0

PURR_TBL	DB	PURR_SUB_SP - GRR_SUB
		DB	PURR_SUB_AF - GRR_SUB
		DB	PURR_SUB_BC - GRR_SUB
		DB	PURR_SUB_DE - GRR_SUB
		DB	PURR_SUB_HL - GRR_SUB
		DB	PURR_SUB_PC - GRR_SUB
		DB	PURR_SUB_IX - GRR_SUB
		DB	PURR_SUB_IY - GRR_SUB
		DB	PURR_SUB_IR - GRR_SUB
		DB	PURR_SUB_AFA - GRR_SUB
		DB	PURR_SUB_BCA - GRR_SUB
		DB	PURR_SUB_DEA - GRR_SUB
		DB	PURR_SUB_HLA - GRR_SUB
		DB	0
		DB	0
		DB	0

		;Stack holds:
		;SP	RETURN TO ISR
		;SP+2	AF
		;SP+4	HL
		;SP+6	RETURN TO MAIN CODE (PC)

GRR_SUB		LD	HL,8		;Get SP;True value of SP (prior to ISR)
		ADD	HL,SP
		RET
GRR_SUB_AF	LD	HL,2		;Get AF
		ADD	HL,SP
		CALL	LD_HL_HL	;HL=(HL)
		RET
GRR_SUB_BC	PUSH	BC
		POP	HL
		RET
GRR_SUB_DE	PUSH	DE
		POP	HL
		RET
GRR_SUB_HL	LD	HL,4		;Get HL
		ADD	HL,SP
		CALL	LD_HL_HL	;HL=(HL)
		RET
GRR_SUB_PC	LD	HL,6		;Get PC
		ADD	HL,SP
		CALL	LD_HL_HL	;HL=(HL)
		RET
GRR_SUB_IX	PUSH	IX
		POP	HL
		RET
GRR_SUB_IY	PUSH	IY
		POP	HL
		RET
GRR_SUB_IR	LD	A,I
		LD	H,A
		LD	A,R
		LD	L,A
		RET
GRR_SUB_AFA	EX	AF,AF'
		PUSH	AF
		EX	AF,AF'
		POP	HL
		RET
GRR_SUB_BCA	EXX
		PUSH	BC
		EXX
		POP	HL
		RET
GRR_SUB_DEA	EXX
		PUSH	DE
		EXX
		POP	HL
		RET
GRR_SUB_HLA	EXX
		PUSH	HL
		EXX
		POP	HL
		RET

		;Stack holds:
		;SP	RETURN TO ISR
		;SP+2	DE
		;SP+4	AF
		;SP+6	HL
		;SP+8	RETURN TO MAIN CODE (PC)

PURR_SUB_SP	RET		;Do we really want to change the SP during RUN mode??? Suicide!
PURR_SUB_AF	LD	HL,4		;Get DE
		ADD	HL,SP
		JP	PURRS_RET
PURR_SUB_BC	PUSH	DE
		POP	BC
		RET
PURR_SUB_DE	LD	HL,2		;10 Get DE
		ADD	HL,SP		;11
		JP	PURRS_RET	;10  st=31
PURR_SUB_HL	LD	HL,6		;Get HL
		ADD	HL,SP
		JP	PURRS_RET
PURR_SUB_PC	LD	HL,8		;Get PC
		ADD	HL,SP
		JP	PURRS_RET
PURR_SUB_IX	PUSH	DE
		POP	IX
		RET
PURR_SUB_IY	PUSH	DE
		POP	IY
		RET
PURR_SUB_IR	LD	A,D
		LD	I,A
		LD	A,E
		LD	R,A
		RET
PURR_SUB_AFA	PUSH	DE
		EX	AF,AF'
		POP	AF
		EX	AF,AF'
		RET
PURR_SUB_BCA	PUSH	DE
		EXX
		POP	BC
		EXX
		RET
PURR_SUB_DEA	PUSH	DE
		EXX
		POP	DE
		EXX
		RET
PURR_SUB_HLA	PUSH	DE
		EXX
		POP	HL
		EXX
		RET
#endif

;=============================================================================
SPACE_GET_BYTE	CALL	PUT_SPACE

;=============================================================================
;GET_BYTE -- Get byte from console as hex
;
;in:	Nothing
;out:	A = Byte (if CY=0)  (last 2 hex characters)  Exit if Space Entered
;	A = non-hex char input (if CY=1)
;-----------------------------------------------------------------------------
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


;=============================================================================
; Print a space, then input a word
;
; in:	Nothing
; out:	c=1	A = non-hex char input
;		DE = Word
; out:	c=0	A = non-hex char input (No Word in DE)

SPACE_GET_WORD	CALL	PUT_SPACE

;=============================================================================
;GET_WORD -- Get word from console as hex
;
;in:	Nothing
;out:	c=1	A = non-hex char input
;		DE = Word
;out:	c=0	A = non-hex char input (No Word in DE)
;-----------------------------------------------------------------------------
GET_WORD:	LD	DE,0
		CALL	GET_HEX_CHAR	;Get 1st HEX CHAR
		JR  	NC, GW_LP
					; Not HEX
		CP	' '		; Is it SPACE
		JR 	Z, GET_WORD	; Loop back if first char is a SPACE
		OR	A		; Otherwise, clear Carry and exit
		RET			; 
GW_LP		LD	E,A		; HEX
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



;===============================================
;Get HEX CHAR
;in:	Nothing
;out:	A = Value of HEX Char when CY=0
;	A = Received (non-hex) char when CY=1
;-----------------------------------------------
GET_HEX_CHAR:	CALL	GET_CHAR
		CP	'0'
		JP M,	GHC_NOT_RET
		CP	'9'+1
		JP M,	GHC_NRET
		CP	'A'
		JP M,	GHC_NOT_RET
		CP	'F'+1
		JP M,	GHC_ARET
		CP	'a'
		JP M,	GHC_NOT_RET
		CP	'f'+1
		JP M,	GHC_ARET
GHC_NOT_RET	SCF
		RET
GHC_ARET	SUB	0x07
GHC_NRET	AND	0x0F	; Clear CY
		RET

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; Put_CharBC
; Output character to RS232
; Character is in A
; Preserve AF
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Put_CharBC:
PUT_CHARBC:	
		PUSH	AF
		RST	08H
		POP	AF
		RET

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;PRINT -- Print A null-terminated string @(HL)
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PRINT:		LD	A, (HL)
		INC	HL
		OR	A
		RET	Z
		CALL	Put_CharBC
		JR	PRINT

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;PRINT IMMEDIATE
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PRINTI:		EX	(SP),HL	;HL = Top of Stack
		CALL	PRINT
		EX	(SP),HL	;Move updated return address back to stack
		RET

;===============================================
;ASCHEX -- Convert ASCII coded hex to nibble
;
;pre:	A register contains ASCII coded nibble
;post:	A register contains nibble
;-----------------------------------------------
ASCHEX:		SUB	0x30
		CP	0x0A
		RET M
		AND	0x5F
		SUB	0x07
		RET

;===============================================
;PUT_HL Prints HL Word
;-----------------------------------------------
PUT_HL:		LD	A, H
		CALL	PUT_BYTE
		LD	A, L
		CALL	PUT_BYTE
		RET

;===============================================
;SPACE_PUT_BYTE -- Output (SPACE) & byte to console as hex
;
;pre:	A register contains byte to be output
;post:	Destroys A
;-----------------------------------------------
SPACE_PUT_BYTE	PUSH	AF
		CALL	PUT_SPACE
		POP	AF

;===============================================
;PUT_BYTE -- Output byte to console as hex
;
;pre:	A register contains byte to be output
;post:	Destroys A
;-----------------------------------------------
PUT_BYTE:	PUSH	AF
		RRCA
		RRCA
		RRCA
		RRCA
		AND	0x0F
		CALL	PUT_HEX
		POP	AF
		AND	0x0F
;		CALL	PUT_HEX
;		RET

;===============================================
;PUT_HEX -- Convert nibble to ASCII char
;-----------------------------------------------
PUT_HEX:	CALL	TO_HEX
		JP	Put_CharBC

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;TO_HEX - Convert nibble to ASCII char
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
TO_HEX:		AND	0xF
		ADD	A,0x30
		CP	0x3A
		RET C
		ADD	A,0x7
		RET

;===============================================
;PUT_SPACE -- Print a space to the console
;
;pre: none
;post: 0x20 printed to console
;-----------------------------------------------
PUT_SPACE:	LD	A, ' '
		JP	Put_CharBC

;===============================================
;PUT_NEW_LINE -- Start a new line on the console
;
;pre: none
;post: 0x0A printed to console
;-----------------------------------------------
PUT_NEW_LINE:	LD	A, 0x0D
		CALL	Put_CharBC
		LD	A, 0x0A
		JP	Put_CharBC

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;Terminal Increment byte at (HL).  Do not pass 0xFF
TINC:		INC	(HL)
		RET	NZ
		DEC	(HL)
		RET

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
DELAY_10mS	LD	C, 24	; bc 12
DELAY_C		PUSH	BC
		LD	B,0
DELAY_LP	DJNZ	DELAY_LP	;13 * 256 / 4 = 832uSec
		DEC	C
		JR	NZ, DELAY_LP	;*4 ~= 7mSec
		POP	BC
		RET

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
ADD_HL_A	ADD	A,L		;4
		LD	L,A		;4
		RET NC			;10
		INC	H
		RET

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
LD_HL_HL	LD      A,(HL)		;7
		INC     HL		;6
		LD      H,(HL)		;7
		LD      L,A		;4
		RET			;10

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
IS_LETTER	CP	'A'
		RET C
		CP	'Z'+1
		CCF
		RET


;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;	Chapter 6	Menu operations. ASCII HEXFILE TRANSFER
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;

; Set the address to the buffer where we want to upload the Intel HEX file
; This is to be used if the Intel HEX file uses 0000h as the start address
; You will want to set this address to somewhere in RAM...
SET_BUFFER
		CALL	SPACE_GET_WORD	;Input address, c=1 if we have a word, c=0 if no word
		JR	NC, SE_0	; If c=0 then there is no word, abort
					; If c=1 then we have a word to load
		LD	(hex_buffer),DE	; Store word
SE_0
		JP	MAIN_MENU

;----------------------------------------------------------------------------------------------------
; ASCII HEXFILE TRANSFER
;Registers:	B= Byte counter per line (initialized at start of line)
;		C= Check sum (initialized at start of line)
;		D= Temp for assembling HEX bytes
;		E= Error counter over the entire transfer
;		HL= Address to save data
; We are jumping in here with the first character ":" already loaded
GETHEXFILE	LD	E,0		;ZERO ERROR COUNTER
		JR	GHDOLINE	; Jump straight to reading in the byte cound

GHWAIT:			; LD	A,20			;10 Second Timeout for Get char
		CALL	TIMED_GETCHAR_BC
		JR  	C, GHENDTO	; Timeout
		CP	27		; ESC
		JR  	Z, GHENDTO	; Abort if ESC
		CP	':'
		JR  	NZ, GHWAIT

		; Handle a line
GHDOLINE	CALL	TGET_BYTE	;GET BYTE COUNT
		LD	B,A		;BYTE COUNTER
		LD	C,A		;CHECKSUM

		CALL	TGET_BYTE	;GET HIGH ADDRESS
		LD	H,A

		CALL	TGET_BYTE	;GET LOW ADDRESS
		LD	L,A
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
GHLOOP		CALL	TGET_BYTE	;GET DATA
		JR	C, GHENDTO
		LD	(HL),A
		INC	HL
		DJNZ	GHLOOP		;Repeat for all data in line

		CALL	TGET_BYTE	;GET CHECKSUM
		JR	C, GHENDTO
		XOR	A
		CP	C		;Test Checksum = 0
		JR 	Z, GHWAIT0	; No error
		INC	E
		JR  	NZ, GHWAIT0
		DEC	E
GHWAIT0
		LD	A, '.'		; Output tick
		CALL	PUT_CHARBC
		JR	GHWAIT
		
;GHENDTO		CALL	PRINTI
;		DB	CR,LF,"HEX TRANSFER TIMEOUT",EOS
;		JR	GHEND1
	
GHEND		; We come here on detecting RECORD TYPE = 1 but there are 2 more characters
		CALL	TGET_BYTE	; Get the last checksum byte
GHENDTO
GHEND1
		CALL	PRINTI
		DB	CR,LF,"HEX TRANSFER COMPLETE ERRORS=",EOS
		LD	A,E
		CALL	PUT_BYTE
		JP	MAIN_MENU
		
;-----------------------------------------------------------------------------
;TGET_BYTE -- Get byte from console as hex with timeout
;
;in:	Nothing
;out:	A = Byte (if CY=0)  (last 2 hex characters)  Exit if Space Entered
;	A = non-hex char input (if CY=1)
;-----------------------------------------------------------------------------
TGET_BYTE:	CALL	TGET_HEX_CHAR	;Get 1st HEX CHAR
		JR  	C,  TGB0	; GHENDTO	;Exit previous routine with a time out (leaves address on stack but MAIN_MENU will reset stack)
		RLCA			;Shift 1st HEX CHAR
		RLCA
		RLCA
		RLCA
		AND	0xF0
		LD	D,A
		CALL	TGET_HEX_CHAR	;Get 2nd HEX CHAR
		JR  	C, TGB0	; GHENDTO
		OR	D
		LD	D,A		;Save byte
		ADD	A,C		;Add byte to Checksum
		LD	C,A
		LD	A,D		;Restore byte
		OR	A		; Clear carry
TGB0:
		RET
	

;===============================================
;Get HEX CHAR
;in:	Nothing
;out:	CY=0, A = Value of HEX Char
;	CY=1, A = Received (non-hex) char or Time out
;-----------------------------------------------
TGET_HEX_CHAR:		; LD	A,20			;10 Second Timeout for Get char
		CALL	TIMED_GETCHAR_BC	; C=1, No Char (Time Out)
						; C=0, A = Char
		RET	C			; Timeout. Should probably test for ESC here
		CP	'0'
		JP M,	TGHC_NOT_RET
		CP	'9'+1
		JP M,	TGHC_NRET
		CP	'A'
		JP M,	TGHC_NOT_RET
		CP	'F'+1
		JP M,	TGHC_ARET
		CP	'a'
		JP M,	TGHC_NOT_RET
		CP	'f'+1
		JP M,	TGHC_ARET
TGHC_NOT_RET	SCF
		RET
TGHC_ARET	SUB	0x07
TGHC_NRET	AND	0x0F
		RET


;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;	Chapter 7	Menu operations. XMODEM FILE TRANSFER
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;----------------------------------------------------------------------------------------------------
; XMODEM ROUTINES

SOH	equ	1	;Start of Header
EOT	equ	4	;End of Transmission
ACK	equ	6
DLE	equ	16
DC1	equ	17	; (X-ON)
DC3	equ	19	; (X-OFF)
NAK	equ	21
SYN	equ	22
CAN	equ	24	;(Cancel)

;---------------------------------------------------------------------------------
;XMODEM MENU
;ENTRY:	TOP OF LDCK HOLDS RETURN ADDRESS (EXIT MECHANDSM IF XMODEM IS CANCELLED)
;---------------------------------------------------------------------------------
XMODEM		CALL	PUT_SPACE
		CALL	GET_CHAR	;get char
		AND	0x5F		;to upper case
		CP	'D'
		JR 	NZ, X_NOTD 
		CALL	XMDN		; D = DOWNLOAD
		JR	XM_EXIT
X_NOTD:
		CP	'U'
		JR 	NZ, X_NOTU 
		CALL	XMUP		; U = UPLOAD
		JR	XM_EXIT
X_NOTU:
		CALL 	PRINTI
		DB	"?",EOS
XM_EXIT:
		JP	MAIN_MENU

;---------------------------------------------------------------------------------
;XMDN - XMODEM DOWNLOAD (send file from IMSAI to Terminal)
;INPUT STARTING ADDRESS AND COUNT OF BLOCKS (WORD)
;WAIT FOR 'C' OR NAK FROM HOST TO START CRC/CS TRANSFER
;---------------------------------------------------------------------------------
XMDN		CALL	SPACE_GET_WORD	;Input Address
		EX	DE,HL		;HL = Address to SAVE DATA
		CALL	SPACE_GET_WORD	;Input #Blocks to Send
					;DE = Count of Blocks

		LD	A,D
		OR	E
		RET Z			;Exit if Block Count = 0

	;HL = Address of data to send from the IMSAI 8080
	;DE = Count of Blocks to send.

		CALL	XMS_INIT	;Starts the Seq, Sets the CS/CRC format
					;Cancelled Transfers will cause a RET

XMDN_LP		CALL	XMS_SEND	;Sends the packet @HL, Resends if NAK
					;Cancelled Transfers will cause a RET
		DEC	DE
		LD	A,D
		OR	E
		JR  NZ,	XMDN_LP

		CALL	XMS_EOT		;Send End of Transmission
		JP	PURGE


;---------------------------------------------------------------------------------
;XMUP - XMODEM UPLOAD (receive file from Terminal to IMSAI 8080)
;INPUT STARTING ADDRESS
;SEND 'C' OR NAK TO HOST TO START CRC/CS TRANSFER
;---------------------------------------------------------------------------------
XMUP		CALL	SPACE_GET_WORD	;Input Address
		EX	DE,HL		;HL = Address to SAVE DATA

	;HL = Address of data to send from the IMSAI 8080

		CALL	XMR_INIT	;Starts the transfer & Receives first PACKET
					;Cancelled Transfers will cause a RET

XMUP_LP		CALL	XMR_RECV	;Receives the next packet @HL, Resends if NAK
					;Cancelled Transfers will cause a RET
		JR C,	XMUP_LP		;Jump until EOT Received
		JP	PURGE



;---------------------------------------------------------------------------------
;INIT FOR SENDING XMODEM PROTOCOL, GET NAK OR 'C', SAVE THE XMTYPE
;---------------------------------------------------------------------------------
XMS_INIT	LD	A,1		;First SEQ number
		LD	(XMSEQ),A

		LD	B,6		;6 retries for initiating the transfer
XMS_INIT_LP	LD	A,28		;GET CHAR, 15 SECONDS TIMEOUT (EXPECT C OR NAK)
		CALL	TIMED_GETCHAR
		JP C,	XMS_INIT_RT	;Cancel if Host Timed out

		CP	NAK		;If NAK, Start Checksum Download
		JR Z,	XMS_DO
		CP	'C'		;If C, Start CRC Download
		JR Z,	XMS_DO
XMS_INIT_RT	DJNZ	XMS_INIT_LP	;Count down Retries
		JP	XM_CANCEL	;Cancel XModem if all retries exhausted

XMS_DO		LD	(XMTYPE),A
		RET

;---------------------------------------------------------------------------------
;SEND A PACKET (RESEND UPON NAK)
;---------------------------------------------------------------------------------
XMS_RESEND	LD	BC,0xFF80
		ADD	HL,BC
XMS_SEND	PUSH	DE
		LD	A,SOH		;SEND THE HEADER FOR CRC OR CHECKSUM
		CALL	Put_CharBC
		LD	A,(XMSEQ)
		CALL	Put_CharBC
		CPL
		CALL	Put_CharBC
		LD	DE,0x0000	;Init DE=0000 (CRC Accumulator)
		LD	C,0		;Init C=00 (CS Accumulator)
		LD	B,128		;Count 128 bytes per block
XMS_BLP		LD	A,(HL)		;Fetch bytes to send  -------------------\
		CALL	Put_CharBC	;Send them
		CALL	CRC_UPDATE	;Update the CRC
		LD	A,(HL)
		ADD	A,C		;Update the CS
		LD	C,A
		INC	HL		;Advance to next byte in block
		DEC	B		;Count down bytes sent
		JR NZ,	XMS_BLP		;Loop back until 128 bytes are sent -----^
		LD	A,(XMTYPE)
		CP	NAK		;If NAK, send Checksum
		JR Z,	XMS_CS		;----------------------v
		LD	A,D		;else, Send the CRC next
		CALL	Put_CharBC
		LD	C,E
XMS_CS		LD	A,C		;----------------------/
		CALL	Put_CharBC
					;Packet Sent, get Ack/Nak Response
		LD	A,120		;GET CHAR, 60 SECONDS TIMEOUT (EXPECT C OR NAK)
		CALL	TIMED_GETCHAR
		POP	DE
		JR C,	XM_CANCEL	;Cancel download if no response within 45 seconds
		CP	NAK
		JR Z,	XMS_RESEND	;Loop back to resend packet
		CP	CAN
		JR Z,	XM_CANCEL
		CP	ACK
		JR NZ,	XM_CANCEL

		LD	A,(XMSEQ)
		INC	A		;NEXT SEQ
		LD	(XMSEQ),A
		RET


;---------------------------------------------------------------------------------
;XMDN - DOWNLOAD XMODEM PACKET
;---------------------------------------------------------------------------------
XMS_EOT		LD	A,EOT		;HANDLE THE END OF TRANSFER FOR CRC OR CHECKSUM
		CALL	Put_CharBC
		LD	A,120		;GET CHAR, 60 SECONDS TIMEOUT (EXPECT C OR NAK)
		CALL	TIMED_GETCHAR
		JR C,	XM_CANCEL
		CP	NAK
		JR Z,	XMS_EOT
		CP	ACK
		JR NZ,	XM_CANCEL

XM_DONE		CALL	PURGE
		CALL	PRINTI
		DB	CR,LF,"TRANSFER COMPLETE\r\n",EOS
		XOR	A		;CLEAR A, CY
		RET

;FINISHING CODE PRIOR TO LEAVING XMODEM
XM_CANCEL	LD	A,CAN
		CALL	Put_CharBC
		CALL	Put_CharBC
		CALL	PURGE
		CALL	PRINTI
		DB	"TRANSFER CANCELED\r\n",EOS
		POP	BC		;SCRAP CALLING ROUTINE AND HEAD TO PARENT
		RET

;---------------------------------------------------------------------------------
;START XMODEM RECEIVING and RECEIVE FIRST PACKET
;---------------------------------------------------------------------------------
XMR_INIT	LD	E,7		;7 ATTEMPTS TO INITIATE XMODEM CRC TRANSFER
		LD	A,1		;EXPECTED SEQ NUMBER starts at 1
		LD	(XMSEQ),A
XMR_CRC		CALL	PURGE
		LD	A,'C'		;Send C
		LD	(XMTYPE),A	;Save as XM Type (CRC or CS)
		CALL	Put_CharBC
		CALL	XMGET_HDR	;Await a packet
		JR NC,	XMR_TSEQ	;Jump if first packet received
		JR NZ,	XM_CANCEL	;Cancel if there was a response that was not a header
		DEC	E		;Otherwise, if no response, retry a few times
		JR NZ,	XMR_CRC

		LD	E,9		;9 ATTEMPTS TO INITIATE XMODEM CHECKSUM TRANSFER
XMR_CS		CALL	PURGE
		LD	A,NAK		;Send NAK
		LD	(XMTYPE),A	;Save as XM Type (CRC or CS)
		CALL	Put_CharBC
		CALL	XMGET_HDR	;Await a packet
		JR NC,	XMR_TSEQ	;Jump if first packet received
		JR NZ,	XM_CANCEL	;Cancel if there was a response that was not a header
		DEC	E		;Otherwise, if no response, retry a few times
		JR NZ,	XMR_CS
		JR	XM_CANCEL	;Abort


;--------------------- XMODEM RECEIVE
;Entry:	XMR_TSEQ in the middle of the routine
;Pre:	C=1 (expected first block as received when negogiating CRC or Checksum)
;	HL=Memory to dump the file to
;Uses:	B to count the 128 bytes per block
;	C to track Block Number expected
;	DE as CRC (Within Loop) (D is destroyed when Getting Header)
;------------------------------------
XMR_RECV	LD	A,ACK		;Send Ack to start Receiving next packet
		CALL	Put_CharBC
XMR_LP		CALL	XMGET_HDR
		JR NC,	XMR_TSEQ
		PUSH	HL
		JR Z,	XMR_NAK		;NACK IF TIMED OUT
		POP	HL
		CP	EOT
		JR NZ,	XM_CANCEL	;CANCEL IF CAN RECEIVED (OR JUST NOT EOT)
		LD	A,ACK
		CALL	Put_CharBC
		JP	XM_DONE

XMR_TSEQ	LD	C,A
		LD	A,(XMSEQ)
		CP	C		;CHECK IF THIS SEQ IS EXPECTED
		JR Z,	XMR_SEQ_OK	;Jump if CORRECT SEQ
		DEC	A		;Else test if Previous SEQ
		LD	(XMSEQ),A
		CP	C
		JP NZ,	XM_CANCEL	;CANCEL IF SEQUENCE ISN'T PREVIOUS BLOCK
		CALL	PURGE		;ELSE, PURGE AND SEND ACK (ASSUMING PREVIOUS ACK WAS NOT RECEIVED)
		JR	XMR_ACK

XMR_SEQ_OK	LD	B,128		;128 BYTES PER BLOCK
		LD	C,0		;Clear Checksum
		LD	DE,0x0000	;CLEAR CRC
		PUSH	HL		;Save HL where block is to go
XMR_BLK_LP	CALL	TIMED1_GETCHAR
		JR C,	XMR_NAK
		LD	(HL),A		;SAVE DATA BYTE
		CALL	CRC_UPDATE
		LD	A,(HL)		;Update checksum
		ADD	A,C
		LD	C,A
		INC	HL		;ADVANCE
		DEC	B
		JR NZ,	XMR_BLK_LP
					;After 128 byte packet, verify error checking byte(s)
		LD	A,(XMTYPE)	;Determine if we are using CRC or Checksum
		CP	NAK		;If NAK, then use Checksum
		JR Z,	XMR_CCS
		CALL	TIMED1_GETCHAR
		JR C,	XMR_NAK
		CP	D
		JR NZ,	XMR_NAK
		CALL	TIMED1_GETCHAR
		JR C,	XMR_NAK
		CP	E
		JR NZ,	XMR_NAK
		JR	XMR_ACK

XMR_CCS		CALL	TIMED1_GETCHAR
		JP C,	XMR_NAK
		CP	C
		JR NZ,	XMR_NAK

		;If we were transfering to a FILE, this is where we would write the
		;sector and reset HL to the same 128 byte sector buffer.
		;CALL	WRITE_SECTOR

XMR_ACK		;LD	A,ACK		;The sending of the Ack is done by
		;CALL	Put_CharBC	;the calling routine, to allow writes to disk
		LD	A,(XMSEQ)
		INC	A		;Advance to next SEQ BLOCK
		LD	(XMSEQ),A
		POP	BC
		SCF			;Carry set when NOT last packet
		RET

XMR_NAK		POP	HL		;Return HL to start of block
		CALL	PURGE
		LD	A,NAK
		CALL	Put_CharBC
		JR	XMR_LP


;--------------------- XMODEM - GET HEADER
;
;pre:	Nothing
;post:	Carry Set: A=0, (Zero set) if Timeout
;	Carry Set: A=CAN (Not Zero) if Cancel received
;	Carry Set: A=EOT (Not Zero) if End of Tranmission received
;	Carry Clear and A = B = Seq if Header found and is good
;------------------------------------------
XMGET_HDR	LD	A,6		;GET CHAR, 3 SECONDS TIMEOUT (EXPECT SOH)
		CALL	TIMED_GETCHAR
		RET C			;Return if Timed out
		CP	SOH		;TEST IF START OF HEADER
		JR Z,	GS_SEQ		;IF SOH RECEIVED, GET SEQ NEXT
		CP	EOT		;TEST IF END OF TRANSMISSION
		JR Z,	GS_ESC		;IF EOT RECEIVED, TERMINATE XMODEM
		CP	CAN		;TEST IF CANCEL
		JR NZ,	XMGET_HDR
GS_ESC		OR	A		;Clear Z flag (because A<>0)
		SCF
		RET
GS_SEQ		CALL	TIMED1_GETCHAR	;GET SEQ CHAR
		RET C			;Return if Timed out
		LD	B,A		;SAVE SEQ
		CALL	TIMED1_GETCHAR	;GET SEQ COMPLEMENT
		RET C			;Return if Timed out
		CPL
		CP	B		;TEST IF SEQ VALID
		JR NZ,	XMGET_HDR	;LOOP BACK AND TRY AGAIN IF HEADER INCORRECT (SYNC FRAME)
		RET

;------------------------------------------ CRC_UPDATE
;HANDLE THE CRC CALCULATION FOR UP/DOWNLOADING
;Total Time=775 cycles = 388uSec
;In:	A  = New char to roll into CRC accumulator
;	DE = 16bit CRC accumulator
;Out:	DE = 16bit CRC accumulator
;------------------------------------------
;CRC_UPDATE	XOR	D		;4
;		LD	D,A		;5
;		PUSH	BC		;11
;		LD	B,8		;7	PRELOOP=27
;CRCU_LP	OR	A		;4	CLEAR CARRY
;		LD	A,E		;5
;		RLA			;4
;		LD	E,A		;5
;		LD	A,D		;5
;		RLA			;4
;		LD	D,A		;5
;		JP NC,	CRCU_NX		;10
;		LD	A,D		;5
;		XOR	0x10		;7
;		LD	D,A		;5
;		LD	A,E		;5
;		XOR	0x21		;7
;		LD	E,A		;5
;CRCU_NX	DEC	B		;5
;		JP NZ,	CRCU_LP		;10	LOOP=91*8 (WORSE CASE)
;		POP	BC		;10	POSTLOOP=20
;		RET			;10


;------------------------------------------ CRC_UPDATE
;HANDLE THE CRC CALCULATION FOR UP/DOWNLOADING
;Total Time=604 cycles = 302uSec MAX
;In:	A  = New char to roll into CRC accumulator
;	DE = 16bit CRC accumulator
;Out:	DE = 16bit CRC accumulator
;------------------------------------------
CRC_UPDATE	EX	DE,HL			;4
		XOR	H		;4
		LD	H,A		;5
		ADD	HL,HL		;10	Shift HL Left 1
		CALL C,	CRC_UPC		;17 (10/61)
		ADD	HL,HL		;10	Shift HL Left 2
		CALL C,	CRC_UPC		;17
		ADD	HL,HL		;10	Shift HL Left 3
		CALL C,	CRC_UPC		;17
		ADD	HL,HL		;10	Shift HL Left 4
		CALL C,	CRC_UPC		;17
		ADD	HL,HL		;10	Shift HL Left 5
		CALL C,	CRC_UPC		;17
		ADD	HL,HL		;10	Shift HL Left 6
		CALL C,	CRC_UPC		;17
		ADD	HL,HL		;10	Shift HL Left 7
		CALL C,	CRC_UPC		;17
		ADD	HL,HL		;10	Shift HL Left 8
		CALL C,	CRC_UPC		;17
		EX	DE,HL			;4
		RET			;10

CRC_UPC		LD	A,H		;5
		XOR	0x10		;7
		LD	H,A		;5
		LD	A,L		;5
		XOR	0x21		;7
		LD	L,A		;5
		RET			;10


;XModem implementation on 8080 Monitor (CP/M-80)
;
;Terminal uploads to 8080 system:
;-Terminal user enters command "XU aaaa"
;-8080 "drives" the protocol since it's the receiver
;-8080 sends <Nak> every 10 seconds until the transmitter sends a packet
;-if transmitter does not begin within 10 trys (100 seconds), 8080 aborts XMODEM
;-a packet is:
; <SOH> [seq] [NOT seq] [128 bytes of data] [checksum or CRC]
;
;<SOH> = 1 (Start of Header)
;<EOT> = 4 (End of Transmission)
;<ACK> = 6
;<DLE> = 16
;<DC1> = 17 (X-ON)
;<DC3> = 19 (X-OFF)
;<NAK> = 21
;<SYN> = 22
;<CAN> = 24 (Cancel)
;
;Checksum is the ModuLOW 256 sum of all 128 data bytes
;
;                                     <<<<<          [NAK]
;       [SOH][001][255][...][csum]    >>>>>
;                                     <<<<<          [ACK]
;       [SOH][002][254][...][csum]    >>>>>
;                                     <<<<<          [ACK]
;       [SOH][003][253][...][csum]    >>>>>
;                                     <<<<<          [ACK]
;       [EOT]                         >>>>>
;                                     <<<<<          [ACK]
;
;-if we get <EOT> then ACK and terminate XModem
;-if we get <CAN> then terminate XModem
;-if checksum invalid, then NAK
;-if seq number not correct as per [NOT seq], then NAK
;-if seq number = previous number, then ACK (But ignore block)
;-if seq number not the expected number, then <CAN><CAN> and terminate XModem
;-if data not received after 10 seconds, then NAK (inc Timeout Retry)
;-if timeout retry>10 then <CAN><CAN> and terminate XModem
;
;-To keep synchronized,
;  -Look for <SOH>, qualify <SOH> by checking the [seq] / [NOT seq]
;  -if no <SOH> found after 135 chars, then NAK
;
;-False EOT condtion
;  -NAK the first EOT
;  -if the next char is EOT again, then ACK and leave XModem
;
;-False <CAN>, expect a 2nd <CAN> ?
;
;-Using CRC, send "C" instead of <NAK> for the first packet
;  -Send "C" every 3 seconds for 3 tries, then degrade to checksums by sending <NAK>
;
;
;
;* The character-receive subroutine should be called with a
;parameter specifying the number of seconds to wait.  The
;receiver should first call it with a time of 10, then <nak> and
;try again, 10 times.
;  After receiving the <soh>, the receiver should call the
;character receive subroutine with a 1-second timeout, for the
;remainder of the message and the <cksum>.  Since they are sent
;as a continuous stream, timing out of this implies a serious
;like glitch that caused, say, 127 characters to be seen instead
;of 128.
;
;* When the receiver wishes to <nak>, it should call a "PURGE"
;subroutine, to wait for the line to clear.  Recall the sender
;tosses any characters in its UART buffer immediately upon
;completing sending a block, to ensure no glitches were mis-
;interpreted.
;  The most common technique is for "PURGE" to call the
;character receive subroutine, specifying a 1-second timeout,
;and looping back to PURGE until a timeout occurs.  The <nak> is
;then sent, ensuring the other end will see it.
;
;* You may wish to add code recommended by Jonh Mahr to your
;character receive routine - to set an error flag if the UART
;shows framing error, or overrun.  This will help catch a few
;more glitches - the most common of which is a hit in the high
;bits of the byte in two consecutive bytes.  The <cksum> comes
;out OK since counting in 1-byte produces the same result of
;adding 80H + 80H as with adding 00H + 00H.






;===============================================
;TIMED1_GETCHAR - Gets a character within 1 second
;-----------------------------------------------
TIMED1_GETCHAR	LD	A, 2

;===============================================
;TIMED_GETCHAR - Gets a character within a time limit
;in:	A contains # of seconds to wait before returning
;out: 	C=1, No Char (Time Out)
;	C=0, A = Char
;-----------------------------------------------

TIMED_GETCHAR_BC
		CALL	In_CharBC	; This is a blocking call
		CP	A, 27		; ESC
		JR	Z, TGC_TOBC
		OR	A		; C=0
		RET
TGC_TOBC
		SCF			; C=1
		RET


TIMED_GETCHAR	
		PUSH	DE
		PUSH	BC
		LD	D,A
TGC_LP1		LD	C,142		; D,C=Loop Count down until timeout
TGC_LP2		
		RST	18H		; Check if a char is available
		CP	A, 00H
		JR	NZ, TGC_AVAILABLE	; NZ = available		
;		CALL	In_Char	;87	;TEST FOR RX DATA
;		JP	NC, TGC_RET	;10
		DJNZ	TGC_LP2	;13/8	;110 Cycles inner Loop time. 70*256*.25 ~= 7 mSec
		DEC	C	;5
		JP 	NZ, TGC_LP2	;10
		DEC	D
		JP	NZ, TGC_LP1
		SCF		; BC uncommented this...SET CARRY TO INDICATE TIME OUT
TGC_RET		POP	BC
		POP	DE
		RET
TGC_AVAILABLE:
		RST	10H	; Go get the character
		CCF		; Clear C, I hope...!
		JP	TGC_RET

;		RET

;===============================================
;PURGE - Clears all in coming bytes until the line is clear for a full 2 seconds
;-----------------------------------------------
PURGE
		LD	A,4	;2 seconds for time out
		CALL	TIMED_GETCHAR
		JR	NC, PURGE
		RET

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;RS-232 Get A byte
;	Exit:	C=0, A=Byte from Buffer
;		C=1, Buffer Empty, no byte
;		w/call, tcy=87 if no byte
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
In_CharBC:
		RST 	10H
		OR	A		; Exit with C=0
		RET

;===============================================
;GET_CHAR -- Get a char from the console NO ECHO
;-----------------------------------------------
GET_CHAR_NE:	CALL	In_CharBC
		JR C,	GET_CHAR_NE
		RET

;===============================================
;GET_CHAR -- Get a char from the console
;-----------------------------------------------
GET_CHAR:	LD	A,(ECHO_ON)
		OR	A
		JR Z,	GET_CHAR_NE
GET_CHAR_LP	CALL	GET_CHAR_NE
		CP	' '	;Do not echo control chars
		RET	M
		;RET		;ECHO THE CHAR
		JP	PUT_CHARBC


