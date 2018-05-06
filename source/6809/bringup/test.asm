

	.org	$f000

        .include        rruart.asm	
	
	.org    $ff00
	
; Vector table
        
        ; Monitor vector $ff00
;                jmp     Monitor

        .org $ff03
input_char      jmp     uart_input       ; wait for input character
        ; $ff06
check_input     jmp     uart_scan        ; scan for input (no wait), C=1 char, C=0 no character
        ; $ff09
output_char     jmp     uart_Output      ; send 1 character

	
resetvector
        lds     #$200
        ldu     #$17f
        lda     #'A'
        jsr     output_char
        lda     #'b'
        jsr     output_char
        jmp     $

swi3vector
swi2vector
firqvector
irqvector
swi1vector
nmivector
        rti




        .org    $fff0
        
	.word		$0000		
	.word		swi3vector
	.word		swi2vector
	.word		firqvector
	.word		irqvector
	.word		swi1vector
	.word		nmivector
	.word		resetvector        
