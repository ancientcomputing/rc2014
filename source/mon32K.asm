; Changes:
; 1. Adapted for zasm assembler including making things case sensitive
; 2. Adapted for RC2014 and modified init32K.asm
; 3. Remove/commented out all non-RS232 code
;
; Changes to Josh's original code are copyright Ben Chong and freely licensed to the community
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;
;Z80 Membership Card Firmware, Beta Version 1.1, Dec 14, 2014
;File: ZMCv11.asm
;
	MACRO 	VERSION_MSG
;	DB	CR,LF,"Z80 MEMBERSHIP CARD.  Beta v1.1, Dec 14, 2014",CR,LF,EOS
	DB	CR,LF,"Modified Monitor based on ZMC Beta v1.1",CR,LF,EOS
	ENDM

;	Table of Contents
;	Acknowledgments
;	Preface i	Acknowledgments, Revisions, notes
;	Preface ii	Description, Operation
;	Preface iii	Memory Mapping, I/O Mapping
;	Chapter 1	Page 0 interrupt & restart locations
;	Chapter 2	Startup Code
;	Chapter 3	Main Loop, MENU selection
;	Chapter 4	Menu operations. Loop back, Memory Enter/Dump/Execute, Port I/O
;	Chapter 5	Supporting routines. GET_BYTE, GET_WORD, PUT_BYTE, PUT_HL, PRINT, DELAY, GET/PUT_REGISTER
;	Chapter 6	Menu operations. ASCII HEXFILE TRANSFER
;	Chapter 7	Menu operations. XMODEM FILE TRANSFER
;	Chapter 8	Menu operations. RAM TEST
;	Chapter 9	Menu operations. DISASSEMBLER - Deleted
;	Chapter 10	BIOS.  PUT_CHAR (RS-232 & LED), GET_CHAR (RS-232), IN_KEY (Keyboard)
;	Chapter 11	ISR.  RS-232 Receive, LED & Keyboard scanning, Timer tic counting
;	Appendix A	LED FONT
;	Appendix B	RAM. System Ram allocation (LED_Buffer, KEY_Status, RX Buffer, etc)
;	Appendix C	Z80 Instruction Reference
;
;
;
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;	Preface i - Acknowledgments
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;
;Assemble using ver 2.0 of the ASMX assembler by Bruce Tomlin
;
;Command to assemble:
;
;   asmx20 -l -o -e -C Z80 ZMC.asm
;
;
;Z80 Membership Card hardware by Lee Hart.
;
;Operation, Documentation and Consultation by Herb Johnson
;
;Firmware by Josh Bensadon. Date: Feb 10, 2014
;
;Operation concepts adapted from the Heathkit H8 computer.
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
;
;- - - HARDWARE - - -
;
;The Hardware is comprised of two boards, the CPU and Front Panel (FP) boards.
;
;CPU Board:
; Z80 CPU, 4Mhz Clock, 5V Regulator, 32K EPROM (w/firmware), 32K RAM, 8 bit input port, 8 bit output port
;
;Front Panel Board:
; Terminal for Power & RS-232 connection, Timer for 1mSec interrupt, LED Display Driver & Keyboard Matrix.
;
; LED Display: 7 x 7-Segment displays (d1 to d7) and 7 annunciator leds (x1 to x7) below the 7 digits.
;
;    d1   d2   d3   d4   d5   d6   d7
;    _    _    _    _    _    _    _
;   |_|  |_|  |_|  |_|  |_|  |_|  |_|
;   |_|  |_|  |_|  |_|  |_|  |_|  |_|
;    _   _      _   _     _   _     _
;    x1  x2     x3  x4    x5  x6    x7
;
; Keyboard: 16 keys labeled "0" to "F" designated as a HEX keyboard
; The "F" key is wired to a separate input line, so it can be used as a "Shift" key to produce an extended number of key codes.
; The "F" and "0" keys are also wired directly to an AND gate, so that pressing both these keys produces a HARD reset.
;
;- - - FIRMWARE - - -
;
;The Firmware provides a means to control the system through two interfaces.
;Control is reading/writing to memory, registers, I/O ports; having the Z80 execute programs in memory or halting execution.
;The two interfaces are:
; 1. The Keyboard and LED display
; 2. A terminal (or PC) connected at 9600,N,8,1 to the RS-232 port.
;
;- - - The Keyboard and LED display interface - - -
;
;While entering commands or data, the annunciator LED's will light according to the state of the operation or system as follows:
;
; x1 = Enter Register
; x2 = Enter Memory Location
; x3 = Alter Memory/Register
; x4 = Send Data to Output Port
; x5 = Monitor Mode (Default Mode upon Power up)
; x6 = Run Mode
; x7 = Beeper (on key press)
;
;Keyboard Functions:
;
; "F" & "0" - Forces a HARD reset to the Z80 and restarts the system.  See System Starting for additional details.
;
; While in Command Mode:
; "F" & "E" - Does a SOFT reset.
; "0" - Display a Register.  x1 lights and you have a few seconds to select which register to display.
; "E" - Display Memory.  x2 lights and you have a few seconds to enter a memory location.
; "5" - Display Input Port.  x2 lights and you have a few seconds to enter a port address.
; "6" - Output Port. x2 lights and you have a few seconds to enter a port address,
;	then x4 lights and you can enter data to output, new data may be sent while x4 remains lit.
; "A" - Advance Display Element.  Advances to next Register, Memory address or Port address.
; "B" - Backup Display Element.  Backs up to previous Register, Memory address or Port address.
; "4" - Go. Preloads all the registers ending with the PC being set, hence it causes execution at the current PC register.
; "D" - Alter/Output.  Depending on the display, Selects a different Register, Memory Address, Port or Sends Port Output.
;	Note, "D" will only send to that Output Port, to change which port, Command 6 must be used.
;
;
;- - - The Terminal interface - - -
;
;Through a Terminal, there are more features you can use.  Entering a question mark (?) or another unrecognized command will display a list of available commands.
;Most commands are easy to understand, given here are the few which could use a better explaination.
;
; C - Continous Dump.	Works like the D command but without pausing on the page boundaries.  This is to allow the text capturing of a dump.
;			The captured file can then be later sent back to the system by simply sending the text file through an ASCII upload.
; M - Multiple Input.	Allows the entering of data in a format that was previously sent & saved in an ASCII text file.
; R - Register.		Entering R without specifiying the register will display all the registers.
;			A specific register can be displayed or set if specified.  eg. R HL<CR>, R HL=1234<CR>
; T - Test RAM		Specify the first and last page to test, eg T 80 8F will test RAM from 8000 to 8FFF.
; X - Xmodem Transfers	Transfers a binary file through the XModem protocol.  Enter the command, then configure your PC to receive or send a file.
;			eg. X U 8000<CR> will transfer a file from your PC to the RAM starting at 8000 for the length of the file (rounded up to the next 128 byte block).
;			eg. X D 8000 0010 will transfer a file from RAM to your PC, starting at 8000 for 10 (16 decimal) blocks, hence file size = 2K.
; : - ASCII HEX Upload	The ":" character is not entered manually, it is part of the Intel HEX file you can upload through ASCII upload.
;			eg. While at the prompt, just instruct your PC's terminal program to ASCII upload a .HEX file.
;
;
;- - - System Starting - - -
;When the Z80 starts execution of the firmware at 0000, all the registers are saved for possible examination and the optional modification.
;There are many ways the Z80 can come to execute at 0000.  The firmware then tries to deterimine the cause of the start up and will respond differently.
;Regardless of why, the firmware first saves all the registers to RAM and saves the last Stack word assuming it was the PC.
;A test is done to check if the FP board is present.
;-If there is no FP board, then the firmware will either RUN code in RAM @8002 (if there's a valid signature of 2F8 @8000) or HALT.
;Next, 8 bytes of RAM is tested & set for/with a signature.
;-If there isn't a signature, it is assumed the system is starting from a powered up condition (COLD Start), no further testing is done.
;When the signature is good (WARM Start), more tests are done as follows:
;Test Keyboard for "F"&"E" = Soft Reset from Keyboard
;Test Keyboard for "F"|"0" = Hard Reset from Keyboard
;Test Last instruction executed (assuming PC was on Stack) for RST 0 (C7) = Code Break
;Test RS-232 Buffer for Ctrl-C (03) = Soft Reset from Terminal
;If cause cannot be deterimined, it is assumed an external source asserted the RESET line.
;
;The Display will indicate the cause of reset as:
;	"COLD 00"  (Power up detected by lack of RAM Signature)
;	"SOFT ##"  (F-E keys pressed)
;	"STEP ##"  (Single Step)
;	"^C   ##"  (Ctrl-C)
;	"HALT ##"  (HALT Instruction executed)
;	"F-0  ##"  (F-0 Hard Reset)
;	"RST0 ##"  (RST0 Instruction executed)
;	"HARD ##"  (HARD Reset by other)
;
;Where the number after the reset shows the total number of resets.
;
;The PC will be changed to 8000 on Cold resets.
;
;
;- - - Firmware BIOS - - -
;
;There are routines which can be called from your program to access the RS-232 Bit banging interface, Keyboard or Display inteface or Timer interrupt services.
;
;Label		Addr.	Description
;Sel_RS232	xxxx	Sets
;Put_Char	xxxx	Sends the ASCII character in A to the RS-232 port or LED Display (no registers, including A, are affected)
;Put_HEX	xxxx	Converts the low nibble of A to an ASCII character 0 to F and sends to RS-232 or LED Display
;Put_Byte	xxxx	Converts/sends both high and low nibbles of A (sends 2 ASCII Character) to RS-232 or LED Display










; Z80 - Registers
;
; A F   A' F'
; B C   B' C'
; D E   D' E'
; H L   H' L'
;    I R
;    IX
;    IY
;    SP
;    PC


;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;	Preface iii- Memory Mapping, I/O Mapping
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

;String equates
CR		equ	0x0D
LF		equ	0x0A
EOS		equ	0x00


;Memory Mapping
;
;0x0000 - 0x7FFF	EPROM
;0x8000 - 0xFFFF	RAM

#if 0
Port40		equ	0x40	;LED DISPLAY, RS-232 TXD/RXD AND KEYBOARD
#endif

;I/O
;0x40	Input/Output
;	Output bits	*Any write to output will clear /INT AND advance the Scan/Column Counter U2A.
;	0 = Segment D OR LED7       --4--
;	1 = Segment E OR LED6      2|   |3
;	2 = Segment F OR LED5       |   |
;	3 = Segment B OR LED4       --5--
;	4 = Segment A OR LED3      1|   |6
;	5 = Segment G OR LED2       |   |
;	6 = Segment C OR LED1       --0--
;	7 = RS-232 TXD (Bit Banged) = 1 when line idle, 0=start BIT
;
;	Input Bits
;	0 = Column Counter BIT 0 (Display AND Keyboard)
;	1 = Column Counter BIT 1 (Display AND Keyboard)
;	2 = Column Counter BIT 2 (Display AND Keyboard)
;	3 = 0 when Keys 0-7 are pressed (otherwise = 1), Row 0
;	4 = 0 when Keys 8-E are pressed (otherwise = 1), Row 1
;	5 = 1 when Key F is pressed (otherwise = 0), Key F is separate so it may be used as A Shift Key
;	6 = 1 when U2B causes an interrupt, Timer Interrupt (Send Output to reset)
;	7 = RS-232 RXD (Bit Banged) = 1 when not connected OR line idle, 0=first start BIT
;
;	Bit 5 allows Key F to be read separately to act as A "Shift" key when needed.
;	Bits 0-2 can be read to ascertain the Display Column currently being driven.



;	Chapter 1	Page 0 interrupt & restart locations
;
;                        *******    *******    *******    *******
;                       *********  *********  *********  *********
;                       **     **  **     **  **     **  **     **
;                       **     **  **     **  **     **  **     **
;---------------------  **     **  **     **  **     **  **     **  ---------------------
;---------------------  **     **  **     **  **     **  **     **  ---------------------
;                       **     **  **     **  **     **  **     **
;                       **     **  **     **  **     **  **     **
;                       *********  *********  *********  *********
;                        *******    *******    *******    *******

; [CODE]
; LABEL INSTRUCT PARAMETER(s)              ADR/OPCODE    ASCII
#if 0
		org	0x0000
					; Z80 CPU LDRTS HERE
		DI			; Disable Interrupts
		IM	1		; Interrupts cause RST 0x38
		JR	RESETLDRT

;		org	0x0008		; RST	0x08
;		RET


		org	0x0010		; RST	0x10
		RET

		org	0x0018		; RST	0x18
		RET

		org	0x0020		; RST	0x20
		RET

		org	0x0028		; RST	0x28
		RET

		org	0x0030		; RST	0x30
		RET

		;RST	0x38		;11	;add another ~10 tc to complete previous instruction
		org	0x0038
		PUSH	HL		;11
		LD	HL,(INT_VEC)	;16
		JP	(HL)		;4

		org	0x0066		; NMI Service Routine
NMI_VEC:	RETN			;
#endif

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;	Chapter 2	Startup Code
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;

		.ORG 150H		; Same as bas32K.asm
		
		; This part is from bas32K.asm
		; int32K.asm is written to jump here
COLD:   	JP      MAIN_MENU	; STARTB          ; Jump for cold start
WARM:   	JP      MAIN_MENU	; WARMST          ; Jump for warm start

;-------------------------------------------------------------------------------- RESET LDRTUP CODE
RESETLDRT:
;Save Registers & SET sp
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#if 0
		LD	(RSHL),HL

		POP	HL		;Fetch PC
		LD	(RPC),HL	;Save the PC
		LD	(RSSP),SP	;Save the SP

		LD	SP,RSDE+2	;Set Stack to save registers DE,BC,AF
		PUSH	DE
		PUSH	BC
		PUSH	AF

		EX	AF,AF'		;Save Alternate register set
		EXX			;Save Alternate register set
		LD	SP,RSHL2+2	;Set Stack to save registers DE,BC,AF
		PUSH	HL
		PUSH	DE
		PUSH	BC
		PUSH	AF
		EX	AF,AF'
		EXX

		LD	A,I		;Fetch IR
		LD	B,A
		LD	A,R
		LD	C,A
		PUSH	BC		;Save IR

		PUSH	IY
		PUSH	IX
		LD	SP,StackTop	; Stack = 0xFF80 (Next Stack Push Location = 0xFF7F,0xFF7E)
#endif

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;Save Input State to Temp location (LED DISPLAY Buffer)
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#if 0
		LD	A,0x80		;Advance Column
		OUT	(Port40),A	; Clear LED Display & Set RS-232 TXD to inactive state
		LD	B,8		; 8 Tries to get to Column 0
RSIS_LP		IN	A,(Port40)	;Fetch Column
		LD	D,A		;Save IN D (For RESET Test)
		AND	7		;Mask Column only
		JR	Z,RSIS_OK	;When 0, exit Test Loop
		LD	A,0x80		;Advance Column
		OUT	(Port40),A	; Clear LED Display & Set RS-232 TXD to inactive state
		DJNZ	RSIS_LP
RSIS_OK					;Input State upon reset saved IN Register D
#endif
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;Test Hardware - FP Board Present?
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#if 0
					;Verify FP board is present
		LD	BC,0x1800	; Several Loops through Column 0 proves FP board is working
		LD	E,10		; 10 Retries if not expected Column

RTHW_LP		IN	A,(Port40)	;Fetch Column
		AND	7
		CP	C
		JP  Z,	RTHW_OK		;Jump if Column = expected value

		DEC	E		;If not expected, count the errors.
		JP  Z,	RTHW_NO_FP	;If error chances down to zero, there's no FP
		JR	RTHW_ADV

RTHW_OK		INC	C		; Advance expected value
		RES	3,C		; Limit expected value to 0-7
RTHW_ADV	LD	A,0x80		;Advance Column
		OUT	(Port40),A	; Clear LED Display & Set RS-232 TXD to inactive state
		DJNZ	RTHW_LP
		JP	RTHW_FP_PRESENT
#endif

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;Execute RAM program if NO FP Board Present
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#if 0
					;If scan counter not running, then either Execute RAM OR HALT
RTHW_NO_FP	LD	HL,(0x8000)	;Address of RAM Valid Signature
		LD	A,0x2		;(FP board probably not present)
		XOR	H		;Verify RAM valid with 2F8 signature at 0x8000
		LD	B,A
		LD	A,0xF8
		XOR	L
		OR	B
		JP	Z,0x8002	;Execute RAM
		JP	$		;Or HALT

RTHW_FP_PRESENT
#endif
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;Deterimine Reason for RESET ie entering Monitor Mode
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#if 0
					;Deterimine why the CPU is executing A RESET.
					;  -Power on (RAM signature will be wrong)
					;  -Reset Switch (one of the switches will still be pressed)
					;  -RST 0 (look for C7 at previous location given by stack)
					;  -External /RESET OR User program branches to 0000

		LD	HL,RAMSIGNATURE
		LD	E,1		;Count of Errors (preset to 1 for test)
		LD	A,0xF0		;First signature byte expected
		LD	B,8		;#bytes in signature (loop)
RAMSIG_LP	CP	(HL)
		JR  Z,	RAMSIG_GOOD
		INC	E		;Count wrong bytes
		LD	(HL),A		;Save Signature
RAMSIG_GOOD	INC	HL
		SUB	0xF
		DJNZ	RAMSIG_LP
		DEC	E		;Test # of errors
		JR	Z,WARM_START
#endif

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#if 0
COLD_START				;RAM Signature
		CALL	WRITE_BLOCK	;COLD_BOOT_INIT
		DW	RC_TYPE		;Where to write
		DW	19		;Bytes to write
		DB	0		;(RC_TYPE)
		DB	0		;(RC_SOFT)
		DB	0		;(RC_STEP)
		DB	0		;(RC_CC)
		DB	0		;(RC_HALT)
		DB	0		;(RC_F0)
		DB	0		;(RC_RST0)
		DB	0		;(RC_HARD)
		DW	UiVec_RET	;(UiVec)
		DB	0		;()
		DB	0		;(RegPtr)
		DW	0		;(ABUSS)
		DB	0		;(IoPtr)
		DB	0		;(RX_ERR_LDRT)
		DB	0		;(RX_ERR_STOP)
		DB	0		;(RX_ERR_OVR)
		DB	1		;(BEEP_TO)
		LD	HL,StackTop-2
		LD	(RSSP),HL
		LD	HL,RAM_LDRT
		LD	(RPC),HL

;							;LOAD TEST PROGRAM INTO RAM
;		LD	BC,SKIP_TEST-TESTP_LP+1
;		LD	DE,0x8000
;		LD	HL,TESTP_LP
;		LDIR
;		JP	SKIP_TEST
;
;TESTP_LP	INC	A
;		JP  NZ,	0x8000
;		INC	BC
;		INC	HL
;		DEC	DE
;	;	HALT
;		JP	0x8000
;SKIP_TEST

		JP	WS_END

WARM_START	LD	HL,RC_SOFT	;HL=RC_SOFT
		LD	A,(SOFT_RST_FLAG)
		CP	0xFE
		JR  Z,	WS_SET
		INC	HL		;HL=RC_STEP
		CP	0xD1
		JR  Z,	WS_SET
		INC	HL		;HL=RC_CC
		CP	0xCC
		JR  Z,	WS_SET
		INC	HL		;HL=RC_HALT
		CP	0x76
		JR  Z,	WS_SET

		INC	HL		;HL=RC_HARD
		LD	A,D		;Fetch Input of Column 0
TEST		BIT	5,A		;
		JR NZ,	WS_SET		;Jump if F switch pressed
		BIT	3,A		;
		JR  Z,	WS_SET		;Jump if 0 switch pressed

		INC	HL		;HL=RC_RST0
		LD	DE,(RPC)
		DEC	DE
		LD	A,(DE)
		CP	0xC7		;Did we get here by a RESTART 0 command?
		JR  Z,	WS_SET		;Jump if RST 0 Instruction

		INC	HL		;HL=RC_HARD

WS_SET		LD	A,L
		LD	(RC_TYPE),A
		CALL	TINC		;Advance the reset counter
WS_END
#endif

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;Init all System RAM, enable interrupts
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

#if 0
		LD	HL,RXBUFFER
		LD	B,0
		CALL	CLEAR_BLOCK

		LD	HL,CLEARED_SPACE
		LD	B,CLEARED_LEN
		CALL	CLEAR_BLOCK

		LD	HL,(DISPMODE)
		LD	(SDISPMODE),HL

		CALL	WRITE_BLOCK
		DW	ANBAR_DEF	;Where to write
		DW	33		;Bytes to write
		DB	0x84		;(ANBAR_DEF) = MON MODE
		DW	GET_REG_MON	;(GET_REG)
		DW	PUT_REG_MON	;(PUT_REG)
		DW	CTRL_C_RET	;(CTRL_C_CHK)
		DW	IDISP_RET	;(LDISPMODE)
		DW	IDISP_RET	;(DISPMODE)
		DW	IMON_CMD	;(KEY_EVENT) Initialize to Command Mode
		DB	1		;(IK_TIMER)
		DB	0x90		;(KEYBFMODE) HEX Keyboard Mode (F on press)
		DB	1		;(DISPLABEL)
		DB	-1		;(IK_HEXST)
		DW	LED_DISPLAY	;(HEX_CURSOR) @d1
		DW	HEX2ABUSS	;(HEX_READY)
		DW	LED_DISPLAY	;(LED_CURSOR)
		DW	PC_LED		;(PUTCHAR_EXE)
		DW	RXBUFFER	;(RXBHEAD)
		DW	RXBUFFER	;(RXBTAIL)
		DW	ISR_INT		;(INT_VEC)
		DW	LED_DISPLAY	;(SCAN_PTR)

		CALL	DELAY_10mS
		LD	A,0x80		;Advance Column / Clear Counter for Interrupt
		OUT	(Port40),A	; Clear LED Display & Set RS-232 TXD to inactive state

		LD	HL,LED_SPLASH_TBL
		LD	A,(RC_TYPE)
		AND	7
		RLCA
		RLCA
		RLCA
		CALL	ADD_HL_A
		CALL	PRINT

		LD	A,(RC_TYPE)
		OR	A
		JP  Z,	LSPLASH_CNT
		LD	H, hi(RC_TYPE)
		LD	L,A
		LD	A,(HL)
LSPLASH_CNT	LD	HL,LED_DISPLAY+5
		CALL	LED_PUT_BYTE
		LD	(HL),0x80	;Annunciator LED's OFF

		JP	SKIP_TABLE1

LED_SPLASH_TBL	DB	"COLD   ",EOS
		DB	"Soft   ",EOS
		DB	"StEp   ",EOS
		DB	"^C     ",EOS
		DB	"HALt   ",EOS
		DB	"F-0    ",EOS
		DB	"Rst0   ",EOS
		DB	"HARD   ",EOS
SKIP_TABLE1
		EI			;************** Interrupts ON!!!!
#endif

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;	Chapter 3	Main Loop, RS-232 MONITOR, MENU selection
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
#if 0
		CALL	SEL_RS232

		LD	HL,RS232_SPLASH
		LD	A,(RC_TYPE)
		AND	7
		RLCA
		CALL	ADD_HL_A
		CALL	LD_HL_HL
		CALL	PRINT
		LD	A,(RC_TYPE)
		OR	A
		JP   Z,	SPLASH_VERSION
		LD	H, hi(RC_TYPE)
		LD	L,A
		LD	A,(HL)
		CALL	SPACE_PUT_BYTE
		CALL	REG_DISP_ALL
		JP	SKIP_TABLE2

RS232_SPLASH	DW	R_COLD
		DW	R_SOFT
		DW	R_STEP
		DW	R_CC
		DW	R_HALT
		DW	R_F0
		DW	R_RST0
		DW	R_HARD

R_COLD		DB	CR,LF,"Cold Start",CR,LF,EOS
R_SOFT		DB	CR,LF,"Soft Restart",EOS
R_STEP		DB	CR,LF,"Step",EOS
R_CC		DB	CR,LF,"<Ctrl>-C",EOS
R_HALT		DB	CR,LF,"CPU HALT",EOS
R_F0		DB	CR,LF,"F-0 Reset",EOS
R_RST0		DB	CR,LF,"<Break>",EOS
R_HARD		DB	CR,LF,"Hard Reset",EOS

SPLASH_VERSION	CALL 	VERSION
SKIP_TABLE2

		LD	A,(RC_TYPE)
		AND	7
		CP	2		;If returning from Single Step, restore Monitor Display
		JR NZ,	WB_NOT_STEP
		LD	HL,(SDISPMODE)
		LD	(LDISPMODE),HL
		LD	(DISPMODE),HL
WB_NOT_STEP	RLCA
#endif

;************************************************************************************
;************************************************************************************
;************************************************************************************
;************************************************************************************
;************************************************************************************
;************************************************************************************
;************************************************************************************
;************************************************************************************
;************************************************************************************
;************************************************************************************
;************************************************************************************
;************************************************************************************
;************************************************************************************


;Monitor
;Functions:
; -Dump, Edit & Execute Memory.
; -Input Port and Output Port.
; -RAM Test
; -ASCII Upload intel HEX file
; -XMODEM up/down load to Memory
;
; D XXXX YYYY	Dump memory from XXXX to YYYY
; E XXXX	Edit memory starting at XXXX (type an X and press enter to exit entry)
; G XXXX	GO starting at address XXXX (Monitor program address left on stack)
; I XX		Input from I/O port XX and display as hex
; O XX YY	Output to I/O port XX byte YY
; L		Loop back test
; X U XXXX	XMODEM Upload to memory at XXXX (CRC or CHECKSUM)
; X D XXXX CCCC	XMODEM Download from memory at XXXX for CCCC number of 128 byte blocks
; :ssHHLLttDDDDDD...CS   -ASCII UPLOAD Intel HEX file to Memory.  Monitor auto downloads with the reception of a colon.
; R XX YY	RAM TEST from pages XX to YY
; V		Report Version


;----------------------------------------------------------------------------------------------------; MAIN MENU
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;----------------------------------------------------------------------------------------------------; MAIN MENU

MAIN_MENU:	LD	SP, StackTop	; Reset Stack = 0xFF80
		EI			; BC Enable interrupts
		LD	HL, MAIN_MENU	;Push Mainmenu onto stack as default return address
		PUSH	HL
		CALL	PRINTI		;Monitor Start, Display Welcome Message
		DB	CR,LF,"Main Menu >",EOS

MM_PURGE:
;		CALL	In_CharBC
; 		JR	NC, MM_PURGE

		LD	A,0xFF
		LD	(ECHO_ON),A	;TURN ON ECHO

		CALL 	GET_CHAR	;get char
		CP	':'
		JP Z,	GETHEXFILE	; : = START HEX FILE LOAD
		CP	3
		JP Z, MM_PURGE
; bc		JP Z,	MM_PURGE	;ignore CTRL-C
		AND 	0x5F		;to upper case
		CP 	'C'		;Branch to Command entered
		JP Z, 	MEM_DUMP	; C = Memory Dump (Continuous)
		CP 	'D'		;Branch to Command entered
		JP Z, 	MEM_DUMP_PAGED	; D = Memory Dump
		CP 	'E'
		JP Z, 	MEM_EDIT	; E = Edit Memory
		CP 	'G'
		JP Z, 	MEM_EXEC	; G = Go (Execute at)
#if 0
		CP 	'S'
		JP Z, 	GO_SINGLE	; S = Single Step
#endif
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
#if 0
		CP 	'T'
		JP Z,	RAM_TEST	; T = RAM TEST
#endif
#if 0
		CP 	'M'
		JP Z,	MEM_ENTER	; M = ENTER INTO MEMORY
#endif
#if 0
		CP 	'L'
		JP Z,	LOOP_BACK_LP	; L = Loop Back Test
#endif
		CP 	'V'
		JP Z,	VERSION		; V = Version

		CALL 	PRINTI		;Display Help when input is invalid
		DB	CR,LF,"HELP"
		DB	CR,LF,"D XXXX YYYY    Dump memory from XXXX to YYYY"
		DB	CR,LF,"C XXXX YYYY    Continous Dump (no pause)"
		DB	CR,LF,"E XXXX         Edit memory starting at XXXX"
;		DB	CR,LF,"M XXXX YY..YY  Enter many bytes into memory at XXXX"
		DB	CR,LF,"G [XXXX]       GO (PC Optional)"
;		DB	CR,LF,"S              Single Step"
		DB	CR,LF,"I XX           Input from I/O"
		DB	CR,LF,"O XX YY        Output to I/O"
;		DB	CR,LF,"R rr [=xx]     Register"
;		DB	CR,LF,"L              Loop back test"
;		DB	CR,LF,"T XX YY        RAM TEST from pages XX to YY"
		DB	CR,LF,"V              Version"
		DB	CR,LF,"X U XXXX       XMODEM Upload to memory at XXXX"
		DB	CR,LF,"X D XXXX CCCC  XMODEM Download from XXXX for CCCC #of 128 byte blocks"
		DB	CR,LF,":sHLtD...C     UPLOAD Intel HEX file, ':' is part of file"
		DB	CR,LF,EOS

		JP 	MAIN_MENU




;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;	Chapter 4	Menu operations
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;

;=============================================================================
;Display Version
;-----------------------------------------------------------------------------
VERSION		CALL	PRINTI
		VERSION_MSG
		RET

;=============================================================================
;Register Display/Set
;-----------------------------------------------------------------------------
#if 0
REG_MENU	CALL	PUT_SPACE
		CALL	GET_CHAR
		CP	CR
		JP  NZ,	RM_NOTALL

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
;Loop back test
;-----------------------------------------------------------------------------
#if 0
LOOP_BACK_LP	CALL	In_Char	;Test for any RS-232 input
		JR C,	LB_0	;Jump if no input
		CP	27	;<Esc> to quit
		RET	Z
		JR	LB_OUT	;Display
LB_0
		CALL In_Key_Hex		;Test regular HEX input
		JP Z,LOOP_BACK_LP	;

LB_1		OR	A
		JP P,	LB_2	;Jump if NOT shifted
		PUSH	AF		;If Shifted, then output a carret before the key
		LD	A,'^'
		CALL	Put_Char
		POP	AF

LB_2		CALL	TO_HEX	;Convert Keypad input to ASCII

LB_OUT		CALL	SEL_LED
		CALL	Put_Char

		CALL	SEL_RS232
		CALL	Put_Char

		JR	LOOP_BACK_LP
#endif

;=============================================================================
;MEMORY ENTER.  M XXXX YY..YY,  ENTERS AS MANY BYTES AS THERE ARE ON THE LINE.
;-----------------------------------------------------------------------------
#if 0
MEM_ENTER	CALL	GET_WORD	;DE = Word from console, A=non-hex character following word (space)
		CP	' '	;Test delimiting character, must be a space
		JP NZ,	MAIN_MENU
		EX	DE,HL		;HL = Start
MEN_LP		CALL	GET_BYTE	;A = Byte or A=non-hex character (Carry Set)
		JR C,	MEN_RET		;Jump if non-hex input
		LD	(HL),A		;else, save the byte
		INC	HL		;advance memory pointer
		JR	MEN_LP		;repeat for next byte input

MEN_RET		CALL	GET_CHAR	;ignore rest of line before returning to main menu
		CP	0x0A		;wait until we get the <LF>
		JP NZ,	MEN_RET
		LD	A,4		;Wait up to 2 seconds for another M command or return to main menu
		CALL	TIMED_GETCHAR	;
		CP	'M'		;If another M command comes in, process it
		JR Z,	MEM_ENTER
		JP 	MAIN_MENU	;If not, return to main menu prompt
#endif

;=============================================================================
;MEMORY DUMP - Continous
;-----------------------------------------------------------------------------
MEM_DUMP:	LD	B,0xFF		;Continuous Dump, No pausing
MEM_DUMP_0	CALL	SPACE_GET_WORD	;Input start address
		EX	DE,HL			;HL = Start
		CALL	SPACE_GET_WORD	;Input end address (DE = end)

MEM_DUMP_LP:	CALL	PUT_NEW_LINE
		CALL	DUMP_LINE	;Dump 16 byte lines (advances HL)
		RET Z			;RETURN WHEN HL=DE
		LD	A,L
		OR	B
		JR  NZ,	MEM_DUMP_LP	;Dump 1 Page, then prompt for continue
		CALL	GET_CONTINUE
		JR	MEM_DUMP_LP
;=============================================================================
;MEMORY DUMP - Paged
;-----------------------------------------------------------------------------
MEM_DUMP_PAGED	LD	B,0		;Paused Dump
		JR	MEM_DUMP_0

;-----------------------------------------------------------------------------
GET_CONTINUE	CALL	PUT_NEW_LINE
		CALL	PRINTI
		DB	"Press any key to continue",EOS
		CALL	GET_CHAR
		CP	27
		RET NZ
		POP	HL		;Scrap return address
		RET


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
		JR  NZ,	DL_P2L

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
		CALL	SPACE_GET_BYTE	;Input new value or Exit if invalid
		RET C			;Exit to Command Loop
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
MEM_EXEC:	CALL	SPACE_GET_WORD	;Input address
		JP	NC, ME_1
		CP	27
		RET Z			;Exit if <ESC> pressed
		LD	(RPC),DE

		PUSH	AF
		CALL	PRINTI
		DB	' PC=',EOS
		LD	H,D
		LD	L,E
		CALL	PUT_HL
		POP	AF

ME_1		CP	27
		RET Z			;Exit if <ESC> pressed
		DI			;
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
#else
		PUSH	DE
#endif
		EI			;4  Enable Interrupts (for the benefit of Single Step)
		RET			;10 PC=(STACK)   Total = 650

;===============================================
;Input from port, print contents
PORT_INP:	CALL	SPACE_GET_BYTE
		LD	C, A
		IN	A,(C)
		CALL	SPACE_PUT_BYTE
		RET

;Get a port address, write byte out
PORT_OUT:	CALL	SPACE_GET_BYTE
		LD	C, A
		CALL	SPACE_GET_BYTE
		OUT	(C),A
		RET



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
		JR  NC,	GB_1
		CP	' '		;Exit if not HEX CHAR (ignoring SPACE)
		JR Z,	GET_BYTE	;Loop back if first char is a SPACE
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
		JR  NC,	GB_2		;If 2nd char is HEX CHAR
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
		JR  NC,	GW_LP
		CP	' '		;Exit if not HEX CHAR (ignoring SPACE)
		JR Z,	GET_WORD	;Loop back if first char is a SPACE
		OR	A		;Clear Carry
		RET			;or EXIT with delimiting char
GW_LP		LD	E,A
		CALL	GET_HEX_CHAR
		RET C			;EXIT when a delimiting char is entered
		EX	DE,HL		;Else, shift new HEX Char Value into DE
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
GHC_NRET	AND	0x0F
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
DELAY_10mS	LD	C,12
DELAY_C		PUSH	BC
		LD	B,0
DELAY_LP	DJNZ	DELAY_LP	;13 * 256 / 4 = 832uSec
		DEC	C
		JR  NZ,	DELAY_LP	;*4 ~= 7mSec
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
;----------------------------------------------------------------------------------------------------; ASCII HEXFILE TRANSFER
					;Registers:	B= Byte counter per line (initialized at start of line)
					;		C= Check sum (initialized at start of line)
					;		D= Temp for assembling HEX bytes
					;		E= Error counter over the entire transfer
					;		HL= Address to save data
GETHEXFILE	LD	E,0		;ZERO ERROR COUNTER
		JR	GHDOLINE

GHWAIT		LD	A,20			;10 Second Timeout for Get char
		CALL	TIMED_GETCHAR
		JR  	C, GHENDTO	; Timeout
		CP	27		; ESC
		JR  	Z, GHENDTO	; Abort if ESC
		CP	':'
		JR  	NZ, GHWAIT

GHDOLINE	CALL	TGET_BYTE	;GET BYTE COUNT
		LD	B,A		;BYTE COUNTER
		LD	C,A		;CHECKSUM

		CALL	TGET_BYTE	;GET HIGH ADDRESS
		LD	H,A

		CALL	TGET_BYTE	;GET LOW ADDRESS
		LD	L,A

		CALL	TGET_BYTE	;GET RECORD TYPE
		CP	1
		JP Z,	GHEND	;IF RECORD TYPE IS 01 THEN END

GHLOOP		CALL	TGET_BYTE	;GET DATA
		LD	(HL),A
		INC	HL
		DJNZ	GHLOOP		;Repeat for all data in line

		CALL	TGET_BYTE	;GET CHECKSUM
		XOR	A
		CP	C		;Test Checksum = 0
		JR Z,	GHWAIT
		INC	E
		JR  NZ,	GHWAIT
		DEC	E
		JR	GHWAIT
		
GHENDTO		CALL	PRINTI
		DB	CR,LF,"HEX TRANSFER TIMEOUT",EOS
	
GHEND		CALL	PRINTI
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
		JR  C,  GHENDTO		;Exit previous routine with a time out (leaves address on stack but MAIN_MENU will reset stack)
		RLCA			;Shift 1st HEX CHAR
		RLCA
		RLCA
		RLCA
		AND	0xF0
		LD	D,A
		CALL	TGET_HEX_CHAR	;Get 2nd HEX CHAR
		JR  C,  GHENDTO
		OR	D
		LD	D,A		;Save byte
		ADD	A,C		;Add byte to Checksum
		LD	C,A
		LD	A,D		;Restore byte
		RET

;===============================================
;Get HEX CHAR
;in:	Nothing
;out:	CY=0, A = Value of HEX Char
;	CY=1, A = Received (non-hex) char or Time out
;-----------------------------------------------
TGET_HEX_CHAR:	LD	A,20			;10 Second Timeout for Get char
		CALL	TIMED_GETCHAR
		RET	C
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
;----------------------------------------------------------------------------------------------------; XMODEM ROUTINES

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
		JR Z,	XMDN		; D = DOWNLOAD
		CP	'U'
		JR Z,	XMUP		; U = UPLOAD
		CALL 	PRINTI
		DB	"?",EOS
		RET

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



;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;	Chapter 8	Menu operations. RAM TEST
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;----------------------------------------------------------------------------------------------------; RAM TEST
#if 0
;B=START PAGE
;C=END PAGE
RAM_TEST:	CALL	SPACE_GET_BYTE
		LD	B, A
		CALL	SPACE_GET_BYTE
		LD	C, A

;Page March Test.  1 Sec/K
;
; FOR E = 00 TO FF STEP FF   'March 00 then March FF
;   FOR H = B TO C
;      PAGE(H) = E
;   NEXT H
;   FOR D = B TO C
;      PAGE(D) = NOT E
;      FOR H = B TO C
;         A = E
;         IF H = D THEN A = NOT E
;         IF PAGE(H) <> A THEN ERROR1
;      NEXT H
;   NEXT D
; NEXT E
;

		CALL	PRINTI
		DB	CR,LF,"TESTING RAM",EOS
		LD	E,0xFF		;E selects the polarity of the test, ie March a page of 1'S or 0's

;Clear/Set all pages
RT1_LP0		LD	H,B		;HL = BASE RAM ADDRESS
		LD	L,0
RT1_LP1		LD	A,E		;CLEAR A
		CPL
RT1_LP2		LD	(HL),A		;WRITE PAGE
		INC	L
		JR NZ,	RT1_LP2		;LOOP TO QUICKLY WRITE 1 PAGE
		LD	A,H
		INC	H		;ADVANCE TO NEXT PAGE
		CP	C		;COMPARE WITH END PAGE
		JR NZ,	RT1_LP1		;LOOP UNTIL = END PAGE

;March 1 PAGE through RAM
		LD	D,B		;Begin with START PAGE

;Write FF to page D
RT1_LP3		LD	H,D		;HL = Marched Page ADDRESS
		;LD	L,0
		CALL	ABORT_CHECK

		LD	A,D
		CPL
;		OUT	FPLED
		;LD	A,E		;SET A
RT1_LP4		LD	(HL),E		;WRITE PAGE
		INC	L
		JR  NZ,	RT1_LP4		;LOOP TO QUICKLY WRITE 1 PAGE

;Test all pages for 0 (except page D = FF)
		LD	H,B		;HL = BASE RAM ADDRESS
		;LD	L,0

RT1_LP5		LD	A,H		;IF H = D
		CP	D
		LD	A,E		;THEN Value = FF
		JR Z,	RT1_LP6
		CPL			;ELSE Value = 00

RT1_LP6		CP	(HL)		;TEST RAM
		JP NZ,	RT_FAIL1
		INC	L
		JR NZ,	RT1_LP6		;LOOP TO QUICKLY TEST 1 PAGE
		LD	A,H
		INC	H		;ADVANCE TO NEXT PAGE
		CP	C		;COMPARE WITH END PAGE
		JR NZ,	RT1_LP5		;LOOP UNTIL = END PAGE

;Write 00 back to page D
		LD	H,D		;HL = Marched Page ADDRESS
		;LD	L,0
		LD	A,E
		CPL
RT1_LP7		LD	(HL),A		;WRITE PAGE
		INC	L
		JR NZ,	RT1_LP7		;LOOP TO QUICKLY WRITE 1 PAGE

		LD	A,D
		INC	D		;ADVANCE TO NEXT PAGE
		CP	C		;COMPARE WITH END PAGE
		JR NZ,	RT1_LP3		;LOOP UNTIL = END PAGE

		INC	E
		JR Z,	RT1_LP0

		CALL	PRINTI
		DB	CR,LF,"RAM PAGE MARCH PASSED",EOS


;Byte March Test.  7 Sec/K
;
; FOR E = 00 TO FF STEP FF   'March 00 then March FF
;   FOR H = B TO C
;      PAGE(H) = E
;      FOR D = 00 TO FF
;         PAGE(H).D = NOT E
;         FOR L=0 TO FF
;            IF PAGE(H).L <> E THEN
;               IF PAGE(H).L <> NOT E THEN ERROR2
;               IF L<>D THEN ERROR2
;            ENDIF
;         NEXT L
;      NEXT D
;   NEXT H
; NEXT E

		LD	E,0xFF		;E selects the polarity of the test, ie March a page of 1'S or 0's

;Clear/Set all pages

RT2_LP0		LD	H,B		;HL = BASE RAM ADDRESS
RT2_LP1		LD	L,0
		CALL	ABORT_CHECK

		LD	A,H
		CPL
;		OUT	FPLED

		LD	A,E		;CLEAR A
		CPL
RT2_LP2		LD	(HL),A		;WRITE PAGE
		INC	L
		JR NZ,	RT2_LP2		;LOOP TO QUICKLY WRITE 1 PAGE


		LD	D,0		;Starting with BYTE 00 of page

RT2_LP3		LD	L,D		;Save at byte march ptr
		LD	A,E		;SET A
		LD	(HL),A

		;LD	A,E
		CPL			;CLEAR A
		LD	L,0

RT2_LP4		CP	(HL)		;TEST BYTE FOR CLEAR
		JR Z,	RT2_NX1
		CPL			;SET A
		CP	(HL)		;TEST BYTE FOR SET
		JP NZ,	RT_FAIL2	;IF NOT FULLY SET, THEN DEFINITELY FAIL
		LD	A,L		;ELSE CHECK WE ARE ON MARCHED BYTE
		CP	D
		JP NZ,	RT_FAIL2
		LD	A,E		;CLEAR A
		CPL
RT2_NX1		INC	L
		JR NZ,	RT2_LP4		;LOOP TO QUICKLY WRITE 1 PAGE

		LD	L,D		;Save at byte march ptr
		LD	A,E
		CPL			;CLEAR A
		LD	(HL),A

		INC	D
		JR NZ,	RT2_LP3

		LD	A,H
		INC	H		;ADVANCE TO NEXT PAGE
		CP	C		;COMPARE WITH END PAGE
		JR NZ,	RT2_LP1		;LOOP UNTIL = END PAGE

		INC	E
		JR Z,	RT2_LP0

		CALL	PRINTI
		DB	CR,LF,"RAM BYTE MARCH 1 PASSED",EOS

;26 Sec/K

BYTEMARCH2
		LD	E,0xFF		;E selects the polarity of the test, ie March a page of 1'S or 0's

RT4_LP0		LD	D,0		;Starting with BYTE 00 of page

;CLEAR all pages

		LD	H,B		;HL = BASE RAM ADDRESS
		LD	L,0

RT4_LP1		LD	A,E		;CLEAR A
		CPL
RT4_LP2		LD	(HL),A		;WRITE PAGE
		INC	L
		JR NZ,	RT4_LP2		;LOOP TO QUICKLY WRITE 1 PAGE

		LD	A,H
		INC	H		;ADVANCE TO NEXT PAGE
		CP	C		;COMPARE WITH END PAGE
		JR NZ,	RT4_LP1		;LOOP UNTIL = END PAGE


RT4_LP3		CALL	ABORT_CHECK
		LD	A,D
		CPL
;		OUT	FPLED

					;Write SET byte at "D" in every page
		LD	H,B		;HL = BASE RAM ADDRESS
		LD	L,D		;Save at byte march ptr
RT4_LP4		LD	(HL),E

		LD	A,H
		INC	H		;ADVANCE TO NEXT PAGE
		CP	C		;COMPARE WITH END PAGE
		JR NZ,	RT4_LP4		;LOOP UNTIL = END PAGE


		LD	L,0

RT4_LP5		LD	H,B		;HL = BASE RAM ADDRESS
		LD	A,L
		CP	D
		JR Z,	RT4_LP7		;Test for marked byte in all pages

RT4_LP6		LD	A,E
		CPL			;CLEAR A
		CP	(HL)		;TEST BYTE FOR CLEAR
		JP NZ,	RT_FAIL2

		LD	A,H
		INC	H		;ADVANCE TO NEXT PAGE
		CP	C		;COMPARE WITH END PAGE
		JR NZ,	RT4_LP6		;LOOP UNTIL = END PAGE
		JR	RT4_NX

RT4_LP7		LD	A,E
		CP	(HL)		;TEST BYTE FOR SET
		JP NZ,	RT_FAIL2

		LD	A,H
		INC	H		;ADVANCE TO NEXT PAGE
		CP	C		;COMPARE WITH END PAGE
		JR NZ,	RT4_LP7		;LOOP UNTIL = END PAGE

RT4_NX		INC	L
		JR NZ,	RT4_LP5

					;Write CLEAR byte at "D" in every page
		LD	H,B		;HL = BASE RAM ADDRESS
		LD	L,D		;Save at byte march ptr
RT4_LP8		LD	A,E
		CPL
		LD	(HL),A

		LD	A,H
		INC	H		;ADVANCE TO NEXT PAGE
		CP	C		;COMPARE WITH END PAGE
		JR NZ,	RT4_LP8		;LOOP UNTIL = END PAGE

		INC	D
		JR NZ,	RT4_LP3


		INC	E
		JR Z,	RT4_LP0

		CALL	PRINTI
		DB	CR,LF,"RAM BYTE MARCH 2 PASSED",EOS


BIT_MARCH
;Bit March Test.  0.1 Sec/K

		LD	E,01		;E selects the bit to march

;Clear/Set all pages

RT3_LP1		LD	H,B		;HL = BASE RAM ADDRESS
		LD	L,0

		CALL	ABORT_CHECK

		LD	A,E		;Display bit pattern on LED PORT
		CPL
;		OUT	FPLED

RT3_LP2		LD	A,E		;FETCH MARCHING BIT PATTERN
RT3_LP3		LD	(HL),A		;WRITE PAGE
		INC	L
		JR NZ,	RT3_LP3		;LOOP TO QUICKLY WRITE 1 PAGE

		LD	A,H
		INC	H		;ADVANCE TO NEXT PAGE
		CP	C		;COMPARE WITH END PAGE
		JR NZ,	RT3_LP2		;LOOP UNTIL = END PAGE

		LD	H,B		;HL = BASE RAM ADDRESS
;		LD	L,0

RT3_LP4		LD	A,E		;FETCH MARCHING BIT PATTERN
RT3_LP5		CP	(HL)
		JP NZ,	RT_FAIL3
		INC	L
		JR NZ,	RT3_LP5		;LOOP TO QUICKLY WRITE 1 PAGE

		LD	A,H
		INC	H		;ADVANCE TO NEXT PAGE
		CP	C		;COMPARE WITH END PAGE
		JR NZ,	RT3_LP4		;LOOP UNTIL = END PAGE


					;0000 0010
					;...
					;1000 0000

		LD	A,E
		RLA			;ROTATE THE 01 UNTIL 00
		LD	A,E
		RLCA
		LD	E,A
		CP	1
		JR NZ,	RT3_NX1
		CPL			;INVERT ALL BITS
		LD	E,A
		JR	RT3_LP1
RT3_NX1		CP	0xFE
		JR NZ,	RT3_LP1

		CALL	PRINTI
		DB	CR,LF,"RAM BIT MARCH PASSED",EOS



		LD	E,01		;E selects the start sequence

;Clear/Set all pages

RT5_LP1		CALL	ABORT_CHECK

		LD	A,E		;Display bit pattern on LED PORT
		CPL
;		OUT	FPLED

		LD	H,B		;HL = BASE RAM ADDRESS
		LD	L,0
		LD	D,E

RT5_LP2		INC	D
		JR NZ,	RT5_NX1
		INC	D
RT5_NX1		LD	(HL),D		;WRITE PAGE
		INC	L
		JR NZ,	RT5_LP2		;LOOP TO QUICKLY WRITE 1 PAGE

		LD	A,H
		INC	H		;ADVANCE TO NEXT PAGE
		CP	C		;COMPARE WITH END PAGE
		JR NZ,	RT5_LP2		;LOOP UNTIL = END PAGE

		LD	H,B		;HL = BASE RAM ADDRESS
		;LD	L,0
		LD	D,E

RT5_LP3		INC	D
		JR NZ,	RT5_NX2
		INC	D
RT5_NX2		LD	A,D
		CP	(HL)		;TEST
		JP NZ,	RT_FAIL5
		INC	L
		JR NZ,	RT5_LP3		;LOOP TO QUICKLY WRITE 1 PAGE

		LD	A,H
		INC	H		;ADVANCE TO NEXT PAGE
		CP	C		;COMPARE WITH END PAGE
		JR NZ,	RT5_LP3		;LOOP UNTIL = END PAGE

		INC	E
		JR NZ,	RT5_LP1

		CALL	PRINTI
		DB	CR,LF,"RAM SEQUENCE TEST PASSED",EOS
		JP	MAIN_MENU


RT_FAIL1	CALL	PRINTI
		DB	CR,LF,"RAM FAILED PAGE MARCH AT:",EOS
		CALL	PUT_HL
		JP	MAIN_MENU

RT_FAIL2	CALL	PRINTI
		DB	CR,LF,"RAM FAILED BYTE MARCH AT:",EOS
		CALL	PUT_HL
		JP	MAIN_MENU

RT_FAIL3	CALL	PRINTI
		DB	CR,LF,"RAM FAILED BIT MARCH AT:",EOS
		CALL	PUT_HL
		JP	MAIN_MENU

RT_FAIL5	CALL	PRINTI
		DB	CR,LF,"RAM FAILED SEQUENCE TEST AT:",EOS
		CALL	PUT_HL
		JP	MAIN_MENU

ABORT_CHECK	CALL	In_Char
		RET C
		CP	27
		RET NZ
		POP	HL			;SCRAP RETURN ADDRESS AND GO TO PARENT ROUTINE
		CALL	PRINTI
		DB	CR,LF,"ABORTED",EOS
		RET
#endif

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;	Chapter 10	BIOS.
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;----------------------------------------------------------------------------------------------------; CONSOLE BIOS

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;Keyboard Get A byte
;All Keys are equal, but F works as a SHIFT on Press and F on release
;Output:	Z=1, No Key Pressed
;		Z=0, A=Key Pressed, bit 4 = Shift, ie, 0x97 = Shift-7
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
In_Key_Hex	LD	A,(KEY_PRESSED)
		XOR	A
		RET

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;Select Put_Char Output
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#if 0
LED_HOME	PUSH	HL
		LD	HL,LED_DISPLAY
		LD	(LED_CURSOR),HL
		POP	HL

SEL_LED		PUSH	HL
		LD	HL,PC_LED
		LD	(PUTCHAR_EXE),HL
		POP	HL
		RET

SEL_RS232	PUSH	HL
		LD	HL,PC_RS232
		LD	(PUTCHAR_EXE),HL
		POP	HL
		RET
#endif

;===============================================
;TIMED1_GETCHAR - Gets a character within 1 second
;-----------------------------------------------
TIMED1_GETCHAR	LD	A,1

;===============================================
;TIMED_GETCHAR - Gets a character within a time limit
;in:	A contains # of seconds to wait before returning
;out: 	C=1, No Char (Time Out)
;	C=0, A = Char
;-----------------------------------------------

TIMED_GETCHAR	
#if 1
		CALL	In_CharBC	; This is a blocking call
		CP	A, 27		; ESC
		JP	Z, TGC_TO
		OR	A		; C=0
		RET
TGC_TO
		SCF			; C=1
		RET
#else
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
#endif
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
;RS-232 RX Buffer Count
RX_COUNT	PUSH	HL
		LD	A,(RXBHEAD)
		LD	HL,RXBTAIL
		SUB	(HL)
		POP	HL
		RET

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;RS-232 Get A byte
;	Exit:	C=0, A=Byte from Buffer
;		C=1, Buffer Empty, no byte
;		w/call, tcy=87 if no byte
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; This is a block read
In_CharBC:
		RST 	10H
		OR	A		; Exit with C=0
		RET

#if 0
In_Char		PUSH	BC		;11 + 17(call)
		LD	A,(RXBHEAD)	;13 Test if TAIL=HEAD (=No bytes in buffer)
		LD	B,A		;4
		LD	A,(RXBTAIL)	;13
		XOR	B		;4 Check if byte(s) in receive buffer
		POP	BC		;10
		SCF			;4  C=1, Assume byte NOT available
		RET Z			;11 Exit if byte not available (ie TAIL=HEAD), C=1
		PUSH	HL
		LD	HL,(RXBTAIL)
		INC	L
		LD	(RXBTAIL),HL	;Tail = Tail + 1
		LD	A,(HL)		;A = Byte from buffer (@ TAIL)
		POP	HL
		OR	A		;Exit with C=0
		RET
#endif

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

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;Send A byte to RS-232 or LED
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;The byte to be sent is done through the msb of the LED Display Output byte.
;To simplify AND expedite the sending of those Display bytes (with the RS-232 BIT), the transmitted
;byte will be scattered IN A secondary buffer that is 10 bytes (1 start, 8 data, 1 stop)
;This secondary buffer will have the transmitted bits mixed IN with the LED Display Bytes
;The Interrupt is disabled only at crucial moments, but otherwise left on to accept any characters
;received from the RS-232 line
#if 0
Put_Char:
PUT_CHAR:	PUSH	AF
		PUSH	BC		;Save registers
		PUSH	DE
		PUSH	HL
		LD	C,A		;Put character to send IN C for shifting

		LD	HL,(PUTCHAR_EXE)
		JP	(HL)

;Put_Char to LED Display
PC_LED		LD	HL,(LED_CURSOR)	;Point to LED Display Buffer
		CP	0x20		;Test for Control/unprintable characters
		JR	C,PCL_CTRL

		LD	B, hi(LED_FONT)	;Set BC to point to LED FONT
		RES	7,C		;Ensure ASCII 0x20-0x7F only
		LD	A,(BC)
		SET	7,A		;Ensure TXbit is 1
		LD	(HL),A		;Save Character in LED_DISPLAY BUFFER
		INC	HL
		LD	(LED_CURSOR),HL
		JR	PCL_RET

PCL_CTRL	CP	0x0C		;<NP>
		JR NZ,	PCLC_1
		LD	B,8		;<NP> Clears LED Line
		LD	A,0x80
		LD	HL,LED_DISPLAY
PCLC_LP		LD	(HL),A
		INC	HL
		DJNZ	PCLC_LP
		JR	PCL_RETC

PCLC_1		CP	0x0D		;<CR>	Control characters:
		JR NZ,	PCL_RET
PCL_RETC	LD	HL,LED_DISPLAY	;<CR> Returns cursor to start of LED Line
		LD	(LED_CURSOR),HL
PCL_RET		JP	PC_RETPOP



;Put_Char to RS232
PC_RS232	LD  HL,LED_DISPLAY_SB
				;Copy 10 bytes from the LED_DISPLAY buffer (MOD 8) to the secondary buffer
PC_REDO		LD  DE,(SCAN_PTR)   ;SCAN_PTR holds the next LED BYTE @ OUTPUT.
		LD  B,E		;Save SCAN_PTR for test if an Interrupt occurs

		LD  A,(DE)
		LD  (HL),A
		RES 7,(HL)	;Configure Start BIT (msb) to be 0

		INC L
				;Shift next 9 bits IN this loop,
PC_LP0		INC E
		RES 3,E		;Bound DE to the 8 bytes of LED_DISPLAY

		LD  A,(DE)
		RLA		;Bump OUT msb
		RRC C		;Fetch Data BIT (non destructive shifting incase of REDO)
		RR  A		;Shift IN Data BIT
		LD  (HL),A
		INC L
		JR  NZ,PC_LP0

		DEC L
		SET 7,(HL)	;Stop Bit

		LD  L, lo(LED_DISPLAY_SB)  ;Restart Pointer to Secondary Buffer

				;Test if SCAN_PTR Changed (due to ISR)
		LD  E,5		;Preload RX delay counter (incase of RX byte during TX)
		LD  D,0x80	;Preload RxD Register with A marker BIT (to count 8 data bits)

		DI		;STOP INTERRUPTS HERE to see if SCAN_PTR has changed (due to Timer Interrupt)
		LD  A,(SCAN_PTR) ;Adjust working scan pointer (counted to 10 mod 8, so subtract 2 to restore)
		XOR B
		JR  Z,PC_0
				;If SCAN_PTR changed, Redo the Secondary Buffer
		EI		;Allow Interrupts again while preparing Secondary Buffer
		RLC C		;ADJUST Transmitted bits due to 9 bits shifted (back up 1 BIT)
		JR  PC_REDO
;- - - - - - - - - - - - - - - - - - - - - Transmit the BYTE here....
;1 Bit time at 9600 = 416.6666 cycles

PC_0		LD  C,Port40

PC_1		LD  A,(HL)	;7	Send BIT
		OUT (Port40),A	;11
		LD  B,8		;7

PC_2		IN  A,(C)	;12	;While waiting, Poll for RX DATA Start bit
		JP  P,PC_5	;10 tc (Note 1.JP)
		LD  A,(0)	;13 tc NOP
PC_3		DJNZ PC_2	;13/8  ;48 IN loop (-5 on last itteration).  48 * 8 + 39 - 5 = 418 tc per BIT

		INC L		;4
		JP  NZ,PC_1	;10	;39 TC Overhead to send BIT
		JP  PC_RET

PC_4		SRL B		;4	If false start bit detected, Divide B by 2 and return to simple tx
		JP  NZ,PC_3	;10
		INC L		;4
		JP  Z,PC_RET	;10
		LD  A,(HL)	;7	Send BIT
		OUT (Port40),A	;11
		JP  PC_2	;10


				;Here an RX byte was detected while transmitting.
				;Delay IN detection could be as much as 60tc, we will assume 1/2 (=30tc)
				;We need to test Start Bit @ 208tc,
				;We are juggling TX & RX. TX will occur earlier than BIT time due to shorter loop delay
PC_5		INC  L		;4
		DEC  B		;4
		JP Z,PC_7	;10
		SLA  B		;8      Multiply B by 2 for 24 cycle loop
PC_6		DEC  E		;4	RxBit Timing
		JR   Z,PC_9	;7/12   ;Either before OR after sending A BIT, we will branch OUT of loop here to check for RX Start Bit
		DJNZ PC_6	;13/8 tc TxBit Timing
				;		24 tc Loop
;TxBit
PC_7	       	LD  B,13	;7
		XOR A		;4
		OR  L		;4
		JR  Z,PC_8	;7/12	;Stop sending if L=0
		LD  A,(HL)	;7	;39 to send next BIT
		OUT (Port40),A	;11
		INC L		;4
PC_8		JP  PC_6	;10 tc (Note 1.JP)

				;Test if Start Bit is good (at ~1/2 BIT time)
PC_9		LD  E,5		;7   E=5 incase we have a bad start bit and have to return to simple TX
		IN  A,(C)	;12  Re-TEST Start Bit at 1/2 bit time
		JP  M,PC_4	;10  If Start BIT not verified, then return to simple TXD (return at point where we are Decrementing B to minimize diff)
		LD  E,15	;7   Adjust initial sampling delay (as per timing observed)


				;At this point, we have good start BIT, 1 OR more TX bits left to go...  here's where timing is accurate again
				;We will go through each TXbit AND RXBit once during the full BIT time.  So the time of these routines are added
PC_10		DEC E		;4
		JR  Z,PC_14	;7/12
PC_11		DJNZ PC_10	;13/8 tc    24Loop= 6uSec

				; TX= S 0 1 2 3 4 5 6 7 S
				; RX=  S 0 1 2 3 4 5 6 7 S  <-It's possible to receive all 8 data bits before sending Stop Bit
;TxBit ;54tc to Send BIT
		XOR A		;4
		OR  L		;4
		JR  Z,PC_13	;7/12	;Stop sending if L=0
		LD  A,(HL)	;7
		OUT (Port40),A	;11
		INC L		;4
PC_12        	LD  B,13	;7     (417 - 54 - 51)/24 = 13 counts required to pace 1 BIT
		JP  PC_10	;10 tc (Note 1.JP)

PC_13		LD  B,13	;7     (7tc NOP)
		JP  PC_12	;10 tc (Note 1.JP)

;RxBit ;51tc to Receive BIT
PC_14		IN   A,(Port40)	;11	Fetch RXbit
		NOP		;4
		RLCA		;4	put IN CARRY
		RR    D		;8	shift into RxD
		LD    E,13	;7      (417 - 54 - 51)/24 = 13 counts required to pace 1 BIT
		JR C, PC_15	;7/12	;Test for marker BIT shifting OUT of D
		JP    PC_11	;10	RXBIT = 40tc

PC_15		NOP		;4
PC_16		DEC  E		;4
		JR Z,PC_19	;7/12
		DJNZ PC_16	;13/8 tc    24Loop= 6uSec

				; TX= S 0 1 2 3 4 5 6 7 S
				; RX=  S 0 1 2 3 4 5 6 7 S  <-It's possible to receive all 8 data bits before sending Stop Bit
;TxBit ;54tc to Send BIT
		XOR  A		;4
		OR   L		;4
		JR Z,PC_18	;7/12	;Stop sending if L=0
		LD   A,(HL)	;7
		OUT (Port40),A	;11
		INC  L		;4
PC_17        	LD   B,13	;7     (417 - 54 - 51)/24 = 13 counts required to pace 1 BIT
		JP   PC_16	;10 tc (Note 1.JP)

PC_18		LD   B,13	;7     (7tc NOP)
		JP   PC_17	;10 tc (Note 1.JP)



;RxBit ;51tc to Receive BIT
PC_19		IN  A,(Port40)	;11	Fetch Stop BIT
		RLCA		;4	put IN CARRY
		JP C,PC_20
		LD   HL,RX_ERR_STOP
		CALL TINC

PC_20		LD  A,D		;Fetch received byte to RX Buffer
		LD  HL,(RXBHEAD)
		INC L
		LD  (RXBHEAD),HL ;Head = Head + 1
		LD  (HL),A	;Stuff into RX BUFFER
		LD  A,(RXBTAIL)
		CP  L
		JR  NZ,PC_RET	;Jump if NOT Zero = No Over run error (Head <> Tail)
		INC A		;Else
		LD  (RXBTAIL),A	;Tail = Tail + 1
		LD   HL,RX_ERR_OVR ;Count Over Run Error
		CALL TINC

PC_RET		IN	A,(Port40)	;Resync the SCAN_PTR
		INC	A
		AND	7
		OR  lo(LED_DISPLAY)
		LD	L,A
		LD	(SCAN_PTR),A	;Save Scan Ptr @ Next Scan Output
		LD	H, hi(SCAN_PTR)
		LD	A,(HL)
		LD	(SCAN_LED),A	;Save for next interrupt
PC_RETF		EI


PC_RETPOP	POP HL
		POP DE
		POP BC
		POP AF
		RET
#endif
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;	Chapter 11	ISR.  RS-232 Receive, LED & Keyboard scanning, Timer tic counting
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;

;                       *********   *******    ********
;                       *********  *********   *********
;                          ***     **     **   **     **
;                          ***     **          **     **
;---------------------     ***     *******     ********   ---------------------
;---------------------     ***       *******   ********   ---------------------
;                          ***            **   **  **
;                          ***     **     **   **   **
;                       *********  *********   **    **
;                       *********   *******    **     **
;
;
;	Normal timer interrupt takes 463 cycles
;	42  ISR Vectoring & Redirection
;	50  Timer Int Detection
;	28  LED Refresh (Re-enable Interrupts)
;	78  Resync & Prepare next LED Refresh value
;	111 Halt Test
;	38  TIC Counter
;	21  Keyboard/Display maintenance required check
;	41  User Interrupt Check
;	34  ISR Exit
;
;	Occuring 8 out of 32 ISR's:
;	82  Scanning non pressed keys
;
;	Occuring 1 out of 32 ISR's
;	165 Processing non pressed keys
;	97  Ctrl-C Checking
;	67  Beeper Timer
;	31  Cmd Expiration Timer
;	262 Display Memory contents
;	649 Display Register contents
;
;	24/32 ISR's = 463 cycles	= 11,112
;	7/32  ISR's = 545 cycles    	=  3,815
;	1/32  ISR's = 1,554 cycles	=  1,554 (Displaying Register)
;	Total over 32 ISR's		= 16,481
;	Average per ISR = 515 cycles
;			= 128.75uS used every 1024uS interrupt cycle
;			= 13% ISR Overhead (When Displaying Register)
;
;
;
;
;					;42 to get here from ORG 38h
;		;PUSH	HL = HL is pushed before getting here
#if 0
ISR_INT		PUSH	AF		;11	Quickely now, determine cause of Interrupt
		IN	A,(Port40)	;11
		RLCA			;4
		JP	NC,ISR_RXD	;10	Jump ASAP if RS-232 byte coming in.
		RLCA			;4
		JP	C,ISR_TIMER	;10 (st=50) Jump if Timer interrupt
		LD	A,0x80		;	Otherwise, unknown interrupt (RS-232 noise?)
		OUT	(Port40),A	;11	Just reset Timer interrupt, just incase?
		POP	AF
		POP	HL
		EI
		RETI

;
;- - - - - - - - - - - - - - RS-232 Receive BYTE
;
;1 Bit time at 9600 = 416.6666 cycles	;We get here ~@88 tc
ISR_RXD		PUSH BC		;11
		LD   HL,RX_ERR_LDRT ;10
		LD   B,5		;7
IRXD_VS		IN   A,(Port40)	;11	;Sample Start BIT @116, 151, 186, 221, 256 tc
		RLCA		;4	;(Actual sampling occurs 9 OR 10 tc later)
		JR   C,IRXD_BAD	;7/12
		DJNZ IRXD_VS	;13/8
				;35tc per loop
				;@286 when we come OUT of loop
				;Must delay 625 to reach middle of 1st data BIT
				;Need another 350 Delay

		LD   B,25	;7	;Delay loop after START Bit
		DJNZ $		;13/8	Delay loop = 25 * 13 - 5 = 356
		NOP		;4
		LD   L,8	;7
				;@624	;Loop through sampling 8 data bits
IRXD_NB		IN   A,(Port40)	;11	;Sample BIT
		RLCA		;4	;Get BIT
		RR   H		;8	;Shift IN
		DEC  L		;4	;Count down 8 bits
	;	JR   Z,IRXD_DD	;7/12

		JR  Z,IRXD_SAVE	;7/12	Optional to finish receiving byte here AND ignore framing errors
				;	(Replace the previous condital jump with IRXD_SAVE destination).

IRXD_NI		LD  A,23	;7	;Delay loop between data bits
		DEC A		;4
		JR  NZ,$-1	;12/7	;Delay loop = 16 * 23 + 53 - 5 = 416
		JR  IRXD_NB	;12	;Total Overhead = 53
				;Time to get all data bits = 416 * 7 + 39 = 2951 (last BIT does not get full delay)
				;@3576  (we wish to sample stop BIT @3958) (need to delay another 382)
IRXD_DD		LD  A,23	;7	;Delay loop before STOP BIT
		DEC A		;4
		JR  NZ,$-1	;12/7	;Delay loop =
		IN  A,(Port40)	;11	;NOP for 11tc
		IN  A,(Port40)	;11	;Sample Stop BIT @3957
		OR  A		;4	;(Actual sampling occurs 9 OR 10 tc later)
		JP  P,IRXD_BAD_STOP ;


IRXD_SAVE	LD  A,H		;4	;Fetch received byte
		LD  HL,(RXBHEAD) ;16	;Advance Head Ptr of RX Buffer, Head = Head + 1
		INC L		;4
		LD  (RXBHEAD),HL ;16
		LD  (HL),A	;7	;Save Received byte into RX Buffer
		LD  A,(RXBTAIL)	;13	;Test if buffer has over ran
		CP  L		;4	;If Tail = Head Then Tail = Tail + 1 & Flag overrun
		JR  NZ,IRXD_RET	;12/7
		INC A
		LD  (RXBTAIL),A

IRXD_OVR	LD   HL,RX_ERR_OVR
		JR   IRXD_BAD
IRXD_BAD_STOP	LD   HL,RX_ERR_STOP
IRXD_BAD	CALL TINC

IRXD_RET	LD	A,(SCAN_LED)	;13 ZMC-Display Refresh / Reset Int
		OUT	(Port40),A	;11 Output ASAP to satisfy Interrupt Flag

		IN	A,(Port40)	;Resync the SCAN_PTR
		INC	A
		AND	7
		OR  lo(LED_DISPLAY)	;LED_DISPLAY is at xxEO (it's ok to overlap in this order)
		LD	(SCAN_PTR),A	;Save Scan Ptr @ Next Scan Output
		LD	HL,(SCAN_PTR)	;Fetch next byte to output
		LD	A,(HL)
		LD	(SCAN_LED),A	;Save for next interrupt

		POP BC		;10
		POP AF		;10
		POP HL		;10
		EI		;4
		RETI		;14

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - Timer Tics
;Refresh next LED Display		;92 to get here from Int.
ISR_TIMER	LD	A,(SCAN_LED)	;13 ZMC-Display Refresh / Reset Int
		OUT	(Port40),A	;11 Output ASAP to satisfy Interrupt Flag
		EI			;4  Allow RXD interrupts
					;st=28

		IN	A,(Port40)	;11 Resync the SCAN_PTR
		INC	A		;4  Advance to next column to match column after next OUT
		AND	7		;7
		OR  lo(LED_DISPLAY)	;7  LED_DISPLAY is at xxEO (it's ok to overlap in this order)
		LD	(SCAN_PTR),A	;13 Save Scan Ptr @ Next Scan Output
		LD	HL,(SCAN_PTR)	;16 Fetch next byte to output
		LD	A,(HL)		;7
		LD	(SCAN_LED),A	;13 Save for next interrupt
					;st=78

;Halt Test
		LD	HL,4		;10 Get PC
		ADD	HL,SP		;11
		CALL	LD_HL_HL	;17+43
		DEC	HL		;6
		LD	A,(HL)		;7 Fetch Previous Instruction
		CP	0x76		;7 Is HALT?
		JP  Z,	ICMD_BREAK_RET	;10
					;st=111

;Tic counter - Advance
		LD	HL,(TicCnt)	;16 Advance Timer Counter
		INC	HL		;6
		LD	(TicCnt),HL	;16
					;st=38

;Keyboard / Display Update / Keyboard Commands or Entry
		LD	A,L		;4  Test timer for ZMC Keyboard Read.  Inputs keyboard at LED scan rate on every 4th complete scan
		AND	0x18		;7  Scan when timer is xxx0 0xxx, ie, 8 consecutive columns every 32mSec.
		JP  NZ,	IKEY_SCAN_END	;10
					;st=21

;-Keyboard Scanning
;	KeyPad	  Code	     Returned
;	 Key	  Value	       in A
;	no-key	1111 1111
;	  0	1111 1110	0	Bit 0 and 4 indicate key down in that group
;	  1	1111 1100	1	Bits 1-3 and 5-7 encode a key down in that group
;	  2	1111 1010	2	All logic is inverted
;	  3	1111 1000	3
;	  4	1111 0110	4
;	  5	1111 0100	5
;	  6	1111 0010	6
;	  7	1111 0000	7
;
;	  8	1110 1111	8
;	  9	1100 1111	9
;	  +	1010 1111	10
;	  -	1000 1111	11
;	  *	0110 1111	12
;	  /	0100 1111	13
;	  #	0010 1111	14
;	  .	0000 1111	15

		IN	A,(Port40)	;11 Read KEY down & ScanPtr
		LD	HL,KBHEXSAMPLE	;10

		BIT 	3,A		;8  Test ROW-0
		JR  NZ,	IKEY0_UP	;12 Jump if key UP
		AND	7
		OR	0x80
		LD	(HL),A		;Save HEX key
		RLCA
		INC	L		;
		OR	(HL)
		LD	(HL),A		;Save Octal key to KBOCTSAMPLE
		DEC	L
		IN	A,(Port40)	;Read KEY down & ScanPtr
IKEY0_UP
		BIT 	4,A		;8 Test ROW-1
		JR  NZ,	IKEY1_UP	;12 Jump if key UP
		AND	7
		OR	0x88
		LD	(HL),A		;Save HEX key
		RLCA
		RLCA
		RLCA
		RLCA
		RLA			;last shift in from Carry to clear lsb
		INC	L		;
		OR	(HL)
		LD	(HL),A		;Save Octal key to KBOCTSAMPLE
		DEC	L
		IN	A,(Port40)	;Read KEY down & ScanPtr
IKEY1_UP

		OR	0xF8		;7  Test for Column 7
		INC	A		;4
		JP  NZ,	IKEY_SCAN_END	;10

;Keys and Display update on Column 7 Only

		IN	A,(Port40)	;11 Read F KEY down
		BIT 	5,A		;8  Test F KEY
		JR  Z,	IKEYF_UP	;12 Jump if key UP
		LD	A,(KEYBFMODE)	;Check the F MODE (shift key or HEX key)
		OR	(HL)
		LD	(HL),A		;Save HEX key
		LD	A,0xF0
		INC	L		;
		OR	(HL)
		LD	(HL),A		;Save Octal key to KBOCTSAMPLE
		DEC	L
IKEYF_UP
		INC	L		;4
		LD	A,(HL)		;7  Save Octal Key Code at end of scan
		CPL			;4
		INC	L		;4
		LD	(HL),A		;7  Save to KEY_OCTAL
		DEC	L		;4
		XOR	A		;4
		LD	(HL),A		;7  Zero KBOCTSAMPLE for next scan

		DEC	L		;4
		LD	A,(HL)		;7  Get new HEX sample
		LD	(HL),0		;10 Zero KBHEXSAMPLE for next scan

IKEY_DEBOUNCE	;A=current key scan or 0x00 for no key.
		LD	HL,(KEYBSCANPV) ;16 Get previously saved scaned key and timer
		CP	L		;4
		JR  Z,	IKEYP_NCOS	;12 Jump if NO Change of State
		LD	H,3		;Timer = 3 (Controls how sensitive the keyboard is to Key Inputs)
		LD	L,A		;Previous scan=current scan

IKEYP_NCOS	DEC	H		;4
		LD	(KEYBSCANPV),HL	;16 Save previous scan & timer
		JP  Z,	IKEYP_EVENT	;10
		JP  P,	IK_NOKEY_EVENT	;10  st=165

		LD	A,0xD0		;Sets when to repeat (closer to FF, faster)
		CP	H
		JP  NZ, IK_NOKEY_EVENT

		LD	A,0xD4		;Sets how fast to repeat (closer to "when to repeat" faster)
		LD	(KEYBSCANTIMER),A ;Save timer
		LD	A,L

IKEYP_EVENT	;A=current key scan or 0x00 for no key (either after debounce or as repeat)
		LD	HL,KEY_PRESSED	;Point HL to previously saved/processed Key
		OR	A
		JP  Z,	IK_KEYUP_EVENT
		
IKEYP_EVENT_DN				;When A<>0, It's a KEY DOWN EVENT
		CP	0x90		;Is it Shift key down?
		JP  NZ,	IK_KEYDN_EVENT	;Jump to process key down if it's NOT a shift key
					;Special consideration given here for Shift Key down.
		BIT	4,(HL)		;Test bit 4 of KEY_PRESSED (previously saved/processed key)
		LD	(HL),A		;Save the 0x90 to KEY_PRESSED
		JP  Z,	IKEY_DONE	;If previously saved key was not a shifted key, keep the 0x90
		DEC	(HL)		;Otherwise, reduce the shift key to a simple "F" key
		JP	IKEY_DONE

IK_KEYUP_EVENT	;*************************************************** KEY UP EVENT
					;When A=0, It's a KEY UP EVENT
		LD	A,(HL)		;Fetch the previous key down code
		CP	0x90
		JP  NZ,	IKEY_DONE	;Exit if not the shift key going up
					;Otherwise, if it was the shift key going up....
		LD	A,0x8F		;replace it with a simple "F" key
		;JP	IK_KEYDN_EVENT	;and execute the key down event.

IK_KEYDN_EVENT	;*************************************************** KEY DOWN EVENT
		LD	(HL),A		;Save Last Key Down (for Shift Testing)

		LD	HL,LED_ANBAR
		SET	0,(HL)
		LD	HL,BEEP_TO
		SET	1,(HL)		;Time out beep in 2 counts

		LD	HL,(KEY_EVENT)
		JP	(HL)

IK_NOKEY_EVENT	;*************************************************** NO KEY EVENT

		LD	HL,(CTRL_C_CHK)	;16 <Ctrl>-C check +77
		JP	(HL)		;4
					;st=97
CTRL_C_RET

		LD	HL,IK_TIMER	;10
		LD	A,(HL)		;7 Time out any pending Monitor Input
		OR	A		;4
		JP Z,	IKEY_DONE	;10 st=31
		DEC	(HL)
		JP NZ,	IKEY_DONE
					;IK Timer Expired Event
IKC_RESET_CMD				;Upon time out, return monitor to CMD input
		LD	HL,(LDISPMODE)
		LD	(DISPMODE),HL
		LD	HL,IMON_CMD
		LD	(KEY_EVENT),HL
		LD	HL,KEYBFMODE	;Shiftable Keyboard
		LD	(HL),0x90

IKC_REFRESH	LD	A,(ANBAR_DEF)	;Refresh Display
		OR	1		;Assume Sounder is ON, Time Out routine below will correct
		LD	(LED_ANBAR),A
IKR_QREFRESH	LD	A,-1
		LD	(IK_HEXST),A	;Zero HEX Input Sequencer
		LD	A,1		;Force Quick Refresh of Label
		LD	(DISPLABEL),A
		;JP	IKEY_DONE


IKEY_DONE
		;*************************************************** UP DATE LED DISPLAY
		LD	HL,(DISPMODE)	;16 +242 (for Display Memory)
		JP	(HL)		;4
IDISP_RET

		LD	HL,BEEP_TO	;10
		DEC	(HL)		;11
		JP NZ,	IKEY_SCAN_END	;10
		INC	(HL)		;11
		LD	HL,LED_ANBAR	;10
		RES	0,(HL)		;15
					;st=67

IKEY_SCAN_END	LD	HL,ISR_TIMER_RET ;10 Set return address
		PUSH	HL		;11
		LD	HL,(UiVec)	;16
		JP	(HL)		;4
					;st=41

ISR_TIMER_RET	POP	AF		;10
		POP	HL		;10
		RETI			;14
					;st=34

UiVec_RET	RET			;Default Return for UiVec


ICMD_BREAK	LD	A,0xFE
ICMD_BREAK_RET	LD	(SOFT_RST_FLAG),A
		LD	A,(GET_REG)	;Soft Restart only allowed while not in Monitor Mode
		CP  lo(GET_REG_MON)
		JP  Z,	IKEY_DONE
		POP	AF
		LD	HL,0
		EX	(SP),HL	;POP HL, PUSH 0000
		RETI		;RETI to 0000 (with PC on stack)


		;Stack holds:
		;SP	AF
		;SP+2	HL
		;SP+4	RETURN TO MAIN CODE (PC)

CTRL_C_TEST	LD	HL,(RXBHEAD)	;16
		LD	A,(HL)		;7
		LD	HL,CTRL_C_TIMER	;10
		CP	3		;7
		JP  Z,	CTRL_C_IN_Q	;10
		LD	(HL),10		;10
CTRL_C_IN_Q	DEC	(HL)		;7
		JP  NZ,	CTRL_C_RET	;10  st=77
		LD	A,0xCC
		JP	ICMD_BREAK_RET

CTRL_C_CHK_ON	LD	HL,CTRL_C_TEST
		LD	(CTRL_C_CHK),HL
		RET
CTRL_C_CHK_OFF	LD	HL,CTRL_C_RET
		LD	(CTRL_C_CHK),HL
		RET



;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;	Keyboard Monitor
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;

;============================================================================
;	IMON - Monitor Loop
;
; This is the main executive loop for the Front Panel Emulator, Dispatch the Command
;============================================================================
IMON_CMD	LD	HL,IMON_TBL
		AND	0x1F
		RLCA			;X2
		CALL	ADD_HL_A
		CALL	LD_HL_HL	; HL = (HL)
		JP	(HL)

IMON_TBL	DW	ICMD0
		DW	IKEY_DONE	;ICMD1
		DW	IKEY_DONE	;ICMD2
		DW	IKEY_DONE	;ICMD3
		DW	GO_EXEC		;ICMD4
		DW	ICMD5
		DW	ICMD6
		DW	ICMD7
		DW	IKEY_DONE	;ICMD8
		DW	IKEY_DONE	;ICMD9
		DW	ICMDA
		DW	ICMDB
		DW	IKEY_DONE	;ICMDC
		DW	ICMDD
		DW	ICMDE
		DW	IKEY_DONE	;ICMDF
		DW	IKEY_DONE	;ICMD10 (Shift-0 Can't happen)
		DW	IKEY_DONE	;ICMD11
		DW	IKEY_DONE	;ICMD12
		DW	IKEY_DONE	;ICMD13
		DW	IKEY_DONE	;ICMD14
		DW	IKEY_DONE	;ICMD15
		DW	IKEY_DONE	;ICMD16
		DW	IKEY_DONE	;ICMD17
		DW	IKEY_DONE	;ICMD18
		DW	IKEY_DONE	;ICMD19
		DW	IKEY_DONE	;ICMD1A
		DW	IKEY_DONE	;ICMD1B
		DW	IKEY_DONE	;ICMD1C
		DW	IKEY_DONE	;ICMD1D
		DW	ICMD_BREAK	;ICMD1E
		DW	IKEY_DONE	;ICMD1F (Shift-F Can't happen)

ICMD0		CALL	WRITE_BLOCK
		DW	LDISPMODE	;Where to write
		DW	7		;Bytes to write
		DW	IDISP_REG	;(LDISPMODE)
		DW	IDISP_REG	;(DISPMODE)
		DW	ICMD0_R		;(KEY_EVENT) Switch to HEX Input Mode
		DB	80		;(IK_TIMER)
		LD	HL,LED_ANBAR
		SET	6,(HL)
		JP	IKEY_DONE

ICMB_REG	LD      A,(RegPtr)
ICMD0_R		DEC	A		;Adjust so Key 1 = 0 = SP
		AND	0xF
ICMD_SET_REG	CP	13
		JR  C,	ICMD_SR_OK
		XOR	A
ICMD_SR_OK	LD	(RegPtr),A
		JP	IKC_RESET_CMD

ICMDE		CALL	WRITE_BLOCK
		DW	LDISPMODE	;Where to write
		DW	14		;Bytes to write
		DW	IDISP_MEM	;(LDISPMODE)
		DW	IDISP_MEM	;(DISPMODE)
		DW	ICMD_WORD	;(KEY_EVENT) Switch to HEX Input Mode
		DB	80		;(IK_TIMER)
		DB	0x8F		;(KEYBFMODE) HEX Keyboard Mode (F on press)
		DB	0		;(DISPLABEL)
		DB	-1		;(IK_HEXST)
		DW	LED_DISPLAY	;(HEX_CURSOR) @d1
		DW	HEX2ABUSS	;(HEX_READY)

		LD	HL,LED_ANBAR
		SET	5,(HL)
		JP	IKEY_DONE


ICMD_WORD	CALL	LED_PUT_HEX
		LD	HL,IK_HEXST
		INC	(HL)
		JR NZ,	ICMD_WORDN1	;Do 1st digit

		LD	HL,(DISPMODE)
		LD	(LDISPMODE),HL
		LD	HL,IDISP_RET
		LD	(DISPMODE),HL	;No Display Update while HEX Input Mode

		LD	HL,(HEX_CURSOR)
		LD	A,0x81		;Underscore
		LD	(HL),A		;Display X _
		INC	HL
		LD	(HL),A		;Display X _ _
		INC	HL
		LD	(HL),A		;Display X _ _ _
		LD	HL,IK_HEXH	;HL=DIGITS 1&2
		JR	ICMD_WORD1

ICMD_WORDN1	LD	A,(HL)
		LD	HL,IK_HEXH	;HL=DIGITS 1&2
		DEC	A
		JR Z,	ICMD_WORD2	;Do 2nd digit
		LD	HL,IK_HEXL	;HL=DIGITS 3&4
		DEC	A
		JR NZ,	ICMD_WORD2

ICMD_WORD1	LD	A,(KEY_PRESSED)	;1st & 3rd DIGIT
		RRD
		JR	ICMD_WORD_RET

ICMD_WORD2	RRD			;2nd & 4th DIGIT
		LD	A,(KEY_PRESSED)
		RLD

ICMD_WORD_RET	LD	A,160
		LD	(IK_TIMER),A	;Set Time out on Register Selection
		LD	A,(IK_HEXST)	;Advance to next DspMod
		CP	3
		JP NZ,	IKEY_DONE
		LD	HL,(HEX_READY)
		JP	(HL)

HEX2ABUSS	LD	HL,(IK_HEXL)
		LD	(ABUSS),HL
		JP	IKC_RESET_CMD

HEX2REG		LD	A,(RegPtr)	;Select Register
		PUSH	DE
		LD	DE,(IK_HEXL)
		CALL	PUT_REGISTER
		POP	DE
		JP	IKC_RESET_CMD


ICMD_BYTE	CALL	LED_PUT_HEX
		LD	HL,IK_HEXST
		INC	(HL)
		JR NZ,	ICMD_BYTE2	;Do 1st digit

		LD	HL,(DISPMODE)
		LD	(LDISPMODE),HL
		LD	HL,IDISP_RET
		LD	(DISPMODE),HL	;No Display Update while HEX Input Mode

		LD	HL,(HEX_CURSOR)
		LD	A,0x81		;Underscore
		LD	(HL),A		;Display X _

		LD	HL,IK_HEXH	;HL=DIGITS 1&2
		LD	A,(KEY_PRESSED)	;1st DIGIT
		RRD
		LD	A,160
		LD	(IK_TIMER),A	;Set Time out on Register Selection
		JP 	IKEY_DONE

ICMD_BYTE2	LD	HL,IK_HEXH	;HL=DIGITS 1&2
		RRD			;2nd DIGIT
		LD	A,(KEY_PRESSED)
		RLD
		LD	A,(HL)
		LD	HL,(HEX_READY)
		JP	(HL)

HEX2IN_Ptr	LD	(IoPtr),A	;Save Byte input to IoPtr
		JP	IKC_RESET_CMD

HEX2OUT_Ptr	LD	(IoPtr),A	;Save Byte input to IoPtr
		JP	ICMD_IO_OUT

HEX2MEM		LD	HL,(ABUSS)
		LD	(HL),A
		INC	HL
		LD	(ABUSS),HL
		JP	ICMD_AMEM

HEX2OUT_PORT	PUSH	BC
		LD	B,A
		LD	A,(IoPtr)
		LD	C,A
		OUT	(C),B
		POP	BC
		JP	ICMD_IO_OUT

ICMD1
ICMD2
ICMD3
ICMD4

ICMD5		CALL	WRITE_BLOCK
		DW	LDISPMODE	;Where to write
		DW	14		;Bytes to write
		DW	IDISP_IN	;(LDISPMODE)
		DW	IDISP_IN	;(DISPMODE)
		DW	ICMD_BYTE	;(KEY_EVENT) Switch to BYTE Input Mode
		DB	80		;(IK_TIMER)
		DB	0x8F		;(KEYBFMODE) HEX Keyboard Mode (F on press)
		DB	0		;(DISPLABEL)
		DB	-1		;(IK_HEXST)
		DW	LED_DISPLAY+2	;(HEX_CURSOR) @d3
		DW	HEX2IN_Ptr	;(HEX_READY)

		LD	HL,LED_ANBAR
		SET	5,(HL)
		JP	IKEY_DONE

ICMD6		CALL	WRITE_BLOCK
		DW	LDISPMODE	;Where to write
		DW	14		;Bytes to write
		DW	IDISP_OUT	;(LDISPMODE)
		DW	IDISP_OUT	;(DISPMODE)
		DW	ICMD_BYTE	;(KEY_EVENT) Switch to BYTE Input Mode
		DB	80		;(IK_TIMER)
		DB	0x8F		;(KEYBFMODE) HEX Keyboard Mode (F on press)
		DB	0		;(DISPLABEL)
		DB	-1		;(IK_HEXST)
		DW	LED_DISPLAY+2	;(HEX_CURSOR) @d3
		DW	HEX2OUT_Ptr	;(HEX_READY)

		LD	HL,LED_DISPLAY+5
		LD	(HL),0x80	;Blank d6
		INC	HL
		LD	(HL),0x80	;Blank d7
		LD	HL,LED_ANBAR
		SET	5,(HL)
		JP	IKEY_DONE

;============================================================================
;	Single Step
;============================================================================
ICMD7		LD	A,(GET_REG)	;Single step only allowed while in Monitor Mode
		CP  lo(GET_REG_MON)
		JP  NZ,	IKEY_DONE

GO_SINGLE	XOR	A
		LD	(SOFT_RST_FLAG),A ;Clear flag for next ISR with junk in A
		LD	HL,ISINGLE	;Redirect next Interrupt to Single Step
		LD	(INT_VEC),HL
		HALT			;Halt for next interrupt (Aligns TC with INT)

					;On the next interrupt, handle it here
					;42 (+ complete last instruction time)
ISINGLE		PUSH	AF		;11
		LD	A,(SCAN_LED)	;13 ZMC-Display Refresh / Reset Int
		OUT	(Port40),A	;11 Output ASAP to satisfy Interrupt Flag

		IN	A,(Port40)	;11 Resync the SCAN_PTR
		INC	A		;4  Advance to next column to match column after next OUT
		AND	7		;7
		OR  lo(LED_DISPLAY)	;7  LED_DISPLAY is at xxEO (it's ok to overlap in this order)
		LD	(SCAN_PTR),A	;13 Save Scan Ptr @ Next Scan Output
		LD	HL,(SCAN_PTR)	;16 Fetch next byte to output
		LD	A,(HL)		;7
		LD	(SCAN_LED),A	;13 Save for next interrupt

		LD	HL,SOFT_RST_FLAG ;10 Is ISR being re-entered after the single step?
		LD	A,0xD1		;7
		CP	(HL)		;7
		JP Z,	ICMD_BREAK_RET	;10 Jump if yes.
		LD	(HL),A		;7  Else, set flag for next ISR
		LD	A,230		;7
					;203 (+completion), There are 4096 cycles between interrupts.
					;	 4096 cycles to waste
					;	 -203 cycles to get here
					;	 -660 cycles to execute
					;	=3233 cycles more to waste
					;
					;	Waste Loop = 14 * 230 + 13 = 3233
					;
ISINGLE_LP	DEC	A		;4  Count down the cycles to time the next ISR to occur
		JP NZ,	ISINGLE_LP	;10 cycle after execution commences
		ADC	HL,HL		;15
		JP	GO_EXEC		;10 Go Execute the single instruction!
					;(650 T states until executing next instruction)

ICMD8
ICMD9



;============================================================================
GET_DISPMODE	LD	A,(DISPMODE)
		CP  lo(IDISP_REG_DATA)
		RET Z				;Z=1 : DISPMODE = REGISTER
		CP  lo(IDISP_MEM_DATA)
		SCF
		RET NZ				;Z=0, C=1 : DISPMODE = I/O
		OR	A			;WARNING, If LOW IDISP_MEM_DATA=0 Then ERROR
		RET				;Z=0, C=0 : DISPMODE = MEM

; bc	if 0x00 = lo(IDISP_MEM_DATA)
; bc	   error "Error, LOW IDISP_MEM_DATA must not be 0x00"
; bc	endif

;============================================================================
;	Increment Display Element
;============================================================================
ICMDA		CALL	GET_DISPMODE
		JP  Z,	ICMA_REG
		JP  C,	ICMA_IO

		LD	HL,(ABUSS)
		INC     HL
		LD	(ABUSS),HL
		JP	IKR_QREFRESH

ICMA_REG	LD      A,(RegPtr)
		INC	A
		JP	ICMD_SET_REG

ICMA_IO		LD	HL,IoPtr
		INC	(HL)
		JP	IKR_QREFRESH


;============================================================================
;	Decrement Display Element
;============================================================================
ICMDB		CALL	GET_DISPMODE
		JP  Z,	ICMB_REG
		JP  C,	ICMB_IO

		LD	HL,(ABUSS)
		DEC     HL
		LD	(ABUSS),HL
		JP	IKR_QREFRESH

ICMB_IO		LD	HL,IoPtr
		DEC	(HL)
		JP	IKR_QREFRESH

;============================================================================
;	Alter Display Element
;============================================================================
ICMDD		CALL	GET_DISPMODE
		JP  Z,	ICMD_REG
		JP  C,	ICMD_IO

ICMD_AMEM	CALL	WRITE_BLOCK
		DW	LDISPMODE	;Where to write
		DW	14		;Bytes to write
		DW	IDISP_MEM	;(LDISPMODE)
		DW	IDISP_MEM	;(DISPMODE)
		DW	ICMD_BYTE	;(KEY_EVENT) Switch to BYTE Input Mode
		DB	80		;(IK_TIMER)
		DB	0x8F		;(KEYBFMODE) HEX Keyboard Mode (F on press)
		DB	1		;(DISPLABEL)
		DB	-1		;(IK_HEXST)
		DW	LED_DISPLAY+5	;(HEX_CURSOR) @d6
		DW	HEX2MEM		;(HEX_READY)

		LD	HL,LED_ANBAR
		SET	5,(HL)
		SET	4,(HL)
		JP	IKEY_DONE



ICMD_REG	LD	HL,ICMD_WORD	;Switch to WORD Input Mode
		LD	(KEY_EVENT),HL
		LD	HL,HEX2REG
		LD	(HEX_READY),HL
		LD	HL,LED_DISPLAY+3 ;@d4
		LD	(HEX_CURSOR),HL
		;LD	A,0x8F
		;LD	(KEYBFMODE),A	;HEX Keyboard
		LD	HL,LED_ANBAR
		SET	5,(HL)
		SET	4,(HL)
		JP	IKEY_DONE

ICMD_IO		CP  lo(IDISP_IN_DATA)
		JP  Z,	ICMD5

ICMD_IO_OUT	CALL	WRITE_BLOCK
		DW	LDISPMODE	;Where to write
		DW	14		;Bytes to write
		DW	IDISP_OUT	;(LDISPMODE)
		DW	IDISP_OUT	;(DISPMODE)
		DW	ICMD_BYTE	;(KEY_EVENT) Switch to HEX Input Mode
		DB	80		;(IK_TIMER)
		DB	0x8F		;(KEYBFMODE) HEX Keyboard Mode (F on press)
		DB	0		;(DISPLABEL)
		DB	-1		;(IK_HEXST)
		DW	LED_DISPLAY+5	;(HEX_CURSOR) @d6
		DW	HEX2OUT_PORT	;(HEX_READY)
		LD	HL,LED_ANBAR
		SET	3,(HL)
		JP	IKEY_DONE

;============================================================================
;	LED Display Memory Location
;============================================================================
IDISP_MEM	LD	HL,LED_DISPLAY	;First, Display location
		LD	A,(ABUSS+1)
		CALL	LED_PUT_BYTE
		LD	A,(ABUSS)
		CALL	LED_PUT_BYTE
		LD	A,0x80		;Blank next char
		LD	(HL),A
		LD	HL,IDISP_MEM_DATA
		LD	(DISPMODE),HL
					;Then Display DATA
IDISP_MEM_DATA	LD	HL,(ABUSS)	;16
		LD	A,(HL)		;7
		LD	HL,LED_DISPLAY+5 ;10
		CALL	LED_PUT_BYTE	;17+165
		LD	HL,DISPLABEL	;10 Repeat Display of Data several times before redisplaying Location
		DEC	(HL)		;7
		JP NZ,	IDISP_RET	;10  st=242
		LD	HL,IDISP_MEM
		LD	(DISPMODE),HL
		JP 	IDISP_RET

;============================================================================
;	LED Display Register
;============================================================================
IDISP_REG	LD	HL,(PUTCHAR_EXE) ;First, Display Register Name
		PUSH	HL
		CALL	LED_HOME
		PUSH	BC
		LD	A,(RegPtr)
		LD	C,A
		CALL	PUT_REGNAME
		JR NC,	IDR_0
		CALL	PUT_SPACE
IDR_0		POP	BC
		POP	HL
		LD	(PUTCHAR_EXE),HL
		LD	HL,IDISP_REG_DATA
		LD	(DISPMODE),HL

IDISP_REG_DATA	LD	A,(RegPtr)	;13 Then Display Data
		CALL	GET_REGISTER	;17+169
		LD	A,L		;4
		PUSH	AF		;11
		LD	A,H		;4
		LD	HL,LED_DISPLAY+3 ;10
		CALL	LED_PUT_BYTE	;17+165
		POP	AF		;10
		CALL	LED_PUT_BYTE	;17+165
		LD	HL,DISPLABEL	;10
		DEC	(HL)		;7
		JP NZ,	IDISP_RET	;10   sp=629
		LD	HL,IDISP_REG
		LD	(DISPMODE),HL
		JP 	IDISP_RET



;============================================================================
;	LED Display Input Port
;============================================================================
IDISP_IN	LD	HL,(PUTCHAR_EXE)
		CALL	LED_HOME
		CALL	PRINTI
		DB	'in',EOS
		LD	(PUTCHAR_EXE),HL
		LD	A,(IoPtr)
		LD	HL,LED_DISPLAY+2
		CALL	LED_PUT_BYTE
		LD	(HL),0x80	;Blank d5
		LD	HL,IDISP_IN_DATA
		LD	(DISPMODE),HL

IDISP_IN_DATA	PUSH	BC
		LD	A,(IoPtr)
		LD	C,A
		IN	A,(C)
		POP	BC
		LD	HL,LED_DISPLAY+5
		CALL	LED_PUT_BYTE
		LD	HL,DISPLABEL
		DEC	(HL)
		JP NZ,	IDISP_RET
		LD	HL,IDISP_IN
		LD	(DISPMODE),HL
		JP 	IDISP_RET


;============================================================================
;	LED Display Output Port
;============================================================================
IDISP_OUT	LD	HL,(PUTCHAR_EXE)
		CALL	LED_HOME
		CALL	PRINTI
		DB	'ou',EOS
		LD	(PUTCHAR_EXE),HL
		LD	A,(IoPtr)
		LD	HL,LED_DISPLAY+2
		CALL	LED_PUT_BYTE
		LD	(HL),0x80	;Blank d5
		LD	HL,IDISP_OUT_DATA
		LD	(DISPMODE),HL

IDISP_OUT_DATA	LD	HL,DISPLABEL
		DEC	(HL)
		JP NZ,	IDISP_RET
		LD	HL,IDISP_OUT
		LD	(DISPMODE),HL
		JP 	IDISP_RET

;============================================================================
;	LED Display OFF
;============================================================================
IDISP_OFF	LD	HL,LED_DISPLAY
		LD	A,0x80
		PUSH	BC
		LD	B,8
IDO_LP		LD	(HL),A
		INC	L
		DJNZ	IDO_LP
		POP	BC
		LD	HL,IDISP_RET
		LD	(DISPMODE),HL
		JP 	(HL)

;============================================================================
;	LED Delay	- After a delay for spash screen, display Registers
;============================================================================
IDISP_DELAY	LD	HL,DISPLABEL
		DEC	(HL)
		JP NZ,	IDISP_RET
		JP 	IKC_RESET_CMD

;============================================================================
;PUTS 2 HEX digits to LED Display
;Input:	A=BYTE to display
;	HL=Where to display
;Output: HL=Next LED Display location
LED_PUT_BYTE	PUSH	AF		;11 Save Byte to display (for 2nd HEX digit)
		PUSH	HL		;11 Save where to display it
		RRCA			;4
		RRCA			;4
		RRCA			;4
		RRCA			;4
		AND	0xF		;7
		LD	H, hi(LED_HEX)	;7
		LD	L,A		;4
		LD	A,(HL)		;7  Fetch LED Font for HEX digit
		POP	HL		;10
		LD	(HL),A		;7  Display 1st HEX digit
		POP	AF		;10
		PUSH	HL		;11 Save where to display 2nd HEX digit
		AND	0xF		;7
		LD	H,hi(LED_HEX)	;7
		LD	L,A		;4
		LD	A,(HL)		;7
		POP	HL		;10
		INC	HL		;6
		LD	(HL),A		;7
		INC	HL		;6
		RET			;10  st=165

LED_PUT_HEX	AND	0xF
		LD	H, hi(LED_HEX)
		LD	L,A
		LD	A,(HL)		;Fetch LED Font for HEX digit
		LD	HL,(HEX_CURSOR)
		LD	(HL),A		;Display 1st HEX digit
		INC	HL
		LD	(HEX_CURSOR),HL
		RET



;============================================================================
;	Subroutine	Dly
;
;	Entry:	A = Millisecond count
;============================================================================
Dly:	PUSH	HL			; Save count
	LD	HL,TicCnt
	ADD	A,(HL)			; A = cycle count
DlyLp	CP	(HL)			; Wait required TicCnt times
	JP	NZ,DlyLp		;  loop if not done
	POP	HL
	RET

#endif

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;	Appendix A	LED FONT
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
#if 0

; **         *********  *******        *********    *****    **     **  *********
; **         *********  ********       *********   *******   ***    **  *********
; **         **         **    ***      **         ***   ***  ****   **     ***
; **         **         **     **      **         **     **  *****  **     ***
; **         *********  **     **      *********  **     **  ** *** **     ***
; **         *********  **     **      *********  **     **  **  *****     ***
; **         **         **     **      **         **     **  **   ****     ***
; **         **         **    ***      **         ***   ***  **    ***     ***
; *********  *********  ********       **          *******   **     **     ***
; *********  *********  *******        **           *****    **     **     ***

;	0 = Segment D OR LED7       --4--
;	1 = Segment E OR LED6      2|   |3
;	2 = Segment F OR LED5       |   |
;	3 = Segment B OR LED4       --5--
;	4 = Segment A OR LED3      1|   |6
;	5 = Segment G OR LED2       |   |
;	6 = Segment C OR LED1       --0--


		ORG  ($ & 0xFF00) + 0x100
LED_HEX	DB	%11011111, %11001000, %10111011, %11111001, %11101100, %11110101, %11110111, %11011000	;00-07 01234567
	DB	%11111111, %11111100, %11111110, %11100111, %10010111, %11101011, %10110111, %10110110	;08-0F 89ABCDEF


		ORG  ($ & 0xFF00) + 0x20
;	**** 	; CGABFED,   CGABFED,   CGABFED,   CGABFED,   CGABFED,   CGABFED,   CGABFED,   CGABFED	;HEX	Character
LED_FONT DB	%10000000, %10000110, %10001100, %10111100, %11010101, %10101000, %10101001, %10000100 	;20-27  !"#$%&'
	DB	%10010111, %11011001, %10010100, %10100110, %11000001, %10100000, %10000001, %10101010	;28-2F ()*+,-./
	DB	%11011111, %11001000, %10111011, %11111001, %11101100, %11110101, %11110111, %11011000	;30-37 01234567
	DB	%11111111, %11111100, %10010001, %11010001, %10000011, %10100001, %11000001, %10111010	;38-3F 89:;<=>?
	DB	%11111011, %11111110, %11100111, %10010111, %11101011, %10110111, %10110110, %11010111	;40-47 @ABCDEFG
	DB	%11101110, %11001000, %11001011, %10101110, %10000111, %11101010, %11011110, %11011111	;48-4F HIJKLMNO
	DB	%10111110, %11111100, %10100010, %11110101, %10010110, %11001111, %11001111, %11001111	;50-57 PQRSTUVW
	DB	%11100000, %11101101, %10011011, %10010111, %11100100, %11011001, %10011100, %10000001	;58-5F XYZ[\]^_
	DB	%10001000, %11111011, %11100111, %10100011, %11101011, %10111111, %10110110, %11111101	;60-67 `abcdefg
	DB	%11100110, %11000000, %11001011, %10101110, %10000110, %11101010, %11100010, %11100011	;68-6F hijklmno
	DB	%10111110, %11111100, %10100010, %11110101, %10100111, %11000011, %11000011, %11000011	;70-77 pqrstuvw
	DB	%11100000, %11101101, %10011011, %10010111, %10000110, %11011001, %10110001, %11101011	;78-7F xyz{|}~


#endif



;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;	Appendix B	RAM. System Ram allocation
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;


;                       ********      ***     **     **
;                       *********    *****    ***   ***
;                       **     **   *** ***   **** ****
;                       **     **  ***   ***  *********
;---------------------  ********   *********  ** *** **  ---------------------
;---------------------  ********   *********  ** *** **  ---------------------
;                       **  **     **     **  **     **
;                       **   **    **     **  **     **
;                       **    **   **     **  **     **
;                       **     **  **     **  **     **

RAM_LDRT	equ	0x8100	; bc bas32K.asm uses RAM from 8065h. Here, we can start higher up 0x8000

;----------------------------------------------------------------------------------------------------; RAM SPACE
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;----------------------------------------------------------------------------------------------------; RAM SPACE
RXBUFFER	equ	0xFE00	;256 bytes of RX Buffer space


;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;Reserve space from 0xFF60 to FF7F for Stack
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
StackTop	equ	0xFF60	; Stack = 0xFF80 (Next Stack Push Location = 0xFF7F)

;*** BEGIN COLD_BOOT_INIT (RAM that is to be initialized upon COLD BOOT) ***
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
RegPtr		equ	0xFF73	;Ptr to Registers
ABUSS		equ	0xFF74	;
IoPtr		equ	0xFF76	; I/O Ptr
RX_ERR_LDRT	equ	0xFF77	;Counts False Start Bits (Noise Flag)
RX_ERR_STOP	equ	0xFF78	;Counts Missing Stop Bits (Framing Error)
RX_ERR_OVR	equ	0xFF79	;Counts Overrun Errors
BEEP_TO		equ	0xFF7A	;Count down the beep (beep duration)

;*** END COLD_BOOT_INIT (RAM that is to be initialized upon COLD BOOT) ***

				;Saved Registers
RSSP		equ	0xFF80	;Value of SP upon REGISTER SAVE
RSAF		equ	0xFF82	;Value of AF upon REGISTER SAVE
RSBC		equ	0xFF84	;Value of BC upon REGISTER SAVE
RSDE		equ	0xFF86	;Value of DE upon REGISTER SAVE
RSHL		equ	0xFF88	;Value of HL upon REGISTER SAVE
RPC		equ	0xFF8A	;Value of PC upon REGISTER SAVE
RSIX		equ	0xFF8C	;Value of IX upon REGISTER SAVE
RSIY		equ	0xFF8E	;Value of IY upon REGISTER SAVE
RSIR		equ	0xFF90	;Value of IR upon REGISTER SAVE
RSAF2		equ	0xFF92	;Value of AF' upon REGISTER SAVE
RSBC2		equ	0xFF94	;Value of BC' upon REGISTER SAVE
RSDE2		equ	0xFF96	;Value of DE' upon REGISTER SAVE
RSHL2		equ	0xFF98	;Value of HL' upon REGISTER SAVE


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
ECHO_ON		equ	0xFFF2	;Echo characters
XMSEQ		equ	0xFFF3	;XMODEM SEQUENCE NUMBER
XMTYPE		equ	0xFFF4	;XMODEM BLOCK TYPE (CRC/CS)
SCAN_LED	equ	0xFFF5	;Holds the next LED output
LED_DISPLAY_SB	equ	0xFFF6	;10 Bytes FFF6=Start BIT, 7,8,9,A,B,C,D,E=Data bits, F=Stop BIT
;10 bytes	equ	0xFFFF	;Warning, LED_DISPLAY_TBL must be at this address (XXF6)


;                       *********   *******    *********
;                       *********  *********   *********
;                       **         **     **   **
;                       **         **     **   **
;---------------------  *******    **     **   *******    ---------------------
;---------------------  *******    **     **   *******    ---------------------
;                       **         **     **   **
;                       **         **     **   **
;                       *********  *********   **
;                       *********   *******    **

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;	Appendix C	Z80 Instruction Reference
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;

;===================================================
;Mnemonic	Cyc	Opcodes		Bytes
;ADC A,(HL)	7	8E		1
;ADC A,(IX+o)	19	DD 8E oo	3
;ADC A,(IY+o)	19	FD 8E oo	3
;ADC A,n	7      	CE nn        	2
;ADC A,r	4	88+r		1
;ADC A,IXp	8	DD 88+P		2
;ADC A,IYp	8	FD 88+P		2
;ADC HL,BC	15	ED 4A		2
;ADC HL,DE	15	ED 5A		2
;ADC HL,HL	15	ED 6A		2
;ADC HL,sp	15	ED 7A		2
;ADD A,(HL)	7	86		1
;ADD A,(IX+o)	19	DD 86 oo	3
;ADD A,(IY+o)	19	FD 86 oo	3
;ADD A,n	7      	C6 nn		2
;ADD A,r	4	80+r		1
;ADD A,IXp      8      	DD 80+P		2
;ADD A,IYp      8      	FD 80+P		2
;ADD HL,BC	11	09		1
;ADD HL,DE	11	19		1
;ADD HL,HL	11	29		1
;ADD HL,sp	11	39		1
;ADD IX,BC	15	DD 09		2
;ADD IX,DE	15	DD 19		2
;ADD IX,IX	15	DD 29		2
;ADD IX,sp	15	DD 39		2
;ADD IY,BC	15	FD 09		2
;ADD IY,DE	15	FD 19		2
;ADD IY,IY	15	FD 29		2
;ADD IY,sp	15	FD 39		2
;AND (HL)	7	A6		1
;AND (IX+o)	19	DD A6 oo	3
;AND (IY+o)	19	FD A6 oo	3
;AND n       	7      	E6 nn		2
;AND r		4	A0+r		1
;AND IXp        8      	DD A0+P		2
;AND IYp        8      	FD A0+P		2
;BIT B,(HL)	12	CB 46+8*B	2	Test BIT B (AND the BIT, but do not save), Z=1 if BIT tested is 0
;BIT B,(IX+o)	20	DD CB oo 46+8*B	4	Test BIT B (AND the BIT, but do not save), Z=1 if BIT tested is 0
;BIT B,(IY+o)	20	FD CB oo 46+8*B	4	Test BIT B (AND the BIT, but do not save), Z=1 if BIT tested is 0
;BIT B,r	8	CB 40+8*B+r	2	Test BIT B (AND the BIT, but do not save), Z=1 if BIT tested is 0
;CALL nn	17	CD nn nn	3
;CALL C,nn	17/10	DC nn nn	3
;CALL M,nn	17/10	FC nn nn	3
;CALL NC,nn	17/10	D4 nn nn	3
;CALL NZ,nn	17/10	C4 nn nn	3
;CALL P,nn	17/10	F4 nn nn	3
;CALL PE,nn	17/10	EC nn nn	3
;CALL PO,nn	17/10	E4 nn nn	3
;CALL Z,nn	17/10	CALL C, nn nn	3
;CCF		4	3F		1
;CP (HL)	7	BE		1
;CP (IX+o)	19	DD BE oo	3
;CP (IY+o)	19	FD BE oo	3
;CP n        	7      	FE nn		2
;CP r		4	B8+r		1
;CP IXp        	8      	DD B8+P		2
;CP IYp        	8      	FD B8+P        	2
;CPD		16	ED A9		2
;CPDR		21/16	ED B9		2
;CP		16	ED A1		2
;CPIR		21/16	ED B1		2
;CPL		4	2F		1
;DAA		4	27		1
;DEC (HL)	11	35		1
;DEC (IX+o)	23	DD 35 oo	3
;DEC (IY+o)	23	FD 35 oo	3
;DEC A		4	3D		1
;DEC B		4	05		1
;DEC BC		6	0B		1
;DEC C		4	0D		1
;DEC D		4	15		1
;DEC DE		6	1B		1
;DEC E		4	1D		1
;DEC H		4	25		1
;DEC HL		6	2B		1
;DEC IX		10	DD 2B		2
;DEC IY		10	FD 2B		2
;DEC IXp        8      	DD 05+8*P	2
;DEC IYp        8      	FD 05+8*q      	2
;DEC L		4	2D		2
;DEC sp		6	3B		1
;DI		4	F3		1
;DJNZ o		13/8	10 oo		2
;EI		4	FB		1
;EX (sp),HL	19	E3		1
;EX (sp),IX	23	DD E3		2
;EX (sp),IY	23	FD E3		2
;EX AF,AF'	4	08		1
;EX	DE,HL	4	EB		1
;EXX		4	D9		1
;HALT		4	76		1
;IM 0		8	ED 46		2
;IM 1		8	ED 56		2
;IM 2		8	ED 5E		2
;IN A,(C)	12	ED 78		2
;IN A,(n)	11	db nn		2
;IN B,(C)	12	ED 40		2
;IN C,(C)	12	ED 48		2
;IN D,(C)	12	ED 50		2
;IN E,(C)	12	ED 58		2
;IN H,(C)	12	ED 60		2
;IN L,(C)	12	ED 68		2
;IN F,(C)	12	ED 70		3
;INC (HL)	11	34		1
;INC (IX+o)	23	DD 34 oo	3
;INC (IY+o)	23	FD 34 oo	3
;INC A		4	3C		1
;INC B		4	04		1
;INC BC		6	03		1
;INC C		4	0C		1
;INC D		4	14		1
;INC DE		6	13		1
;INC E		4	1C		1
;INC H		4	24		1
;INC HL		6	23		1
;INC IX		10	DD 23		2
;INC IY		10	FD 23		2
;INC IXp        8      	DD 04+8*P	2
;INC IYp       	8      	FD 04+8*q      	2
;INC L		4	2C		1
;INC sp		6	33		1
;IND		16	ED AA		2
;INDR		21/16	ED BA		2
;INI		16	ED A2		2
;INIR		21/16	ED B2		2
;JP nn		10	C3 nn nn	3	Jump Absolute
;JP (HL)	4	E9		1
;JP (IX)	8	DD E9		2
;JP (IY)	8	FD E9		2
;JP C,nn	10	DA nn nn	3
;JP M,nn	10	FA nn nn	3
;JP NC,nn	10	D2 nn nn	3
;JP NZ,nn	10	C2 nn nn	3
;JP P,nn	10	F2 nn nn	3
;JP PE,nn	10	EA nn nn	3
;JP PO,nn	10	E2 nn nn	3
;JP Z,nn	10	CA nn nn	3
;JR o		12	18 oo		2	Jump Relative
;JR C,o		12/7	38 oo		2
;JR NC,o	12/7	30 oo		2
;JR NZ,o	12/7	20 oo		2
;JR Z,o		12/7	28 oo		2
;LD (BC),A	7	02		1
;LD (DE),A	7	12		1
;LD (HL),n      10     	36 nn		2
;LD (HL),r	7	70+r		1
;LD (IX+o),n    19     	DD 36 oo nn	4
;LD (IX+o),r	19	DD 70+r oo	3
;LD (IY+o),n    19     	FD 36 oo nn	4
;LD (IY+o),r	19	FD 70+r oo	3
;LD (nn),A	13	32 nn nn	3
;LD (nn),BC	20	ED 43 nn nn	4
;LD (nn),DE	20	ED 53 nn nn	4
;LD (nn),HL	16	22 nn nn	3
;LD (nn),IX	20	DD 22 nn nn	4
;LD (nn),IY	20	FD 22 nn nn	4
;LD (nn),sp	20	ED 73 nn nn	4
;LD A,(BC)	7	0A		1
;LD A,(DE)	7	1A		1
;LD A,(HL)	7	7E		1
;LD A,(IX+o)	19	DD 7E oo	3
;LD A,(IY+o)	19	FD 7E oo	3
;LD A,(nn)	13	3A nn nn	3
;LD A,n        	7     	3E nn		2
;LD A,r		4	78+r		1
;LD A,IXp       8      	DD 78+P        	2
;LD A,IYp       8      	FD 78+P        	2
;LD A,I		9	ED 57		2
;LD A,R		9	ED 5F		2
;LD B,(HL)	7	46		1
;LD B,(IX+o)	19	DD 46 oo	3
;LD B,(IY+o)	19	FD 46 oo	3
;LD B,n        	7      	06 nn		2
;LD B,r		4	40+r		1
;LD B,IXp       8      	DD 40+P		2
;LD B,IYp       8     	FD 40+P        	2
;LD BC,(nn)	20	ED 4B nn nn	4
;LD BC,nn	10	01 nn nn	3
;LD C,(HL)	7	4E		1
;LD C,(IX+o)	19	DD 4E oo	3
;LD C,(IY+o)	19	FD 4E oo	3
;LD C,n        	7      	0E nn        	2
;LD C,r		4	48+r		1
;LD C,IXp       8      	DD 48+P        	2
;LD C,IYp       8      	FD 48+P		2
;LD D,(HL)	7	56		1
;LD D,(IX+o)	19	DD 56 oo	3
;LD D,(IY+o)	19	FD 56 oo	3
;LD D,n        	7      	16 nn		2
;LD D,r		4	50+r		1
;LD D,IXp       8      	DD 50+P        	2
;LD D,IYp       8      	FD 50+P        	2
;LD DE,(nn)	20	ED 5B nn nn	4
;LD DE,nn	10	11 nn nn	3
;LD E,(HL)	7	5E		1
;LD E,(IX+o)	19	DD 5E oo	3
;LD E,(IY+o)	19	FD 5E oo	3
;LD E,n        	7      	1E nn        	2
;LD E,r		4	58+r		1
;LD E,IXp       8      	DD 58+P        	2
;LD E,IYp       8      	FD 58+P        	2
;LD H,(HL)	7	66		1
;LD H,(IX+o)	19	DD 66 oo	3
;LD H,(IY+o)	19	FD 66 oo	3
;LD H,n        	7      	26 nn		2
;LD H,r		4	60+r		1
;LD HL,(nn)	16	2A nn nn	5
;LD HL,nn	10	21 nn nn	3
;LD I,A		9	ED 47		2
;LD IX,(nn)	20	DD 2A nn nn	4
;LD IX,nn	14	DD 21 nn nn	4
;LD IXh,n       11     	DD 26 nn 	2
;LD IXh,P       8     	DD 60+P		2
;LD IXl,n       11     	DD 2E nn 	2
;LD IXl,P       8     	DD 68+P		2
;LD IY,(nn)	20	FD 2A nn nn	4
;LD IY,nn	14	FD 21 nn nn	4
;LD IYh,n       11     	FD 26 nn 	2
;LD IYh,q       8     	FD 60+P		2
;LD IYl,n       11     	FD 2E nn 	2
;LD IYl,q       8     	FD 68+P		2
;LD L,(HL)	7	6E		1
;LD L,(IX+o)	19	DD 6E oo	3
;LD L,(IY+o)	19	FD 6E oo	3
;LD L,n       	7     	2E nn		2
;LD L,r		4	68+r		1
;LD R,A		9	ED 4F		2
;LD sp,(nn)	20	ED 7B nn nn	4
;LD sp,HL	6	F9		1
;LD sp,IX	10	DD F9		2
;LD sp,IY	10	FD F9		2
;LD sp,nn	10	31 nn nn	3
;LDD		16	ED A8		2
;LDDR		21/16	ED B8		2
;LDI		16	ED A0		2
;LDIR		21/16	ED B0		2
;MULUB A,r 		ED C1+8*r 	2
;MULUW HL,BC		ED C3 		2
;MULUW HL,sp		ED F3 		2
;NEG		8	ED 44		2
;NOP		4	00		1
;OR (HL)	7	B6		1
;OR (IX+o)	19	DD B6 oo	3
;OR (IY+o)	19	FD B6 oo	3
;OR n       	7     	F6 nn		2
;OR r		4	B0+r		1
;OR IXp       	8     	DD B0+P		2
;OR IYp       	8     	FD B0+P		2
;OTDR		21/16	ED BB		2
;OTIR		21/16	ED B3		2
;OUT (C),A	12	ED 79		2
;OUT (C),B	12	ED 41		2
;OUT (C),C	12	ED 49		2
;OUT (C),D	12	ED 51		2
;OUT (C),E	12	ED 59		2
;OUT (C),H	12	ED 61		2
;OUT (C),L	12	ED 69		2
;OUT (n),A	11	D3 nn		2
;OUTD		16	ED AB		2
;OUTI		16	ED A3		2
;POP AF		10	F1		1
;POP BC		10	C1		1
;POP DE		10	D1		1
;POP HL		10	E1		1
;POP IX		14	DD E1		2
;POP IY		14	FD E1		2
;PUSH AF	11	F5		1
;PUSH BC	11	C5		1
;PUSH DE	11	D5		1
;PUSH HL	11	E5		1
;PUSH IX	15	DD E5		2
;PUSH IY	15	FD E5		2
;RES B,(HL)	15	CB 86+8*B	2	Reset BIT B (clear BIT)
;RES B,(IX+o)	23	DD CB oo 86+8*B	4	Reset BIT B (clear BIT)
;RES B,(IY+o)	23	FD CB oo 86+8*B	4	Reset BIT B (clear BIT)
;RES B,r	8	CB 80+8*B+r	2	Reset BIT B (clear BIT)
;RET		10	C9		1
;RET C		11/5	D8		1
;RET M		11/5	F8		1
;RET NC		11/5	D0		1
;RET NZ		11/5	C0		1
;RET P		11/5	F0		1
;RET PE		11/5	E8		1
;RET PO		11/5	E0		1
;RET Z		11/5	C8		1
;RETI		14	ED 4D		2
;RETN		14	ED 45		2
;RL (HL)	15	CB 16		2  	9 BIT rotate left through Carry
;RL (IX+o)	23	DD CB oo 16	4	9 BIT rotate left through Carry
;RL (IY+o)	23	FD CB oo 16	4	9 BIT rotate left through Carry
;RL r       	8     	CB 10+r		2	9 BIT rotate left through Carry
;RLA		4	17		1	9 BIT rotate left through Carry
;RLC (HL)	15	CB 06		2	8 BIT rotate left, C=msb
;RLC (IX+o)	23	DD CB oo 06	4	8 BIT rotate left, C=msb
;RLC (IY+o)	23	FD CB oo 06	4	8 BIT rotate left, C=msb
;RLC r		8	CB 00+r		2	8 BIT rotate left, C=msb
;RLCA		4	07		1	8 BIT rotate left, C=msb
;RLD		18	ED 6F		2	3 nibble rotate, A3-0 to (HL)3-0, (HL)3-0 to (HL)7-4, (HL)7-4 to A3-0
;RR (HL)	15	CB 1E		2	9 BIT rotate right through Carry
;RR (IX+o)	23	DD CB oo 1E	4	9 BIT rotate right through Carry
;RR (IY+o)	23	FD CB oo 1E	4	9 BIT rotate right through Carry
;RR r       	8     	CB 18+r		2	9 BIT rotate right through Carry
;RRA		4	1F		1	9 BIT rotate right through Carry
;RRCA (HL)	15	CB 0E		2	8 BIT rotate right, C=lsb
;RRCA (IX+o)	23	DD CB oo 0E	4	8 BIT rotate right, C=lsb
;RRCA (IY+o)	23	FD CB oo 0E	4	8 BIT rotate right, C=lsb
;RRCA r		8	CB 08+r		2	8 BIT rotate right, C=lsb
;RRCAA		4	0F		1	8 BIT rotate right, C=lsb
;RRD		18	ED 67		2	3 nibble rotate, A3-0 to (HL)7-4, (HL)7-4 to (HL)3-0, (HL)3-0 to A3-0
;RST 0		11	C7		1
;RST 8H		11	CF		1
;RST 10H	11	D7		1
;RST 18H	11	DF		1
;RST 20H	11	E7		1
;RST 28H	11	EF		1
;RST 30H	11	F7		1
;RST 38H	11	FF		1
;SBC A,(HL)	7	9E		1
;SBC A,(IX+o)	19	DD 9E oo	3
;SBC A,(IY+o)	19	FD 9E oo	3
;SBC A,n	7	DE nn		2
;SBC A,r	4	98+r		1
;SBC A,IXp      8     	DD 98+P		2
;SBC A,IYp      8     	FD 98+P		2
;SBC HL,BC	15	ED 42		2
;SBC HL,DE	15	ED 52		2
;SBC HL,HL	15	ED 62		2
;SBC HL,sp	15	ED 72		2
;SCF		4	37		1	Set Carry
;SET B,(HL)	15	CB C6+8*B	2	Set BIT B (0-7)
;SET B,(IX+o)	23	DD CB oo C6+8*B	4	Set BIT B (0-7)
;SET B,(IY+o)	23	FD CB oo C6+8*B	4	Set BIT B (0-7)
;SET B,r	8	CB C0+8*B+r	2	Set BIT B (0-7)
;SLA (HL)	15	CB 26		2	9 BIT shift left, C=msb, lsb=0
;SLA (IX+o)	23	DD CB oo 26	4	9 BIT shift left, C=msb, lsb=0
;SLA (IY+o)	23	FD CB oo 26	4	9 BIT shift left, C=msb, lsb=0
;SLA r		8	CB 20+r		2	9 BIT shift left, C=msb, lsb=0
;SRA (HL)	15	CB 2E		2	8 BIT shift right, C=lsb, msb=msb (msb does not change)
;SRA (IX+o)	23	DD CB oo 2E	4	8 BIT shift right, C=lsb, msb=msb (msb does not change)
;SRA (IY+o)	23	FD CB oo 2E	4	8 BIT shift right, C=lsb, msb=msb (msb does not change)
;SRA r		8	CB 28+r		2	8 BIT shift right, C=lsb, msb=msb (msb does not change)
;SRL (HL)	15	CB 3E		2	8 BIT shift right, C=lsb, msb=0
;SRL (IX+o)	23	DD CB oo 3E	4	8 BIT shift right, C=lsb, msb=0
;SRL (IY+o)	23	FD CB oo 3E	4	8 BIT shift right, C=lsb, msb=0
;SRL r		8	CB 38+r		2	8 BIT shift right, C=lsb, msb=0
;SUB (HL)	7	96		1
;SUB (IX+o)	19	DD 96 oo	3
;SUB (IY+o)	19	FD 96 oo	3
;SUB n       	7     	D6 nn		2
;SUB r		4	90+r		1
;SUB IXp       	8     	DD 90+P		2
;SUB IYp       	8     	FD 90+P		2
;XOR (HL)	7	AE		1
;XOR (IX+o)	19	DD AE oo	3
;XOR (IY+o)	19	FD AE oo	3
;XOR n       	7     	EE nn		2
;XOR r       	4     	A8+r		1
;XOR IXp       	8     	DD A8+P		2
;XOR IYp       	8     	FD A8+P		2
;
;variables used:
;
; B = 3-BIT value
; n = 8-BIT value
; nn= 16-BIT value
; o = 8-BIT offset (2-complement)
; r = Register. This can be A, B, C, D, E, H, L OR (HL). Add to the last byte of the opcode:
;
;		Register	Register bits value
;		A		7
;		B		0
;		C		1
;		D		2
;		E		3
;		H		4
;		L		5
;		(HL)		6
;
; P = The high OR low part of the IX OR IY register: (IXh, IXl, IYh, IYl). Add to the last byte of the opcode:
;
;		Register	Register bits value
;		A		7
;		B		0
;		C		1
;		D		2
;		E		3
;		IXh (IYh)	4
;		IXl (IYl)	5
		