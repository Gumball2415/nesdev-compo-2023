.include "global.inc"
.include "nes.inc"
.include "checked_branches.inc"

.export gallery_subroutine

.segment MAIN_ROUTINES_BANK_SEGMENT

.align $100
.proc gallery_display_kernel_ntsc
	; here, we have a budget of 10528 cycles before sprite 0 hits

.if .not(::SKIP_DOT_DISABLE)
	; delay until it's ok to poll for sprite 0
	@wait_sprite0_reset:
		bit PPUSTATUS
		bvs @wait_sprite0_reset
.endif

	inc s_A53_MUTEX
	; splitting the a53_write macro in half for timing reasons 1/2
	lda #A53_REG_CHR_BANK
	sta z:s_A53_REG_SELECT

@wait_sprite0_hit:
	bit PPUSTATUS
	bvc @wait_sprite0_hit ; wait for sprite 0 hit

	; splitting the a53_write macro in half for timing reasons 2/2
	sta A53_REG_SELECT
	lda #1
	sta A53_REG_VALUE

	; cycle-counted delay to wait before swapping to CHR bank 2 (3rd image slice)
	; exactly 64 scanlines
	lda #%00010000                   ;    2    2  DMC active status bit
	and SNDCHN                       ;    4    6
	c_beq @dpcm_off                  ;    3    9
	;                                ;    .   ..     -1    8

	lda s_dmc_4010                   ;    .   ..      4   12
	and #$0f                         ;    .   ..      2   14
	clc                              ;    .   ..      2   16
	adc #1                           ;    .   ..      2   18
	bne @skip_compensation           ;    .   ..      3   21  always jumps

@dpcm_off:
	;                                ;         9      .   ..
	inc temp1_8                      ;    5   14      .   ..
	dec temp1_8                      ;    5   19      .   ..
	nop                              ;    2   21      .   ..

@skip_compensation:
	ldx #11                          ;    2   23

	@delay:
		ldy #128                          ;   2   2

		@inner:
			dey                           ;  2  2
			c_bne @inner                  ;  3  5
			;                             ; -1

		;                                 ; 639 641
		dex                               ;   2 643
		c_bne @delay                      ;   3 646
		;                                 ;  -1

	;                                ; 7105 7128 + s, s = stolen cycles from DPCM playback
	ldy #7                           ;    2 7130 + s
	@loop:
		dey          ;  2  2
		c_bne @loop  ;  3  5
	;                    ; -1
	;                                ;   34 7164 + s
	nop                              ;    2 7166 + s
	nop                              ;    2 7168 + s
	.scope
		tay                              ;    2  2
		lda jump_table_lo, y             ;    4  6
		sta temp1_16                     ;    3  9
		lda jump_table_hi, y             ;    4 13
		sta temp1_16+1                   ;    3 16
		jmp (temp1_16)                   ;    5 21
	.endscope
	;                                ;   21 7189 + s
nop_sled_start:
.repeat 34
	nop
.endrep
nop_sled_end:
	;                                ; 68-s 7257
	ldx $0                           ;    3 7260  dummy
	a53_write A53_REG_CHR_BANK, #2   ;   15 7275

	dec s_A53_MUTEX

	; let update_graphics know that we have sprite0
	lda sys_mode
	ora #sys_MODE_SPRITE0SET
	sta sys_mode
	rts

	.macro nopsled_ptr_cycles_lo cycles
		.assert cycles & 1 = 0, error, "cycles must be an even number"
		.assert (nop_sled_end - (cycles / 2)) >= nop_sled_start, error, "exceeded starting point of nop sled"
		.byte (.lobyte (nop_sled_end - (cycles / 2)))
	.endmacro
	.macro nopsled_ptr_cycles_hi cycles
		.assert cycles & 1 = 0, error, "cycles must be an even number"
		.assert (nop_sled_end - (cycles / 2)) >= nop_sled_start, error, "exceeded starting point of nop sled"
		.byte (.hibyte (nop_sled_end - (cycles / 2)))
	.endmacro
jump_table_lo:
	nopsled_ptr_cycles_lo 68   ; DPCM off
	nopsled_ptr_cycles_lo 60   ; DPCM rate $0
	nopsled_ptr_cycles_lo 58   ; DPCM rate $1
	nopsled_ptr_cycles_lo 58   ; DPCM rate $2
	nopsled_ptr_cycles_lo 56   ; DPCM rate $3
	nopsled_ptr_cycles_lo 56   ; DPCM rate $4
	nopsled_ptr_cycles_lo 54   ; DPCM rate $5
	nopsled_ptr_cycles_lo 52   ; DPCM rate $6
	nopsled_ptr_cycles_lo 52   ; DPCM rate $7
	nopsled_ptr_cycles_lo 50   ; DPCM rate $8
	nopsled_ptr_cycles_lo 46   ; DPCM rate $9
	nopsled_ptr_cycles_lo 42   ; DPCM rate $a
	nopsled_ptr_cycles_lo 40   ; DPCM rate $b
	nopsled_ptr_cycles_lo 34   ; DPCM rate $c
	nopsled_ptr_cycles_lo 26   ; DPCM rate $d
	nopsled_ptr_cycles_lo 18   ; DPCM rate $e
	nopsled_ptr_cycles_lo  0   ; DPCM rate $f
	.assert >* = >jump_table_lo, error, "table data crosses a page boundary"

jump_table_hi:
	nopsled_ptr_cycles_hi 68   ; DPCM off
	nopsled_ptr_cycles_hi 60   ; DPCM rate $0
	nopsled_ptr_cycles_hi 58   ; DPCM rate $1
	nopsled_ptr_cycles_hi 58   ; DPCM rate $2
	nopsled_ptr_cycles_hi 56   ; DPCM rate $3
	nopsled_ptr_cycles_hi 56   ; DPCM rate $4
	nopsled_ptr_cycles_hi 54   ; DPCM rate $5
	nopsled_ptr_cycles_hi 52   ; DPCM rate $6
	nopsled_ptr_cycles_hi 52   ; DPCM rate $7
	nopsled_ptr_cycles_hi 50   ; DPCM rate $8
	nopsled_ptr_cycles_hi 46   ; DPCM rate $9
	nopsled_ptr_cycles_hi 42   ; DPCM rate $a
	nopsled_ptr_cycles_hi 40   ; DPCM rate $b
	nopsled_ptr_cycles_hi 34   ; DPCM rate $c
	nopsled_ptr_cycles_hi 26   ; DPCM rate $d
	nopsled_ptr_cycles_hi 18   ; DPCM rate $e
	nopsled_ptr_cycles_hi  0   ; DPCM rate $f
	.assert >* = >jump_table_hi, error, "table data crosses a page boundary"

.endproc

.importzp line_counter
.proc gallery_subroutine
exit_check = line_counter
	lda sys_mode
	and #sys_MODE_INITDONE
	bne @skip_init
	; load screen, tileset, nametable, and palettes associated
	jsr gallery_init
	rts



@skip_init:
	; if palette fading is in progress, skip all logic and continue raster display
	lda sys_mode
	and #sys_MODE_PALETTEFADE
	bne @check_fade_dir

	; run logic
	; todo:  refer to "docs/state machine diagram or whatevs.png"
	lda #KEY_LEFT
	bit new_keys
	beq @check_right

	jsr gallery_left
	jmp @img_index_epilogue

@check_right:
	lda #KEY_RIGHT
	bit new_keys
	beq @check_b
	jsr gallery_right
	jmp @img_index_epilogue

@check_b:
	lda #KEY_B
	bit new_keys
	beq @skip
	jsr gallery_exit
	lda #3
	jsr start_music

@img_index_epilogue:
	; fade out
	lda #fade_dir_out
	sta fade_dir

	; bug the system to transfer the new CHR
	; bug the system to do fade out
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
	lda exit_check
	bne @exit
	
	; after fade out is done, bug the system to transfer the new CHR
	lda sys_mode
	and #($FF - sys_MODE_INITDONE)
	sta sys_mode
	jmp @skip

@exit:
	; after fade out is done, go back to title
	lda #STATE_ID::sys_TITLE
	sta sys_state
	lda sys_mode
	and #($FF - (sys_MODE_INITDONE|sys_MODE_GALLERYINIT))
	sta sys_mode
	lda #3
	jsr start_music

@skip:
	; display raster bankswitched image
	jsr gallery_display_kernel_ntsc
	rts


IMG_INDEX_MAX = <(img_table_size/2)-1

; helper functions
gallery_left:
	; change the image index
	lda img_index
	beq @wrap_up

	dec img_index
	jmp @left_end

@wrap_up:
	lda #IMG_INDEX_MAX
	sta img_index
@left_end:
	rts


gallery_right:
	; change the image index
	lda img_index
	cmp #IMG_INDEX_MAX
	beq @wrap_down

	inc img_index
	jmp @right_end

@wrap_down:
	lda #0
	sta img_index

@right_end:
	rts


gallery_exit:
	lda #1
	sta exit_check
	rts
.endproc

.proc gallery_init
exit_check = line_counter
	; disable rendering
	lda #0
	sta PPUMASK
	sta PPUCTRL
	
	; clear OAM
	lda #$FF
	ldx #0
@clear_OAM:
	sta OAM_SHADOW_1,x
	sta OAM_SHADOW_2,x
	inx
	bne @clear_OAM

	; set CHR bank to first bank of image
	a53_set_chr_safe #0
	
	; reset exit check variable
	lda #0
	sta exit_check

	lda #NAMETABLE_A
	jsr set_gallery_nametable

	lda #NAMETABLE_C
	jsr set_gallery_loading_screen
	
	; let the system know we've already initialized the nametables
	; let the NMI handler know that we're transferring CHR
	; enable OAM transfer for sprite 0
	lda sys_mode
	ora #sys_MODE_GALLERYINIT
	sta sys_mode
	
	; init fade here, so that the first frame doesn't flash
	lda #fade_amt_max
	sta pal_fade_amt

	; this is a special routine
	; it has to load chr while NMI is enabled
	jsr load_chr_bitmap

	; let the NMI handler know that we're done loading the current gallery image
	; let the NMI handler know that we're done transferring CHR
	; let the NMI handler know that we're fading in
	lda sys_mode
	and #($FF - sys_MODE_GALLERYLOAD)
	ora #sys_MODE_INITDONE|sys_MODE_PALETTEFADE
	sta sys_mode

	; set fade direction
	lda #fade_dir_in
	sta fade_dir

	; fast fade speed
	lda #2
	sta pal_fade_int
	sta pal_fade_ctr
	
	; setup PPUCTRL for gallery
	lda #NT_2000|OBJ_8X16|BG_0000|VBLANK_NMI
	sta s_PPUCTRL
	rts
.endproc
