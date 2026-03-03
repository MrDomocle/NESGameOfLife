RULES = $601 ; $c179 for city, $601 for gol

.define CURSOR_SPEED 2
.define CLEAR_TIMEOUT 180 ; how many frames to hold down select for clearing screen

.segment "CODE"

.if RULES = $c179 ; city
birth_table: .byte $00, $00, $00, $00, $01, $01, $01, $01, $01
survive_table: .byte $00, $00, $01, $01, $01, $01, $00, $00, $00
.endif
.if RULES = $601 ; gol
birth_table: .byte $00, $00, $00, $01, $00, $00, $00, $00, $00
survive_table: .byte $00, $00, $01, $01, $00, $00, $00, $00, $00
.endif

.proc TickRow

.segment "BSS"
tmp: .res 1
; neighbour tiles
t00: .res 1
t01: .res 1
t02: .res 1
t10: .res 1
t11: .res 1
t12: .res 1
t20: .res 1
t21: .res 1
t22: .res 1
; neighbour counts
nb: .res 4 ; bottom right, bottom left, top left, top right

alive_in_curr: .res 1

.segment "CODE"
  jsr ResetMapPointer_Calculate

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
  loop: ; calculate a single 2x2 cell tile
    lda (map_currbuff),y
    sta tmp
    ; count live cells in current tile
    .repeat 4
    ror tmp ; shift rightmost bit into carry
    sta tmp
    lda #$00
    adc alive_in_curr ; add to 0 to include carry
    sta alive_in_curr
    lda tmp
    .endrepeat

    ; load neighbour tiles for easier access

    ClampY $1f
    lda (map_prevptr),y
    sta t01
    lda (map_currptr),y
    sta t11
    lda (map_nextptr),y
    sta t21

    dey
    ClampY $1f
    lda (map_prevptr),y
    sta t00
    lda (map_currptr),y
    sta t10
    lda (map_nextptr),y
    sta t20

    iny
    iny
    ClampY $1f
    lda (map_prevptr),y
    sta t02
    lda (map_currptr),y
    sta t12
    lda (map_nextptr),y
    sta t22

    ; restore y
    dey
    ClampY $1f

    ; count neighbours per cell

    lda alive_in_curr
    ; copy as initial neighbour count
    sta nb+0
    sta nb+1
    sta nb+2
    sta nb+3
    
    ; subtract considered cell
    lda t11
    and #%0000001
    beq next_nb1
      dec nb+0 ; decrease neighbour count if this cell is live (don't count twice)
    next_nb1:
    lda t11
    and #%00000010
    beq next_nb2
      dec nb+1
    next_nb2:
    lda t11
    and #%00000100
    beq next_nb3
      dec nb+2
    next_nb3:
    lda t11
    and #%00001000
    beq next_others
      dec nb+3
    next_others:
    
    ; cells that only neighbour one considered cell
    Increment1NB t00, %00000001, nb+2
    Increment1NB t02, %00000010, nb+3
    Increment1NB t20, %00001000, nb+1
    Increment1NB t22, %00000100, nb+0

    ; others
    Increment2NB t01, %00000001, nb+2, nb+3
    Increment2NB t01, %00000010, nb+2, nb+3

    Increment2NB t10, %00000001, nb+1, nb+2 
    Increment2NB t10, %00001000, nb+1, nb+2
    
    Increment2NB t12, %00000010, nb+0, nb+3
    Increment2NB t12, %00000100, nb+0, nb+3

    Increment2NB t21, %00000100, nb+0, nb+1
    Increment2NB t21, %00001000, nb+0, nb+1
    
    .repeat 4, I
    .scope
    ldx nb+I
    lda t11
    and #1<<I
    beq birth
    survive:
      lda survive_table,x
      jmp apply
    birth:
      lda birth_table,x
    apply:
    ; move into corresponding spot
    .repeat I
      clc
      rol
    .endrepeat
    ora (map_otherbuffptr),y
    sta (map_otherbuffptr),y
    .endscope
    .endrepeat

    iny
    cpy #MAP_WIDTH
  beq break
  jmp loop
  break:

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