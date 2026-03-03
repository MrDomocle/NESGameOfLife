.segment "CODE"
VRAM_PAL1 = $3F00
VRAM_PAL2 = $3F10

VRAM_TILE_FIRST = $2000
VRAM_TILE_LAST = $21ff

; oam sprite byte offsets
OAM_Y = $0
OAM_TILE = $1
OAM_ATTR = $2
OAM_X = $3

COL_WHITE = $30
COL_BLACK = $0F
COL_ORANGE = $27

Palette:
.byte COL_BLACK, COL_WHITE, COL_ORANGE, COL_WHITE, COL_WHITE, COL_WHITE, COL_WHITE, COL_WHITE, COL_WHITE, COL_WHITE, $00, $00, $00, $00, $00, COL_WHITE
.byte COL_BLACK, COL_WHITE, COL_ORANGE, COL_WHITE, COL_WHITE, COL_WHITE, COL_WHITE, COL_WHITE, COL_WHITE, COL_WHITE, $00, $00, $00, $00, $00, COL_WHITE

.proc ZeroTilemap ; i think this overshoots
  lda #<map_padding1
  sta map_currptr
  lda #>map_padding1
  sta map_currptr+1

  ; load all rows
  ldx #$00
  ldy #$00
  lda #$00
  loop:
    lda #$00
    sta (map_currptr),y ; indirect indexed - add y to pointer, with x would add to pointer's address
    iny
    cpy #MAP_WIDTH
    bne loop
    ; if reached end of row
    inx
    cpx #MAP_HEIGHT*2+3*MAP_WIDTH ; clear both buffers and padding
    beq break
    Add168 map_currptr, MAP_WIDTH
    ldy #$00
    jmp loop
  break:
  
  UndoScroll
  rts
.endproc

.proc ZeroOAM
  lda #$00
  sta PPU_SPR_ADDR
  ldx #00
  loop:
    sta PPU_SPR_IO
    inx
    bne loop
  rts
.endproc

.proc LoadPalette
  ; init transfer to pal 1 vram address
  VRAMTransferInit VRAM_PAL1
  
  ldx #$00
  loop:
    lda Palette,x
    sta PPU_VRAM_IO
    inx
    cpx #$20
  bne loop

  UndoScroll
  rts
.endproc

.proc LoadTilesFull
  jsr ResetMapPointer_Draw

  ; load all rows
  VRAMTransferInit VRAM_TILE_FIRST
  ldx #$00
  ldy #$00
  loop:
    lda (map_currptr),y ; indirect indexed - add y to pointer, with x would add to pointer's address
    sta PPU_VRAM_IO
    iny
    cpy #MAP_WIDTH
    bne loop
    ; if reached end of row
    inx
    cpx #MAP_HEIGHT
    beq break
    Add168 map_currptr, MAP_WIDTH
    ldy #$00
    jmp loop
  break:

  UndoScroll  
  rts
.endproc

; On game frames, update 1 row per frame, increment on each frame.
.proc LoadNextTileRow
  ; reset map_currptr and map_offset
  jsr ResetMapPointer_Draw

  lda #$00
  sta map_offset
  sta map_offset+1

  lda #<VRAM_TILE_FIRST
  sta map_vramptr
  lda #>VRAM_TILE_FIRST
  sta map_vramptr+1
  ; get current frame's last 5 bits (up to 32 - i.e. number of rows)
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

  ; load this row
  VRAMTransferInitOffset map_vramptr, map_offset
  Add1616 map_currptr, map_offset
  ldx #$00
  ldy #$00
  loop:
    lda (map_currptr),y ; indirect indexed - add y to pointer, using x would add to pointer's address
    sta PPU_VRAM_IO
    iny
    cpy #MAP_WIDTH
  bne loop
  UndoScroll
  rts
.endproc

.proc LoadOAM
  ; set address (do i really need to? it should be 0 at nmi anyway)
  lda #$00
  sta PPU_SPR_ADDR

  lda cursor_y
  sta PPU_SPR_IO
  lda #%00010000 ; tile
  sta PPU_SPR_IO
  lda cursor_attr
  sta PPU_SPR_IO
  lda cursor_x
  sta PPU_SPR_IO

  rts
.endproc

.proc InitCursor
  lda #(16*8) ; ~middle of screen
  sta cursor_x
  sta cursor_y
  lda #%00000000
  sta cursor_attr
  rts
.endproc