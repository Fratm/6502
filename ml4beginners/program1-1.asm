// Program 1-1 Page ix of Introduction (Written to use labels for kickAssembler)

BasicUpstart2(start)
.const SCREEN   = $0400   // the example in the book used $8000, but that doesn't work on C64, so I made this label and went from there.

start:
    lda #$01
    ldy #$00
 loop:
    sta SCREEN,y
    sta SCREEN+256,y
    sta SCREEN+512,y
    sta SCREEN+768,y
    iny
    bne loop
    rts
