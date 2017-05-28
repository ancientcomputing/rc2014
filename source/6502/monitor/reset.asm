;---------------------------------------------------------------------
; Modified for RC2014
; Changes are copyright Ben Chong and freely licensed to the community
;
; ----------------- assembly instructions ---------------------------- 
;
;****************************************************************************
; Reset, Interrupt, & Break Handlers
;****************************************************************************
        ; put this in last page of ROM
        .org    $ff00

; Vector table
        
        ; Monitor vector
                jmp Monitor

        .org    $ff03
input_char      jmp   uart_input       ; wait for input character
        ; $ff06
check_input     jmp   uart_scan        ; scan for input (no wait), C=1 char, C=0 no character
        ; $ff09
output_char     jmp   uart_Output      ; send 1 character
        ; $ff0c
printstring     jmp     PrintStrAX

;--------------Reset handler----------------------------------------------

reset          SEI                     ; diable interupts
               CLD                     ; clear decimal mode                      
               LDX   #$FF              ;
               TXS                     ; init stack pointer

                ; Initialize interrupt vectors
                lda     #>irq_handler
                ldx     #<irq_handler
                stx      irq_vector
                sta      irq_vector+1
                lda     #>nmi_handler
                ldx     #<nmi_handler
                stx      nmi_vector
                sta      nmi_vector+1
                jsr   uart_init	       ; init the I/O devices

               CLI                     ; Enable interrupt system
               JMP  MonitorBoot        ; Monitor for cold reset                       


irqjump         jmp     (irq_vector)
irq_handler     PHA                     ; a
                TXA  	               ; 
                PHA                     ; X
                TSX                     ; get stack pointer
                LDA   $0103,X           ; load INT-P Reg off stack
                AND   #$10              ; mask BRK
                BNE   BrkCmd            ; BRK CMD
                PLA                     ; x
                tax                     ; 		
                pla                     ; a
nmi_handler
                RTI                     ; Null Interrupt return
nmijump         jmp     (nmi_vector)

BrkCmd         pla                     ; X
               tax                     ;
               pla                     ; A
               jmp   BRKroutine        ; patch in user BRK routine

;
;  NMIjmp      =     $FFFA             
;  RESjmp      =     $FFFC             
;  INTjmp      =     $FFFE             

;               *=    $FFFA
        .org    $fffa
               .word  nmijump
               .word  reset 
               .word  irqjump
;end of file
