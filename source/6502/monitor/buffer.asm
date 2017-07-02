; 64 byte char buffer
;---------------------------------------------------------------------
; Compare Result	N	Z	C
; A, X, or Y < Memory	*	0	0
; A, X, or Y = Memory	0	1	1
; A, X, or Y > Memory	*	0	1
;---------------------------------------------------------------------

MAXCOUNT        =       64
HIWATER         =       40
LOWATER         =       20

inptr           =       $e7     ;$380    ;$f2
outptr          =       $e8     ;$381    ;$f3
charcount       =       $e9     ;$382    ;$f4

;---------------------------------------------------------------------
; Initialize buffer operations

init_buffer
        lda     #$00
        sta     inptr
        sta     outptr
        sta     charcount
        rts
        
;---------------------------------------------------------------------        
; Store char in buffer
; Entry: A = char
put_buffer
        pha
        lda     charcount
        cmp     #MAXCOUNT       ; Are we at max?
        bcs     bp_max          ; Yes, abort
        cmp     #HIWATER        ;
        bcc     not_hiw         ; Not high water mark
        jsr     uart_deassert_rts
not_hiw
        inc     charcount
        stx     ysav            ; Temp storage. 6502 doesn't have enough flexibility...!
        ldx     inptr           ; Grab inptr from memory
        pla                     ; Get char
        sta     buffer, x       ; Store in buffer
        inx                     ; Increment to next location
        cpx     #64             ; Top of buffer area?
        bcc     pb_not          ; < 64
        ldx     #$00            ; If >=64, go back to bottom of buffer 
pb_not
        stx     inptr           ; Update inptr in memory
        ldx     ysav            ; Restore X
bp_max
        rts

;---------------------------------------------------------------------
; Check if char in buffer, C=1 char, C=0 no character
; Exit: A contains char
pull_buffer
        sei                     ; Disable IRQ
        lda     charcount
        beq     plb_nochar       ; No character in buffer
        dec     charcount
        cmp     #LOWATER
        bcs     not_low         ; Not low water
        jsr     uart_assert_rts
not_low
        stx     ysav            ; Save x
        ldx     outptr
        lda     buffer, x
        inx
        cpx     #64             ; Top of buffer?
        bcc     plb_not         ; No
        ldx     #$00            ; Back to bottom
plb_not
        stx     outptr          ; Save
        ldx     ysav            ; Restore x
        sec
        bcs     plb_end         ; Equiv to bra
plb_nochar
        clc
plb_end
        cli                     ; Enable IRQ
        rts

check_buffer
        lda     charcount
        rts
