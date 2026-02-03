// COMMODORE 64 SMOOTH SCROLLING DEMO
// FORMATTED and DOCUMENTED VERSION
// Converted for kickassmbler by Fratm 02/03/2026

* = $1000    // staRT ADDRESS AT $1000 (4096)

// ============================================
// INITIALIZATION ROUTINE
// ============================================

          lda  #$00 
          sta  $D020       // SET BORDER COLOR TO BLACK (53280)
          sta  $D021       // SET BACKGROUND COLOR TO BLACK (53281)
          lda  #21
          sta  53272       // SET CHARACTER SET MEMORY LOCATION

          lda  #$93        // CLEAR SCREEN CHARACTER
          jsr  $FFD2       // CALL KERNAL ROUTINE TO OUTPUT CHARACTER
          
          lda  #$00
          sta  OFFSET      // INITIALIZE COLOR CYCLE OFFSET
         
          jsr  RESET       // INITIALIZE SCROLL TEXT POINTER
          
          // DISPLAY TITLE PAGE
          lda  #<INTRO    // LOW BYTE OF INTRO TEXT ADDRESS
          ldy  #>INTRO    // HIGH BYTE OF INTRO TEXT ADDRESS
          jsr  $AB1E       // KERNAL STRING PRINT ROUTINE (255 CHARS MAX)
          
          // SETUP INTERRUPT SYSTEM
          sei              // DISABLE INTERRUPTS
          lda  #$01        
          sta  $DC0D       // DISABLE CIA #1 TIMER INTERRUPTS
          sta  $D01A       // ENABLE VIC RASTER INTERRUPTS
          
          lda  #<IRQ      // LOW BYTE OF IRQ HandLER
          sta  $0314       // SET INTERRUPT VECTOR LOW BYTE
          lda  #>IRQ      // HIGH BYTE OF IRQ HandLER
          sta  $0315       // SET INTERRUPT VECTOR HIGH BYTE
          lda  #$30        // RASTER LINE $30 (48)
          sta  $D012       // SET RASTER COMPARE REGISTER
         
          lda  #$1B        // %00011011
          sta  $D011       // SET SCREEN CONTROL REGISTER
          cli              // ENABLE INTERRUPTS
          
LOOP1:        
        jmp  LOOP1           // INFINITE LOOP - MAIN PROGRAM WAITS HERE

// ============================================
// INTERRUPT HandLER #1 - TOP OF SCREEN
// ============================================

IRQ:
          lda  #$01
          sta  $D019       // ACKNOWLEDGE RASTER INTERRUPT

          lda  #200        // NORMAL HORIZONTAL SCROLL VALUE
          sta  53270       // $D016 - HORIZONTAL SCROLL REGISTER
          
          lda  #<IRQ2     // CHAIN TO NEXT INTERRUPT HandLER
          sta  $0314
          lda  #>IRQ2
          sta  $0315
          
          lda  #$83        // RASTER LINE $83 (131)
          sta  $D012       // SET NEXT RASTER INTERRUPT POSITION
          
          jmp  $EA81       // JUMP TO KERNAL IRQ EXIT ROUTINE

// ============================================
// INTERRUPT HandLER #2 - FIRST COLOR BAR
// ============================================
          
IRQ2:
          lda  #$01
          sta  $D019       // ACKNOWLEDGE INTERRUPT
          
          ldx  #$00        // INITIALIZE COLOR INDEX
LOOP:     ldy  COLOURBAR1, X  // LOAD COLOR VALUE FROM TABLE
          lda  $D012       // READ CURRENT RASTER LINE

WAIT:      cmp  $D012       // WAIT FOR RASTER LINE TO ADVANCE
          beq  WAIT        // LOOP UNTIL RASTER MOVES
          
          sty  $D020       // SET BORDER COLOR
          sty  $D021       // SET BACKGROUND COLOR
          
          inx              // incREMENT COLOR INDEX
          cpx  #$05        // CHECK IF ALL 5 COLORS DISPLAYED
          bne  LOOP        // CONTINUE IF NOT DONE
 
          lda  PIX         // GET CURRENT SCROLL POSITION
          sta  53270       // $D016 - SET HORIZONTAL SCROLL
          
          lda  #<IRQ3     // CHAIN TO NEXT INTERRUPT HandLER
          sta  $0314
          lda  #>IRQ3
          sta  $0315
          lda  #$B3        // RASTER LINE $B3 (179)
          sta  $D012
          jmp  $EA81       // EXIT TO KERNAL

// ============================================
// INTERRUPT HandLER #3 - SECOND COLOR BAR
// ============================================

IRQ3:
          lda  #$01
          sta  $D019       // ACKNOWLEDGE INTERRUPT
          
          ldx  #$00        // INITIALIZE COLOR INDEX
LOOP2:     ldy  COLOURBAR2, X  // LOAD COLOR VALUE FROM TABLE
          lda  $D012       // READ CURRENT RASTER LINE

WAIT2:     cmp  $D012       // WAIT FOR RASTER LINE TO ADVANCE
          beq  WAIT2       // LOOP UNTIL RASTER MOVES
          
          sty  $D020       // SET BORDER COLOR
          sty  $D021       // SET BACKGROUND COLOR
          
          inx              // incREMENT COLOR INDEX
          cpx  #$05        // CHECK IF ALL 5 COLORS DISPLAYED
          bne  LOOP2       // CONTINUE IF NOT DONE
 
          lda  #200        // RESET TO NORMAL SCROLL VALUE
          sta  53270       // $D016
          
          jsr  SCROLL      // UPDATE SCROLL POSITION
          jsr  FADER       // UPDATE COLOR CYcliNG
          
          
          lda  #<IRQ      // CHAIN BACK TO FIRST INTERRUPT
          sta  $0314
          lda  #>IRQ
          sta  $0315
          lda  #$30        // RASTER LINE $30 (48)
          sta  $D012
          jmp  $EA31       // EXIT TO KERNAL

// ============================================
// SCROLL ROUTINE - SMOOTH HORIZONTAL SCROLL
// ============================================

SCROLL:
          dec  PIX         // decREASE PIXEL POSITION
          lda  PIX
          cmp  #$BF        // CHECK IF AT BOUNDARY
          bne  EXIT        // IF NOT, EXIT
          lda  #$C7        // RESET PIXEL POSITION
          sta  PIX
          
          // SHIFT SCREEN CHARACTERS LEFT
          ldx  #$00
LOOP3:     lda  $0609, X    // READ CHARACTER FROM POSITION+1
          sta  $0608, X    // WRITE TO CURRENT POSITION
          inx
          cpx  #$27        // 39 CHARACTERS (SCREEN WIDTH)
          bne  LOOP3
          
          // GET NEXT CHARACTER FROM SCROLL TEXT
          ldy  #$00  
          lda  ($BB), Y    // READ FROM TEXT POINTER
          cmp  #$00        // CHECK FOR END OF TEXT
          beq  RESET       // RESET IF AT END
          and  #63         // CONVERT TO SCREEN CODE
          sta  $0608 + 39  // PLACE AT RIGHT EDGE OF SCREEN
          
          inc  $BB         // incREMENT TEXT POINTER LOW BYTE
          bne  EXIT        // IF NO CARRY, EXIT
          inc  $BC         // incREMENT TEXT POINTER HIGH BYTE
          
EXIT:
          rts

// ============================================
// RESET SCROLL TEXT POINTER
// ============================================

RESET:
          lda  #<SCROLLTEXT  // LOW BYTE OF SCROLL TEXT
          sta  $BB            // SET POINTER LOW BYTE
          lda  #>SCROLLTEXT  // HIGH BYTE OF SCROLL TEXT
          sta  $BC            // SET POINTER HIGH BYTE
          rts

// ============================================
// COLOR FADER ROUTINE
// ============================================
      
FADER:
          inc  DELAY       // incREMENT DELAY COUNTER
          lda  DELAY
          cmp  #6          // CHECK IF DELAY REACHED
          bne  Exit           // IF NOT, EXIT
          lda  #$00        // RESET DELAY
          sta  DELAY

          ldx  OFFSET      // GET CURRENT COLOR OFFSET
          lda  COLOUR, X   // LOAD COLOR FROM TABLE
          sta  FLASH       // STORE IN FLASH COLOR
          inc  OFFSET      // NEXT COLOR
          lda  OFFSET
          cmp  #8          // CHECK IF AT END OF COLOR TABLE
          bne  Exit           // IF NOT, EXIT
          lda  #$00        // RESET OFFSET
          sta  OFFSET
Exit:         rts

// ============================================
// DATA TABLES
// ============================================

COLOUR:    .byte 6,14,3,1,3,14,6,0  // COLOR CYCLE TABLE

COLOURBAR1:
          .byte  $09, $08, $07, $01  // ORANGE, BROWN, YELLOW, WHITE
FLASH:    .byte  $00                // DYNAMIC FLASH COLOR
          
OFFSET:    .byte 0                  // COLOR CYCLE OFFSET

COLOURBAR2:
          .byte $01, $07, $08, $09, $00  // WHITE, YELLOW, BROWN, ORANGE, BLACK
          
PIX:       .byte $C7                // CURRENT PIXEL SCROLL POSITION

DELAY:     .byte 0                  // FADER DELAY COUNTER

// ============================================
// TEXT DATA
// ============================================

INTRO:
          .text "WELCOME TO MY NEW SMOOTH SCROLLER"
          .byte $0D,$0D    // CARRIAGE RETURNS
          .text "I HOPE YOU LIKE IT"
          .byte $08,$00    // CURSOR UP, STRING TERMINATOR
          
SCROLLTEXT:
          .text " WELCOME TO MY NEW DEMO. THIS SHOULD APPEAR VERY SMOOTH"
          .text "                            "  // SPACING
          .byte $00        // END OF TEXT MARKER