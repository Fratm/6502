// Basic upstart sequence
// border color #$d020
* = $0801
    .word $0810
    .word $0801
    .byte $9E
    .text "2064"
    .byte 0, 0

* = $0810
lda $d020  // Load value from $d020
sta $d020
inc $d020
sta $d020
sta $0400
jmp $0810
