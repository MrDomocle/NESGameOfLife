; 16-bit + 8 bit addition by static increment, mostly for adding 1 - little endian
.macro Add168 addr_lo, increment
clc
lda addr_lo
adc #increment
sta addr_lo
lda addr_lo+1
adc #$00
sta addr_lo+1
.endmacro

; 16bit + 16bit, both in memory (little endian)
.macro Add1616 addr1_lo, addr2_lo
clc
lda addr1_lo
adc addr2_lo
sta addr1_lo
lda addr1_lo+1
adc addr2_lo+1
sta addr1_lo+1
.endmacro

; reset ppu transfer flags and load high and low bytes of wanted vram address into vram addr2. pass 16 bit address
.macro VRAMTransferInit start_addr
  lda PPU_STATUS
  lda #>start_addr
  sta PPU_VRAM_ADDR2
  lda #<start_addr
  sta PPU_VRAM_ADDR2
.endmacro

.macro VRAMTransferInitOffset start_addr, offset_addr
  lda PPU_STATUS
  Add1616 start_addr, offset_addr
  lda start_addr+1
  sta PPU_VRAM_ADDR2
  lda start_addr
  sta PPU_VRAM_ADDR2
.endmacro

.macro UndoScroll
  lda #$00
  sta PPU_VRAM_ADDR1
  sta PPU_VRAM_ADDR1
.endmacro