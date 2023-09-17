.include "global.inc"
.include "nes.inc"

.segment "ZEROPAGE"
; shadow regs for PPUCTRL, PPUMASK, PPUSCROLL
; and some extra variables for OAM and palettes
; 
s_PPUCTRL:    .res 1
s_PPUMASK:    .res 1
ppu_scroll_x: .res 1
ppu_scroll_y: .res 1
oam_size:     .res 1
shadow_oam_ptr: .res 2
shadow_palette: .res 32 ; we store in zeropage for speed

; misc. stuff
pal_fade_dec: .res 1
img_progress: .res 1
img_index:    .res 1
img:          .tag img_DATA_PTR


.segment "PRG0_8000"
universal_tileset:
	.incbin "obj/universal.donut"
universal_pal:
	.byte $0f,$13,$24,$30
	.byte $0f,$38,$31,$11
	.byte $0f,$0f,$0f,$0f
	.byte $0f,$0f,$0f,$0f
	.byte $0f,$0f,$0f,$0f
	.byte $0f,$0f,$0f,$0f
	.byte $0f,$0f,$0f,$0f
	.byte $0f,$0f,$0f,$0f


; TODO: these labeled includes could be generated on compile time
img_0_pal:
	.include "../obj/img_0/pal.s"
img_0_attr:
	.include "../obj/img_0/attr.s"
img_0_oam:
	.include "../obj/img_0/oam.s"
img_0_bank_0:
	.incbin "obj/img_0/bank_0.donut" 
img_0_bank_1:
	.incbin "obj/img_0/bank_1.donut"
img_0_bank_2:
	.incbin "obj/img_0/bank_2.donut"
img_0_bank_s:
	.incbin "obj/img_0/bank_s.donut"

img_1_pal:
	.include "../obj/img_1/pal.s"
img_1_attr:
	.include "../obj/img_1/attr.s"
img_1_oam:
	.include "../obj/img_1/oam.s"
img_1_bank_0:
	.incbin "obj/img_1/bank_0.donut"
img_1_bank_1:
	.incbin "obj/img_1/bank_1.donut"
img_1_bank_2:
	.incbin "obj/img_1/bank_2.donut"
img_1_bank_s:
	.incbin "obj/img_1/bank_s.donut"

.segment "PRG1_8000"
img_title_pal:
	.include "../obj/img_title/pal.s"
img_title_attr:
	.include "../obj/img_title/attr.s"
img_title_oam:
	.include "../obj/img_title/oam.s"
img_title_bank_0:
	.incbin "obj/img_title/bank_0.donut"
img_title_bank_1:
	.incbin "obj/img_title/bank_1.donut"
img_title_bank_2:
	.incbin "obj/img_title/bank_2.donut"
img_title_bank_s:
	.incbin "obj/img_title/bank_s.donut"


.segment "PRGFIXED_C000"
img_0:
	.addr img_0_pal
	.addr img_0_attr
	.addr img_0_oam
	.addr img_0_bank_0
	.addr img_0_bank_1
	.addr img_0_bank_2
	.addr img_0_bank_s
	.byte <.bank(img_0_pal)
	.byte <.bank(img_0_attr)
	.byte <.bank(img_0_oam)
	.byte <.bank(img_0_bank_0)
	.byte <.bank(img_0_bank_1)
	.byte <.bank(img_0_bank_2)
	.byte <.bank(img_0_bank_s)

img_1:
	.addr img_1_pal
	.addr img_1_attr
	.addr img_1_oam
	.addr img_1_bank_0
	.addr img_1_bank_1
	.addr img_1_bank_2
	.addr img_1_bank_s
	.byte <.bank(img_1_pal)
	.byte <.bank(img_1_attr)
	.byte <.bank(img_1_oam)
	.byte <.bank(img_1_bank_0)
	.byte <.bank(img_1_bank_1)
	.byte <.bank(img_1_bank_2)
	.byte <.bank(img_1_bank_s)

img_title:
	.addr img_title_pal
	.addr img_title_attr
	.addr img_title_oam
	.addr img_title_bank_0
	.addr img_title_bank_1
	.addr img_title_bank_2
	.addr img_title_bank_s
	.byte <.bank(img_title_pal)
	.byte <.bank(img_title_attr)
	.byte <.bank(img_title_oam)
	.byte <.bank(img_title_bank_0)
	.byte <.bank(img_title_bank_1)
	.byte <.bank(img_title_bank_2)
	.byte <.bank(img_title_bank_s)

img_table:
	.addr img_0
	.addr img_1
	.addr img_title
img_table_size := * - img_table

; sprite 0 hit happens precisely on this pixel
gallery_sprite0_data:
	.byte $4E, $FF, $00, $F8
	gallery_sprite0_data_size := * - gallery_sprite0_data
loadscreen_sprite0_data:
	.byte $16, $FF, $00, $DF
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
.import donut_block_ayx
.proc transfer_4k_chr
	bit PPUSTATUS
	sta temp2_16+1
	sta PPUADDR
	ldy #0
	sty temp2_16+0
	sty PPUADDR
	lda temp1_16+1
	ldy temp1_16+0
	ldx #64
	jsr donut_block_ayx

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
	sta img,y
	iny
	cpy #.sizeof(img_DATA_PTR)
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
	lda s_PPUCTRL
	pha
	lda #NT_2400|OBJ_8X16|BG_1000|VBLANK_NMI
	sta PPUCTRL
	sta s_PPUCTRL

	; switch to universal CHR bank
	a53_set_chr_safe #3

	; wait until vblank to transfer image palettes
	; this allows the ppu palette transfer flag to expire
	; and thus only display the universal palette
	ldx #1
	jsr wait_x_frames

	; transfer palettes, attributes, and OAM buffer
	lda z:img+img_DATA_PTR::img_PAL_LOC
	sta s_A53_PRG_BANK
	a53_set_prg_safe s_A53_PRG_BANK
	lda z:img+img_DATA_PTR::img_PAL_PTR
	ldx z:img+img_DATA_PTR::img_PAL_PTR+1
	jsr load_ptr_temp1_16
	jsr transfer_img_pal

	lda z:img+img_DATA_PTR::img_ATTR_LOC
	sta s_A53_PRG_BANK
	a53_set_prg_safe s_A53_PRG_BANK
	lda z:img+img_DATA_PTR::img_ATTR_PTR
	ldx z:img+img_DATA_PTR::img_ATTR_PTR+1
	jsr load_ptr_temp1_16
	lda #$23
	jsr transfer_img_attr

	lda z:img+img_DATA_PTR::img_OAM_LOC
	sta s_A53_PRG_BANK
	a53_set_prg_safe s_A53_PRG_BANK
	lda z:img+img_DATA_PTR::img_OAM_PTR
	ldx z:img+img_DATA_PTR::img_OAM_PTR+1
	jsr load_ptr_temp1_16
	jsr transfer_img_oam

	; transfer BG CHR banks
	lda #0
	sta s_A53_CHR_BANK
	a53_set_chr_safe s_A53_CHR_BANK
	lda z:img+img_DATA_PTR::img_BANK_0_LOC
	sta s_A53_PRG_BANK
	a53_set_prg_safe s_A53_PRG_BANK
	lda z:img+img_DATA_PTR::img_BANK_0_PTR
	ldx z:img+img_DATA_PTR::img_BANK_0_PTR+1
	jsr load_ptr_temp1_16
	lda #$00
	jsr transfer_4k_chr
	lda z:img+img_DATA_PTR::img_BANK_S_LOC
	sta s_A53_PRG_BANK
	a53_set_prg_safe s_A53_PRG_BANK
	lda z:img+img_DATA_PTR::img_BANK_S_PTR
	ldx z:img+img_DATA_PTR::img_BANK_S_PTR+1
	jsr load_ptr_temp1_16
	lda #$10
	jsr transfer_4k_chr

	inc s_A53_CHR_BANK
	a53_set_chr_safe s_A53_CHR_BANK
	lda z:img+img_DATA_PTR::img_BANK_1_LOC
	sta s_A53_PRG_BANK
	a53_set_prg_safe s_A53_PRG_BANK
	lda z:img+img_DATA_PTR::img_BANK_1_PTR
	ldx z:img+img_DATA_PTR::img_BANK_1_PTR+1
	jsr load_ptr_temp1_16
	lda #$00
	jsr transfer_4k_chr
	lda z:img+img_DATA_PTR::img_BANK_S_LOC
	sta s_A53_PRG_BANK
	a53_set_prg_safe s_A53_PRG_BANK
	lda z:img+img_DATA_PTR::img_BANK_S_PTR
	ldx z:img+img_DATA_PTR::img_BANK_S_PTR+1
	jsr load_ptr_temp1_16
	lda #$10
	jsr transfer_4k_chr

	inc s_A53_CHR_BANK
	a53_set_chr_safe s_A53_CHR_BANK
	lda z:img+img_DATA_PTR::img_BANK_2_LOC
	sta s_A53_PRG_BANK
	a53_set_prg_safe s_A53_PRG_BANK
	lda z:img+img_DATA_PTR::img_BANK_2_PTR
	ldx z:img+img_DATA_PTR::img_BANK_2_PTR+1
	jsr load_ptr_temp1_16
	lda #$00
	jsr transfer_4k_chr
	lda z:img+img_DATA_PTR::img_BANK_S_LOC
	sta s_A53_PRG_BANK
	a53_set_prg_safe s_A53_PRG_BANK
	lda z:img+img_DATA_PTR::img_BANK_S_PTR
	ldx z:img+img_DATA_PTR::img_BANK_S_PTR+1
	jsr load_ptr_temp1_16
	lda #$10
	jsr transfer_4k_chr

	lda sys_mode
	ora #sys_MODE_NMIPAL
	sta sys_mode

	pla
	sta s_PPUCTRL
	pla
	sta s_A53_CHR_BANK
	a53_set_chr_safe s_A53_CHR_BANK
	pla
	sta s_A53_PRG_BANK
	a53_set_prg_safe s_A53_PRG_BANK

	; let the NMI handler know that we're done transferring CHR
	lda sys_mode
	and #($FF - sys_MODE_CHRTRANSFER)
	sta sys_mode
	
	rts
.endproc

;;
; decompresses and transfers palette data to shadow palette
; @param temp1_16 pointer to compressed palette data
; @param pal_fade_dec increment steps to the palette
.proc transfer_img_pal
	ldy #0

@loop:
	lda (temp1_16),y
	ldx pal_fade_dec
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
	.byte "now loading... ", $04
	txt_now_loading_size := * - txt_now_loading
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
	lda #txt_now_loading_size
	sta temp2_8
	jsr draw_text

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

@loop:
    sta PPUDATA
	dex
	bne @loop

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

txt_gallery:
	.byte "gallery"
	txt_gallery_size := * - txt_gallery
txt_credits:
	.byte "credits"
	txt_credits_size := * - txt_credits
txt_shvtera_group:
	.byte "shvtera group ", $04
	txt_shvtera_group_size := * - txt_shvtera_group
txt_NesDev_2023:
	.byte $08,$09,$0A,$0B,$0C,$0D,$0E, " ", $10,$11,$12,$13
	txt_NesDev_2023_size := * - txt_NesDev_2023
;;
; sets the nametable for the title screen
; @param A base address of nametable ($20, $24, $28, or $2C)
; @param temp1_8 nametable high byte scratch pointer
.proc set_title_nametable
	sta temp1_8
	tax
	lda #0
	tay
	jsr ppu_clear_nt

	; todo: setup title card nametable
	
	; set address to offset $026D
	; draw option gallery text
	bit PPUSTATUS
	inc temp1_8
	inc temp1_8
	lda temp1_8
	sta PPUADDR
	lda #$6D
	sta PPUADDR
	lda #<txt_gallery
	ldx #>txt_gallery
	jsr load_ptr_temp1_16
	lda #txt_gallery_size
	sta temp2_8
	jsr draw_text
	
	; set address to offset $02AD
	; draw option credits text
	lda temp1_8
	sta PPUADDR
	lda #$AD
	sta PPUADDR

	lda #<txt_credits
	ldx #>txt_credits
	jsr load_ptr_temp1_16
	lda #txt_gallery_size
	sta temp2_8
	jsr draw_text
	
	; set address to offset $032F
	; draw shvtera text
	inc temp1_8
	lda temp1_8
	sta PPUADDR
	lda #$2F
	sta PPUADDR

	lda #<txt_shvtera_group
	ldx #>txt_shvtera_group
	jsr load_ptr_temp1_16
	lda #txt_shvtera_group_size
	sta temp2_8
	jsr draw_text
	
	; set address to offset $0352
	; draw nesdev text
	lda temp1_8
	sta PPUADDR
	lda #$52
	sta PPUADDR

	lda #<txt_NesDev_2023
	ldx #>txt_NesDev_2023
	jsr load_ptr_temp1_16
	lda #txt_NesDev_2023_size
	sta temp2_8
	jsr draw_text
	
	; write attributes for NesDev text
	lda temp1_8
	sta PPUADDR
	lda #$F4
	sta PPUADDR
	lda #%01000000
	sta PPUDATA
	lda #%01010000
	sta PPUDATA
	lda #%01010000
	sta PPUDATA
	lda #%00010000
	sta PPUDATA

	rts
.endproc

.proc load_titlescreen
	rts
.endproc

;;
; helper function to draw text. set PPUADDR before calling
; @param temp2_8 size of raw text data
; @param temp1_16 pointer to raw text data
.proc draw_text
	ldy #0
@textprint_loop:
	lda (temp1_16),y
	sta PPUDATA
	iny
	cpy temp2_8
	bne @textprint_loop
	rts
.endproc

;;
; interrupt protection for PPU data. call before loading data to A/X/Y
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

;;
; interrupt protection for PPU data. call after storing to PPUDATA
.proc inc_ppuaddr_ptr
	inc temp2_16+0
	bne @skip_inc

	inc temp2_16+1
	inc img_progress

@skip_inc:
	rts
.endproc
