;---------------------------------------------------------------------
; Modified for RC2014
; Changes are copyright Ben Chong and freely licensed to the community
;
;****************************************************************************
; Reset, Interrupt, & Break Handlers
;****************************************************************************
        ; Put this in the last page of ROM
        .org    $ff00

; Vector table
        
        ; Monitor vector $ff00
                jmp     Monitor

        .org $ff03
input_char      jmp     (uart_input_vecl)       ; wait for input character
        ; $ff06
check_input     jmp     (uart_scan_vecl)        ; scan for input (no wait), C=1 char, C=0 no character
        ; $ff09
output_char     jmp     (uart_output_vecl)      ; send 1 character
        ; $ff0c
printstring     jmp     PrintStrAX

;--------------Reset handler----------------------------------------------

reset          sei                     ; diable interupts
               cld                     ; clear decimal mode                      
               ldx      #$FF              ;
               txs                     ; init stack pointer

                ; Initialize interrupt vectors
                ; Use null_irq and similar NMI handlers first
                lda     #>null_irq
                ldx     #<null_irq
                stx      irq_vector
                sta      irq_vector+1
                lda     #>nmi_handler
                ldx     #<nmi_handler
                stx      nmi_vector
                sta      nmi_vector+1
                ; Init the I/O devices
                ; At this point, the actual IRQ handling may be set up
                jsr     uart_init	       
                
                ; Set up default handlers
                lda     #>uart_input
                ldx     #<uart_input
                stx      uart_input_vecl
                sta      uart_input_vech
                lda     #>uart_scan
                ldx     #<uart_scan
                stx      uart_scan_vecl
                sta      uart_scan_vech
                lda     #>uart_output
                ldx     #<uart_output
                stx      uart_output_vecl
                sta      uart_output_vech

               cli                      ; Enable interrupt
               jmp      MonitorBoot     ; Monitor for cold reset                       

; -------------------------------------
; Interrupt or BRK entry point
irqbrkhandler
                PHA                     ; Save A
                TXA  	                ; 
                PHA                     ; Save X
                TSX                     ; get stack pointer
                LDA     $0103,X           ; load INT-P Reg off stack
                AND     #$10              ; mask BRK
                BNE     BrkCmd            ; BRK CMD
                ; Not BRK, so it must be a real interrupt
                ; The Interrupt handler needs to know that 
                ; A and X are already on the stack
irqjump         jmp     (irq_vector)    ; Jump to indirect handler 

                ; Default IRQ handler, before we return, restore X and A               
null_irq
                pla                     ; Restore X
                tax                     ; 		
                pla                     ; Restore A
                ; Then return from interrupt
nmi_handler
                rti                     ; Null Interrupt return

; -------------------------------------
; NMI entry point
nmijump         jmp     (nmi_vector)

; -------------------------------------
; BRK handler
; We'll leave X and A on the stack and have the break handler deal with them
BrkCmd
;                pla                     ; X
;                tax                     ;
;                pla                     ; A
                jmp   BRKroutine        ; patch in user BRK routine

;
;  NMIjmp      =     $FFFA             
;  RESjmp      =     $FFFC             
;  INTjmp      =     $FFFE             

        .org    $fffa
               .word  nmijump
               .word  reset 
               .word  irqbrkhandler
;end of file
