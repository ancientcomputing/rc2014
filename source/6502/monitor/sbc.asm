;---------------------------------------------------------------------
; Modified for RC2014
; Changes are copyright Ben Chong and freely licensed to the community
; ----------------- assembly instructions ---------------------------- 
; This version is assembled using asmx in the following way:
;       asmx -l -b 8000h-ffffh -e -C 6502 sbc.asm
;

;
; Assembly the sections of the Monitor
;
	.org $e000
	
	; The following files should NOT define absolute addresses
	
        ; Intel HEX file handler
 	.include upload.asm

        ; Change this line according to the type of UART board 
      	.include rruart.asm	   ; uart init

 	.include sbcmon.asm         ; actual monitor

        ; -----------------------------
        ; Only this file defines absolute addresses
	.include reset.asm         ; Reset & IRQ handler

	.end
