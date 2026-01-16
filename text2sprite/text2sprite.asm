// -----------------------------------------------------------------------------
// POKE $0400, <lettercode> then SYS 49152
// Reads the character from screen RAM and makes sprite 0 look like it.
// (Glyph is 8x8 placed at top-left of 24x21 sprite; rest blank)
//
// Assemble to a PRG. Code is at $C000 (49152).
// Sprite data is in VIC bank 0 at $3000.
// -----------------------------------------------------------------------------

* = $0801
    .word nextLine
    .word 10
    .byte $80      // END
nextLine:
    .word 0

// -----------------------------------------------------------------------------
// Constants
.const SCREEN      = $0400
.const SPRPTRS     = $07F8

.const CIA2_PRA    = $DD00

.const VIC_SPR_EN  = $D015
.const VIC_SPR0_X  = $D000
.const VIC_SPR0_Y  = $D001
.const VIC_SPR_XMSB= $D010
.const VIC_SPR_EXPX= $D01D
.const VIC_SPR_EXPY= $D017
.const VIC_SPR_MC  = $D01C

.const VIC_SPR0_COL= $D027

.const CPU_PORT    = $0001

.const SPRITE_ADDR = $3000          // must be in current VIC bank
.const SPRITE_PTR  = (SPRITE_ADDR / 64)  // pointer value written to $07F8

// -----------------------------------------------------------------------------
// Code at $C000 (49152)
* = $C000

start:
    sei

    // Ensure VIC bank = 0 ($0000-$3FFF) so sprite at $3000 is visible
    // CIA2 $DD00 bits 0-1: 11=bank0, 10=bank1, 01=bank2, 00=bank3
    lda CIA2_PRA
    and #%11111100
    ora #%00000011
    sta CIA2_PRA

    // Read the "letter" from top-left screen cell
    lda SCREEN
    sta charValue

    // Optional: if user POKEs ASCII letters (65-90 or 97-122),
    // convert to C64 screen code.
    jsr asciiToScreenCode

    // Build sprite bitmap from CHAR ROM
    jsr buildSpriteFromChar

    // Point sprite 0 at our sprite data
    lda #SPRITE_PTR
    sta SPRPTRS

    // Sprite settings
    lda VIC_SPR_MC
    and #%11111110
    sta VIC_SPR_MC          // sprite0 = hires

    lda VIC_SPR_EXPX
    and #%11111110
    sta VIC_SPR_EXPX        // no x expand

    lda VIC_SPR_EXPY
    and #%11111110
    sta VIC_SPR_EXPY        // no y expand

    lda VIC_SPR_XMSB
    and #%11111110
    sta VIC_SPR_XMSB        // x < 256

    // Position sprite somewhere visible
    lda #120
    sta VIC_SPR0_X
    lda #60
    sta VIC_SPR0_Y

    // Color
    lda #$01                // white
    sta VIC_SPR0_COL

    // Enable sprite 0
    lda VIC_SPR_EN
    ora #%00000001
    sta VIC_SPR_EN

    cli
    rts

// -----------------------------------------------------------------------------
// Convert ASCII letters to screen codes (only for A-Z / a-z)
// If not in those ranges, leaves value as-is.
asciiToScreenCode:
    lda charValue

    // 'A'..'Z' = 65..90 -> screen code 1..26 (subtract 64)
    cmp #65
    bcc !done+
    cmp #91
    bcs !checkLower+
    sec
    sbc #64
    sta charValue
    rts

!checkLower:
    // 'a'..'z' = 97..122 -> screen code 1..26 (subtract 96)
    lda charValue
    cmp #97
    bcc !done+
    cmp #123
    bcs !done+
    sec
    sbc #96
    sta charValue
!done:
    rts

// -----------------------------------------------------------------------------
// Build sprite data at SPRITE_ADDR from CHAR ROM glyph
// Uses charValue as screen code -> offset = code*8
//
// Sprite format: 21 rows, 3 bytes per row.
// We copy 8 rows of glyph into the first byte of first 8 sprite rows.
// Remaining bytes/rows are cleared.
buildSpriteFromChar:
    // Clear entire sprite (63 bytes)
    ldx #0
    lda #0
!clr:
    sta SPRITE_ADDR,x
    inx
    cpx #63
    bne !clr-

    // Map CHAR ROM in at $D000 by turning off I/O (CHAREN=0)
    lda CPU_PORT
    sta savedPort
    lda #$35
    sta CPU_PORT

    // Compute source pointer = $D000 + (charValue * 8)
    lda charValue
    asl
    asl
    asl                 // A = code*8
    sta srcLo
    lda #$D0
    adc #0              // carry from shifts (always 0 here, but safe pattern)
    sta srcHi

    // Copy 8 bytes (8 rows) into sprite rows 0..7, byte0 of each row
    ldy #0              // glyph row
    ldx #0              // sprite write offset (row*3)

!copy8:
    lda (srcLo),y
    sta SPRITE_ADDR,x   // first byte of sprite row
    iny
    txa
    clc
    adc #3              // next sprite row (3 bytes per row)
    tax
    cpy #8
    bne !copy8-

    // Restore I/O mapping
    lda savedPort
    sta CPU_PORT

    rts

// -----------------------------------------------------------------------------
// Zero-page pointers / vars
srcLo:      .byte 0
srcHi:      .byte 0

// Regular vars
charValue:  .byte 0
savedPort:  .byte 0
