; 6502 BIOS 
; Based on original code by Daryl Rictor
; Adapted to 6551 ACIA board for RC2014
; This implementation uses IRQ
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
                lda     #>uart_irq
                ldx     #<uart_irq
                stx     irq_vector
                sta     irq_vector+1
                jsr     init_buffer     ; Initialize IRQ buffer
                
                ; Software reset
                lda     #$00
                sta     uart_status_reg
                
                ; 0000 1001     -> recv irq
                lda     #$09
                sta     uart_command_reg
                
		; 0001 1110
                lda     #$1e    ; 9600 baud, /16, 8+1
                sta     uart_control_reg
                
                rts                     ; done
                
;---------------------------------------------------------------------
; Input char from UART (blocking)
; Exit: character in A
ACIA1_Input
uart_input
                jsr     check_buffer
                beq     uart_input
                jsr     pull_buffer
                rts                      ;

;---------------------------------------------------------------------
; Non-waiting get character routine 
; Scan for input (no wait), C=1 char, C=0 no character
ACIA1_Scan
uart_scan
                clc
                jsr     check_buffer
                beq     uart_scan2
                jsr     pull_buffer     ; Exit with C=1
uart_scan2
                rts

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
                
;------------------------------------------------------------------------------
; This is the UART-specific call to bring RTS high to disable transmit from terminal
; We can use A
uart_deassert_rts
;                lda     uart_command_reg
;                and     #$f3            ; bits 3-2 = 0
;                sta     uart_command_reg
                rts

;------------------------------------------------------------------------------
; This is the UART-specific call to bring RTS low to re-enable transmit

uart_assert_rts
;                lda     uart_command_reg
;                ora     #$08            ; bit 3 = 1
;                sta     uart_command_reg
                rts

;---------------------------------------------------------------------
uart_irq
                ; Check if our interrupt
                lda     uart_status_reg      ; Serial port status
                tax             
                and     #$88           ; is irq
                beq     ui_end         ; no char to get
                and     #$08
                bne     ui_isours
                brk                     ; Breakpoint if not our interrupt
ui_isours
                ; It's our interrupt
                lda     uart_data_reg           ; get chr
                jsr     put_buffer
                
ui_end
                jmp     null_irq
                
        .include        buffer.asm
;
;end of file
