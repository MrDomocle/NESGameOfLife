.proc ResetMapPointer_Draw
  ; prepare bss offset
  lda map_currbuff
  bne second_buffer

  first_buffer:
  lda #<map
  sta map_currptr
  lda #>map
  sta map_currptr+1
  jmp buffer_done
  second_buffer:
  lda #<map1
  sta map_currptr
  lda #>map1
  sta map_currptr+1
  buffer_done:
  rts
.endproc

.proc ResetMapPointer_Calculate
  ; prepare bss offset
  lda map_currbuff
  beq second_buffer

  first_buffer:
  lda #<map
  sta map_currptr
  lda #>map
  sta map_currptr+1

  lda #<map1
  sta map_otherbuffptr
  lda #>map1
  sta map_otherbuffptr+1

  jmp buffer_done
  second_buffer:
  lda #<map1
  sta map_currptr
  lda #>map1
  sta map_currptr+1

  lda #<map
  sta map_otherbuffptr
  lda #>map
  sta map_otherbuffptr+1

  buffer_done:
  rts
.endproc

.proc SwapMapBuffers
  lda game_state
  beq buffer_done ; don't swap while paused - otherwise flickers last and prev
  eor #$01 ; see if pause was queued
  beq pause
  jmp nopause
  pause:
    lda #$00
    sta game_state
    rts
  nopause:
  
  lda map_currbuff
  bne second_buffer

  first_buffer:
  lda #$01
  sta map_currbuff
  jmp buffer_done

  second_buffer:
  lda #$00
  sta map_currbuff

  buffer_done:

  rts
.endproc