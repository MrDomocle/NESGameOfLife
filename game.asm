RULES = $601 ; $c179 for city, $601 for gol

.define CURSOR_SPEED 2
.define CLEAR_TIMEOUT 180 ; how many frames to hold down select for clearing screen

.segment "CODE"

.if RULES = $c179 ; city
birth_table: .byte $00, $00, $00, $00, $0f, $0f, $0f, $0f, $0f
survive_table: .byte $00, $00, $0f, $0f, $0f, $0f, $00, $00, $00
.endif
.if RULES = $601 ; gol
birth_table: .byte $00, $00, $00, $0f, $00, $00, $00, $00, $00
survive_table: .byte $00, $00, $0f, $0f, $00, $00, $00, $00, $00
.endif

.proc TickRow

.segment "ZEROPAGE"
curr_neighbours: .res 1

.segment "CODE"
  jsr ResetMapPointer_Calculate

  lda #$00
  sta map_offset
  sta map_offset+1

  ; last 5 bits of frame = row
  lda frame
  and #$1f
  ; skip however many rows there are in accumulator - A*MAP_WIDTH bytes
  sta map_offset ; low
  lda #$00
  sta map_offset+1 ; high
  .repeat 5 ; shift whole word 5 times for x32
    clc
    rol map_offset
    rol map_offset+1 ; should absolutely not make carry 1
  .endrepeat
  
  ;tick
  Add1616 map_currptr, map_offset
  Add1616 map_otherbuffptr, map_offset
  ; copy current to next and prev
  lda map_currptr
  sta map_nextptr
  sta map_prevptr
  lda map_currptr+1
  sta map_nextptr+1
  sta map_prevptr+1
  
  ; actually make them next and prev to current
  Add168 map_nextptr, MAP_WIDTH
  Sub168 map_prevptr, MAP_WIDTH-1

  ldy #$00
  loop:
    ; neighbour count stored in x
    ldx #$00
    
    next00:
    dey
    ClampY $1f
    lda (map_prevptr),y ; x is added to pointer's address to access curr and next
    beq next01
      inx
    next01:
    iny
    ClampY $1f
    lda (map_prevptr),y
    beq next02
      inx
    next02:
    iny
    ClampY $1f
    lda (map_prevptr),y
    beq next10
      inx

    next10:
    dey
    dey
    ClampY $1f
    lda (map_currptr),y ; x is added to pointer's address to access curr and next
    beq next12
      inx
    ; skip middle cell
    next12:
    iny
    iny
    ClampY $1f
    lda (map_currptr),y
    beq next20
      inx

    next20:
    dey
    dey
    ClampY $1f
    lda (map_nextptr),y ; x is added to pointer's address to access curr and next
    beq next21
      inx
    next21:
    iny
    ClampY $1f
    lda (map_nextptr),y
    beq next22
      inx
    next22:
    iny
    ClampY $1f
    lda (map_nextptr),y
    beq counted
      inx

    counted:
    dey
    ClampY $1f
    
    lda (map_currptr),y
    beq birth
    survive:
      lda survive_table,x
      jmp done
    birth:
      lda birth_table,x
    
    done:
    sta (map_otherbuffptr),y

    iny
    cpy #MAP_WIDTH
  bne loop

  rts
.endproc

.proc ClearMap
  ; disable NMI & rendering
  lda #$00
  sta PPU_CTRL1
  sta PPU_CTRL2

  ; zero out
  jsr ZeroTilemap
  ; fix oam
  jsr InitCursor

  ; re-enable
  lda #$80 ; enable nmi
  sta PPU_CTRL1
  lda #$18 ; 08 to enable bg rendering + 10 to enable sprites
  sta PPU_CTRL2
  rts
.endproc

.proc GetCursorCoords
  lda cursor_x
  ; divide by 8 - get tile coordinates
  lsr
  lsr
  lsr
  sta cursor_tile_x

  lda cursor_y
  lsr
  lsr
  lsr
  sta cursor_tile_y

  rts
.endproc

; Put accumulator value at coordinates in cursor_tile_x/y
.proc ModifyCursorTile
  pha ; save value to stack
  jsr ResetMapPointer_Calculate ; make sure pointer is in the right place

  ; skip y rows - y*MAP_WIDTH(i.e. 32) bytes
  lda cursor_tile_y
  sta map_offset ; low
  lda #$00
  sta map_offset+1 ; high
  .repeat 5 ; shift whole word 5 times for x32
    clc
    rol map_offset
    rol map_offset+1 ; should absolutely not make carry 1
  .endrepeat

  Add1616 map_currptr, map_offset
  Add1616 map_otherbuffptr, map_offset

  ldy cursor_tile_x ; load x coordinate into y register because 6502 is stoopid
  
  ; put initial accumulator value into the found cell
  pla
  sta (map_currptr),y
  sta (map_otherbuffptr),y

  rts
.endproc

.proc InputHandler
  ; read controller
  lda #$01
  sta APU_PAD1
  lda #$00
  sta APU_PAD1
  
  ; back up joy
  lda joy
  sta joy_old
  
  ldx #$08
  lda #$00
  clc
  loop:
    lda APU_PAD1
    lsr
    rol joy
    dex
  bne loop
  
  ; find up & down buttons
  lda joy_old
  eor joy ; changed inputs
  
  and joy ; active now - down
  sta joy_down
  
  ; 1 cycle faster to do this again on zp than push and pull value from stack
  lda joy_old
  eor joy
  
  and joy_old ; active before - up
  sta joy_up
  
  ; do stuff with inputs
  lda joy_down
  
  ; PAUSING MECHANISM - which map buffer is used for what
  ; map     map1
  ; draw    calc
  ;    PAUSE
  ; calc    draw   - to always draw latest buffer
  ;   UNPAUSE
  ; draw    calc

  and #JOY_START
  beq start_end
    lda game_state
    beq paused
      lda #$01
      sta game_state
      jmp start_end
    paused:
      lda #$02
      sta game_state
  start_end:

  ; edit
  jsr GetCursorCoords ; update cursor coords
  lda joy ; keep placing as long as pressed
  and #JOY_A
  beq not_place
    lda #$0f
    jsr ModifyCursorTile
    jmp edit_end
  not_place:
  lda joy
  and #JOY_B
  beq edit_end
    lda #$00
    jsr ModifyCursorTile
  edit_end:
  
  ; clear screen timer
  lda joy
  and #JOY_SELECT
  beq no_select
    inc clear_time
    lda clear_time
    cmp #CLEAR_TIMEOUT
    bne clear_end
      jsr ClearMap
      jmp clear_end
  no_select:
    lda #$00
    sta clear_time
  clear_end:


  ; cursor movement
  lda joy
  and #JOY_LEFT
  beq left_end
  .repeat CURSOR_SPEED
    dec cursor_x
  .endrepeat
  left_end:
  lda joy
  and #JOY_RIGHT
  beq right_end
  .repeat CURSOR_SPEED
    inc cursor_x
  .endrepeat
  right_end:
  lda joy
  and #JOY_UP
  beq up_end
  .repeat CURSOR_SPEED
    dec cursor_y
  .endrepeat
  up_end:
  lda joy
  and #JOY_DOWN
  beq down_end
  .repeat CURSOR_SPEED
    inc cursor_y
  .endrepeat
  down_end:

  rts
.endproc