;---------------------------------------------------------------------
; via6522.asm
; Various 6522 routines
; Copyright Ben Chong and freely licensed to the community
;
;---------------------------------------------------------------------

; Comment out this next line if you are building this file with the Monitor/Debugger
irq_vector      =       $03e8           ; Interrupt vector

; Handle interrupt chaining
old_irq_vectorl         =       $03f0           ; Where we save the old IRQ vector
old_irq_vectorh         =       $03f1

; The software counter
via6522_count           =       $03f2

; Tone machine variables
via6522_freqcntl        =       $03f3           ; Count to program into T1
via6522_freqcnth        =       $03f4           ; Count to program into T1
via6522_duration        =       $03f5           ; Duration in 10ms ticks

; Change via_base depending on your hardware set up
via_base        =       $c070
; Definition of 6522 registers
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
; Initalize the chip and interrupt handlers
via6522_init
        sei
        ; Save old IRQ vector
        lda     irq_vector
        sta     old_irq_vectorl
        lda     irq_vector+1
        sta     old_irq_vectorh
        ; Insert new IRQ vector
        lda     #>via6522_irq
        ldx     #<via6522_irq
        stx      irq_vector
        sta      irq_vector+1

        ; Enable interrupts
        lda     #$c0            ; Enable Timer 1
        sta     ier_reg

        ; Init software counter
        lda     #$00
        sta     via6522_count
        cli
        rts

;---------------------------------------------------------------------        
; From: http://6502.org/source/io/6522timr.htm (which included errors)
; 1MHz clock + 10000 count = 10ms; $2710 in hex
; It looks like the actual value is 2 less i.e. $2708
; Entry:
;   X = count_hi
;   A = count_lo
; Exit: trashes A

via6522_test_1shot1
        ldx     #$27            ; High
        lda     #$0e            ; Low
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
        ldx     #$27            ; High
        lda     #$0e            ; Low
via6522_cont1
        pha
        LDA     #($40+$80)
        STA     ACR_reg      ; Continuous Mode: No PB7 Pulses
        pla
        STA     T1LL_reg     ;Low-Latch
        stx     T1CH_reg     ;Loads also T1CL and Starts

        IF 0
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
        ENDIF
        rts

;---------------------------------------------------------------------        
; Interrupt handler
via6522_irq
        lda     ifr_reg
        asl                     ; Bit 7 -> C
        bcc     not_via6522_irq         ; Not a 6522 IRQ
        and     #$80            ; Is it Timer1?
        bne     via6522_timer1_irq
        brk                     ; Break if it's some other 6522 interrupt
via6522_timer1_irq
        lda     T1CL_reg        ; Clear Interrupt Flag        
        inc     via6522_count
        pla                     ; Restore X
        tax                     ; 		
        pla                     ; Restore A
        rti     
        
;---------------------------------------------------------------------    
; Not our interrupt, next IRQ handler
not_via6522_irq
        jmp     (old_irq_vectorl)       ; Jump to the next interrupt handler
        
;---------------------------------------------------------------------    
; Set up Timer 1 for continuous with PB7
via6522_cont1pb7
        ; Disable Timer 1 interrupt
        lda     #$40            ; Disable Timer 1
        sta     ier_reg

        LDA     #($40+$80)      ; Timer1 cont with PA7
        STA     ACR_reg         ; Continuous Mode: PB7 Pulses
        lda     via6522_freqcntl
        STA     T1LL_reg        ;Low-Latch
        lda     via6522_freqcnth
        sta     T1CH_reg        ;Loads also T1CL and Starts
        rts

;---------------------------------------------------------------------
; Polling for 10ms 

via6522_10ms_1shot2
        ldx     #$27            ; High
        lda     #$0e            ; Low
via6522_1shot2
;        pha
;        lda     acr_reg
;        and     #$bf
;        STA     ACR_reg      ;1-Shot Mode: No PB7 Pulses
;        pla
        STA     T2cl_reg     ;Low-Latch
        stx     T2ch_reg     ;Loads also T1CL and Starts
loop_1shot2
        LDA     IFR_reg         ; Time Out?
        AND     #$20            ;   
        BEQ     loop_1shot2
        LDA     T2CL_reg        ; Clear Interrupt Flag
        rts

;---------------------------------------------------------------------        
; Tone machine
; Variables stored in RAM before calling this routine
; via6522_freqcntl         =       $03f3
; via6522_freqcnth         =       $03f43
; via6522_duration         =       $03f5

play_tone
        jsr     via6522_cont1pb7        ; Set up for the tone
pt_loop
        jsr     via6522_10ms_1shot2     ; Set up timer 2 for tone duration
        dec     via6522_duration
        bne     pt_loop
;        LDA     #$00                    ; Stop Timer 1
        lda     acr_reg
        and     #$3f                    ; Zero the T1 timer controls
        sta     acr_reg
        rts
        
;---------------------------------------------------------------------   
; Counter values for a chromatic scale

scale_table
        .byte   $75, $07        ; C
        .byte   $0A, $07        ; C#
        .byte   $A5, $06        ; D
        .byte   $45, $06        ; D#
        .byte   $EB, $05        ; E
        .byte   $96, $05        ; F
        .byte   $45, $05        ; F#
        .byte   $FA, $04        ; G
        .byte   $B2, $04        ; G#
        .byte   $6E, $04        ; A - 440Hz
        .byte   $2F, $04        ; A#
        .byte   $F2, $03        ; B
        .byte   $BA, $03        ; C

;---------------------------------------------------------------------
; Example to play all the notes of the scale

play_scale
        ldx     #$00
ps_loop
        lda     scale_table, x
        sta     via6522_freqcntl
        inx
        lda     scale_table, x
        sta     via6522_freqcnth
        inx
        lda     #20             ; Time for each note. Value x10ms
        sta     via6522_duration
        txa
        pha
        jsr     play_tone
        pla    
        tax
        cpx     #26
        bne     ps_loop
        rts
        
;---------------------------------------------------------------------
; Play a note
; Entry: X is duration, A is the key

play_note
        stx     via6522_duration
        sta     via6522_freqcntl
        asl     via6522_freqcntl        ; Need to x2 to get index into scale
        ldx     via6522_freqcntl        ; Using memory as a scratch pad
        lda     scale_table, x
        sta     via6522_freqcntl
        inx
        lda     scale_table, x
        sta     via6522_freqcnth
        jmp     play_tone       
        
;---------------------------------------------------------------------
; Format:
;   Note, duration, note, duration...
doe_a_deer
        .byte   0, $30, 2, $10, 4, $20, 0, $20, 4, $20, 0, $20, 4, $40
        .byte   2, $20, 4, $10, 5, $10, 5, $10, 4, $10, 2, $10, 5, $40
        .byte   4, $30, 5, $10, 7, $20, 4, $20, 7, $20, 4, $20, 7, $40
        .byte   $ff
        
play_doe_a_deer
        ldy     #$00
pdad_loop
        lda     doe_a_deer, y
        cmp     #$ff
        beq     pdad_end
        iny    
        ldx     doe_a_deer, y 
        jsr     play_note
        iny
        jmp     pdad_loop
pdad_end
        rts
        
        
        
        
  
        
        
        