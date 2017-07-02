;---------------------------------------------------------------------
; Modified for RC2014
; Changes are copyright Ben Chong and freely licensed to the community
;---------------------------------------------------------------------
; upload.asm   
; By Daryl Rictor & Ross Archer  Aug 2002
;

temp      	=   	$ea     	; save hex value
chksum    	=   	$eb        	; record checksum accumulator
reclen    	=   	$ec        	; record length in bytes
start_lo  	=   	$ed
start_hi  	=   	$ee
rectype   	=   	$ef

bytecount_l     =       $f0
bytecount_h     =       $f1

dlfail    	=   	$03ec    	; flag for upload failure  

;
;
;****************************************************
;
; Intel-hex 6502 upload program
; Ross Archer, 25 July 2002
;
; Changes:
; 1. Make everything breakable/escapable with an ESC
; 2. Consolidate error handling
;
HexUpLd
		lda    	#0
        	sta	dlfail          ;Start by assuming no D/L failure
        	sta     bytecount_l
        	sta     bytecount_h
                lda	#>MsgStart
		ldx	#<MsgStart
                jsr     PrintStrAX
;	  	beq	IHex	        ; Equivalent to a BRA
                ; Record processing loop
HdwRecs         
        ; 	jsr     GetSer          ; Wait for start of record mark ':'
                jsr     input_char
                cmp     #ESC            ; If we pressed ESC
                bne     hul0            ; Not ESC
hul1                                    ; Branch here because HdEr3 is too faraway
                jmp     hul_done        ; Handle ESC
hul0
        	cmp     #':'
        	bne     HdwRecs         ; not found yet
        	; Start of record marker has been found
IHex    	jsr     GetHex          ; Get the record length
                bcs     hul1            ; ESC = quit
        	sta     reclen          ; save it
       	 	sta     chksum          ; and save first byte of checksum
        	jsr     GetHex          ; Get the high part of start address
                bcs     hul1            ; ESC = quit
        	sta     start_hi
        	clc
        	adc     chksum          ; Add in the checksum       
        	sta     chksum          ; 
        	jsr     GetHex          ; Get the low part of the start address
        	bcs     hul1            ; ESC = quit
        	sta     start_lo
        	clc
        	adc     chksum
        	sta     chksum  
        	jsr     GetHex          ; Get the record type
                bcs     hul_done        ; ESC = quit
        	sta     rectype         ; & save it
        	clc
        	adc     chksum
        	sta     chksum   
        	lda     rectype
        	bne     HdEr1           ; Not data record; check for end-of-record
        	ldx     reclen          ; number of data bytes to write to memory
        	ldy     #0              ; start offset at 0

                ; Data handler loop
HdLp1   	jsr     GetHex          ; Get the first/next/last data byte
                bcs     hul_done        ; ESC = quit
        	sta     (start_lo),y    ; Save it to RAM
        	inc     bytecount_l     ; increment byte count
        	bne     bc_1
        	inc     bytecount_h
bc_1
        	clc
        	adc     chksum
        	sta     chksum          ; 
        	iny                     ; update data pointer
        	dex                     ; decrement count
        	bne     HdLp1
        	jsr     GetHex          ; get the checksum
                bcs     hul_done        ; ESC = quit
        	clc
        	adc     chksum
        	bne     HdDlF1          ; If failed, report it
        	; Another successful record has been processed
        	lda     #'.'            ; Character indicating record OK = '.'
        	sta	uart_xmit        ; write it out but don't wait for output 
;                jsr     output_char
        	jmp     HdwRecs         ; get next record    
        	; Bad checksum 
HdDlF1  	lda     #'F'            ; Character indicating record failure = 'F'
        	sta     dlfail          ; upload failed if non-zero
        	sta	uart_xmit        ; write it to transmit buffer register
        	jmp     HdwRecs         ; wait for next record start

                ; Not a data record
HdEr1   	cmp     #1              ; Check for end-of-record type
        	beq     hul_endrec
        	lda     #'X'            ; Character indicating bad record type
        	sta     dlfail          ; non-zero --> upload has failed
        	sta     uart_xmit
;		lda	#>MsgUnknownRecType
;		ldx	#<MsgUnknownRecType
;                jsr     PrintStrAX      ; Warn user of unknown record type
;		lda     rectype         ; Get it
;        	sta     dlfail          ; non-zero --> upload has failed
;        	jsr     Print1Byte      ; print it
;		lda     #CR		; but we'll let it finish so as not to 
;        	jsr     output_char		; falsely start a new d/l from existing 
;        	lda     #LF		; file that may still be coming in for 
;        	jsr     output_char          ; quite some time yet.
;		jmp	HdwRecs
                jmp     hul_done        ; Done

		; We've reached the end-of-record record
hul_endrec
           	jsr     GetHex          ; get the checksum
                bcs     hul_done        ; ESC = quit 
        	clc
        	adc     chksum          ; Add previous checksum accumulator value
        	beq     HdEr3           ; checksum = 0 means we're OK!
;		lda	#>MsgBadRecChksum
;		ldx	#<MsgBadRecChksum
;               jsr     PrintStrAX
                lda     #'F'            ; Character indicating record failure = 'F'
        	sta     dlfail          ; upload failed if non-zero
        	sta	uart_xmit        ; write it to transmit buffer register
;                jmp     HdErNX
                ; Pass through to central error/completion handling
                ; -------------------
                ; We're done here
hul_done
HdEr3   	lda     dlfail
        	beq     HdErOK          ; No errors
        	;A upload failure has occurred
		lda	#>MsgUploadFail
		ldx	#<MsgUploadFail
                jsr     PrintStrAX
                jmp     HdErNX          ; Quit
                ; No errors     
HdErOK  	lda	#>MsgUploadOK
		ldx	#<MsgUploadOK
                jsr     PrintStrAX
                ; # of bytes
                lda     bytecount_h
                ldx     bytecount_l
                jsr     print2byte
		; Eat final characters so monitor doesn't cope with it
;	  	jsr     Flush		; flush the input buffer
HdErNX          
                jmp     monitor
                
;---------------------------------------------------------------------
;  subroutines
;
                     
;GetSer  	jsr	input_char	; get input from Serial Port	    
;                cmp     #ESC            ; check for abort 
;        	bne     GSerXit         ; return character if not
; 
;                ; Escape
;                jmp     HdEr3

;---------------------------------------------------------------------
; Exit: CY=1 if ESC
;
GetHex  	lda     #$00
	  	sta     temp
        	jsr     GetNibl
        	bcs     gh_quit
        	asl     a
        	asl     a
        	asl     a
       	 	asl     a       	; This is the upper nibble
        	sta     temp
;---------------------------------------------------------------------
GetNibl
; 	        jsr     GetSer
                jsr     input_char
                cmp     #ESC
                beq     gh_quit
					; Convert the ASCII nibble to numeric value from 0-F:
	        cmp     #'9'+1  	; See if it's 0-9 or 'A'..'F' (no lowercase yet)
       	 	bcc     MkNnh   	; If we borrowed, we lost the carry so 0..9
        	sbc     #7+1    	; Subtract off extra 7 (sbc subtracts off one less)
        	; If we fall through, carry is set unlike direct entry at MkNnh
MkNnh   	sbc     #'0'-1  	; subtract off '0' (if carry clear coming in)
        	and     #$0F    	; no upper nibble no matter what
        	ora     temp
        	clc
;GSerXit
        	rts             	; return with the nibble received
gh_quit
                sec
                rts



; Checksum messages
;					
;MsgUnknownRecType  
;		.byte   CR,LF
;      		.byte   "Unknown record type $"
;		.byte	0		; null-terminate every string
;MsgBadRecChksum .byte   CR,LF
;                .byte   "Bad record checksum!"
;        	.byte   0		; Null-terminate  
MsgUploadFail   .byte   CR,LF
                .byte   "Upload Failed",CR,LF
;                .byte   "Aborting!"
                .byte   0               ; null-terminate every string or crash'n'burn
MsgUploadOK	.byte   CR,LF
                .byte   "Upload byte count: "
        	.byte   0   
        	
MsgStart        .byte   CR, LF
                .byte   "Upload now (ESC to quit):"
                .byte   0
      	
;  Fin.
;
