// Sprite demo written in assembly by Fratm
// This is the demo from the C64 users guide
// But I re-wrote it in assembly.  Release to public domain 

// constants 
.const VICII = $D000
.const SPRITEBANK = $0340

// The basic header stuff.
* = $0801
    .word $0810
    .word $0801
    .byte $9E
    .text "2064"
    .byte 0, 0

// Start 
* = $0810

// Enable Sprite #2
    lda #$0004
    ldx #$0015
    sta VICII,x 

// Point sprite to block 13?
    lda #$000D
    sta $07FA

// Load sprite data
    ldx #$0000
spriteload:
    lda sprite, x 
    sta SPRITEBANK, x 
    inx
    cpx #$003E
    bne spriteload

// move the sprite across the screen
    lda #$0000
    sta counter
moveloop:
    ldx #$0004
    sta VICII, x
    ldx #$0005  
    sta VICII, x  
    inc  counter
    lda counter
    jsr delay 
    cmp #$00C8
    bne moveloop

// poke 42, 55 is a good smooth speed.  This is the same dealy routine
// I used in my simple scroller program, but added a variable speed control.
// change delay time with poke 42, ##  (Lower the ## the faster the scroll)
delay:
    stx bufferx
    sty buffery
    ldx $002A          // Set X to a high value for the outer loop
outerLoop:
    ldy $002A          // Set Y to a high value for the inner loop
innerLoop:
    dey               // Decrement Y
    bne innerLoop     // Continue the inner loop until Y is 0
    dex               // Decrement X after the inner loop completes
    bne outerLoop     // Continue the outer loop until X is 0
    ldx bufferx
    ldy buffery
    rts               // Return from subroutine

// Just some register buffers -- I'm new a this, im sure there is a better way.
bufferx: .byte 00
buffery: .byte 00
buffera: .byte 00

// probably a better way then to allocate this byte, but I'm still new and this made sense.
counter:
    .byte 00

// Sprite data in decimal, copied from the book.
sprite:
    .byte 0,127,0,1,255,192,3,255,224,3,231,224
    .byte 7,217,240,7,223,240,7,217,240,3,231,224
    .byte 3,255,224,3,255,224,2,255,160,1,127,64
    .byte 1,62,64,0,156,128,0,156,128,0,73,0,0,73,0
    .byte 0,62,0,0,62,0,0,62,0,0,28,0
