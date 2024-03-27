// Basic upstart sequence
// border color #$d020
* = $0801
    .word $0810
    .word $0801
    .byte $9E
    .text "2064"
    .byte 0, 0

* = $0810

/**********************************************
		10 print Classic v0.1
		josip.kalebic@gmail.com
***********************************************/
.var CHROUT = $ffd2
.var BASIC_RND = $e097

////10 print chr$(205.5+rnd(1));:goto 10

//Main program
mainProg: {		

loop:

		jsr BASIC_RND
		lda $8c    //$8b - $8f
		and #%00000001
		tax
		lda chars,x
		jsr CHROUT
		jmp loop
}

//-----------------------------------------------------
chars: .byte $cd,$ce
