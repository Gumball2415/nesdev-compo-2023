.include "global.inc"
.include "nes.inc"

.segment "ZEROPAGE"
shadow_palette: .res 32
; shadow regs for PPUCTRL and PPUMASK
; 
s_PPUCTRL:      .res 1
s_PPUMASK:      .res 1
ppu_scroll_x:   .res 1
ppu_scroll_y:   .res 1



.segment "PRG0_8000"
universal_tileset:
	.incbin "obj/universal.chr"
img0_bank0:
	.incbin "obj/bank0.chr"
img0_bank1:
	.incbin "obj/bank1.chr"
img0_bank2:
	.incbin "obj/bank2.chr"

.segment "PRGFIXED_C000"
img_0:
    .addr universal_tileset
    .addr img_0_lo
    .addr img_0_hi

img_0_lo:
    .byte .lobyte(universal_tileset)
    .byte .lobyte(img0_bank0)
    .byte .lobyte(img0_bank1)
    .byte .lobyte(img0_bank2)

img_0_hi:
    .byte .hibyte(universal_tileset)
    .byte .hibyte(img0_bank0)
    .byte .hibyte(img0_bank1)
    .byte .hibyte(img0_bank2)

.proc transfer_palette
; copies the palette from shadow regs to PPU

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

	rts
.endproc

;;
; decompresses and transfers 4K chr data to PPU
; @param A 0 = left, 1 = right 
; @param temp1_16 pointer to compressed chr data
.proc transfer_4k_chr
	clc
	ror a
	ror a
	sta PPUADDR
	ldy #0
	sty PPUADDR
	ldx #>4096
@loop:
	lda (temp1_16),y
	sta PPUDATA
	iny
	bne @loop
	inc temp1_16+1
	dex
	bne @loop
	rts
.endproc

;;
; clears current CHR RAM bank
.proc clear_chr
	lda #0
	tay
	sta PPUADDR
	sta PPUADDR
	ldx #>8192
@loop:
	sta PPUDATA
	iny
	bne @loop
	dex
	bne @loop
	rts
.endproc

.proc clear_all_chr
	a53_set_chr #0
	jsr clear_chr
	a53_set_chr #1
	jsr clear_chr
	a53_set_chr #2
	jsr clear_chr
	a53_set_chr #3
	jsr clear_chr
	a53_set_chr s_A53_CHR_BANK
	rts
.endproc

;;
; loads 3 4K chr banks into RAM
; @param A image index
; TODO: do actual indexing
.proc load_chr_bitmap
	a53_set_chr #0
	lda #<img0_bank0
	sta temp1_16+0
	lda #>img0_bank0
	sta temp1_16+1
	lda #0
	jsr transfer_4k_chr
	a53_set_chr #1
	lda #<img0_bank1
	sta temp1_16+0
	lda #>img0_bank1
	sta temp1_16+1
	lda #0
	jsr transfer_4k_chr
	a53_set_chr #2
	lda #<img0_bank2
	sta temp1_16+0
	lda #>img0_bank2
	sta temp1_16+1
	lda #0
	jsr transfer_4k_chr
	a53_set_chr s_A53_CHR_BANK
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
