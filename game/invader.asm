// ------------------------------------------------------
// CHAR INVADERS (character graphics Space-Invaders-like)
// Commodore 64 / 6510 Assembly
// KickAssembler v5.25 compatible
//
// Controls (keyboard):
//   A = move left
//   D = move right
//   SPACE = fire
//
// Notes:
// - No sprites. Uses RAM charset at $2000.
// - Screen at $0400, Color RAM at $D800.
// - Uses KERNAL GETIN ($FFE4) for keyboard input.
// ------------------------------------------------------

.const SCREEN      = $0400
.const COLOR       = $D800

.const VIC_D018    = $D018
.const VIC_D011    = $D011
.const VIC_D016    = $D016
.const VIC_D012    = $D012
.const VIC_BORD    = $D020
.const VIC_BG      = $D021

.const CPU_PORT    = $0001
.const GETIN       = $FFE4

.const CHARSET_RAM = $2000

// IMPORTANT: zero page pointers for (zp),Y addressing
.const ptr1        = $FB      // $FB/$FC
.const ptr2        = $FD      // $FD/$FE

// Custom screen codes (we will patch bitmaps in RAM charset)
.const CH_INV      = 81
.const CH_SHIP     = 82
.const CH_BULLET   = 83
.const CH_EMPTY    = 32

// Colors
.const COL_INV     = 5        // green
.const COL_SHIP    = 3        // cyan
.const COL_BUL     = 1        // white
.const COL_UI      = 14       // light blue

// Formation settings
.const INV_ROWS      = 3
.const INV_COLS      = 5
.const INV_COUNT     = INV_ROWS * INV_COLS
.const INV_X_SPACING = 2
.const INV_Y_SPACING = 2

// Make UI text display correctly as screen codes
.encoding "screencode_upper"

// ------------------------------------------------------------
* = $0801
BasicUpstart2(start)

// ------------------------------------------------------------
* = $0810

// Variables
invOriginX:      .byte 5
invOriginY:      .byte 4
invDir:          .byte 1        // 1=right, $FF=left
invStepCounter:  .byte 0
invSpeed:        .byte 6        // smaller=faster

playerX:         .byte 20
playerY:         .byte 23
playerOldX:      .byte 20

bulletActive:    .byte 0
bulletX:         .byte 0
bulletY:         .byte 0
bulletOldY:      .byte 0

invAlive:
    .fill INV_COUNT, 1

// temps
tmpX:   .byte 0
tmpY:   .byte 0
tmpC:   .byte 0
tmpCol: .byte 0

invTmpRow: .byte 0
invTmpCol: .byte 0

// ------------------------------------------------------------

start:
    sei
    jsr initVideo
    jsr copyCharsetToRAM
    jsr patchCustomChars
    jsr clearScreen
    jsr drawUI
    cli                    // ensure IRQs on for normal KERNAL behavior

    jsr drawInvaders
    jsr drawPlayer

mainLoop:
    jsr waitRaster

    // (optional) comment out once you trust it
    // inc VIC_BORD

    jsr handleInput
    jsr updateInvaders
    jsr updateBullet
    jmp mainLoop

// ------------------------------------------------------------
// Video init: screen=$0400, charset=$2000, VIC bank 0
initVideo:
    lda #0
    sta VIC_BORD
    sta VIC_BG

    // VIC bank 0 ($0000-$3FFF): $DD00 low bits = %11
    lda $DD00
    and #%11111100
    ora #%00000011
    sta $DD00

    // D018: screen=$0400 -> 1 (bits 4-7), charset=$2000 -> 4 (bits 1-3)
    // screen nibble = 1 => $10, charset bits = 4<<1 => $08 => $18
    lda #$18
    sta VIC_D018

    // 25 rows
    lda VIC_D011
    ora #%00001000
    sta VIC_D011

    // 40 cols
    lda VIC_D016
    and #%11101111
    sta VIC_D016
    rts

// ------------------------------------------------------------
// Copy ROM charset ($D000-$D7FF) to RAM at $2000
copyCharsetToRAM:
    // Map char ROM in at $D000 (I/O off)
    lda CPU_PORT
    pha
    lda #$33
    sta CPU_PORT

    ldx #0
!copy:
    lda $D000,x
    sta CHARSET_RAM,x
    lda $D100,x
    sta CHARSET_RAM+$100,x
    lda $D200,x
    sta CHARSET_RAM+$200,x
    lda $D300,x
    sta CHARSET_RAM+$300,x
    lda $D400,x
    sta CHARSET_RAM+$400,x
    lda $D500,x
    sta CHARSET_RAM+$500,x
    lda $D600,x
    sta CHARSET_RAM+$600,x
    lda $D700,x
    sta CHARSET_RAM+$700,x
    inx
    bne !copy-

    // Restore mapping
    pla
    sta CPU_PORT
    rts

// ------------------------------------------------------------
// Patch custom character bitmaps into RAM charset
patchCustomChars:
    // INVADER
    ldx #0
!inv:
    lda invChar,x
    sta CHARSET_RAM + (CH_INV*8),x
    inx
    cpx #8
    bne !inv-

    // SHIP
    ldx #0
!ship:
    lda shipChar,x
    sta CHARSET_RAM + (CH_SHIP*8),x
    inx
    cpx #8
    bne !ship-

    // BULLET
    ldx #0
!bul:
    lda bulletChar,x
    sta CHARSET_RAM + (CH_BULLET*8),x
    inx
    cpx #8
    bne !bul-
    rts

invChar:
    .byte %00111100
    .byte %01111110
    .byte %11011011
    .byte %11111111
    .byte %00100100
    .byte %01011010
    .byte %10100101
    .byte %01000010

shipChar:
    .byte %00011000
    .byte %00111100
    .byte %01111110
    .byte %11111111
    .byte %00111100
    .byte %00111100
    .byte %01111110
    .byte %00000000

bulletChar:
    .byte %00011000
    .byte %00011000
    .byte %00011000
    .byte %00011000
    .byte %00011000
    .byte %00000000
    .byte %00000000
    .byte %00000000

// ------------------------------------------------------------

clearScreen:
    lda #CH_EMPTY
    ldx #0
!cl:
    sta SCREEN,x
    sta SCREEN+$100,x
    sta SCREEN+$200,x
    sta SCREEN+$300,x
    inx
    bne !cl-

    lda #0
    ldx #0
!clc:
    sta COLOR,x
    sta COLOR+$100,x
    sta COLOR+$200,x
    sta COLOR+$300,x
    inx
    bne !clc-
    rts

drawUI:
    ldx #0
!msg:
    lda uiMsg,x
    beq !done+
    sta SCREEN + 0,x
    lda #COL_UI
    sta COLOR  + 0,x
    inx
    bne !msg-
!done:
    rts

uiMsg:
    .text "CHAR INVADERS  A/D MOVE  SPACE FIRE"
    .byte 0

// ------------------------------------------------------------
// Frame pacing
waitRaster:
!w1:
    lda VIC_D012
    cmp #$f8
    bne !w1-
!w2:
    lda VIC_D012
    cmp #$f8
    beq !w2-
    rts

// ------------------------------------------------------------
// Row address tables for screen & color
rowLo:     .fill 25, <(SCREEN + i*40)
rowHi:     .fill 25, >(SCREEN + i*40)
colRowLo:  .fill 25, <(COLOR  + i*40)
colRowHi:  .fill 25, >(COLOR  + i*40)

// ------------------------------------------------------------
// putChar expects tmpX,tmpY,tmpC,tmpCol
// IMPORTANT: ptr1/ptr2 are ZERO-PAGE pointers ($FB-$FE)
putChar:
    ldy tmpY
    lda rowLo,y
    sta ptr1
    lda rowHi,y
    sta ptr1+1

    lda colRowLo,y
    sta ptr2
    lda colRowHi,y
    sta ptr2+1

    ldy tmpX
    lda tmpC
    sta (ptr1),y
    lda tmpCol
    sta (ptr2),y
    rts

getChar:
    ldy tmpY
    lda rowLo,y
    sta ptr1
    lda rowHi,y
    sta ptr1+1

    ldy tmpX
    lda (ptr1),y
    rts

// ------------------------------------------------------------
// Player
drawPlayer:
    lda playerX
    sta tmpX
    lda playerY
    sta tmpY
    lda #CH_SHIP
    sta tmpC
    lda #COL_SHIP
    sta tmpCol
    jsr putChar
    rts

erasePlayer:
    lda playerOldX
    sta tmpX
    lda playerY
    sta tmpY
    lda #CH_EMPTY
    sta tmpC
    lda #0
    sta tmpCol
    jsr putChar
    rts

// ------------------------------------------------------------
// Bullet
drawBullet:
    lda bulletX
    sta tmpX
    lda bulletY
    sta tmpY
    lda #CH_BULLET
    sta tmpC
    lda #COL_BUL
    sta tmpCol
    jsr putChar
    rts

eraseBullet:
    lda bulletX
    sta tmpX
    lda bulletOldY
    sta tmpY
    lda #CH_EMPTY
    sta tmpC
    lda #0
    sta tmpCol
    jsr putChar
    rts

// ------------------------------------------------------------
// Invaders
drawInvaders:
    ldx #0
!loop:
    lda invAlive,x
    beq !next+

    // Compute row/col from index X by repeated subtract
    txa
    ldy #0
!div:
    cmp #INV_COLS
    bcc !divDone+
    sbc #INV_COLS
    iny
    bne !div-
!divDone:
    sta invTmpCol
    sty invTmpRow

    // tmpX = originX + col*2
    lda invTmpCol
    asl
    clc
    adc invOriginX
    sta tmpX

    // tmpY = originY + row*2
    lda invTmpRow
    asl
    clc
    adc invOriginY
    sta tmpY

    lda #CH_INV
    sta tmpC
    lda #COL_INV
    sta tmpCol
    jsr putChar

!next:
    inx
    cpx #INV_COUNT
    bne !loop-
    rts

eraseInvaders:
    ldx #0
!loop:
    lda invAlive,x
    beq !next+

    txa
    ldy #0
!div:
    cmp #INV_COLS
    bcc !divDone+
    sbc #INV_COLS
    iny
    bne !div-
!divDone:
    sta invTmpCol
    sty invTmpRow

    lda invTmpCol
    asl
    clc
    adc invOriginX
    sta tmpX

    lda invTmpRow
    asl
    clc
    adc invOriginY
    sta tmpY

    lda #CH_EMPTY
    sta tmpC
    lda #0
    sta tmpCol
    jsr putChar

!next:
    inx
    cpx #INV_COUNT
    bne !loop-
    rts

// ------------------------------------------------------------
// Keyboard input: A=left, D=right, SPACE=fire
handleInput:
    lda playerX
    sta playerOldX

    jsr GETIN
    beq !draw+              // no key

    // Normalize A-Z to a-z
    cmp #$41
    bcc !check+
    cmp #$5B
    bcs !check+
    ora #$20
!check:
    cmp #$61                // 'a'
    bne !chkD+
    lda playerX
    beq !draw+
    dec playerX
    jmp !draw+

!chkD:
    cmp #$64                // 'd'
    bne !chkSpace+
    lda playerX
    cmp #39
    beq !draw+
    inc playerX
    jmp !draw+

!chkSpace:
    cmp #$20                // space
    bne !draw+

    lda bulletActive
    bne !draw+

    lda #1
    sta bulletActive
    lda playerX
    sta bulletX
    lda playerY
    sec
    sbc #1
    sta bulletY
    sta bulletOldY

!draw:
    jsr erasePlayer
    jsr drawPlayer
    rts

// ------------------------------------------------------------
// Invader movement
updateInvaders:
    lda invStepCounter
    clc
    adc #1
    sta invStepCounter
    cmp invSpeed
    bcc !noMove+
    lda #0
    sta invStepCounter

    jsr eraseInvaders

    lda invDir
    bmi !moveLeft+

!moveRight:
    lda invOriginX
    clc
    adc #((INV_COLS-1)*2)
    cmp #39
    bcc !okR+
    jsr invDownAndReverse
    jmp !redraw+
!okR:
    inc invOriginX
    jmp !redraw+

!moveLeft:
    lda invOriginX
    beq !bounceL+
    dec invOriginX
    jmp !redraw+
!bounceL:
    jsr invDownAndReverse

!redraw:
    jsr drawInvaders
!noMove:
    rts

invDownAndReverse:
    lda invOriginY
    clc
    adc #1
    sta invOriginY

    // Flip 1 <-> $FF
    lda invDir
    eor #$FE
    sta invDir
    rts

// ------------------------------------------------------------
// Bullet update + collision
updateBullet:
    lda bulletActive
    beq !done+

    jsr eraseBullet

    lda bulletY
    sta bulletOldY
    beq !kill+

    dec bulletY

    // collision test
    lda bulletX
    sta tmpX
    lda bulletY
    sta tmpY
    jsr getChar
    cmp #CH_INV
    bne !noHit+

    // blank hit cell
    lda #CH_EMPTY
    sta tmpC
    lda #0
    sta tmpCol
    jsr putChar

    jsr killInvaderAtTmp

    lda #0
    sta bulletActive
    jmp !done+

!noHit:
    lda bulletY
    cmp #1
    bcc !kill+

    jsr drawBullet
    jmp !done+

!kill:
    lda #0
    sta bulletActive
!done:
    rts

killInvaderAtTmp:
    // row = (tmpY - originY)/2
    lda tmpY
    sec
    sbc invOriginY
    lsr
    sta invTmpRow

    // col = (tmpX - originX)/2
    lda tmpX
    sec
    sbc invOriginX
    lsr
    sta invTmpCol

    // index = row*INV_COLS + col
    lda invTmpRow
    tay
    lda #0
!mul:
    cpy #0
    beq !mulDone+
    clc
    adc #INV_COLS
    dey
    bne !mul-
!mulDone:
    clc
    adc invTmpCol
    tax
    cpx #INV_COUNT
    bcs !out+
    lda #0
    sta invAlive,x
!out:
    rts
