; 6502 BIOS 
; Based on original code by Daryl Rictor
; Adapted to 6850 ACIA board for RC2014
; NOTE: The 6850 ACIA works with the 6502 card for simple Monitor functions
; However, loading an Intel HEX file appears to overwhelm the ACIA.
;
;
; ----------------- assembly instructions ---------------------------- 
;
; this is a subroutine library only
; it must be included in an executable source file
;
;
;*** I/O Locations *******************************
; Define the i/o address of the UART chip
;*** 6850 ACIA ************************

uart_base       = $c080
uart_reg0       = $c080
uart_reg1       = $c081
uart_xmit       = uart_reg1     ; Used by upload.asm

;
;***********************************************************************
; UART I/O Support Routines
; We'll use Daryl's routine names for compatibility with his software/code
; Otherwise, we'll use UART-agnostic nomemclature

;---------------------------------------------------------------------
;
 
ACIA1_init
uart_init
                lda     #$03    ; master reset
                sta     uart_reg0
		; 0001 0110
;                lda     #$16    ; 28.8k baud, /64, 8+1, rts=0, no interrupts
		; 0001 0101
                lda     #$15    ; 115200 baud, /16, 8+1, rts=0, no interrupts

                sta     uart_reg0
                rts                     ; done
                
;---------------------------------------------------------------------
; Input char from UART (blocking)
; Exit: character in A
ACIA1_Input
uart_input
               lda      uart_reg0           ; Serial port status             
               and      #$01               ; is recvr full
               beq      uart_input        ; no char to get
               lda      uart_reg1           ; get chr
               rts                      ;

;---------------------------------------------------------------------
; Non-waiting get character routine 
; Scan for input (no wait), C=1 char, C=0 no character
ACIA1_Scan
uart_scan
                clc
                lda   uart_reg0        ; Serial port status
                and   #$01               ; mask rcvr full bit
                beq   uart_scan2
                lda   uart_reg1           ; get chr
                sec
uart_scan2     rts

;---------------------------------------------------------------------
; output to OutPut Port
; Entry: character in A
; Exit: character in A
ACIA1_Output
uart_output   
                pha                      ; save registers
uart_out1     
                lda   uart_reg0           ; serial port status
                and   #$02               ; is tx buffer empty
                beq   uart_out1         ; no
                pla                      ; get chr
                sta   uart_reg1           ; put character to Port
                rts                      ; done
;
;end of file
