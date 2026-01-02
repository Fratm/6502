// A simple scroller  -- Written by Fratm and yes, I know it sucks. 

// Constance
    .const FARRIGHT = $0427
    .const HOME = $0400
    .const HOME2 = $0401

* = $0801
    .word $0810
    .word $0801
    .byte $9E
    .text "2064"
    .byte 0, 0

* = $0810
    ldx #0 // Initialize X register to index the message characters

print_loop:
    lda message, x // Load each character of the message
    cmp #$00
    beq done       // If it's the end of the message (0), we're done
    // Calculate the position and store the character
    sta FARRIGHT
    inx            // Move to the next character
    jsr scrollleft
    jmp print_loop

done: 
    //ldx $d020
    //inx
    //stx $d020
    ldx #$00
doneloop:    // Scrolls all the text off the screen
    jsr scrollleft
    inx
    cpx #$28   // need to do it 40 times to get everything.
    bne doneloop
    nop

// Scroll everything 1 byte to the left
scrollleft:  stx bufferx  // Preserve the x reg so we can use it in this loop
            ldx #00      // set x to zero for loop 
loop2:      lda HOME2, x  // lets copy everyting over one byte 
            sta HOME, x  //
            inx           // increase x for the loop 
            cpx #$27       // See if we did all 40 characters
            bne loop2    // if not continue the loop  
            ldx bufferx // we are done so restore the x register before returning
            ldy #$20     // Let's clear the far right spot so we don't get double characters
            sty FARRIGHT
            jsr delay
            rts

delay:
    stx bufferx
    sty buffery
    ldx #$A0          // Set X to a high value for the outer loop
outerLoop:
    ldy #$A0          // Set Y to a high value for the inner loop
innerLoop:
    dey               // Decrement Y
    bne innerLoop     // Continue the inner loop until Y is 0
    dex               // Decrement X after the inner loop completes
    bne outerLoop     // Continue the outer loop until X is 0
    ldx bufferx
    ldy buffery
    rts               // Return from subroutine

message:
    .text "hello world!  this is a simple scroller written by fratm!  ya this is awesome! "
    .byte 0,0,0 // Null terminator

// buffer's x y and a -- Probably not needed, but I always felt it was good to protect your registers.

bufferx: .byte 00
buffery: .byte 00
buffera: .byte 00





