// Sprite demo written in assembly by Fratm
// This is the demo from the C64 users guide
// But I re-wrote it in assembly.

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

* = $0810
// set speed

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


// You can change the speed by poking a value into $002A (42 decimal)
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

counter:
    .byte 00


sprite:
    .byte 0,127,0,1,255,192,3,255,224,3,231,224
    .byte 7,217,240,7,223,240,7,217,240,3,231,224
    .byte 3,255,224,3,255,224,2,255,160,1,127,64
    .byte 1,62,64,0,156,128,0,156,128,0,73,0,0,73,0
    .byte 0,62,0,0,62,0,0,62,0,0,28,0



