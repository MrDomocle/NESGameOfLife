.include "nes.inc"
.include "controller.inc"
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
cursor: .incbin "cursor.chr"

.segment "ZEROPAGE"
nmi_ptr: .res 2 ; point to vblank skips for first 2 frames
frame: .res 2
game_state: .res 1 ; 0 paused, 1 pause queued (on next buffer swap), 2 running
clear_time: .res 1 ; count up if non-zero, clear map if reaches CLEAR_TIMEOUT

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

cursor_x: .res 1
cursor_y: .res 1
cursor_attr: .res 1 ; maybe make cursor orange when paused and white when running?

cursor_tile_x: .res 1
cursor_tile_y: .res 1

.segment "STARTUP" ; unused

.segment "CODE"

RESET:
sei
cld

lda #<vblank1
sta nmi_ptr ; for skipping first 2 vblanks
lda #>vblank1
sta nmi_ptr+1

lda #$00
sta frame
sta frame+1
sta joy_old
sta clear_time

lda #$02
sta game_state

; enable interrupts to time first 2 vblanks
lda #$80
sta PPU_CTRL1

NMIVector:
jmp (nmi_ptr)

; skip first 2 frames
vblank1:
lda #<vblank2
sta nmi_ptr
lda #>vblank2
sta nmi_ptr+1
jmp WAIT
vblank2:
lda #<ready
sta nmi_ptr
lda #>ready
sta nmi_ptr+1
jmp WAIT
ready:
; go directly to nmi handler on next nmi
lda #<NMIHandler
sta nmi_ptr
lda #>NMIHandler
sta nmi_ptr+1

lda #$00 ; disable nmi for initial tile load
sta PPU_CTRL1

; INIT GFX
jsr LoadPalette
jsr ZeroTilemap
jsr LoadTilesFull
jsr ZeroOAM
jsr InitCursor

; ready to run
lda #$80 ; enable nmi
sta PPU_CTRL1
lda #$18 ; 08 to enable bg rendering + 10 to enable sprites
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
  
  jsr GetCursorCoords
  jsr InputHandler
  jsr LoadNextTileRow
  jsr LoadOAM
  
  lda game_state
  beq paused
    jsr TickRow
  paused:
  rti
.endproc
WAIT: jmp WAIT

IRQ:

.segment "VECTORS"
.word NMIVector
.word RESET
.word IRQ