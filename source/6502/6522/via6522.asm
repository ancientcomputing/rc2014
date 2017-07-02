;---------------------------------------------------------------------
; via6522.asm
; Various 6522 routines
; Changes/fixes are copyright Ben Chong and freely licensed to the community
;
;---------------------------------------------------------------------

;irq_vector      =       $03e8           ; Interrupt vector
old_irq_vectorl         =       $03f0           ; Where we save the old IRQ vector
old_irq_vectorh         =       $03f1
via6522_count           =       $03f2

; Change via_base depending on your hardware set up
via_base        =       $c070
iorb_reg        =       via_base+0
iora_reg        =       via_base+1
ddrb_reg        =       via_base+2
ddra_reg        =       via_base+3
t1cl_reg        =       via_base+4
t1ch_reg        =       via_base+5
t1ll_reg        =       via_base+6
t1lh_reg        =       via_base+7
t2cl_reg        =       via_base+8
t2ch_reg        =       via_base+9
sr_reg          =       via_base+10
acr_reg         =       via_base+11
pcr_reg         =       via_base+12
ifr_reg         =       via_base+13
ier_reg         =       via_base+14
iora2_reg       =       via_base+15


;---------------------------------------------------------------------

via6522_init
        ; Disable interrupts
        lda     #$80
        sta     ier_reg
        lda     #$00
        sta     via6522_count
        rts
        
        
;---------------------------------------------------------------------        
; From: http://6502.org/source/io/6522timr.htm (which included errors)
; 1MHz clock + 10000 count = 10ms; $2710 in hex
; Entry:
;   X = count_hi
;   A = count_lo
; Exit: trashes A

via6522_test_1shot1
        lda     #$10
        ldx     #$27
via6522_1shot1
        pha
        LDA     #$00
        STA     ACR_reg      ;1-Shot Mode: No PB7 Pulses
        pla
        STA     T1LL_reg     ;Low-Latch
        stx     T1CH_reg     ;Loads also T1CL and Starts
loop_1shot1
        LDA     IFR_reg         ; Time Out?
        AND     #$40            ; The original example was incorrect  
        BEQ     loop_1shot1
        LDA     T1CL_reg        ; Clear Interrupt Flag
        rts
        
;---------------------------------------------------------------------
; Continuous 1 second intervals
; Call via6522_test_cont1 to set up
; Then call via6522_check_count continuously to see if 1 second is up. 
; Returns C=1 if 1 second is up.

via6522_test_cont1
        lda     #$10
        ldx     #$27
via6522_cont1
        pha
        LDA     #$40
        STA     ACR_reg      ; Continuous Mode: No PB7 Pulses
        pla
        STA     T1LL_reg     ;Low-Latch
        stx     T1CH_reg     ;Loads also T1CL and Starts
via6522_check_count
loop_cont1
        LDA     IFR_reg         ; Time Out?
        AND     #$40            ;   
        BEQ     via6522_check_count
        LDA     T1CL_reg        ; Clear Interrupt Flag
        inc     via6522_count
        lda     via6522_count
        cmp     #100
        bcc     cc_end          ; Less than 100s
        lda     #$00
        sta     via6522_count
        sec
cc_end
        rts
        
        
        
        
  
        
        
        