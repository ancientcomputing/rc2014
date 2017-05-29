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

uart_base       = $c0c0
uart_reg0       = $c0c0
uart_reg1       = $c0c1
uart_reg2       = $c0c2
uart_reg3       = $c0c3
uart_reg4       = $c0c4
uart_reg5       = $c0c5
uart_reg6       = $c0c6
uart_reg7       = $c0c7
uart_xmit       = uart_reg0
;uart_recv       = $c040
;uart_status     = $c041

;
;***********************************************************************
; UART I/O Support Routines


;---------------------------------------------------------------------
;
 

uart_init
                lda     #$80                  ; Line control register, Set DLAB=1
                sta     uart_reg3
                lda     #$01                    ; 115200 with 1.8432MHz;  OSC / (16 * Baudrate)
                sta     uart_reg0    ; Divisor latch
                lda     #$00
                sta     uart_reg1           ; Divisor latch
                LDA     #$03                  ; Line control register, 8N1, DLAB=0
                sta     uart_reg3
                LDA     #$02                  ; Modem control register
                sta     uart_reg4    ; Enable RTS
                LDA     #$87                  ; FIFO enable, reset RCVR/XMIT FIFO
                sta     uart_reg2
                lda     #$01                  ; Enable receiver interrupt
                sta     uart_reg1
                jsr     AFE_16C550
                ; Nothing to init
        IF 0
                ldx     #4
                lda     #$0a
ui_loop
                jsr     uart_output
                dex
                bne     ui_loop
                lda     #$0d
                jsr     uart_output
                ldx     #'1'
eeee
                txa
                jsr     uart_output
                inx    
                jmp     eeee
        ENDIF
                rts                      ; done
                
;---------------------------------------------------------------------
; Input char from UART (blocking)
; Exit: character in A
uart_input
               lda      uart_reg5           ; Serial port status             
               and      #$01               ; is recvr full
               beq      uart_input        ; no char to get
               lda      uart_reg0           ; get chr
               rts                      ;

;---------------------------------------------------------------------
; Non-waiting get character routine 
; Scan for input (no wait), C=1 char, C=0 no character
uart_scan
                clc
                lda   uart_reg5        ; Serial port status
                and   #$01               ; mask rcvr full bit
                beq   uart_scan2
                lda   uart_reg0           ; get chr
                sec
uart_scan2     rts

;---------------------------------------------------------------------
; output to OutPut Port
; Entry: character in A
; Exit: character in A
uart_output   
                pha                      ; save registers
uart_out1     
                lda   uart_reg5           ; serial port status
                and   #$20               ; is tx buffer empty
                beq   uart_out1         ; no
                pla                      ; get chr
                sta   uart_reg0           ; put character to Port
                rts                      ; done

;---------------------------------------------------------------------

AFE_16C550
                LDA     #$87                  ; Trigger level, FIFO enable, reset FIFO
                sta     uart_reg2
                ; Use this to enable autoflow control
                LDA     #$22                  ; Modem control register
                sta     uart_reg4    ; Enable AFE
                rts

;
;end of file
