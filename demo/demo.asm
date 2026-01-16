// -----------------------------------------------------------------------------
// Demo Controller with:
//  - Resident task: top-line smooth scroller (always runs)
//  - Sequenced parts: currently just border color cycle (can add more)
//  - Raster split so ONLY row 0 uses D016 fine scroll
//  - KERNAL IRQ chaining so BASIC prompt can still work
// -----------------------------------------------------------------------------

BasicUpstart2(start)

// --- Screen constants
.const SCREEN   = $0400
.const ROW0     = SCREEN
.const ROWLEN   = 40
.const FARRIGHT = ROW0 + (ROWLEN-1)

// --- VIC
.const D011   = $D011
.const D012   = $D012
.const D016   = $D016
.const D019   = $D019
.const D01A   = $D01A
.const BORDER = $D020
.const BG0    = $D021

// --- CIA interrupt control
.const CIA1_ICR = $DC0D
.const CIA2_ICR = $DD0D

// --- KERNAL IRQ vector (indirect)
.const IRQVEC = $0314

// --- Raster split (tweak TOP if needed)
.const RASTER_TOP    = $2F
.const RASTER_BOTTOM = RASTER_TOP+10

// --- Sequenced parts
.const NUM_PARTS = 1

// --- Scroller tuning (resident)
.const SCROLLER_SPEED_DIV = 3

// --- Border tuning (part)
.const BORDER_SPEED_DIV   = 1

// -----------------------------------------------------------------------------
// Start / Setup
start:
    sei
    cld

    // Disable CIA IRQ sources (prevents extra interrupts)
    lda #$7f
    sta CIA1_ICR
    sta CIA2_ICR
    lda CIA1_ICR
    lda CIA2_ICR

    // Save old KERNAL IRQ vector so we can chain
    lda IRQVEC
    sta oldIrqLo
    lda IRQVEC+1
    sta oldIrqHi

    // Install our IRQ handler into the KERNAL vector
    lda #<demoIrq
    sta IRQVEC
    lda #>demoIrq
    sta IRQVEC+1

    // Init resident tasks
    jsr scroller_init

    // Init control sequence parts
    lda #0
    sta partIndex
    jsr loadPart

    // Setup raster IRQ
    lda #RASTER_TOP
    sta D012
    lda D011
    and #%01111111
    sta D011

    lda D01A
    ora #%00000001
    sta D01A

    lda #$0f
    sta D019

    lda #0
    sta irqPhase

    cli

main:
    jmp main

// -----------------------------------------------------------------------------
// DEMO IRQ CONTROLLER
demoIrq:
    pha
    txa
    pha
    tya
    pha

    lda D019
    and #%00000001
    beq chainOld

    lda #%00000001
    sta D019

    lda irqPhase
    bne doBottom

doTop:
    // stabilize: don't change D016 mid-line
    lda D012
!w:
    cmp D012
    beq !w-

    // Apply fine scroll for top band (row 0)
    lda D016
    and #%11111000
    ora scroller_fine
    sta D016

    // ---- ALWAYS RUN RESIDENT TASKS ----
    jsr scroller_tick

    // ---- RUN CURRENT PART (if any) ----
    jsr callPartTick

    // Part timer: duration $0000 means run forever (no decrement/switch)
    lda partTimeLo
    ora partTimeHi
    beq !noSwitch+

    // Decrement part timer
    lda partTimeLo
    bne !decLo+
    lda partTimeHi
    beq !timeUp+
    dec partTimeHi
    lda #$ff
    sta partTimeLo
    jmp !afterTimer+

!decLo:
    dec partTimeLo
!afterTimer:
    lda partTimeLo
    ora partTimeHi
    bne !noSwitch+
!timeUp:
    jsr nextPart

!noSwitch:
    // Schedule bottom split
    lda #RASTER_BOTTOM
    sta D012
    lda #1
    sta irqPhase
    jmp chainOld

doBottom:
    // Reset fine scroll for rest of screen
    lda D016
    and #%11111000
    sta D016

    // Schedule top split
    lda #RASTER_TOP
    sta D012
    lda #0
    sta irqPhase
    jmp chainOld

chainOld:
    pla
    tay
    pla
    tax
    pla
    jmp (oldIrqLo)

// -----------------------------------------------------------------------------
// Control sequence (parts table)
// Entry: initPtr(2), tickPtr(2), durationLo(1), durationHi(1)
loadPart:
    // offset = partIndex * 6
    lda partIndex
    asl
    sta tmp                // idx*2
    lda partIndex
    asl
    asl                     // idx*4
    clc
    adc tmp                 // idx*6
    tay

    lda partsTable,y
    sta partInitPtr
    lda partsTable+1,y
    sta partInitPtr+1

    lda partsTable+2,y
    sta partTickPtr
    lda partsTable+3,y
    sta partTickPtr+1

    lda partsTable+4,y
    sta partTimeLo
    lda partsTable+5,y
    sta partTimeHi

    jsr callPartInit
    rts

nextPart:
    inc partIndex
    lda partIndex
    cmp #NUM_PARTS
    bne !ok+
    lda #0
    sta partIndex
!ok:
    jsr loadPart
    rts

callPartInit:
    jmp (partInitPtr)

callPartTick:
    jmp (partTickPtr)

// -----------------------------------------------------------------------------
// RESIDENT TASK: Top-line smooth scroller (always running)
scroller_init:
    // Clear row 0
    ldx #0
!clr:
    lda #$20
    sta ROW0,x
    inx
    cpx #ROWLEN
    bne !clr-

    lda #7
    sta scroller_fine
    lda #0
    sta scroller_msgIndex
    sta scroller_speedCnt
    rts

scroller_tick:
    inc scroller_speedCnt
    lda scroller_speedCnt
    cmp #SCROLLER_SPEED_DIV
    bne !done+
    lda #0
    sta scroller_speedCnt

    dec scroller_fine
    bpl !done+

    lda #7
    sta scroller_fine

    jsr scroller_shiftRow0
    jsr scroller_putNextChar
!done:
    rts

scroller_shiftRow0:
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

scroller_putNextChar:
    ldx scroller_msgIndex
    lda scroller_message,x
    bne !ok+
    ldx #0
    stx scroller_msgIndex
    lda scroller_message,x
!ok:
    sta FARRIGHT
    inx
    stx scroller_msgIndex
    rts

scroller_fine:     .byte 7
scroller_msgIndex: .byte 0
scroller_speedCnt: .byte 0

scroller_message:
    .text "resident scroller + part effects at the same time.  border bars can run while this keeps scrolling.  "
    .byte 0

// -----------------------------------------------------------------------------
// PART 0: Border color cycle (runs alongside resident scroller)
part_border_init:
    lda #0
    sta borderPhase
    sta borderSpeed
    rts

part_border_tick:
    inc borderSpeed
    lda borderSpeed
    cmp #BORDER_SPEED_DIV
    bne !done+
    lda #0
    sta borderSpeed

    inc borderPhase
    lda borderPhase
    and #$0f
    sta BORDER
!done:
    rts

borderPhase: .byte 0
borderSpeed: .byte 0

// -----------------------------------------------------------------------------
// Parts table (only one part here, duration $0000 = forever)
partsTable:
    .word part_border_init, part_border_tick
    .byte $00, $00

// -----------------------------------------------------------------------------
// Controller state
irqPhase:    .byte 0

partIndex:   .byte 0
partInitPtr: .word 0
partTickPtr: .word 0
partTimeLo:  .byte 0
partTimeHi:  .byte 0

oldIrqLo:    .byte 0
oldIrqHi:    .byte 0

tmp:         .byte 0
