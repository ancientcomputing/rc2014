; Test


; wait for input character
input_char      =       $ff03      

; scan for input (no wait), C=1 char, C=0 no character
check_input     =       $ff06

; Send 1 character
output_char     =       $ff09

        .org    $2000
reloop_scale
        jsr     play_scale
        ; Press a key to stop the scale
        jsr     check_input
        bcc     reloop_scale
        jsr     play_doe_a_deer
        jmp     $ff00           ; return to monitor        

        .org    $2100
        ; Tests out the free running 1 second timer          
test_timer
        jsr     via6522_init
        
        lda     #'A'
        jsr     output_char
        
oc_loop:
        jsr     via6522_test_cont1      ; Set up continuous 1s interrupts
oc_loop2:
        lda     via6522_count           ; Check the counter
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
        jmp     oc_loop2                ; Loop forever

        
        
        
        .include via6522.asm