;---------------------------------------------------------------------
; Modified for RC2014
; Changes are copyright Ben Chong and freely licensed to the community
;---------------------------------------------------------------------
; upload.asm   
; By Daryl Rictor & Ross Archer  Aug 2002
;
; 21st century code for 20th century CPUs (tm?)
; 
; A simple file transfer program to allow upload from a serial
; port to the SBC.  It integrates both x-modem/CRC transfer protocol 
; and Intel Hex formatted files. Primary is XMODEM-CRC, due to its
; superior reliability.  Fallback to Intel Hex is automagical following
; receipt of the first Hexfile d/l character, so the selection is 
; transparent to the user.
;
; Files uploaded via XMODEM-CRC must be
; in .o64 format -- the first two bytes are the load address in
; little-endian format:  
;  FIRST BLOCK
;     offset(0) = lo(load start address),
;     offset(1) = hi(load start address)
;     offset(2) = data byte (0)
;     offset(n) = data byte (n-2)
;
; Subsequent blocks
;     offset(n) = data byte (n)
;
; The TASS assembler and most Commodore 64-based tools generate this
; data format automatically and you can transfer their .obj/.o64 output
; file directly.  
;   
; The only time you need to do anything special is if you have 
; a raw memory image file (say you want to load a data
; table into memory). For XMODEM you'll have to 
; "insert" the start address bytes to the front of the file.
; Otherwise, XMODEM would have no idea where to start putting
; the data.
;
; The "fallback" format is Intel Hex.  As address information is included
; at the start of each line of an Intel Hex file, there is no need for a special
; "first block". As soon as the receiver sees an Intel Hex
; character ':' coming in, it aborts the XMODEM-CRC upload attempt and
; tries to accept Intel Hex instead.  This is the format used natively
; by a lot of generic tools such as TASM.
; Note there is no "fallback fallback."  Once it quits CRC and 
; thinks you're sending it Intel Hex, you either have to finish the download 
; or press CTRL-C to abort.
;
; By having support for both formats under the same "U"pload command,
; it enables seamless switching between either kind of toolchain with
; no special user intervention.  This seemed like a Good Thing (tm).
;
; Note: testing shows that no end-of-line delay is required for Intel Hex
; uploads, but in case your circumstances differ and you encounter
; error indications from a download (especially if you decided to run the
; controller under 1 Mhz), adding a 10-50 mS delay after each line is 
; harmless and will ensure no problems even at low clock speeds
;
;
; Style conventions being tried on this file for possible future adoption:
; 1. Constants known at assembly time are ALL CAPS
; 2. Variables are all lower-case, with underscores used as the word separator
; 3. Labels are PascalStyleLikeThis to distinguish from constants and variables
; 4. Old labels from external modules are left alone.  We may want
;    to adopt these conventions and retrofit old source later.
; 5. Op-codes are lower-case
; 6. Comments are free-style but ought to line up with similar adjacent comments

; zero page variables (Its ok to stomp on the monitor's zp vars)
;
;
;crc		=	$38		; CRC lo byte
;crch		=	$39		; CRC hi byte
;ptr		=	$3a		; data pointer
;ptrh		=	$3b		;   "    "
;blkno		=	$3c		; block number
;retry		=	$3d		; retry counter
;retry2	=	$3e		; 2nd counter
;bflag		=	$3f		; block flag 

bytecount_l     =       $36
bytecount_h     =       $37
chksum    	=   	$38        	; record checksum accumulator
reclen    	=   	$39        	; record length in bytes
start_lo  	=   	$3b
start_hi  	=   	$3c
rectype   	=   	$3d
dlfail    	=   	$3e     	; flag for upload failure
temp      	=   	$3f     	; save hex value

;
;  tables and constants
;
;crclo    	=	$7a00      	; Two 256-byte tables for quick lookup
;crchi    	= 	$7b00      	; (should be page-aligned for speed)
;Rbuff		=	$0300      	; temp 128 byte receive buffer 
					; (uses the Monitor's input buffer)
SOH		=	$01		; start block
EOT		=	$04		; end of text marker
ACK		=	$06		; good block acknowleged
NAK		=	$15		; bad block acknowleged
CAN		=	$18		; cancel (not standard, not supported)
CR		=	13
LF		=	10
ESC         =     27          ; ESC to exit


;
;
;****************************************************
;
; Intel-hex 6502 upload program
; Ross Archer, 25 July 2002
;
; 
HexUpLd
		lda    	#0
        	sta	dlfail          ;Start by assuming no D/L failure
        	sta     bytecount_l
        	sta     bytecount_h
	  	beq	IHex	        ; Equivalent to a BRA
                ; Record processing loop
HdwRecs 	jsr     GetSer          ; Wait for start of record mark ':'
        	cmp     #':'
        	bne     HdwRecs         ; not found yet
        	; Start of record marker has been found
IHex    	jsr     GetHex          ; Get the record length
        	sta     reclen          ; save it
       	 	sta     chksum          ; and save first byte of checksum
        	jsr     GetHex          ; Get the high part of start address
        	sta     start_hi
        	clc
        	adc     chksum          ; Add in the checksum       
        	sta     chksum          ; 
        	jsr     GetHex          ; Get the low part of the start address
        	sta     start_lo
        	clc
        	adc     chksum
        	sta     chksum  
        	jsr     GetHex          ; Get the record type
        	sta     rectype         ; & save it
        	clc
        	adc     chksum
        	sta     chksum   
        	lda     rectype
        	bne     HdEr1           ; end-of-record
        	ldx     reclen          ; number of data bytes to write to memory
        	ldy     #0              ; start offset at 0
                ; Data handler loop
HdLp1   	jsr     GetHex          ; Get the first/next/last data byte
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
        	clc
        	adc     chksum
        	bne     HdDlF1          ; If failed, report it
        	; Another successful record has been processed
        	lda     #'#'            ; Character indicating record OK = '#'
        	sta	uart_xmit        ; write it out but don't wait for output 
        	jmp     HdwRecs         ; get next record    
        	; Bad checksum 
HdDlF1  	lda     #'F'            ; Character indicating record failure = 'F'
        	sta     dlfail          ; upload failed if non-zero
        	sta	uart_xmit        ; write it to transmit buffer register
        	jmp     HdwRecs         ; wait for next record start

                ; Not a data record
HdEr1   	cmp     #1              ; Check for end-of-record type
        	beq     HdEr2
		lda	#>MsgUnknownRecType
		ldx	#<MsgUnknownRecType
                jsr     PrintStrAX      ; Warn user of unknown record type
		lda     rectype         ; Get it
        	sta     dlfail          ; non-zero --> upload has failed
        	jsr     Print1Byte      ; print it
		lda     #CR		; but we'll let it finish so as not to 
        	jsr     output_char		; falsely start a new d/l from existing 
        	lda     #LF		; file that may still be coming in for 
        	jsr     output_char          ; quite some time yet.
		jmp	HdwRecs

		; We've reached the end-of-record record
HdEr2   	jsr     GetHex          ; get the checksum 
        	clc
        	adc     chksum          ; Add previous checksum accumulator value
        	beq     HdEr3           ; checksum = 0 means we're OK!
		lda	#>MsgBadRecChksum
		ldx	#<MsgBadRecChksum
                jsr     PrintStrAX
                jmp     HdErNX
                ; Completion
HdEr3   	lda     dlfail
        	beq     HdErOK
        	;A upload failure has occurred
		lda	#>MsgUploadFail
		ldx	#<MsgUploadFail
                jsr     PrintStrAX
                jmp     HdErNX
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
;
;  subroutines
;
                     
GetSer  	jsr	input_char	; get input from Serial Port	    
                cmp     #ESC            ; check for abort 
        	bne     GSerXit         ; return character if not
 
                ; Escape
                jmp     HdEr3

GetHex  	lda     #$00
	  	sta     temp
        	jsr     GetNibl
        	asl     a
        	asl     a
        	asl     a
       	 	asl     a       	; This is the upper nibble
        	sta     temp
GetNibl 	jsr     GetSer
					; Convert the ASCII nibble to numeric value from 0-F:
	        cmp     #'9'+1  	; See if it's 0-9 or 'A'..'F' (no lowercase yet)
       	 	bcc     MkNnh   	; If we borrowed, we lost the carry so 0..9
        	sbc     #7+1    	; Subtract off extra 7 (sbc subtracts off one less)
        	; If we fall through, carry is set unlike direct entry at MkNnh
MkNnh   	sbc     #'0'-1  	; subtract off '0' (if carry clear coming in)
        	and     #$0F    	; no upper nibble no matter what
        	ora     temp
GSerXit
        	rts             	; return with the nibble received



; Checksum messages
;					
MsgUnknownRecType  
		.byte   CR,LF
      		.byte   "Unknown record type $"
		.byte	0		; null-terminate every string
MsgBadRecChksum .byte   CR,LF
                .byte   "Bad record checksum!"
        	.byte   0		; Null-terminate  
MsgUploadFail   .byte   CR,LF
                .byte   "Upload Failed",CR,LF
;                .byte   "Aborting!"
                .byte   0               ; null-terminate every string or crash'n'burn
MsgUploadOK	.byte   CR,LF
                .byte   "Upload byte count: "
        	.byte   0   
      	
;  Fin.
;
