;---------------------------------------------------------------------
; Modified for RC2014
; Changes are copyright Ben Chong and freely licensed to the community
;
;---------------------------------------------------------------------
;  Original version information:
;       SBC Firmware V5.1.1, 7-4-13, by Daryl Rictor
;       5.1.1 Lite Version - removed List and Mini-Assembler & Help
;
;
;*********************************************************************       
;  local Zero-page variables
;
xsav           =     $30               ; 1 byte
ysav           =     $31               ; 1 byte
rowcount        =       $32
;Prompt         =     $32               ; 1 byte   
;linecnt        =     $33               ; 1 byte
;Modejmp        =     $34               ; 1 byte
;Hexdigcnt      =     $35               ; 1 byte
;OPCtxtptr      =     $36               ; 1 byte
;Memchr         =     $37               ; 1 byte
Startaddr      =     $38               ; 2 bytes
Startaddr_H    =     $39
;Addrptr        =     $3a               ; 2 bytes
;Addrptr_H      =     $3b
Hexdigits      =     $3c               ; 2 bytes
Hexdigits_H    =     $3d
;Memptr         =     $3e               ; 2 bytes
;Memptr_H       =     $3f
strptr          =     $40
strptrh         =     $41		; temporary string pointer (not preserved across calls)
;
; Local Non-Zero Page Variables
;
buffer         =     $0300             ; keybd input buffer (127 chrs max)
PCH            =     $03e0             ; hold program counter (need PCH next to PCL for Printreg routine)
PCL            =     $03e1             ;  ""
ACC            =     $03e2             ; hold Accumulator (A)
XREG           =     $03e3             ; hold X register
YREG           =     $03e4             ; hold Y register
SPTR           =     $03e5             ; hold stack pointer
PREG           =     $03e6             ; hold status register (P)
irq_vector      =       $03e8           ; Interrupt vector
nmi_vector      =       $03ea           ; NMI vector
;

;
;               
; *************************************************************************
; kernal commands
; *************************************************************************
; PrintRegCR   - subroutine prints a CR, the register contents, CR, then returns
; PrintReg     - same as PrintRegCR without leading CR
; Print2Byte   - prints AAXX hex digits
; Print1Byte   - prints AA hex digits
; PrintDig     - prints A hex nibble (low 4 bits)
; Print_CR     - prints a CR (ASCII 13)and LF (ASCII 10)
; PrintXSP     - prints # of spaces in X Reg
; Print2SP     - prints 2 spaces
; Print1SP     - prints 1 space
; Input_Char    - get one byte from input port, waits for input
; check_Input   - Checks for an input character (no waiting)
; Output_char   - send one byte to the console
; *************************************************************************
;
RegData        .byte" PC=  A=  X=  Y=  S=  P= (NVRBDIZC)="
;
; Prints a CR, the register contents, CR, then returns
;
PrintReg       Jsr   Print_CR          ; Lead with a CR
               ldx   #$ff              ;
               ldy   #$ff              ;
Printreg1      iny                     ;
               lda   Regdata,y         ;
               jsr   Output_char            ;
               cmp   #$3D              ; "="
               bne   Printreg1         ;
Printreg2      inx                     ;
               cpx   #$07              ;
               beq   Printreg3         ; done with first 6
               lda   PCH,x             ;  
               jsr   Print1Byte        ;
               cpx   #$00              ;
               bne   Printreg1         ;
               beq   Printreg2         ;
Printreg3      dex                     ;
               lda   PCH,x             ; get Preg
               ldx   #$08              ; 
Printreg4      rol                     ;
               tay                     ;
               lda   #$31              ;
               bcs   Printreg5         ;
               sbc   #$00              ; clc implied:subtract 1
Printreg5      jsr   Output_char            ;
               tya                     ;
               dex                     ;
               bne   Printreg4         ;
; fall into the print CR routine
;---------------------------------------------------------------------
; Print CR/LF
; Preserves A
Print_CR       PHA                     ; Save Acc
               LDA   #$0D              ; "cr"
               JSR   OUTPUT_char            ; send it
               LDA   #$0A              ; "lf"
               JSR   OUTPUT_char            ; send it
               PLA                     ; Restore Acc
               RTS                     ; 

;---------------------------------------------------------------------
; Prints AAXX hex digits
;
Print2Byte     JSR   Print1Byte        ;  prints AAXX hex digits
               TXA                     ;

;---------------------------------------------------------------------
; Prints AA hex digits
; A=byte
Print1Byte     PHA                     ;  Save A on stack
               LSR                     ;  MOVE UPPER NIBBLE TO LOWER
               LSR                     ;
               LSR                     ;
               LSR                     ;
               JSR   PrintDig          ; Print nibble
               PLA                     ;  Restore A

;---------------------------------------------------------------------
; Print lower nibble of A
;
PrintDig       sty   ysav              ;  prints A hex nibble (low 4 bits)
               AND   #$0F              ;
               TAY                     ;
               LDA   Hexdigdata,Y      ;
               ldy   ysav              ;
               jmp   output_char            ;
PrintXSP1      JSR   Print1SP          ;
               dex                     ;
PrintXSP       cpx   #$00              ;
               bne   PrintXSP1         ;
               rts                     ;

;---------------------------------------------------------------------
; Print 2 spaces
; Exit: A is changed
Print2SP       jsr   Print1SP          ; print 2 SPACES

;---------------------------------------------------------------------
; Print 1 space
; Exit: A is changed
Print1SP       LDA   #$20              ; print 1 SPACE
               JMP   OUTPUT_char            ;
               
;---------------------------------------------------------------------
;Print the string starting at (AX) until we encounter a NULL
;string can be in RAM or ROM.  It's limited to <= 255 bytes.
;
PrintStrAX      sta     strptr+1
		stx	strptr
		tya
		pha
		ldy	#0
PrintStrAXL1    lda     (strptr),y
                beq     PrintStrAXX1      ; quit if NULL
    		jsr	output_char
		iny
                bne     PrintStrAXL1      ; quit if > 255
PrintStrAXX1    pla
		tay
		rts   

;---------------------------------------------------------------------
;
; Break Handler
;
BRKroutine     sta   ACC               ; save A    Monitor"s break handler
               stx   Xreg              ; save X
               sty   Yreg              ; save Y
               pla                     ; 
               sta   Preg              ; save P
               pla                     ; PCL
               tay
               pla                     ; PCH
               tax
               tya 
               sec                     ;
               sbc   #$02              ;
               sta   PCL               ; backup to BRK cmd
               bcs   Brk2              ;
               dex                     ;
Brk2           stx   PCH               ; save PC
               TSX                     ; get stack pointer
               stx   SPtr              ; save stack pointer
               jsr   PrintReg          ; dump register contents 
               ldx   #$FF              ; 
               txs                     ; clear stack
               cli                     ; enable interrupts again
               jmp   Monitor           ; start the monitor

;*************************************************************************
;     
;  Monitor Program 
;
;**************************************************************************

MonitorBoot    
                JSR   Version           ;
SYSjmp                                 ; Added for EhBASIC
                ; Primary monitor entry point
Monitor         
                LDX     #$FF              ; 
                TXS		        ;  Init the stack
monitor_loop
                jsr    print_cr
                lda     #'>'            ; Print prompt
                jsr     output_char
                ; Init monitor variables
                lda     #$00              ;
                sta     Hexdigits         ;  holds parsed hex
                sta     Hexdigits_H       ;
                jsr    input_char        ; Get user input; blocking
                jsr    output_char          ; Echo
                cmp     #':'            ; HEX upload?
                bne     nothex
                jmp     HexUpLd
nothex
                cmp     #'?'
                bne     nothelp
                jmp     go_help
nothelp
                and     #$5f            ; Convert to upper case
                cmp     #'G'            ; Go?
                bne     notgo
                jmp     go_exec         ; Jump to user program
notgo           cmp     #'E'
                bne     notmem
                jmp     go_mem
notmem
                cmp     #'D'
                bne     notdump
                jmp     go_dump
notdump
                jmp     monitor_loop    ; Reloop if invalid command

;---------------------------------------------------------------------
; Go and run a program...
go_exec
        jsr     print1sp        ; Space out
        jsr     get_word        ; Grab address
        cpy     #$00            ; Did we grab a whole word?
        bne     ge_end
        ; Print out the bytes
        lda	#>ge_string
	ldx	#<ge_string
	jsr     PrintStrAX
        lda     hexdigits_h
        ldx     hexdigits
        jsr     print2byte
        jsr     print_cr
        sei                     ; Disable interrupt
        ; Set the monitor return address on stack
        ; This is so that user program can do an rts to return to monitor
        ; Entry point to monitor is $ff00. Stack value is 1 less than actual 
        lda     #$fe               
        pha
        lda     #$ff
        pha        
        ; Indirect jump to user program
        cli                     ; Reenable interrupt  
        jmp     (Hexdigits)
     
ge_end
        jmp     monitor         ; return to Monitor, resetting stack pointer
        
ge_string       .byte   " PC=",0
        
;---------------------------------------------------------------------
; Get 8-bit byte
; Y is the nibble count
; Exit: Y=0 if we got all the nibbles
get_byte
        ldy     #$02
        jmp     get_byte_start
        
;---------------------------------------------------------------------
; Get 16-bit word
; Exit: Y=0 if we got all the nibbles
get_word
        ldy     #$04
get_byte_start                  ; Y contains nibble count
        lda     #$00              ; Init hex buffer
        sta     Hexdigits         ; Holds parsed hex
        sta     Hexdigits_H
gw_loop0
        jsr     get_hex_char
        bcs     gw_end          ; If non hex char, abort
        ; Build a byte with the first nibble already in A
        ; Entry: A = first hex nibble
        ;       Y = 2
build_byte
        LDX     #$04              ;  
gw_loop1                        ; Insert nibble
        ASL     Hexdigits         ;
        ROL     Hexdigits_H       ;
        DEX                     ;
        BNE     gw_loop1        ;
        ora     Hexdigits         ;
        sta     Hexdigits
        dey
        bne     gw_loop0        ; Loop until we get all in
gw_end
        rts

;---------------------------------------------------------------------
; Compare Result	N	Z	C
; A, X, or Y < Memory	*	0	0
; A, X, or Y = Memory	0	1	1
; A, X, or Y > Memory	*	0	1
;---------------------------------------------------------------------
; Get hex char
; C=0 if valid
; C=1 if invalid
get_hex_char
        jsr     input_char       ; Get character, blocking
        jsr     output_char          ; Echo character
        ; Character in A
        ; Check if it is a hex
check_hex_char 
        cmp     #'0'
        bcc     ghc_abort       ; A<'0'
        cmp     #('9'+1)
        bcs     ghc_notnumber   ; A>=('9'+1)
        ; Number
        sec
        sbc     #'0'
        jmp     ghc_done
ghc_notnumber
        and     #$5f            ; convert to upper
        cmp     #'A'
        bcc     ghc_abort       ; A<'A'
        cmp     #('F'+1)
        bcs     ghc_abort       ; A>=('F'+1)
        sec
        sbc     #('A'-10)
ghc_done
        clc
        rts
ghc_abort
        sec     ; Set carry
        rts
        
;---------------------------------------------------------------------       

helptxt
                .byte   $0d,$0a,"6502 Monitor RC2014 v0.1.1"
                .byte   CR,LF,"?              Print this help"
		.byte	CR,LF,"D XXXX         Dump memory from XXXX"
		.byte	CR,LF,"E XXXX         Edit memory from XXXX"    ;; CR to skip"
		.byte	CR,LF,"G XXXX         Go execute from XXXX"
		.byte	CR,LF,":sHLtD...C     Load Intel HEX file, ':' is part of file",0
helptxt2:
		.byte   CR,LF,"               ESC to quit when upload is done"
                .byte   $0d, $0a
                .byte   $00	

;---------------------------------------------------------------------    
                
go_help
        lda     #CR
        ldx   #$ff              ; set txt pointer
gh_loop
        inx                     ;
        JSR   Output_char            ; put character to Port
        lda   helptxt,x         ; get message text
        bne   gh_loop      ; 
        tax             ; Init x = 0
gh_loop2
        lda     helptxt2, x
        beq     gh_end
        jsr     output_char
        inx
        bne     gh_loop2
gh_end
        jmp     monitor_loop
        
;---------------------------------------------------------------------
; Display byte at an address
; Change byte at the address
; ENTER to go to next address
; ESC to escape back to monitor
; enter hex value to replace current value and skip to next address

go_mem
        lda     #$00
        sta     Startaddr
        sta     Startaddr_H
        jsr     print1sp        ; Space out
        ; Get address
        jsr     get_word
        cpy     #$00            ; Did we grab a whole word?
        bne     gm_end
        ; Copy the word to the address pointer
        lda     Hexdigits
        sta     Startaddr
        lda     Hexdigits_H
        sta     Startaddr_H
gm_loop0
        jsr     print_cr       ; Go to next line
gm_loop1
        ; Print address
        lda     Startaddr_H
        ldx     Startaddr
        jsr     print2byte
        jsr     print1sp        ; 1 Space
        ; Print byte at address
        ldy     #$00
        lda     (Startaddr), y  ; get byte at address
        jsr     Print1Byte      ; Print byte
        jsr     print1sp
        ; Grab command
        ; Next is either ESC (quit), ENTER (next) or HEX value
gm_loop
        ; Init hex buffer first
        lda     #$00
        sta     Hexdigits
        sta     Hexdigits_H
        ; Get command or hex
        jsr     input_char       ; Get a char
        cmp     #27             ; ESC
        beq      gm_end         ; ESC so abort
        cmp     #$0d            ; ENTER
        bne     gm_not_enter    ; Not ENTER, data entry mode?
        ;
        ; ENTER, increment Startaddr to next memory address
        ;
gm_next_address
        inc     Startaddr
        bne     gm_inc_done
        inc     Startaddr_H
gm_inc_done
        jmp     gm_loop0        ; Get next byte and display it        
        
        ; Check if hex
        ; A=first character
gm_not_enter
        tay                     ; Save char
        ; Char in A
        jsr     check_hex_char
        bcs     gm_loop0        ; Not hex, reprint line
        pha                     ; Save hex value
        tya                     ; Get original char
        jsr     output_char          ; Echo it
        pla                     ; Restore hex value
        ldy     #$02
        jsr     build_byte      ; Get the full byte
        cpy     #$00            ; Are we done?
        bne     gm_loop0
        sta     (Startaddr), y  ; Store byte at address
        jsr     print1sp        ; Print space
        ldy     #$00
        lda     (Startaddr), y  ; get byte at address
        jsr     Print1Byte      ; Print byte at address
        jmp     gm_next_address ; Next
        
gm_end
        jmp     monitor_loop


;---------------------------------------------------------------------

go_dump
dump_mem
        lda     #$00
        sta     Startaddr
        sta     Startaddr_H
        jsr     print1sp        ; Space out
        ; Get address
        jsr     get_word
        cpy     #$00            ; Did we grab a whole word?
        bne     dm_end
        ; Copy the word to the address pointer
        lda     Hexdigits
        sta     Startaddr
        lda     Hexdigits_H
        sta     Startaddr_H
dm_loopx
        lda     #16
        sta     rowcount
dm_loop0
        jsr     print_cr       ; Go to next line
dm_loop1
        ; Print address
        lda     Startaddr_H
        ldx     Startaddr
        jsr     print2byte
        jsr     print1sp        ; 1 Space
        ; Read 16 bytes
        ldy     #$00
        ldx     #$10
dm_loop2
        lda     (Startaddr), y
        jsr     print1byte
        jsr     print1sp
        iny
        dex
        bne     dm_loop2
        ; Next section
        lda     #':'
        jsr    output_char
        jsr     print1sp
        ldy     #$00
        ldx     #$10
dm_loop3
        lda     (Startaddr), y  ; Get byte
        cmp     #32             ; Control character?
        bcc     not_printable    ; not printable
        cmp     #127            ; non-ascii characters?
        bcs     not_printable
dm_xx
        jsr     output_char     ; Print character
        jmp     dm_next0
not_printable
        lda     #'.'            ; Print . instead
        jmp     dm_xx
dm_next0                        ; Incrememt address pointer
        inc     startaddr
        bne     dm_next1
        inc     startaddr_h
dm_next1                        ; Have we done 16 bytes?
        dex
        bne     dm_loop3        ; Reloop if not
        jsr     print_cr        ; Go to next row
        dec     rowcount        ; Have we done 16 rows?
        bne     dm_loop1        ; Next row if not
        lda	#>dm_prompt     ; Print prompt
	ldx	#<dm_prompt
	jsr     $ff0c
	jsr     input_char      ; Get user input
	cmp     #27             ; Escape?
	bne     dm_loopx        ; Next 16 lines
dm_end       
        jmp     monitor_loop  

dm_prompt       .byte	"Press any key to continue, ESC to abort",0

;---------------------------------------------------------------------
; Print version
Version         jsr     Print_CR          ; 
                lda	#>buildtxt
		ldx	#<buildtxt
                jsr     PrintStrAX
                rts                     ;

;---------------------------------------------------------------------
; 

;
;-----------DATA TABLES ------------------------------------------------
;
Hexdigdata     .byte "0123456789ABCDEF";hex char table 

;---------------------------------------------------------------------
;
buildtxt         
                .byte   $0d, $0a
                .byte   "6502 Board for RC2014"
                .byte   $0d, $0a
                .byte   $00
	


;end of file
