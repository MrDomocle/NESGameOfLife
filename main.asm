.include "nes.inc"
.include "macros.asm"
.include "misc.asm"
.include "gfx.asm"
.include "game.asm"

.segment "HEADER"
.byte "NES", $1A   ; Magic number
.byte 2            ; 2 x 16KB PRG = 32KB
.byte 1            ; 1 x 8KB CHR = 8KB
.byte $00          ; Flags 6 (mapper 0, horizontal mirroring)
.byte $00          ; Flags 7
.byte $00          ; PRG RAM size (usually 0)
.byte $00          ; TV system
.byte $00          ; TV system
.byte $00,$00,$00,$00,$00  ; Padding to 16 bytes

.segment "CHARS"
; patterns in nibbles: 1111 - bottom right, bottom left, top left, top right (high to low) match tile address low byte, high byte is 0
.incbin "gol.chr"

.segment "ZEROPAGE"
state: .res 2 ; point to vblank skips for first 2 frames
frame: .res 2

; A B SELECT START U D L R
joy: .res 1 
joy_old: .res 1
joy_down: .res 1
joy_up: .res 1

map_offset: .res 2 ; for loading tilemap to vram
map_currbuff: .res 1 ; which buffer is drawn right now - 0 = 1st, !0 = 2nd
map_prevptr: .res 2 ; for game calculations
map_currptr: .res 2 ; absolute adress in BSS
map_nextptr: .res 2 ; for game calculations
map_otherbuffptr: .res 2 ; for game calculations
map_vramptr: .res 2

.segment "BSS"
MAP_WIDTH = 32
MAP_HEIGHT = 32
MAP_LENGTH = MAP_WIDTH*MAP_HEIGHT
; .assert VRAM_TILE_LAST-VRAM_TILE_FIRST = MAP_LENGTH-1, error, "Map size doesn't match vram addresses"

map_padding1: .res MAP_WIDTH ; provide empty row for neighbour calculations
map: .res MAP_LENGTH ; first map buffer
map_padding2: .res MAP_WIDTH
map1: .res MAP_LENGTH ; second map buffer
map_padding3: .res MAP_WIDTH ; provide empty row for neighbour calculations

.segment "STARTUP" ; unused

.segment "CODE"

RESET:
sei
cld

lda #<vblank1
sta state ; for skipping first 2 vblanks
lda #>vblank1
sta state+1

lda #$00
sta frame
sta frame+1
sta joy_old

; enable interrupts to time first 2 vblanks
lda #$80
sta PPU_CTRL1

NMI:
jmp (state)

; skip first 2 frames
vblank1:
lda #<vblank2
sta state
lda #>vblank2
sta state+1
jmp WAIT
vblank2:
lda #<ready
sta state
lda #>ready
sta state+1
jmp WAIT
ready:
; go directly to nmi handler on next nmi
lda #<NMIHandler
sta state
lda #>NMIHandler
sta state+1

lda #$00 ; disable nmi for initial tile load
sta PPU_CTRL1

; INIT GFX
jsr LoadPalette
jsr ZeroTilemap
jsr LoadTilesFull

; ready to run
lda #$80 ; enable nmi
sta PPU_CTRL1
lda #$08 ; 08 to enable bg rendering
sta PPU_CTRL2

; actual NMI handler
.proc NMIHandler

; 16 bit increment frame
Add168 frame, 1
; swap map buffers every 32 frames
lda frame
and #$1f
bne noswap
  jsr SwapMapBuffers
noswap:

jsr LoadNextTileRow

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

jsr TickRow

.endproc
WAIT: jmp WAIT

IRQ:

.segment "VECTORS"
.word NMI
.word RESET
.word IRQ