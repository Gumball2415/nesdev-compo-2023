.include "global.inc"
.include "nes.inc"

.segment "ZEROPAGE"
shadow_palette: .res 32
s_PPUCTRL:      .res 1
s_PPUMASK:      .res 1
ppu_scroll_x:   .res 1
ppu_scroll_y:   .res 1

.segment "PRGFIXED_C000"

.proc transfer_palette
; copies the palette from shadow regs to PPU
	lda #0
	sta PPUMASK				; disable rendering
	sta PPUCTRL				; writes to PPUDATA will increment by 1 to the next PPU address

	lda PPUSTATUS

	lda #$3F
	sta PPUADDR
	lda #$00
	sta PPUADDR

	ldx #$20
:
	lda shadow_palette, x
	sta PPUDATA
	dex
	bne :-

	lda s_PPUCTRL				; enable NMI immediately
	sta PPUCTRL

	rts
.endproc

;;
; taken from ppuclear.s by PinoBatch
; Clears a nametable to a given tile number and attribute value.
; (Turn off rendering in PPUMASK and set the VRAM address increment
; to 1 in PPUCTRL first.)
; @param A tile number
; @param X base address of nametable ($20, $24, $28, or $2C)
; @param Y attribute value ($00, $55, $AA, or $FF)
.proc ppu_clear_nt

  ; Set base PPU address to XX00
  stx PPUADDR
  ldx #$00
  stx PPUADDR

  ; Clear the 960 spaces of the main part of the nametable,
  ; using a 4 times unrolled loop
  ldx #960/4
loop1:
  .repeat 4
    sta PPUDATA
  .endrepeat
  dex
  bne loop1

  ; Clear the 64 entries of the attribute table
  ldx #64
loop2:
  sty PPUDATA
  dex
  bne loop2
  rts
.endproc

; bugs the PPU to update the scroll position
.proc update_scrolling
	bit PPUSTATUS
	lda ppu_scroll_x
	sta PPUSCROLL
	lda ppu_scroll_y
	sta PPUSCROLL
	rts
.endproc
