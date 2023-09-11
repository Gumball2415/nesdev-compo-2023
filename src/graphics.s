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
oam_size:     .res 1



.segment "PRG0_8000"
universal_tileset:
	.incbin "obj/universal.toku"
universal_pal:
	.repeat 8
		.byte $0F,$03,$24,$30
	.endrepeat

img_0_pal:
	.repeat 8
		.byte $0F,$0A,$19,$29
	.endrepeat
img_0_attr:
	.res 64, 0
img_0_oam:
	.res $FF, $FF ; sprite 0 is skipped
img_0_bank_0:
	.incbin "obj/img_0/bank_0.toku"
img_0_bank_1:
	.incbin "obj/img_0/bank_1.toku"
img_0_bank_2:
	.incbin "obj/img_0/bank_2.toku"
img_0_bank_s:
	.incbin "obj/img_0/bank_s.toku"

img_1_pal:
	.repeat 8
		.byte $0F,$03,$15,$34
	.endrepeat
img_1_attr:
	.res 64, 0
img_1_oam:
	.res $FF, $FF ; sprite 0 is skipped
img_1_bank_0:
	.incbin "obj/img_1/bank_0.toku"
img_1_bank_1:
	.incbin "obj/img_1/bank_1.toku"
img_1_bank_2:
	.incbin "obj/img_1/bank_2.toku"
img_1_bank_s:
	.incbin "obj/img_1/bank_s.toku"


.segment "PRGFIXED_C000"
img_0:
	.addr img_0_pal
	.addr img_0_attr
    .addr img_0_oam
    .addr img_0_bank_0
    .addr img_0_bank_1
    .addr img_0_bank_2
    .addr img_0_bank_s
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	.byte 0

img_1:
	.addr img_1_pal
	.addr img_1_attr
    .addr img_1_oam
    .addr img_1_bank_0
    .addr img_1_bank_1
    .addr img_1_bank_2
    .addr img_1_bank_s
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	.byte 0

img_table:
	.addr img_0
	.addr img_1
img_table_size := * - img_table

; sprite 0 hit happens precisely on this pixel
gallery_sprite0_data:
	.byte $56, $FF, $00, $F8
	gallery_sprite0_data_size := * - gallery_sprite0_data
loadscreen_sprite0_data:
	.byte $1E, $FF, $00, $DF
	loadscreen_sprite0_data_size := * - loadscreen_sprite0_data

; copies the palette from shadow regs to PPU
; not interrupt safe!
.proc transfer_palette
	bit PPUSTATUS
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
	bit PPUSTATUS
	sta temp2_16+1
	sta PPUADDR
	ldy #0
	sty temp2_16+0
	sty PPUADDR
	jsr DecompressTokumaru

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
  bit PPUSTATUS
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

;;
; clears current CHR RAM bank
.proc clear_chr
	lda #0
	tay
	bit PPUSTATUS
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
	sty oam_size

@ptr_load:
	lda (temp1_16),y
	sta img_pointer,y
	iny
	cpy #img_DATA_PTR::img_DATA_PTR_SIZE
	bne @ptr_load
	
	; setup loading screen

	; save current PRG and CHR bank
	lda s_A53_PRG_BANK
	pha
	lda s_A53_CHR_BANK
	pha

	;set up sprite zero in OAM shadow buffers
	lda #$06
	sta shadow_oam_ptr+1
	ldy #<loadscreen_sprite0_data_size
	dey
@copysprite0inoam2:
	lda loadscreen_sprite0_data, y
	sta (shadow_oam_ptr), y
	inc oam_size
	dey
	bpl @copysprite0inoam2

	lda #$07
	sta shadow_oam_ptr+1
	ldy #<gallery_sprite0_data_size
	dey
@copysprite0inoam1:
	lda gallery_sprite0_data, y
	sta (shadow_oam_ptr), y
	dey
	bpl @copysprite0inoam1

	; switch to universal palette
	a53_set_prg_safe #0
	lda #<universal_pal
	ldx #>universal_pal
	jsr load_ptr_temp1_16
	jsr transfer_img_pal
	lda sys_mode
	ora #sys_MODE_NMIPAL
	sta sys_mode

	; setup loading screen NMI
	lda #NT_2400|OBJ_1000|BG_1000|VBLANK_NMI
	sta PPUCTRL

	; switch to universal CHR bank
	a53_set_chr_safe #3

	lda nmis

@wait_nmi:
	cmp nmis
	beq @wait_nmi

	a53_set_prg_safe img_pointer+img_DATA_PTR::img_PAL_LOC
	lda img_pointer+img_DATA_PTR::img_PAL_PTR
	ldx img_pointer+img_DATA_PTR::img_PAL_PTR+1
	jsr load_ptr_temp1_16
	jsr transfer_img_pal

	a53_set_prg_safe img_pointer+img_DATA_PTR::img_ATTR_LOC
	lda img_pointer+img_DATA_PTR::img_ATTR_PTR
	ldx img_pointer+img_DATA_PTR::img_ATTR_PTR+1
	jsr load_ptr_temp1_16
	lda #$23
	jsr transfer_img_attr
	

	a53_set_prg_safe img_pointer+img_DATA_PTR::img_OAM_LOC
	lda img_pointer+img_DATA_PTR::img_OAM_PTR
	ldx img_pointer+img_DATA_PTR::img_OAM_PTR+1
	jsr load_ptr_temp1_16
	jsr transfer_img_oam

	; transfer BG CHR banks
	lda #0
	sta s_A53_CHR_BANK
	a53_set_chr_safe s_A53_CHR_BANK
	a53_set_prg_safe img_pointer+img_DATA_PTR::img_BANK_0_LOC
	lda img_pointer+img_DATA_PTR::img_BANK_0_PTR
	ldx img_pointer+img_DATA_PTR::img_BANK_0_PTR+1
	jsr load_ptr_temp1_16
	lda #$00
	jsr transfer_4k_chr
	a53_set_prg_safe img_pointer+img_DATA_PTR::img_BANK_S_LOC
	lda img_pointer+img_DATA_PTR::img_BANK_S_PTR
	ldx img_pointer+img_DATA_PTR::img_BANK_S_PTR+1
	jsr load_ptr_temp1_16
	lda #$10
	jsr transfer_4k_chr

	inc s_A53_CHR_BANK
	a53_set_chr_safe s_A53_CHR_BANK
	a53_set_prg_safe img_pointer+img_DATA_PTR::img_BANK_1_LOC
	lda img_pointer+img_DATA_PTR::img_BANK_1_PTR
	ldx img_pointer+img_DATA_PTR::img_BANK_1_PTR+1
	jsr load_ptr_temp1_16
	lda #$00
	jsr transfer_4k_chr
	a53_set_prg_safe img_pointer+img_DATA_PTR::img_BANK_S_LOC
	lda img_pointer+img_DATA_PTR::img_BANK_S_PTR
	ldx img_pointer+img_DATA_PTR::img_BANK_S_PTR+1
	jsr load_ptr_temp1_16
	lda #$10
	jsr transfer_4k_chr

	inc s_A53_CHR_BANK
	a53_set_chr_safe s_A53_CHR_BANK
	a53_set_prg_safe img_pointer+img_DATA_PTR::img_BANK_2_LOC
	lda img_pointer+img_DATA_PTR::img_BANK_2_PTR
	ldx img_pointer+img_DATA_PTR::img_BANK_2_PTR+1
	jsr load_ptr_temp1_16
	lda #$00
	jsr transfer_4k_chr
	a53_set_prg_safe img_pointer+img_DATA_PTR::img_BANK_S_LOC
	lda img_pointer+img_DATA_PTR::img_BANK_S_PTR
	ldx img_pointer+img_DATA_PTR::img_BANK_S_PTR+1
	jsr load_ptr_temp1_16
	lda #$10
	jsr transfer_4k_chr

	lda sys_mode
	ora #sys_MODE_NMIPAL
	sta sys_mode

	pla
	sta s_A53_CHR_BANK
	a53_set_chr_safe s_A53_CHR_BANK
	pla
	sta s_A53_PRG_BANK
	a53_set_prg_safe s_A53_PRG_BANK
	
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
; decompresses and transfers metasprite data to shadow OAM
; @param temp1_16 pointer to compressed palette data
.proc transfer_img_oam
	ldy oam_size

@loop:
	lda (temp1_16),y
	sta (shadow_oam_ptr),y
	iny
	bne @loop

	rts
.endproc

;;
; decompresses and transfers attribute data to PPU
; @param A base address of attribute table ($23, $27, $2B, or $2F)
; @param temp1_16 pointer to compressed attribute data
; @param temp2_16 shadow pointer to PPUADDR
.proc transfer_img_attr
	bit PPUSTATUS
	sta temp2_16+1
	sta PPUADDR
	lda #$C0
	sta temp2_16+0
	sta PPUADDR
	ldy #0

@loop:
	; NMI interrupt check
	; thanks Kasumi!
	jsr sync_ppuaddr_ptr
	lda (temp1_16),y
	sta PPUDATA
	jsr inc_ppuaddr_ptr
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
	; check if we've already initialized the nametable
	lda sys_mode
	and #sys_MODE_GALLERYINIT
	bne @skip_nametable_init

	pla
	pha
	tax
	lda #0
	tay
	jsr ppu_clear_nt
	pla

	bit PPUSTATUS
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

	lda #$FF
	ldx #3
	ldy #$30
@loop2:
	sta PPUDATA
	dey
	bne @loop2

	ldy #$30
	dex
	bne @loop2

	rts

@skip_nametable_init:
	pla
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
	; we don't really need to zero the nametable again
	; but we do need to redraw the loading bar
	lda sys_mode
	and #sys_MODE_GALLERYINIT
	bne @skip_nametable_init

	pla
	pha
	tax
	lda #0
	tay
	jsr ppu_clear_nt

@skip_nametable_init:
	; draw text
	pla
	sta temp1_8
	bit PPUSTATUS
	sta PPUADDR
	lda #$48
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

	; draw loading bar
	lda temp1_8
	bit PPUSTATUS
	sta PPUADDR
	lda #$64
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


	rts
.endproc

;;
; updates the loading progress bar
; @param A base address of nametable ($20, $24, $28, or $2C)
.proc update_progress_bar
	bit PPUSTATUS
	sta PPUADDR
	lda #$64
	sta PPUADDR

	lda img_progress
	lsr a
	lsr a
	cmp #24
	beq @skip_update
	tax
	lda #$03
	; by the time we reach this point, the progress has already been incremented
	inx

@loop1:
    sta PPUDATA
	dex
	bne @loop1

@skip_update:
	rts
.endproc

.proc sync_ppuaddr_ptr
	bit sys_mode
	bpl @skip_sync

	pha
	lda sys_mode
	and #($FF - sys_MODE_NMIOCCURRED)
	sta sys_mode
	bit PPUSTATUS
	lda temp2_16+1
	sta PPUADDR
	lda temp2_16+0
	sta PPUADDR
	pla

@skip_sync:
	rts
.endproc

.proc inc_ppuaddr_ptr
	inc temp2_16+0
	bne @skip_inc

	inc temp2_16+1
	inc img_progress

@skip_inc:
	rts
.endproc
