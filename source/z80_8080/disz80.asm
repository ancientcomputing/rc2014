; Comment out this if not running in RAM
;        .ORG    5000H

; Comment out this if running in RAM
; This is the address of DISZ80 in ROM. It resides after Int32K + Mon32K
; We assume that Int32K+Mon32K take up less than 2304 bytes
       .ORG    0B00H



; -----------------------------------------------------------------------------
; The following header note is from U3.asm, a utility for the Spectrum
; -----------------------------------------------------------------------------
; DIS-Z80 was published in the SUBSET column of Personal Computer World 1987.
; The routine disassembles a single Z80 instruction at address DE. 
; It is required to be followed by a routine called CHROP that outputs a 
; single ASCII character.
; It was originally developed for CP/M on an Amstrad CPC128.
; The original ORG was $0100. I have added $5000 to all addresses.
; The stated aim was to write a Z80 disassembly routine in as short a space
; as possible and, at just over 1K (1090 bytes), it is a rather incredible 
; program. 
; The SUBSET editor David Barrow was able to trim only one byte from John 
; Kerr's compact code. I've forgotten where so there's a challenge.
; -----------------------------------------------------------------------------
; Note that John Kerr's website also mentions the disassembler and includes
; actual scans of the original code along with comments:
; http://mycodehere.blogspot.co.uk/2012/04/my-work-in-print-1987.html



; Enter with DE pointing to the instruction

DISZ80 	CALL 	ADRSP
       	LD 	BC,$0900
       	LD 	HL,$2020

BUFFER 	PUSH 	HL
       	DJNZ 	BUFFER
       	LD 	H,B
       	LD 	L,C
       	ADD 	HL,SP

       	PUSH 	BC
       	EX 	(SP),IX
       	PUSH 	BC
       	PUSH 	BC
       	ADD 	IX,SP

       	PUSH 	HL
       	LD 	HL,GROUP3

TRYNDX 	CALL 	FETCH

       	LD 	B,C
       	CP 	$ED
       	JR 	Z,CONFLG

       	INC 	B
       	CP 	$DD
       	JR 	Z,CONFLG

       	INC 	B
       	CP 	$FD
       	JR 	NZ,NOTNDX

CONFLG 	LD 	(IX+1),B
       	INC 	B
       	DJNZ 	TRYNDX

       	JR 	NXBYTE

NOTNDX 	LD 	C,A
       	LD 	A,(IX+1)
       	OR 	A
       	JR 	Z,NODISP

       	LD 	A,C
       	CP 	$CB
       	JR 	Z,GETDIS

       	AND 	$44
       	CP 	4
       	JR 	Z,GETDIS

       	LD 	A,C
       	AND 	$C0
       	CP 	$40
       	JR 	NZ,NODISP

GETDIS 	CALL 	FETCH
       	LD 	(IX+2),A

NODISP 	LD 	HL,GROUP1
       	LD 	A,C
       	CP 	$CB
       	JR 	NZ,NEWMSK

       	LD 	HL,GROUP2

NXBYTE 	CALL 	FETCH
       	LD 	C,A

NEWMSK 	LD 	A,(HL)
       	OR 	A
       	JR 	Z,TABEND

       	AND 	C
       	INC 	HL

NEWMOD 	LD 	B,(HL)
       	INC 	HL
       	INC 	B
       	JR 	Z,NEWMSK

TRYMAT 	CP 	(HL)
       	INC 	HL
       	JR 	Z,GETNDX

       	BIT 	7,(HL)
       	INC 	HL
       	JR 	Z,TRYMAT

       	JR 	NEWMOD

GETNDX 	LD 	A,(HL)
       	AND 	$7F
       	DEC 	B

TABEND 	POP 	HL
       	PUSH 	DE
       	PUSH 	HL

       	EX 	DE,HL
       	LD 	HL,MONICS
       	CALL 	XTRACT

       	POP 	HL
       	LD 	DE,5
       	ADD 	HL,DE
       	POP 	DE

       	LD 	A,B
       	AND 	$F0
       	JR 	Z,SECOND

       	RRA
       	RRA
       	RRA
       	RRA
       	PUSH 	BC

       	LD 	B,A
       	LD 	A,C
       	CALL 	OPRND1

       	POP 	BC
       	LD 	A,B
       	AND 	$0F
       	JR 	Z,OPDONE

       	LD 	(HL),44  		;,
       	INC 	HL

SECOND 	LD 	A,B
       	AND 	$0F

       	LD 	B,A
       	LD 	A,C
       	CALL 	NZ,OPRND2

OPDONE 	LD 	A,3
       	SUB 	(IX)

       	POP 	HL
       	POP 	HL
       	POP 	IX

       	JR 	C,OUTEXT

       	INC 	A
       	LD 	B,A
       	ADD 	A,B
       	ADD 	A,B
       	LD 	B,A

SPACES 	LD 	A,$20
       	CALL 	CHROP
       	DJNZ 	SPACES

OUTEXT 	LD 	B,18

PUTOUT 	DEC 	SP
       	POP 	HL
       	LD 	A,H
       	CALL 	CHROP
       	DJNZ 	PUTOUT

       	RET

;***********************

GROUP2 	DEFB 	$C0,$36,$40
	DEFB 	$04,$80,$2D,$C0,$BE
	DEFB 	$FF,$F8,$06,$00,$33
	DEFB 	$08,$38,$10,$35,$18
	DEFB 	$3A,$20,$3F,$28,$40
	DEFB 	$30,$00,$38,$C1


GROUP1 	DEFB 	$FF,$00,$00
	DEFB 	$24,$07,$32,$0F,$37
	DEFB 	$17,$31,$1F,$36,$27
	DEFB 	$0D,$2F,$0B,$37,$3D
	DEFB 	$3F,$06,$76,$14,$C9
	DEFB 	$30,$D9,$12,$F3,$0F
	DEFB 	$FB,$91,$72,$C6,$02
	DEFB 	$CE,$01,$DE,$BC,$02
	DEFB 	$D6,$42,$E6,$03,$EE
	DEFB 	$43,$F6,$25,$FE,$8C
	DEFB 	$04,$08,$93,$01,$10
	DEFB 	$10,$18,$9D,$AF,$22
	DEFB 	$A2,$FA,$2A,$A2,$A7
	DEFB 	$32,$A2,$7A,$3A,$A2
	DEFB 	$03,$C3,$1C,$CD,$85
	DEFB 	$97,$D3,$AA,$79,$DB
	DEFB 	$9B,$5F,$E3,$93,$0E
	DEFB 	$E9,$9C,$05,$EB,$93
	DEFB 	$DF,$F9,$A2,$FF,$C0
	DEFB 	$B6,$40,$A2,$FF,$F8
	DEFB 	$76,$80,$02,$88,$01
	DEFB 	$98,$BC,$06,$90,$42
	DEFB 	$A0,$03,$A8,$43,$B0
	DEFB 	$25,$B8,$8C,$FF,$C7
	DEFB 	$0B,$04,$16,$05,$8E
	DEFB 	$B2,$06,$A2,$20,$C0
	DEFB 	$B0,$23,$C2,$1C,$C4
	DEFB 	$85,$10,$C7,$BB,$FF
	DEFB 	$CF,$D3,$01,$A2,$0D
	DEFB 	$03,$16,$0B,$8E,$FD
	DEFB 	$09,$82,$60,$C1,$2B
	DEFB 	$C5,$AC,$FF,$E7,$21
	DEFB 	$20,$9D,$FF,$EF,$E7
	DEFB 	$02,$A2,$7E,$0A,$A2


GROUP3 	DEFB 	$FF,$00,$44
	DEFB 	$23,$45,$2F,$4D,$2E
	DEFB 	$4E,$00,$67,$39,$6F
	DEFB 	$34,$70,$00,$71,$00
	DEFB 	$A0,$21,$A1,$0A,$A2
	DEFB 	$1A,$A3,$29,$A8,$1F
	DEFB 	$A9,$08,$AA,$18,$AB
	DEFB 	$28,$B0,$20,$B1,$09
	DEFB 	$B2,$19,$B3,$27,$B8
	DEFB 	$1E,$B9,$07,$BA,$17
	DEFB 	$BB,$A6,$FF,$C7,$B8
	DEFB 	$40,$9B,$8B,$41,$AA
	DEFB 	$FF,$CF,$FD,$42,$3C
	DEFB 	$4A,$81,$AD,$43,$A2
	DEFB 	$DA,$4B,$A2,$FF,$E7
	DEFB 	$40,$46,$95,$FF,$F7
	DEFB 	$C7,$47,$A2,$7C,$57
	DEFB 	$A2,$FF,$00

;_______________

MONICS 	DEFB 	$BF
	DEFB 	'A','D','C'+$80   	; ADC 
	DEFB 	'A','D','D'+$80   	; ADD 
	DEFB 	'A','N','D'+$80   	; AND 
	DEFB 	'B','I','T'+$80   	; BIT 
	DEFB 	'C','A','L','L'+$80	; CALL 
	DEFB 	'C','C','F'+$80   	; CCF
	DEFB 	'C','P','D','R'+$80	; CPDR
	DEFB 	'C','P','D'+$80   	; CPD
	DEFB 	'C','P','I','R'+$80	; CPIR
	DEFB 	'C','P','I'+$80   	; CPI
	DEFB 	'C','P','L'+$80   	; CPL
	DEFB 	'C','P'+$80      	; CP 
	DEFB 	'D','A','A'+$80   	; DAA
	DEFB 	'D','E','C'+$80   	; DEC 
	DEFB 	'D','I'+$80      	; DI
	DEFB 	'D','J','N','Z'+$80	; DJNZ 
	DEFB 	'E','I'+$80      	; EI
	DEFB 	'E','X','X'+$80   	; EXX
	DEFB 	'E','X'+$80      	; EX 
	DEFB 	'H','A','L','T'+$80	; HALT
	DEFB 	'I','M'+$80      	; IM 
	DEFB 	'I','N','C'+$80   	; INC 
	DEFB 	'I','N','D','R'+$80	; INDR
	DEFB 	'I','N','D'+$80   	; IND
	DEFB 	'I','N','I','R'+$80	; INIR
	DEFB 	'I','N','I'+$80   	; INI
	DEFB 	'I','N'+$80      	; IN 
	DEFB 	'J','P'+$80      	; JP 
	DEFB 	'J','R'+$80      	; JR 
	DEFB 	'L','D','D','R'+$80	; LDDR
	DEFB 	'L','D','D'+$80   	; LDD
	DEFB 	'L','D','I','R'+$80	; LDIR
	DEFB 	'L','D','I'+$80   	; LDI
	DEFB 	'L','D'+$80      	; LD 
	DEFB 	'N','E','G'+$80   	; NEG
	DEFB 	'N','O','P'+$80   	; NOP
	DEFB 	'O','R'+$80      	; OR 
	DEFB 	'O','T','D','R'+$80	; OTDR
	DEFB 	'O','T','I','R'+$80	; OTIR
	DEFB 	'O','U','T','D'+$80	; OUTD
	DEFB 	'O','U','T','I'+$80	; OUTI
	DEFB 	'O','U','T'+$80   	; OUT 
	DEFB 	'P','O','P'+$80   	; POP 
	DEFB 	'P','U','S','H'+$80	; PUSH 
	DEFB 	'R','E','S'+$80   	; RES 
	DEFB 	'R','E','T','I'+$80	; RETI
	DEFB 	'R','E','T','N'+$80	; RETN
	DEFB 	'R','E','T'+$80   	; RET
	DEFB 	'R','L','A'+$80   	; RLA
	DEFB 	'R','L','C','A'+$80	; RLCA
	DEFB 	'R','L','C'+$80   	; RLC 
	DEFB 	'R','L','D'+$80   	; RLD
	DEFB 	'R','L'+$80      	; RL 
	DEFB 	'R','R','A'+$80   	; RRA
	DEFB 	'R','R','C','A'+$80	; RA
	DEFB 	'R','R','C'+$80   	; RRC 
	DEFB 	'R','R','D'+$80   	; RRD
	DEFB 	'R','R'+$80      	; RR 
	DEFB 	'R','S','T'+$80   	; RST 
	DEFB 	'S','B','C'+$80   	; SBC 
	DEFB 	'S','C','F'+$80   	; SCF
	DEFB 	'S','E','T'+$80   	; SET 
	DEFB 	'S','L','A'+$80   	; SLA 
	DEFB 	'S','R','A'+$80   	; SRA 
	DEFB 	'S','R','L'+$80   	; SRL 
	DEFB 	'S','U','B'+$80   	; SUB 
	DEFB 	'X','O','R'+$80   	; XOR 



;*****************

OPRND1 	DJNZ 	CONDIT

RSTADR 	AND 	$38
       	JR 	DA

OPRND2 	DJNZ 	DAT8

RELADR 	CALL 	FETCH
       	LD 	C,A
       	RLA
       	SBC 	A,A
       	LD 	B,A
       	EX 	DE,HL
       	PUSH 	HL
       	ADD 	HL,BC
       	JR 	DHL

CONDIT 	RRA
       	RRA
       	RRA
       	DJNZ 	BITNUM

       	BIT 	4,A
       	JR 	NZ,ABS

       	AND 	3
	
ABS    	AND 	7
       	ADD 	A,$14
       	JR 	PS1

DAT8   	DJNZ 	DAT16

D8     	CALL 	FETCH
       	JR 	DA

BITNUM 	DJNZ 	INTMOD
       	AND 	7

DA     	LD 	C,A
       	SUB 	A
       	JR 	DAC

DAT16  	DJNZ 	EXAF
	
D16    	CALL 	FETCH
       	LD 	C,A
       	CALL 	FETCH

DAC    	EX 	DE,HL
       	PUSH 	HL
       	LD 	H,A
       	LD 	L,C

DHL    	LD 	C,$F8
       	PUSH 	HL
       	CALL 	CONVHL
       	POP 	HL
       	LD 	BC,$000A
       	OR 	A
       	SBC 	HL,BC
       	POP 	HL
       	EX 	DE,HL
       	RET 	C

       	LD 	(HL),'H'
       	INC 	HL
       	RET


INTMOD 	DJNZ 	STKTOP
       	AND 	3
       	ADD 	A,$1C
	
PS1    	JR 	PS3

STKTOP 	LD 	C,$13
       	DEC 	B
       	JR 	Z,PS2

REG16P 	DJNZ 	COMMON
       	RRA
       	AND 	3
       	CP 	3
       	JR 	NZ,RX

       	DEC 	A
       	JR 	RNX

EXAF   	LD 	C,$0A
       	DEC 	B
       	JR 	Z,PS2

EXDE   	INC 	C
       	DEC 	B
       	JR 	Z,PS2

REG8S  	DJNZ 	ACCUM

R8     	AND 	7
       	CP 	6
       	JR 	NZ,PS3

       	LD 	(HL),'('
       	INC 	HL
       	CALL 	REGX
       	LD 	A,(IX+2)
       	OR 	A
       	JR 	Z,RP

       	LD 	(HL),43 		;+
       	RLCA
       	RRCA
       	JR 	NC,POS

       	LD 	(HL),45			;-
       	NEG

POS    	INC 	HL
       	EX 	DE,HL
       	PUSH 	HL
       	LD 	H,B
       	LD 	L,A
       	LD 	C,$FB
       	CALL 	CONVHL
       	POP 	HL
       	EX 	DE,HL
       	JR 	RP

ACCUM  	RRA
       	RRA
       	RRA

COMMON 	LD 	C,7
       	DEC 	B
       	JR 	Z,PS2

PORTC  	DEC 	C
       	DJNZ 	IDAT8

PS2    	LD 	A,C
PS3    	JR 	PS4

IDAT8  	DJNZ 	IDAT16
       	LD 	(HL),'('
       	INC 	HL
       	CALL 	D8
       	JR 	RP

IDAT16 	DJNZ 	REG8
       	LD 	(HL),'('
       	INC 	HL
       	CALL 	D16
       	JR 	RP

REG8   	DEC 	B
       	JR 	Z,R8

IPAREF 	DJNZ 	REG16
       	AND 	9
       	JR 	PS4

REG16  	RRA
       	DJNZ 	IREG16

R16    	AND 	3
RX     	CP  	2
       	JR 	Z,REGX

RNX    	ADD 	A,$0C
       	JR 	PS4

IREG16 	DJNZ 	REGX
       	LD 	(HL),'('
       	INC 	HL
       	CALL 	R16

RP     	LD 	(HL),')'
       	INC 	HL
       	RET

REGX   	LD 	A,(IX+1)
       	ADD 	A,$10

PS4    	EX 	DE,HL
       	PUSH 	HL
       	LD 	HL,RGSTRS
       	CALL 	XTRACT
       	POP 	HL
       	EX 	DE,HL
       	RET

;*************

RGSTRS 	DEFB 	'B'				+$80
	DEFB 	'C'       			+$80
	DEFB 	'D'       			+$80
	DEFB 	'E'       			+$80
	DEFB 	'H'       			+$80
	DEFB 	'L'       			+$80
	DEFB 	"(","C",')' 			+$80
	DEFB 	'A'       			+$80
	DEFB 	'I'       			+$80
	DEFB 	'R'       			+$80
	DEFB 	"A","F",",","A","F",'''		+$80
	DEFB 	"D","E",",","H",'L'    		+$80
	DEFB 	"B",'C'             		+$80
	DEFB 	"D",'E'             		+$80
	DEFB 	"A",'F'             		+$80
	DEFB 	"S",'P'             		+$80
	DEFB 	"H",'L'             		+$80
	DEFB 	"I",'X'             		+$80
	DEFB 	"I",'Y'             		+$80
	DEFB 	"(","S","P",')'       		+$80
	DEFB 	"N",'Z'             		+$80
	DEFB 	'Z'                		+$80
	DEFB 	"N",'C'             		+$80
	DEFB 	'C'                		+$80
	DEFB 	"P",'O'             		+$80
	DEFB 	"P",'E'             		+$80
	DEFB 	'P'                		+$80
	DEFB 	'M'                		+$80
	DEFB 	'0'    				+$80
	DEFB 	'?'    				+$80
	DEFB 	'1'    				+$80
	DEFB 	'2'    				+$80

;********************

CONVHL 	SUB 	A

CVHL1  	PUSH 	AF
       	SUB 	A
       	LD 	B,16

CVHL2  	ADD 	A,C
       	JR 	C,CVHL3
       	SUB 	C

CVHL3  	ADC 	HL,HL
       	RLA
       	DJNZ 	CVHL2

       	JR 	NZ,CVHL1

       	CP 	10
       	INC 	B
       	JR 	NC,CVHL1

CVHL4  	CP 	10
       	SBC 	A,$69
       	DAA
       	LD 	(DE),A
       	INC 	DE
       	POP 	AF
       	JR 	NZ,CVHL4

       	RET

;****************

XTRACT 	OR 	A
       	JR 	Z,COPY

SKIP   	BIT 	7,(HL)
       	INC 	HL
       	JR 	Z,SKIP

       	DEC 	A
       	JR 	NZ,SKIP

COPY   	LD 	A,(HL)
       	RLCA
       	SRL 	A
       	LD 	(DE),A

       	INC 	DE
       	INC 	HL
       	JR 	NC,COPY

       	RET

;*******************

FETCH  	LD 	A,(DE)
       	INC 	DE
       	INC 	(IX+0)
       	PUSH 	AF
       	CALL 	BYTSP
       	POP 	AF
       	RET

ADRSP  	LD 	A,D
       	CALL 	BYTOP
       	LD 	A,E

BYTSP  	CALL 	BYTOP
       	LD 	A,$20
       	JR 	CHROP

BYTOP  	PUSH 	AF
       	RRA
       	RRA
       	RRA
       	RRA
       	CALL 	HEXOP
       	POP 	AF

HEXOP  	AND 	$0F
       	CP 	10
       	SBC 	A,$69
       	DAA

; -----------------------------------
;
; End of John Kerr's DIS-Z80 routine.
; 
; The next routine outputs a character.
;
; -------------------------------------

; In theory, we don't have to save all the registers, just AF
; since we don't really destroy anything with RST 08H
CHROP:  
        PUSH    HL
        PUSH    DE
        PUSH    BC
        PUSH    AF
        RST     08H
        POP     AF
        POP     BC
        POP     DE
        POP     HL
        RET

        .ORG    0FFFH
        DB      55H
                         
