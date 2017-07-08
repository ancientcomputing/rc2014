; 6502 BIOS 
; Based on original code by Daryl Rictor
; Adapted to 6551 ACIA board for RC2014
; NOTE: The 6551 ACIA works with the 6502 card for simple Monitor functions
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
;*** 6551 ACIA ************************

uart_base               = $c0a0
uart_data_reg           = $c0a0
uart_status_reg         = $c0a1
uart_command_reg        = $c0a2
uart_control_reg        = $c0a3
uart_xmit               = uart_data_reg     ; Used by upload.asm

;
;***********************************************************************
; UART I/O Support Routines
; We'll use Daryl's routine names for compatibility with his software/code
; Otherwise, we'll use UART-agnostic nomemclature

;---------------------------------------------------------------------

ACIA1_init
uart_init
                ; Software reset
                lda     #$00
                sta     uart_status_reg
                
                ; 0000 1011     -> no recv irq
                lda     #$0b
                sta     uart_command_reg
                
		; 0001 0000
                lda     #$10    ; 115200 baud, /16, 8+1
                sta     uart_control_reg

                rts                     ; done
                
;---------------------------------------------------------------------
; Input char from UART (blocking)
; Exit: character in A
ACIA1_Input
uart_input
               lda      uart_status_reg           ; Serial port status             
               and      #$08               ; is recvr full
               beq      uart_input        ; no char to get
               lda      uart_data_reg           ; get chr
               rts                      ;

;---------------------------------------------------------------------
; Non-waiting get character routine 
; Scan for input (no wait), C=1 char, C=0 no character
ACIA1_Scan
uart_scan
                clc
                lda   uart_status_reg        ; Serial port status
                and   #$08               ; mask rcvr full bit
                beq   uart_scan2
                lda   uart_data_reg           ; get char
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
                lda   uart_status_reg           ; serial port status
                and   #$10              ; is tx buffer empty
                beq   uart_out1         ; no
                pla                     ; get char
                sta   uart_data_reg     ; Write character to Port
                rts                     ; done
;
;end of file
