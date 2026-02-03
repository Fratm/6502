// ============================================================================
//  C64 SPACE INVADERS (Character Mode)
//  Controls: A (Left), D (Right), Space (Fire)
// ============================================================================

// --- Constants ---
.const SCREEN_RAM = $0400       
.const COLOR_RAM  = $D800       
.const RASTER     = $D012       
.const VIC_BORDER = $D020
.const VIC_BG     = $D021
.const CIA1_PRA   = $DC00       
.const CIA1_PRB   = $DC01       

// --- Zero Page ---
.const zp_ptr     = $FB         // Used for screen addressing

// --- Characters ---
.const CHAR_PLAYER = 30         
.const CHAR_ALIEN  = 81         
.const CHAR_BULLET = 102        
.const CHAR_EMPTY  = 32         

// --- Game Settings ---
.const ALIEN_SPEED = 15         // Higher = Slower
.const MAX_ALIENS  = 10         // Number of aliens per row

// --- BASIC Header (10 SYS 2064) ---
* = $0801
.byte $0C, $08, $0A, $00, $9E, $20, $32, $30, $36, $34, $00, $00, $00

* = $0810 // Entry point

// ============================================================================
//  MAIN LOOP
// ============================================================================
Main:
    jsr InitSystem      
    jsr InitGame        

GameLoop:
    jsr WaitFrame       
    
    jsr ErasePlayer     
    jsr HandleInput     
    jsr DrawPlayer      
    
    jsr UpdateBullet    
    jsr UpdateAliens    

    jmp GameLoop        

// ============================================================================
//  SUBROUTINES
// ============================================================================

InitSystem:
    lda #0              
    sta VIC_BORDER
    sta VIC_BG
    
    // Clear Screen and Set Colors
    ldx #0
ClearLoop:
    lda #CHAR_EMPTY
    sta SCREEN_RAM, x
    sta SCREEN_RAM + 250, x
    sta SCREEN_RAM + 500, x
    sta SCREEN_RAM + 750, x
    lda #5              // Green for screen area
    sta COLOR_RAM, x
    sta COLOR_RAM + 250, x
    sta COLOR_RAM + 500, x
    sta COLOR_RAM + 750, x
    dex
    bne ClearLoop
    rts

InitGame:
    lda #20             
    sta player_x
    lda #0
    sta bullet_active
    sta alien_x_offset
    sta alien_y_offset
    sta alien_dir
    lda #ALIEN_SPEED
    sta alien_timer

    // Initialize Alien Array (all 1 = alive)
    ldx #0
    lda #1
InitArr:
    sta alien_alive, x
    inx
    cpx #MAX_ALIENS * 2 // 2 rows
    bne InitArr
    rts

WaitFrame:
    lda #250
WaitL1:
    cmp RASTER
    bne WaitL1
    rts

// --- Movement & Input ---
HandleInput:
    lda #$FD            // Scan Row 2 (includes A and D)
    sta CIA1_PRA
    lda CIA1_PRB
    
    // Check 'A' (Bit 2)
    and #$04        
    bne CheckRight  
    lda player_x
    beq CheckRight      // Edge check
    dec player_x

CheckRight:
    lda #$FB            // Scan Row 2
    sta CIA1_PRA
    lda CIA1_PRB
    and #$04
    bne CheckFire
    lda player_x
    cmp #39
    beq CheckFire       // Edge check
    inc player_x

CheckFire:
    lda #$7F            // Scan Row 4 (Space)
    sta CIA1_PRA
    lda CIA1_PRB
    and #$10
    bne InputDone
    
    lda bullet_active
    bne InputDone       
    lda #1              // Fire!
    sta bullet_active
    lda player_x
    sta bullet_x
    lda #23             
    sta bullet_y
InputDone:
    rts

ErasePlayer:
    ldy #24             // Row
    ldx player_x        // Col
    jsr GetScreenPos
    lda #CHAR_EMPTY
    ldy #0
    sta (zp_ptr), y
    rts

DrawPlayer:
    ldy #24
    ldx player_x
    jsr GetScreenPos
    lda #CHAR_PLAYER
    ldy #0
    sta (zp_ptr), y
    rts

// --- Bullet Logic ---
UpdateBullet:
    lda bullet_active
    beq BulletExit      

    // 1. Erase old
    ldy bullet_y
    ldx bullet_x
    jsr GetScreenPos    
    lda #CHAR_EMPTY
    ldy #0
    sta (zp_ptr), y     

    // 2. Move
    dec bullet_y
    lda bullet_y
    bmi KillBullet      

    // 3. Collision Check
    ldy bullet_y
    ldx bullet_x
    jsr GetScreenPos    
    ldy #0
    lda (zp_ptr), y     
    cmp #CHAR_EMPTY
    beq DrawBullet      
    
    // HIT! Find which alien was hit (simplified: just erase character)
    lda #CHAR_EMPTY 
    sta (zp_ptr), y
    
KillBullet:
    lda #0
    sta bullet_active
    rts

DrawBullet:
    lda #CHAR_BULLET
    sta (zp_ptr), y
BulletExit:
    rts

// --- Alien Logic ---
UpdateAliens:
    dec alien_timer
    lda alien_timer
    beq DoAlienMove
    rts

DoAlienMove:
    lda #ALIEN_SPEED
    sta alien_timer

    jsr EraseAlienBlock

    lda alien_dir
    beq MoveRight
MoveLeft:
    dec alien_x_offset
    lda alien_x_offset
    beq HitLeft
    jmp FinishAlien
HitLeft:
    lda #0
    sta alien_dir
    inc alien_y_offset
    jmp FinishAlien
MoveRight:
    inc alien_x_offset
    lda alien_x_offset
    cmp #15             // Max shift right
    beq HitRight
    jmp FinishAlien
HitRight:
    lda #1
    sta alien_dir
    inc alien_y_offset

FinishAlien:
    jsr DrawAlienBlock
    rts

EraseAlienBlock:
    lda #CHAR_EMPTY
    sta temp_char
    jmp RunAlienLoop

DrawAlienBlock:
    lda #CHAR_ALIEN
    sta temp_char

RunAlienLoop:
    ldx #0              // Alien counter
AlienLoop:
    stx temp_x_reg
    
    // Calculate X = (X * 2) + offset + 5
    txa
    asl                 // spacing
    clc
    adc alien_x_offset
    adc #5
    sta temp_col
    
    // Row 1
    lda alien_y_offset
    clc
    adc #2              // Row 2 start
    tay
    ldx temp_col
    jsr GetScreenPos
    lda temp_char
    ldy #0
    sta (zp_ptr), y

    // Row 2
    lda alien_y_offset
    clc
    adc #4              // Row 4 start
    tay
    ldx temp_col
    jsr GetScreenPos
    lda temp_char
    ldy #0
    sta (zp_ptr), y

    ldx temp_x_reg
    inx
    cpx #MAX_ALIENS
    bne AlienLoop
    rts

// --- Helper: Address calculation ---
// Y = Row (0-24), X = Col (0-39)
GetScreenPos:
    stx temp_hold_x
    lda #$04            // High byte Screen RAM
    sta zp_ptr+1
    lda #0
    sta zp_ptr
    
    cpy #0
    beq AddX
RowAdd:
    clc
    lda zp_ptr
    adc #40
    sta zp_ptr
    lda zp_ptr+1
    adc #0
    sta zp_ptr+1
    dey
    bne RowAdd
AddX:
    clc
    lda zp_ptr
    adc temp_hold_x
    sta zp_ptr
    lda zp_ptr+1
    adc #0
    sta zp_ptr+1
    ldx temp_hold_x     // Restore X
    rts

// ============================================================================
//  DATA STORAGE
// ============================================================================
player_x:       .byte 0
bullet_active:  .byte 0
bullet_x:       .byte 0
bullet_y:       .byte 0

alien_x_offset: .byte 0
alien_y_offset: .byte 0
alien_dir:      .byte 0         // 0=R, 1=L
alien_timer:    .byte 0
alien_alive:    .fill 20, 0     // State tracking (unused in this simple version)

temp_x_reg:     .byte 0
temp_col:       .byte 0
temp_char:      .byte 0
temp_hold_x:    .byte 0

