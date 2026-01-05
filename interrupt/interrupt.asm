// Kick Assembler C64: install a raster irq "background task" that cycles border color
// returns to basic after installing, so you can keep using basic normally


.const irq_vector_lo = $0314
.const irq_vector_hi = $0315
*=$c000
start:
    sei

    // disable cia interrupts (prevents random extra irqs)
    lda #$7f
    sta $dc0d
    sta $dd0d
    lda $dc0d
    lda $dd0d

    // set raster line (change this if you want)
   // lda #$50
    //sta $d012

    // ensure raster high bit is 0 (bit 7 of $d011)
    lda $d011
    and #$7f
    sta $d011

    // clear any pending raster irq
    lda #$01
    sta $d019

    // enable raster irq
    lda #$01
    sta $d01a

    // install our irq handler
    lda #<irq
    sta irq_vector_lo
    lda #>irq
    sta irq_vector_hi

    cli
    rts              // return to basic (background irq keeps running)

irq:
    // quick effect: cycle border color
    inc color
    lda color
    and #$0f
    sta color
    sta $d020

    // acknowledge raster irq
    lda #$01
    sta $d019

    // chain to kernal irq so basic/keyboard/etc keep working
    jmp $ea31

color:
    .byte $00


