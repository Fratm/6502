.const SCREEN = $0400
.const ROWS   = 25
.const COLS   = 40

* = $0801
BasicUpstart2(WipeLeft)   // small BASIC stub at $0801

// sys49152  will wipe the screen and home the cursor.
* = $C000



WipeLeft:
    // preserve zp ptr used by basic/kernal
    lda $fb
    pha
    lda $fc
    pha

    ldx #40              // do 40 shifts

WipeLoop:
    sei
    jsr ShiftScreenLeft 
    cli
    dec wipeCount
    bne WipeLoop
    ldx #40          // Reset the wipeCount so we can run it again
    stx wipeCount
    lda #$13        // Lets home the cursor
    jsr $FFD2

    // restore zp ptr
    pla
    sta $fc
    pla
    sta $fb

    rts             // DONE!

// Shift left by 1, fill column 39 with space
ShiftScreenLeft:
    ldx #0                      // row = 0..24

RowLoop:
    // Compute row base address = SCREEN + row*40
    // Put it in zp ptr ($fb/$fc)
    lda RowLo,x
    sta $fb
    lda RowHi,x
    sta $fc

    ldy #0                      // col = 0..38
ColLoop:
    lda ($fb),y                 // read col
    iny
    lda ($fb),y                 // read col+1
    dey
    sta ($fb),y                 // write into col
    iny
    cpy #39                     // stop after shifting col 0..38
    bne ColLoop

    ldy #39
    lda #$20                    // space
    sta ($fb),y                 // clear last column

    inx
    cpx #ROWS
    bne RowLoop

    rts

wipeCount: .byte 40
tmpfb: .byte 00
tmpfc: .byte 00



// ------------------------------------------------------------------
// Row address tables for SCREEN + row*40
// ------------------------------------------------------------------
RowLo:
    .for (var r=0; r<ROWS; r++) {
        .byte <(SCREEN + r*COLS)
    }

RowHi:
    .for (var r=0; r<ROWS; r++) {
        .byte >(SCREEN + r*COLS)
    }

