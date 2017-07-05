;---------------------------------------------------------------------
; ANSI/VT100 Terminal routines
; Designed for RC2014
; Copyright Ben Chong and freely licensed to the community

;---------------------------------------------------------------------
; Comment this out if these values are already defined elsewhere        
; wait for input character
input_char      =       $ff03      
; scan for input (no wait), C=1 char, C=0 no character
check_input     =       $ff06
; Send 1 character
output_char     =       $ff09

;---------------------------------------------------------------------
; ANSI/VT100 commands
; http://www.termsys.demon.co.uk/vtansi.htm

go_home_cmd             .byte   27, "[H",0
clear_screen_cmd        .byte   27, "[2J",0
eteol_cmd               .byte   27,"[K",0


;---------------------------------------------------------------------
; Go to top left of screen
go_home       
        ldx     #$00
go_home_loop
        lda     go_home_cmd, x
        beq     go_home_end
        jsr     output_char
        inx
        bne     go_home_loop    ; =bra
go_home_end
        rts        
        
; Clear screen
clear_screen           
        ldx     #$00
clear_screen_loop
        lda     clear_screen_cmd, x
        beq     clear_screen_end
        jsr     output_char
        inx
        bne     clear_screen_loop    ; =bra
clear_screen_end
        rts
             
        
; ETEOL
eteol
        ldx     #$00
eteol_loop
        lda     eteol_cmd, x
        beq     eteol_end
        jsr     output_char
        inx
        bne     eteol_loop    ; =bra
eteol_end
        rts


        

