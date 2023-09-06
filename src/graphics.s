.include "global.inc"
.include "nes.inc"

.segment "ZEROPAGE"
shadow_palette: .res 32
; shadow regs for PPUCTRL and PPUMASK
; 
s_PPUCTRL:    .res 1
s_PPUMASK:    .res 1
ppu_scroll_x: .res 1
ppu_scroll_y: .res 1
img_progress: .res 1
img_index:    .res 1
img_pointer:  .tag img_DATA_PTR



.segment "PRG0_8000"
universal_tileset:
	.incbin "obj/universal.chr"

img_0_bank0:
	.incbin "obj/bank0.chr"
img_0_bank1:
	.incbin "obj/bank1.chr"
img_0_bank2:
	.incbin "obj/bank2.chr"

.segment "PRG1_8000"
img_0_pal:
	.byte $0f,$00,$10,$30
	.byte $0f,$01,$21,$31
	.byte $0f,$06,$16,$26
	.byte $0f,$09,$19,$29
	.byte $0f,$00,$10,$30
	.byte $0f,$01,$21,$31
	.byte $0f,$06,$16,$26
	.byte $0f,$09,$19,$29
img_0_attr:
	.res 64, 0



.segment "PRGFIXED_C000"
img_table:
	.addr img_0

img_0:
    .addr img_0_bank0
	.byte 0
    .addr img_0_bank1
	.byte 0
    .addr img_0_bank2
	.byte 0
	.addr img_0_pal
	.byte 1
	.addr img_0_attr
	.byte 1 

; sprite 0 hit happens precisely on this pixel
gallery_sprite0_data:
	.byte $56, $08, $00, $F8
	gallery_sprite0_data_size := * - gallery_sprite0_data
loadscreen_sprite0_data:
	.byte $7E, $08, $00, $BE
	loadscreen_sprite0_data_size := * - loadscreen_sprite0_data
; copies the palette from shadow regs to PPU
.proc transfer_palette
	lda #$3F
	sta PPUADDR
	lda #$00
	sta PPUADDR

	ldx #0
@loop:
	lda shadow_palette,x
	sta PPUDATA
	inx
	cpx #32
	bne @loop
	rts
.endproc

;;
; decompresses and transfers 4K chr data to PPU
; @param A base address of CHR page ($00 or $10)
; @param temp1_16 pointer to compressed chr data
.proc transfer_4k_chr
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
	inc img_progress
	dex
	bne @loop
	rts
.endproc

;;
; decompresses and transfers palette data to shadow palette
; @param temp1_16 pointer to compressed palette data
.proc transfer_img_pal
	ldy #0
@loop:
	lda (temp1_16),y
	sta shadow_palette,y
	iny
	cpy #32
	bne @loop
	rts
.endproc

;;
; decompresses and transfers attribute data to PPU
; @param A base address of attribute table ($23, $27, $2B, or $2F)
; @param temp1_16 pointer to compressed attribute data
.proc transfer_img_attr
	sta PPUADDR
	lda #$C0
	sta PPUADDR
	ldy #0
@loop:
	lda (temp1_16),y
	sta PPUDATA
	iny
	cpy #64
	bne @loop
	rts
.endproc

;;
; sets the nametable for gallery view
; @param A base address of nametable ($20, $24, $28, or $2C)
.proc set_gallery_nametable
	pha
	tax
	lda #0
	tay
	jsr ppu_clear_nt
	pla

	sta PPUADDR
	lda #$60
	sta PPUADDR

	ldx #3
	ldy #0
@loop:
    sty PPUDATA
	iny
	bne @loop
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
; loads the bitmap image with palette and attribute table
; @param A image index
.proc load_chr_bitmap

	; index into the image table
	lda img_index
	asl a
	tax
	lda img_table,x
	sta temp1_16+0
	lda img_table+1,x
	sta temp1_16+1

	ldy #0
	sty img_progress
@ptr_load:
	lda (temp1_16),y
	sta img_pointer,y
	iny
	cpy #15
	bne @ptr_load

	a53_set_prg img_pointer+img_DATA_PTR::img_PAL_LOC
	lda img_pointer+img_DATA_PTR::img_PAL_PTR
	ldx img_pointer+img_DATA_PTR::img_PAL_PTR+1
	jsr load_ptr_temp1_16
	jsr transfer_img_pal

	a53_set_prg img_pointer+img_DATA_PTR::img_ATTR_LOC
	lda img_pointer+img_DATA_PTR::img_ATTR_PTR
	ldx img_pointer+img_DATA_PTR::img_ATTR_PTR+1
	jsr load_ptr_temp1_16
	lda #$23
	jsr transfer_img_attr


	; setup loading screen
	lda s_A53_CHR_BANK
	pha
	a53_set_chr #4
	;set up sprite zero in OAM shadow buffer
	ldy #<loadscreen_sprite0_data_size
	dey
	:
		lda loadscreen_sprite0_data, y
		sta SHADOW_OAM, y
		dey
		bpl :-
	lda s_PPUMASK
	sta PPUMASK
	lda #NT_2400|OBJ_1000|BG_1000|VBLANK_NMI
	sta PPUCTRL

	lda nmis
@wait_for_nmi:
	cmp nmis
	beq @wait_for_nmi

	lda #0
	sta s_A53_CHR_BANK
	a53_set_chr s_A53_CHR_BANK
	a53_set_prg img_pointer+img_DATA_PTR::img_BANK0_LOC
	lda img_pointer+img_DATA_PTR::img_BANK0_PTR
	ldx img_pointer+img_DATA_PTR::img_BANK0_PTR+1
	jsr load_ptr_temp1_16
	lda #$00
	jsr transfer_4k_chr

	lda #1
	sta s_A53_CHR_BANK
	a53_set_chr s_A53_CHR_BANK
	a53_set_prg img_pointer+img_DATA_PTR::img_BANK1_LOC
	lda img_pointer+img_DATA_PTR::img_BANK1_PTR
	ldx img_pointer+img_DATA_PTR::img_BANK1_PTR+1
	jsr load_ptr_temp1_16
	lda #$00
	jsr transfer_4k_chr

	lda #2
	sta s_A53_CHR_BANK
	a53_set_chr s_A53_CHR_BANK
	a53_set_prg img_pointer+img_DATA_PTR::img_BANK2_LOC
	lda img_pointer+img_DATA_PTR::img_BANK2_PTR
	ldx img_pointer+img_DATA_PTR::img_BANK2_PTR+1
	jsr load_ptr_temp1_16
	lda #$00
	jsr transfer_4k_chr

	pla
	sta s_A53_CHR_BANK
	a53_set_chr s_A53_CHR_BANK
	a53_set_prg s_A53_PRG_BANK
	rts
.endproc

.charmap $20, $00
txt_now_loading:
	.byte "now loading... "
;;
; sets the nametable for gallery view
; @param A base address of nametable ($20, $24, $28, or $2C)
.proc set_gallery_loading_screen
	pha
	tax
	lda #0
	tay
	jsr ppu_clear_nt

	; draw loading bar
	pla
	tax
	inx
	stx temp1_8
	stx PPUADDR
	lda #$A4
	sta PPUADDR

	lda #$05
	sta PPUDATA
	ldx #22
	lda #$06
@loop1:
    sta PPUDATA
	dex
	bne @loop1
	lda #$07
	sta PPUDATA

	; draw text
	lda temp1_8
	sta PPUADDR
	lda #$E8
	sta PPUADDR

	lda #<txt_now_loading
	ldx #>txt_now_loading
	jsr load_ptr_temp1_16

	ldy #0
@loop2:
	lda (temp1_16),y
	sta PPUDATA
	iny
	cpy #15
	bne @loop2

	lda #$04
	sta PPUDATA

	rts
.endproc

;;
; updates the loading progress bar
; @param A base address of nametable ($20, $24, $28, or $2C)
.proc update_progress_bar
	tax
	inx
	stx PPUADDR
	lda #$A4
	sta PPUADDR

	lda img_progress
	lsr a
	beq @end
	tax
	lda #$03
@loop1:
    sta PPUDATA
	dex
	bne @loop1
@end:
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
