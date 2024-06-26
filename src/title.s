.include "global.inc"
.include "nes.inc"
.include "checked_branches.inc"

.export title_subroutine

.segment MAIN_ROUTINES_BANK_SEGMENT

.proc title_display_kernel_ntsc
.if .not(::SKIP_DOT_DISABLE)
	; delay until it's ok to poll for sprite 0
	@wait_sprite0_reset:
		bit PPUSTATUS
		bvs @wait_sprite0_reset
.endif

@wait_sprite0_hit:
	bit PPUSTATUS
	bvc @wait_sprite0_hit ; wait for sprite 0 hit

	; let update_graphics know that we have sprite0
	lda sys_mode
	ora #sys_MODE_SPRITE0SET
	sta sys_mode
	rts
.endproc

title_select:
	.byte STATE_ID::sys_GALLERY
	.byte STATE_ID::sys_CREDITS

.proc title_subroutine
mode_select = temp3_8
	lda sys_mode
	and #sys_MODE_INITDONE
	bne @skip_init
	; load screen, tileset, nametable, and palettes associated
	jsr title_init
	rts


@skip_init:
	; if palette fading is in progress, skip all logic and continue raster display
	lda sys_mode
	and #sys_MODE_PALETTEFADE
	bne @check_fade_dir

	; run logic
	; todo:  refer to "docs/state machine diagram or whatevs.png"
	lda #KEY_UP|KEY_DOWN|KEY_SELECT
	bit new_keys
	bne @toggle_mode_select

@check_start:
	lda #KEY_START|KEY_A
	bit new_keys
	bne @mode_selected
	jmp @skip

@toggle_mode_select:
	lda mode_select
	eor #%00000001
	sta mode_select

	; important: sprite1 is star sprite!
	; toggle sprite1 y coordinate between $98 and $A8
	ldy #4
	lda (shadow_oam_ptr),y
	eor #%00110000
	sta (shadow_oam_ptr),y

	jmp @skip

@mode_selected:
	lda #3
	jsr start_music
	lda #fade_dir_out
	sta fade_dir
	lda sys_mode
	ora #sys_MODE_PALETTEFADE
	sta sys_mode
	jmp @skip

@check_fade_dir:
	lda fade_dir
	bpl @skip ; do nothing else on fade in
	lda pal_fade_amt
	cmp #fade_amt_max
	bne @skip

	; after fade out is done, bug the system to transfer to gallery state
	ldx mode_select
	lda title_select,x
	sta sys_state
	lda sys_mode
	and #($FF - sys_MODE_INITDONE)
	sta sys_mode
	; hackfix: since gallery mode recalls the init routine, we set music here in advance
	; if in credits, this will be overriden anyway
	lda #1
	jsr start_music

@skip:
	; display raster title image
	jsr title_display_kernel_ntsc
	rts
.endproc

.proc title_init
	; disable rendering
	lda #0
	sta PPUMASK
	sta PPUCTRL
	
	; reset scroll
	sta ppu_scroll_x
	sta ppu_scroll_y

	; init OAM
	lda #0
	sta oam_size
	lda #>OAM_SHADOW_1
	sta shadow_oam_ptr+1
	jsr init_oam

	lda #0
	jsr start_music

	; set CHR bank to universal tileset
	a53_set_chr_safe #3

	lda #NAMETABLE_A
	jsr load_titlescreen

	; let the NMI handler know that we're done initializing
	; let the NMI handler know that we're fading in
	; let the NMI handler enable OAM and palette
	lda sys_mode
	ora #sys_MODE_INITDONE|sys_MODE_PALETTEFADE|sys_MODE_NMIPAL
	sta sys_mode

	; init fade
	lda #fade_amt_max
	sta pal_fade_amt

	; fade in
	lda #fade_dir_in
	sta fade_dir

	; slow fade speed
	lda #(4-1)
	sta pal_fade_int
	sta pal_fade_ctr

	; remove if the stuff up here enables NMI
	; enable NMI immediately
	lda #NT_2000|OBJ_1000|BG_0000|VBLANK_NMI
	sta PPUCTRL
	sta s_PPUCTRL
	rts
.endproc
