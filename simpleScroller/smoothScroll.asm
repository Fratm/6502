// Smooth scrolling text demo V0.02  - Written By Fratm //
//////////////////////////////////////////////////////////
BasicUpstart2(start)

.const SCREEN   = $0400
.const ROW0     = SCREEN
.const ROWLEN   = 40
.const FARRIGHT = ROW0 + (ROWLEN-1)

// VIC
.const D011 = $D011
.const D012 = $D012
.const D016 = $D016
.const D019 = $D019
.const D01A = $D01A

// KERNAL IRQ vector (indirect)
.const IRQVEC = $0314

// Choose split around first text row.
// If your screen still "moves", tweak RASTER_TOP by +/- a few.
.const RASTER_TOP    = $30          // ~48 decimal (good starting point)
.const RASTER_BOTTOM = RASTER_TOP+9 // exactly one character row later

// Slow it down: 2..4 is usually nice
.const SPEED_DIV = 2

// ------------------------------------------------------------
start:
    sei

    // Clear row 0 (optional)
    ldx #0
!clr:
    lda #$20
    sta ROW0,x
    inx
    cpx #ROWLEN
    bne !clr-

    lda #7
    sta fineScroll
    lda #0
    sta msgIndex
    sta speedCnt
    sta phase

    // Save old KERNAL IRQ vector
    lda IRQVEC
    sta oldIrqLo
    lda IRQVEC+1
    sta oldIrqHi

    // Install our handler into KERNAL's vector
    lda #<rasterIrq
    sta IRQVEC
    lda #>rasterIrq
    sta IRQVEC+1

    // Set first raster line
    lda #RASTER_TOP
    sta D012
    lda D011
    and #%01111111          // raster high bit = 0
    sta D011

    // Enable raster IRQ source
    lda D01A
    ora #%00000001
    sta D01A

    // Ack any pending VIC IRQs
    lda #$0f
    sta D019

    cli

main:
    jmp main

// ------------------------------------------------------------
// Our IRQ runs inside the normal KERNAL IRQ flow.
// We do our split work, then JMP to the original handler.
rasterIrq:
    pha
    txa
    pha
    tya
    pha

    // Only handle if VIC raster IRQ is pending
    lda D019
    and #%00000001
    beq !chain+

    // ACK raster IRQ
    lda #%00000001
    sta D019

    lda phase
    beq doTop

doBottom:
    // Reset fine scroll so rest of screen is stable
    lda D016
    and #%11111000
    sta D016

    // Next interrupt at top split
    lda #RASTER_TOP
    sta D012
    lda #0
    sta phase
    jmp !chain+

doTop:
    // Apply fine scroll for row 0
    lda D016
    and #%11111000
    ora fineScroll
    sta D016

    // Next interrupt after row 0
    lda #RASTER_BOTTOM
    sta D012
    lda #1
    sta phase

    // Speed divider (so you can read it)
    inc speedCnt
    lda speedCnt
    cmp #SPEED_DIV
    bne !chain+
    lda #0
    sta speedCnt

    // Pixel step: count 7..0 then wrap
    dec fineScroll
    bpl !chain+

    lda #7
    sta fineScroll
    jsr scrollleft_char_row0
    jsr putNextChar_row0

!chain:
    pla
    tay
    pla
    tax
    pla

    // Chain to original IRQ handler (keeps KERNAL happy)
    jmp (oldIrqLo)

// ------------------------------------------------------------
scrollleft_char_row0:
    ldx #0
!lp:
    lda ROW0+1,x
    sta ROW0,x
    inx
    cpx #(ROWLEN-1)
    bne !lp-
    lda #$20
    sta FARRIGHT
    rts

putNextChar_row0:
    ldx msgIndex
    lda message,x
    bne !ok+
    ldx #0
    stx msgIndex
    lda message,x
!ok:
    sta FARRIGHT
    inx
    stx msgIndex
    rts

// ------------------------------------------------------------
fineScroll: .byte 7
msgIndex:   .byte 0
speedCnt:   .byte 0
phase:      .byte 0

oldIrqLo:   .byte 0
oldIrqHi:   .byte 0

message:
    .text "simple 6510 smooth text scroller v0.02  - written by fratm "
    .text "                    "
    .byte 0
