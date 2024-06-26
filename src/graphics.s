.include "global.inc"
.include "nes.inc"

.segment "ZEROPAGE"
; shadow regs for PPUCTRL, PPUMASK, PPUSCROLL
; and some extra variables for OAM and palettes
; 
s_PPUCTRL:      .res 1
s_PPUMASK:      .res 1
ppu_scroll_x:   .res 1
ppu_scroll_y:   .res 1
oam_size:       .res 1 ; oam bytes used
shadow_oam_ptr: .res 2
; palette buffers, stored here for speed
shadow_palette_primary: .res 32 ; primary buffer, tranferred to PPUDATA
shadow_palette_secondary: .res 32 ; transferred to primary with add. processing

; misc. stuff
pal_fade_amt:   .res 1
pal_fade_ctr:   .res 1
pal_fade_int:   .res 1
fade_dir:       .res 1
img_progress:   .res 1
img_index:      .res 1
img:            .tag img_DATA_PTR

.include "../obj/img_index.s"

.segment "PRGFIXED_C000"

; these routines must absolutely stay on fixed bank

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
	lda shadow_palette_primary,x
	sta PPUDATA
	inx
	cpx #32
	bne @loop

	rts
.endproc

;;
; @param fade_dir 1 = fade in, -1 = fade out
; @param pal_fade_ctr increment ticks per frame + 1
; @param pal_fade_int interval of ticks + 1
; @param pal_fade_amt fade steps to fade the palette
.proc run_fade
	lda pal_fade_ctr
	beq @tick_fade

	dec pal_fade_ctr
	rts

@tick_fade:
	lda fade_dir
	bpl @increment
	lda pal_fade_amt
	cmp #fade_amt_max
	beq @return
	inc pal_fade_amt
	jmp @end
@increment:
	lda pal_fade_amt
	beq @return
	dec pal_fade_amt

@end:
	lda pal_fade_int
	sta pal_fade_ctr
	rts

@return:
	; fade complete, let NMI know about it
	lda sys_mode
	and #($FF - sys_MODE_PALETTEFADE)
	sta sys_mode
	rts
.endproc

;;
; @param pal_fade_amt incremental steps to dim the palette. range is 0 to 4
; temp1_8: fade amount for brightness nybble
; temp2_8: hue nybble scratch byte
; Y: brightness nybble scratch byte
.proc fade_shadow_palette
	lda pal_fade_amt
	and #%00000111
	cmp #fade_amt_max+1
	bcc @shift_fade_amt
	lda #fade_amt_max
@shift_fade_amt:
	asl
	asl
	asl
	asl
	sta temp1_8
	ldx #0

@loop:
	lda shadow_palette_secondary,x
	ldy pal_fade_amt
	beq @write_entry
	sta temp2_8
	; shift brightness
	and #$F0
	beq @set_to_black ; column 0 gets set to black after 1 step
	sec
	sbc temp1_8
	bmi @set_to_black
	tay ; brightness nybble is stored in Y

	; shift hue
	lda temp2_8
	and #$0F
	beq @x0_color ; check for gray colors
	cmp #$0D
	bcs @xD_xF_color
	sec
	sbc pal_fade_amt
	sta temp2_8 ; hue nybble is stored in temp2_8
	beq @color_underflow ; check for color $x0
	bpl @recombine
	; fall through

@color_underflow:
	; handle color underflow
	clc
	adc #12
	sta temp2_8
	; fall through

@recombine:
	; combine brightness and hue nybbles
	tya
	ora temp2_8
	jmp @write_entry

@x0_color:
	tya
	jmp @write_entry

@xD_xF_color:
	bne @set_to_black ; $xE/$xF colors are transmuted to $0F
	sta temp2_8
	cpy #$10
	; $0D/$1D is converted to $0F to avoid issues
	beq @set_to_black
	bmi @set_to_black
	; else, continue with entry write
	jmp @recombine

@set_to_black:
	lda #$0F
	; fall through

@write_entry:
	sta shadow_palette_primary,x
	inx
	cpx #32
	bne @loop

	rts
.endproc

;;
; decompresses and transfers 4K chr data to PPU
; @param A base address of CHR page ($00 or $10)
; @param temp1_16 pointer to compressed chr data
.import donut_bulk_load_ayx
.proc transfer_4k_chr
	bit PPUSTATUS
	sta temp2_16+1
	sta PPUADDR
	lda #0
	sta temp2_16+0
	sta PPUADDR
	lda temp1_16+1
	ldy temp1_16+0
	ldx #4096/64
	jsr donut_bulk_load_ayx

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

;;
; taken from ppuclear.s by PinoBatch
; Clears a nametable to a given tile number and attribute value.
; adds a custom guard rail at the left edge for sprite 0 hit
; (Turn off rendering in PPUMASK and set the VRAM address increment
; to 1 in PPUCTRL first.)
; @param A tile number
; @param X base address of nametable ($20, $24, $28, or $2C)
; @param Y attribute value ($00, $55, $AA, or $FF)
; @param temp1_8 scratch byte
.proc ppu_clear_nt_with_sprite_0_rail
guard_rail_tile = $01
guard_rail_attribute = %01
guard_rail_attribute_byte = (%00 << 6) | (guard_rail_attribute << 4) | (%00 << 2) | (guard_rail_attribute << 0)

	; Set base PPU address to XX00	
	bit PPUSTATUS
	stx PPUADDR
	stx temp1_8
	ldx #$00
	stx PPUADDR

	; Clear the 960 spaces of the main part of the nametable
	; with guard rail tile at left edge
	sta temp1_8
	tya
	pha
	ldx #960/32
loop3:
	lda #guard_rail_tile
	sta PPUDATA
	lda temp1_8
	ldy #(32-1)
@subloop3:
	sta PPUDATA
	dey
	bne @subloop3
	dex
	bne loop3

	; Clear the 64 entries of the attribute table
	; with guard rail attribute at left edge
	pla
	sta temp1_8
	ldx #64/8
loop4:
	lda #guard_rail_attribute_byte
	sta PPUDATA
	lda temp1_8
	ldy #(8-1)
@subloop4:
	sta PPUDATA
	dey
	bne @subloop4
	dex
	bne loop4

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
; transfers palette data to shadow_palette_secondary
; @param temp1_16 pointer to palette data
.proc transfer_img_pal
	ldy #0

@loop:
	lda (temp1_16),y
	sta shadow_palette_secondary,y
	iny
	cpy #32
	bne @loop

	rts
.endproc

;;
; inits shadow OAM at shadow_oam_ptr after oam_size
; oam_size gets reset to 0
; @param temp1_16 pointer to OAM data
.proc init_oam
	ldy oam_size
	lda #$FF
@loop:
	sta (shadow_oam_ptr),y
	iny
	iny
	iny
	iny
	bne @loop
	sty oam_size

	rts
.endproc

;;
; transfers metasprite data to shadow OAM
; make sure shadow_oam_ptr is set to destination!
; @param temp1_16 pointer to OAM data
.proc transfer_metasprite
	; preserve shadow OAM pointer
	lda shadow_oam_ptr+0
	pha
	lda shadow_oam_ptr+1
	pha

	; allocate sprites after used OAM bytes
	clc
	lda oam_size
	adc shadow_oam_ptr+0
	sta shadow_oam_ptr+0
	lda #0
	adc shadow_oam_ptr+1
	sta shadow_oam_ptr+1

	ldy #0
	lda (temp1_16),y ; object count
	beq @end ; no sprites
	; multiply by 4 and add to oam_size
	asl
	asl
	tax ; set loop counter
	clc
	adc oam_size
	sta oam_size
	bcs @end ; overflow? probably too much objects to store safely

	; hack! increment temp1_16 ptr
	clc
	lda #1
	adc temp1_16+0
	sta temp1_16+0
	lda #0
	adc temp1_16+1
	sta temp1_16+1

@loop:
	lda (temp1_16),y
	sta (shadow_oam_ptr),y
	iny
	dex
	bne @loop

@end:
	pla
	sta shadow_oam_ptr+1
	pla
	sta shadow_oam_ptr+0

	rts
.endproc

;;
; decompresses and transfers attribute data to PPU
; @param A base address of nametable ($20, $24, $28, or $2C)
; @param temp1_16 pointer to compressed attribute data
; @param temp2_16 shadow pointer to PPUADDR
.proc transfer_img_attr
	clc
	adc #3 ; attribute table is last 64 bytes
	bit PPUSTATUS
	sta temp2_16+1
	sta PPUADDR
	lda #$C0
	sta temp2_16+0
	sta PPUADDR
	ldy #0

@loop:
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
; decompresses and transfers nametable and attribute data to PPU
; @param A base address of attribute table ($20, $24, $28, or $2C)
; @param temp1_16 pointer to compressed attribute data
; @param temp2_16 shadow pointer to PPUADDR
.proc transfer_img_nam
	bit PPUSTATUS
	sta temp2_16+1
	sta PPUADDR
	ldy #0
	sty temp2_16+0
	sty PPUADDR
	lda temp1_16+1
	ldy temp1_16+0
	ldx #1024/64
	jsr donut_bulk_load_ayx

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

;;
; prints text to the nametable location specifed
; set PPUADDR before calling.
; @param temp1_16 pointer to raw text data
; @param temp1_8 bank of raw text data
.proc print_line
	; switch to raw text bank
	lda s_A53_PRG_BANK
	pha
	a53_set_prg_safe temp1_8

	ldy #0
@charprint_loop:
	lda (temp1_16),y
	bmi @end_of_line ; end loop if $FF is encountered
	sta PPUDATA
	iny
	jmp @charprint_loop

@end_of_line:
	; switch back to current bank
	pla
	sta s_A53_PRG_BANK
	a53_set_prg_safe s_A53_PRG_BANK
	rts
.endproc

;;
; interrupt protection for PPU data. call before loading data to A/X/Y
; thanks Kasumi!
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
; thanks Kasumi!
.proc inc_ppuaddr_ptr
	inc temp2_16+0
	bne @skip_inc

	inc temp2_16+1
	inc img_progress

@skip_inc:
	rts
.endproc

.segment MAIN_ROUTINES_BANK_SEGMENT

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
	lda #>OAM_SHADOW_1
	sta shadow_oam_ptr+1
	lda #<.bank(gallery_sprite0_data)
	sta temp3_8
	lda #<gallery_sprite0_data
	ldx #>gallery_sprite0_data
	jsr load_ptr_temp1_16
	lda #<transfer_metasprite
	ldx #>transfer_metasprite
	jsr load_ptr_temp3_16
	jsr far_call_subroutine

	; from now on, we use OAM_SHADOW_2
	; reset oam_size to reflect this
	; todo: separate oam_size per buffer?
	lda #0
	sta oam_size
	lda #>OAM_SHADOW_2
	sta shadow_oam_ptr+1
	lda #<.bank(loadscreen_sprite0_data)
	sta temp3_8
	lda #<loadscreen_sprite0_data
	ldx #>loadscreen_sprite0_data
	jsr load_ptr_temp1_16
	lda #<transfer_metasprite
	ldx #>transfer_metasprite
	jsr load_ptr_temp3_16
	jsr far_call_subroutine

	; bug NMI to use loading screen NMI
	lda sys_mode
	ora #sys_MODE_GALLERYLOAD
	sta sys_mode

	; setup loading screen NMI
	lda s_PPUCTRL
	pha
	lda #NT_2800|OBJ_8X16|BG_1000|VBLANK_NMI
	sta PPUCTRL
	sta s_PPUCTRL

	; wait until after vblank to transfer image palettes
	; so we don't see visual glitches
	ldx #1
	jsr wait_x_frames

	; switch to universal CHR bank
	lda #3
	sta s_A53_CHR_BANK

	; switch to universal palette
	lda #<.bank(universal_pal)
	sta temp3_8
	lda #<universal_pal
	ldx #>universal_pal
	jsr load_ptr_temp1_16
	lda #<transfer_img_pal
	ldx #>transfer_img_pal
	jsr load_ptr_temp3_16
	jsr far_call_subroutine

	; override fade
	lda pal_fade_amt
	pha
	lda #0
	sta pal_fade_amt
	jsr fade_shadow_palette
	pla
	sta pal_fade_amt

	; wait until vblank to transfer image palettes
	; this allows the ppu palette transfer flag to expire
	; and thus only display the universal palette
	lda sys_mode
	ora #sys_MODE_NMIPAL
	sta sys_mode
	ldx #1
	jsr wait_x_frames

	; transfer palettes, attributes, and OAM buffer
	lda z:img+img_DATA_PTR::img_PAL_LOC
	sta temp3_8
	lda z:img+img_DATA_PTR::img_PAL_PTR
	ldx z:img+img_DATA_PTR::img_PAL_PTR+1
	jsr load_ptr_temp1_16
	lda #<transfer_img_pal
	ldx #>transfer_img_pal
	jsr load_ptr_temp3_16
	jsr far_call_subroutine

	lda z:img+img_DATA_PTR::img_ATTR_LOC
	sta temp3_8
	lda z:img+img_DATA_PTR::img_ATTR_PTR
	ldx z:img+img_DATA_PTR::img_ATTR_PTR+1
	jsr load_ptr_temp1_16
	lda #<transfer_img_attr
	ldx #>transfer_img_attr
	jsr load_ptr_temp3_16
	lda #NAMETABLE_A
	sta temp1_8
	jsr far_call_subroutine

	lda z:img+img_DATA_PTR::img_OAM_LOC
	sta temp3_8
	a53_set_prg_safe s_A53_PRG_BANK
	lda z:img+img_DATA_PTR::img_OAM_PTR
	ldx z:img+img_DATA_PTR::img_OAM_PTR+1
	jsr load_ptr_temp1_16
	lda #<transfer_metasprite
	ldx #>transfer_metasprite
	jsr load_ptr_temp3_16
	jsr far_call_subroutine

	; transfer BG CHR banks
	lda #<transfer_4k_chr
	ldx #>transfer_4k_chr
	jsr load_ptr_temp3_16

	; CHR RAM bank 0
	a53_set_chr_safe #0
	lda z:img+img_DATA_PTR::img_BANK_0_LOC
	sta temp3_8
	lda z:img+img_DATA_PTR::img_BANK_0_PTR
	ldx z:img+img_DATA_PTR::img_BANK_0_PTR+1
	jsr load_ptr_temp1_16
	lda #$00
	sta temp1_8
	jsr far_call_subroutine
	lda z:img+img_DATA_PTR::img_BANK_S_LOC
	sta temp3_8
	lda z:img+img_DATA_PTR::img_BANK_S_PTR
	ldx z:img+img_DATA_PTR::img_BANK_S_PTR+1
	jsr load_ptr_temp1_16
	lda #$10
	sta temp1_8
	jsr far_call_subroutine

	; CHR RAM bank 1
	a53_set_chr_safe #1
	lda z:img+img_DATA_PTR::img_BANK_1_LOC
	sta temp3_8
	lda z:img+img_DATA_PTR::img_BANK_1_PTR
	ldx z:img+img_DATA_PTR::img_BANK_1_PTR+1
	jsr load_ptr_temp1_16
	lda #$00
	sta temp1_8
	jsr far_call_subroutine
	lda z:img+img_DATA_PTR::img_BANK_S_LOC
	sta temp3_8
	lda z:img+img_DATA_PTR::img_BANK_S_PTR
	ldx z:img+img_DATA_PTR::img_BANK_S_PTR+1
	jsr load_ptr_temp1_16
	lda #$10
	sta temp1_8
	jsr far_call_subroutine

	; CHR RAM bank 2
	a53_set_chr_safe #2
	lda z:img+img_DATA_PTR::img_BANK_2_LOC
	sta temp3_8
	lda z:img+img_DATA_PTR::img_BANK_2_PTR
	ldx z:img+img_DATA_PTR::img_BANK_2_PTR+1
	jsr load_ptr_temp1_16
	lda #$00
	sta temp1_8
	jsr far_call_subroutine
	lda z:img+img_DATA_PTR::img_BANK_S_LOC
	sta temp3_8
	lda z:img+img_DATA_PTR::img_BANK_S_PTR
	ldx z:img+img_DATA_PTR::img_BANK_S_PTR+1
	jsr load_ptr_temp1_16
	lda #$10
	sta temp1_8
	jsr far_call_subroutine


	; done with CHR transfer, begin to restore state

	; bug system to load in new palettes
	lda sys_mode
	ora #sys_MODE_NMIPAL
	sta sys_mode

	; wait until vblank to restore state
	ldx #1
	jsr wait_x_frames

	jsr fade_shadow_palette

	pla
	sta s_PPUCTRL
	pla
	sta s_A53_CHR_BANK
	a53_set_chr_safe s_A53_CHR_BANK
	pla
	sta s_A53_PRG_BANK
	a53_set_prg_safe s_A53_PRG_BANK

	rts
.endproc
gallery_sprite0_data:
	.byte 1
	.byte $4E, $FF, $00, $F8
loadscreen_sprite0_data:
	.byte 1
	.byte $16, $FF, $00, $DF

;;
; sets the nametable for the title screen
; @param A base address of nametable ($20, $24, $28, or $2C)
.proc load_titlescreen
	sta temp2_8 ; scratch byte; using this for transfer_img_nam
	lda #<img_title
	ldx #>img_title
	jsr load_ptr_temp1_16

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


	; set sprite0 pixel and star sprite
	lda #<.bank(titlescreen_metasprite_data)
	sta temp3_8
	lda #<titlescreen_metasprite_data
	ldx #>titlescreen_metasprite_data
	jsr load_ptr_temp1_16
	lda #<transfer_metasprite
	ldx #>transfer_metasprite
	jsr load_ptr_temp3_16
	jsr far_call_subroutine

	; transfer palettes, attributes, and OAM buffer
	lda z:img+img_DATA_PTR::img_PAL_LOC
	sta temp3_8
	lda z:img+img_DATA_PTR::img_PAL_PTR
	ldx z:img+img_DATA_PTR::img_PAL_PTR+1
	jsr load_ptr_temp1_16
	lda #<transfer_img_pal
	ldx #>transfer_img_pal
	jsr load_ptr_temp3_16
	jsr far_call_subroutine

	; it says attribute, but really it points to nametable data
	lda z:img+img_DATA_PTR::img_ATTR_LOC
	sta temp3_8
	lda z:img+img_DATA_PTR::img_ATTR_PTR
	ldx z:img+img_DATA_PTR::img_ATTR_PTR+1
	jsr load_ptr_temp1_16
	lda #<transfer_img_nam
	ldx #>transfer_img_nam
	jsr load_ptr_temp3_16
	lda temp2_8
	sta temp1_8
	jsr far_call_subroutine

	; no OAM afaik?
	lda z:img+img_DATA_PTR::img_OAM_LOC
	sta temp3_8
	lda z:img+img_DATA_PTR::img_OAM_PTR
	ldx z:img+img_DATA_PTR::img_OAM_PTR+1
	jsr load_ptr_temp1_16
	lda #<transfer_metasprite
	ldx #>transfer_metasprite
	jsr load_ptr_temp3_16
	jsr far_call_subroutine

	; transfer BG CHR bank
	a53_set_chr_safe #3
	lda z:img+img_DATA_PTR::img_BANK_0_LOC
	sta temp3_8
	lda z:img+img_DATA_PTR::img_BANK_0_PTR
	ldx z:img+img_DATA_PTR::img_BANK_0_PTR+1
	jsr load_ptr_temp1_16
	lda #<transfer_4k_chr
	ldx #>transfer_4k_chr
	jsr load_ptr_temp3_16
	lda #$00
	sta temp1_8
	jsr far_call_subroutine

	; bug system to load in new palettes?
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
titlescreen_metasprite_data:
	.byte 2
	.byte $16, $FF, $00, $7F ; sprite 0
	.byte $98, STAR_TILE, $00, $58 ; star sprite

;;
; sets the nametable for gallery view
; @param A base address of nametable ($20, $24, $28, or $2C)
.proc set_gallery_loading_screen
	pha
	; we don't really need to zero the nametable again
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
	pha
	bit PPUSTATUS
	sta PPUADDR
	lda #$48
	sta PPUADDR

	lda #<txt_now_loading
	ldx #>txt_now_loading
	jsr load_ptr_temp1_16
	lda #<.bank(txt_now_loading)
	sta temp1_8
	lda #1
	sta temp2_8
	jsr print_line

	; draw loading bar
	pla
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
txt_now_loading:
	.byte "now loading... ", STAR_TILE, $FF
	txt_now_loading_size := * - txt_now_loading

;;
; sets the nametable for the credits screen
; @param A base address of first nametable ($20, $24, $28, or $2C)
; @param X base address of second nametable ($20, $24, $28, or $2C)
.importzp line_index
.proc load_credits_screens
	; clear second nametable
	pha
	lda #0
	ldy #0
	jsr ppu_clear_nt

	; clear first nametable
	pla
	tax
	lda #0
	ldy #0
	jsr ppu_clear_nt

	; save current PRG and CHR bank
	lda s_A53_PRG_BANK
	pha
	lda s_A53_CHR_BANK
	pha

	; transfer palette
	lda #<.bank(universal_pal)
	sta temp3_8
	lda #<universal_pal
	ldx #>universal_pal
	jsr load_ptr_temp1_16
	lda #<transfer_img_pal
	ldx #>transfer_img_pal
	jsr load_ptr_temp3_16
	jsr far_call_subroutine

	; fill two screens with text data
	; fill second screen with text data
	lda #NAMETABLE_A
	sta temp2_16+1
	lda #$02
	sta temp2_16+0
	; 60 lines
	; two screens worth of text
	ldx #60
@text_loop:
	jsr print_credits_line
	inc line_index
	dex
	bne @text_loop

	; bug system to load in new palettes
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
