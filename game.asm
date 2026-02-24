.segment "CODE"

birth_table: .byte $00, $00, $00, $0f, $00, $00, $00, $00, $00, $00
survive_table: .byte $00, $00, $0f, $0f, $00, $00, $00, $00, $00, $00

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
  tax
  beq noskip ; don't run loop if result 0 - no offset
  skipping_loop:
    Add168 map_offset, MAP_WIDTH
    dex
    cpx #$00
  bne skipping_loop
  noskip:
  
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

AddNeighbour:
  inc curr_neighbours
  rts
.endproc