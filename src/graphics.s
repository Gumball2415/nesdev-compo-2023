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

; bugs the PPU to update the scroll position
.proc update_scrolling
	bit PPUSTATUS
	lda ppu_scroll_x
	sta PPUSCROLL
	lda ppu_scroll_y
	sta PPUSCROLL
	rts
.endproc
