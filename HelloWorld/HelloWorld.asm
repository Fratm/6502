// Initialize constants
.const SCREEN_WIDTH = 40
.const MESSAGE_LENGTH = 12
.const ROW_TO_PRINT = 12
.const START_COLUMN = (SCREEN_WIDTH - MESSAGE_LENGTH) / 2
.const SCREEN_START = $0400
.const ROW_OFFSET = (ROW_TO_PRINT - 1) * SCREEN_WIDTH + START_COLUMN

// Basic upstart sequence
* = $0801
    .word $0810
    .word $0801
    .byte $9E
    .text "2064"
    .byte 0, 0

* = $0810
    sei // Disable interrupts

    ldx #0 // Initialize X register to index the message characters

// Begin printing the message at the calculated position
print_loop:
    lda message, x // Load each character of the message
    beq done       // If it's the end of the message (0), we're done
    // Calculate the position and store the character
    sta SCREEN_START + ROW_OFFSET, x
    inx            // Move to the next character
    cpx #MESSAGE_LENGTH // Compare X with the length of the message
    bne print_loop // If not done, loop back

done:
    cli // Re-enable interrupts
    rts // Return from subroutine

// Define the message to be displayed
message:
    .text "hello world!"
    .byte 0 // Null terminator
