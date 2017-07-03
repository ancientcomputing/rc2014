; Test


; wait for input character
input_char      =       $ff03      

; scan for input (no wait), C=1 char, C=0 no character
check_input     =       $ff06

; Send 1 character
output_char     =       $ff09

        .org    $2000
          
        jsr     via6522_init
        
        lda     #'A'
        jsr     output_char
        
oc_loop:
;        jsr     via6522_test_1shot1
        jsr     via6522_test_cont1
oc_loop2:
;        jsr     via6522_check_count
        lda     via6522_count
        cmp     #100                    ; Are we there yet?
        bcs     oc_1sec
        jsr     check_input
        bcc     oc_loop2
        bcs     oc_outchar
oc_1sec:
        ; We're at 1sec
        lda     #$00
        sta     via6522_count        
        lda     #'#'
oc_outchar:
        jsr     output_char        
;        jmp     oc_loop 
        jmp     oc_loop2 
        
        .include via6522.asm