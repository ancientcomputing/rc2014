; 6502 BIOS 
; Based on original code by Daryl Rictor
; Adapted to Real Retro UART board for RC2014
; Renamed to rruart.asm
;
; ----------------- assembly instructions ---------------------------- 
;
; this is a subroutine library only
; it must be included in an executable source file
;
;
;*** I/O Locations *******************************
; Define the i/o address of the UART chip
;*** Real Retro UART ************************

uart_base       = $c040
uart_xmit       = $c040
uart_recv       = $c040
uart_status     = $c041

;
;***********************************************************************
; UART I/O Support Routines
; We'll use Daryl's routine names for compatibility with his software/code
; Otherwise, we'll use UART-agnostic nomemclature

;---------------------------------------------------------------------
;
ACIA1_init
uart_init    
                ; Nothing to init
                ldx     #4
                lda     #$0a
ui_loop
                jsr     uart_output
                dex
                bne     ui_loop
                lda     #$0d
                jsr     uart_output
                rts                      ; done
                
;---------------------------------------------------------------------
; Input char from UART (blocking)
; Exit: character in A
ACIA1_Input
uart_input
               lda   uart_status           ; Serial port status             
               and   #$01               ; is recvr full
               beq   uart_input        ; no char to get
               lda   uart_recv           ; get chr
               rts                      ;

;---------------------------------------------------------------------
; Non-waiting get character routine 
; Scan for input (no wait), C=1 char, C=0 no character
ACIA1_Scan
uart_scan
                clc
                lda   uart_status        ; Serial port status
                and   #$01               ; mask rcvr full bit
                beq   uart_scan2
                lda   uart_recv           ; get chr
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
                lda   uart_status           ; serial port status
                and   #$02               ; is tx buffer empty
                beq   uart_out1         ; no
                pla                      ; get chr
                sta   uart_xmit           ; put character to Port
                rts                      ; done
;
;end of file
