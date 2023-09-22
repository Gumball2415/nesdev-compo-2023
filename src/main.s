.include "global.inc"
.include "nes.inc"
.include "checked_branches.inc"

; waits for end of vblank before enabling rendering
; scanline 0 is glitched
SKIP_DOT_DISABLE = 1

.segment "ZEROPAGE"
nmis:        .res 1
cur_keys:    .res 2
new_keys:    .res 2
mode_select: .res 1

.segment "PRGFIXED_C000"

; these routines are sensitive to page crosses
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
	bvc @wait_sprite0_hit  ; spin on sprite 0 hit

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

.proc title_display_kernel_ntsc
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
	bvc @wait_sprite0_hit  ; spin on sprite 0 hit
	dec s_A53_MUTEX
	lda #NT_2000|OBJ_1000|BG_1000|VBLANK_NMI
	sta PPUCTRL

	; let update_graphics know that we have sprite0
	lda sys_mode
	ora #sys_MODE_SPRITE0SET
	sta sys_mode
	rts
.endproc



program_table_lo:
	.byte .lobyte(title_subroutine)
	.byte .lobyte(gallery_subroutine)
	.byte .lobyte(credits_subroutine)

program_table_hi:
	.byte .hibyte(title_subroutine)
	.byte .hibyte(gallery_subroutine)
	.byte .hibyte(credits_subroutine)

title_select:
	.byte STATE_ID::sys_GALLERY
	.byte STATE_ID::sys_CREDITS

.proc nmi_handler
	pha
	tya
	pha
	txa
	pha

	inc nmis

	lda #sys_MODE_PALETTEFADE
	bit sys_mode
	beq @skip_palettefade
	; force palette update when fading
	lda sys_mode
	ora #sys_MODE_NMIPAL
	sta sys_mode
	lda fade_dir
	jsr run_fade

	; check if we're interrupting gallery CHR transfer
@skip_palettefade:
	lda #sys_MODE_GALLERYLOAD
	bit sys_mode
	beq @skip_galleryload

	jsr gallery_chr_transfer_interrupt
	jmp @skip_update_graphics

@skip_galleryload:
	jsr update_graphics

@skip_update_graphics:
	lda sys_mode
	ora #sys_MODE_NMIOCCURRED
	sta sys_mode

	pla
	tax
	pla
	tay
	pla
	rti
.endproc

.proc gallery_chr_transfer_interrupt
	lda #$24
	jsr update_progress_bar
	; use shadow oam 2 for sprite 0 hit
	lda #>OAM_SHADOW_2
	sta shadow_oam_ptr+1
	; overwrite s_A53_CHR_BANK
	lda s_A53_CHR_BANK
	pha
	lda #3
	sta s_A53_CHR_BANK
	jsr update_graphics

.if .not(::SKIP_DOT_DISABLE)
@wait_sprite0_reset:
	bit PPUSTATUS
	bvs @wait_sprite0_reset
.endif

@check_sprite0:
	bit PPUSTATUS
	bvc @check_sprite0  ; spin on sprite 0 hit

	; let the next update_graphics know that we have sprite0
	lda sys_mode
	ora #sys_MODE_SPRITE0SET
	sta sys_mode
	; prepare for partial CHR load
	lda #0
	sta PPUMASK
	pla
	sta s_A53_CHR_BANK
	a53_set_chr s_A53_CHR_BANK
	lda #>OAM_SHADOW_1
	sta shadow_oam_ptr+1
	bit PPUSTATUS
	lda temp2_16+1
	sta PPUADDR
	lda temp2_16+0
	sta PPUADDR
	
	; since we are interrupting mainloop, run music here too
	jsr run_music
	rts
.endproc

.proc irq_handler
	rti
.endproc

.proc reset_handler
	sei        ; ignore IRQs
	cld        ; disable decimal mode
	ldx #$40
	stx $4017  ; disable APU frame IRQ
	ldx #$ff
	txs        ; Set up stack
	inx        ; now X = 0
	stx PPUCTRL  ; disable NMI
	stx PPUMASK  ; disable rendering
	stx $4010  ; disable DMC IRQs

	; The vblank flag is in an unknown state after reset,
	; so it is cleared here to make sure that @vblankwait1
	; does not exit immediately.
	bit PPUSTATUS

	; First of two waits for vertical blank to make sure that the
	; PPU has stabilized
@vblankwait1:  
	bit PPUSTATUS
	bpl @vblankwait1

	; We now have about 30,000 cycles to burn before the PPU stabilizes.
	; One thing we can do with this time is put RAM in a known state.
	; Here we fill it with $00, which matches what (say) a C compiler
	; expects for BSS.  Conveniently, X is still 0.
	txa
@clrmem:
	sta $000,x
	sta $100,x
	sta $200,x
	sta $300,x
	sta $400,x
	sta $500,x
	; clear shadow OAM 1 and 2
	lda #$FF
	sta OAM_SHADOW_1,x
	sta OAM_SHADOW_2,x
	lda #0
	inx
	bne @clrmem

	; initialize shadow palette
	ldy #0
	lda #$0F

@clrshadowpal:
	sta shadow_palette_primary,y
	sta shadow_palette_secondary,y
	iny
	cpy #32
	bne @clrshadowpal

	; set shadow OAM page
	lda #>OAM_SHADOW_1
	sta shadow_oam_ptr+1

	; Set PRG and CHR bank
	jsr init_action53
	lda #3 ; universal CHR bank
	sta s_A53_CHR_BANK
	a53_set_chr s_A53_CHR_BANK
	lda #0
	sta s_A53_PRG_BANK

@vblankwait2:
	bit PPUSTATUS
	bpl @vblankwait2

	; as we are in vblank, transfer palettes so that we don't linger on a dead screen
	jsr transfer_palette

	; set up universal bank
	a53_set_chr #3
	lda #<universal_tileset
	ldx #>universal_tileset
	jsr load_ptr_temp1_16
	lda #$10
	jsr transfer_4k_chr

	; enable NMI immediately
	lda #VBLANK_NMI
	sta PPUCTRL
	sta s_PPUCTRL

	; enable rendering, will be updated later
	lda #BG_ON|OBJ_ON
	sta s_PPUMASK

	; set system state to title screen
	lda #STATE_ID::sys_TITLE
	sta sys_state

	; start music with song id #0
	lda #1
	jsr start_music
	
	jmp mainloop
.endproc

.proc mainloop
	; read input
	jsr read_pads
	; run fade algorithm
	lda #sys_MODE_PALETTEFADE
	bit sys_mode
	beq @skip_palettefade

	; force palette update when fading
	lda sys_mode
	ora #sys_MODE_NMIPAL
	sta sys_mode
	jsr fade_shadow_palette

@skip_palettefade:
	; run the machine
	jsr run_state_machine
	; run music
	; we do it here to ensure that sprite0 wait will not crash
	jsr run_music
	; done, wait for NMI
	ldx #1
	jsr wait_x_frames
	jmp mainloop
.endproc

.proc run_state_machine
	ldx sys_state
	cpx #STATE_ID::sys_ID_COUNT
	bcs @end

	lda program_table_lo,x
	sta temp1_16+0
	lda program_table_hi,x
	sta temp1_16+1
	jmp (temp1_16)

@end:
	; something has gone terribly wrong.
	jmp @end
.endproc

.proc title_subroutine
	lda sys_mode
	and #sys_MODE_INITDONE
	bne @skip_init
	; load screen, tileset, nametable, and palettes associated
	jsr title_init
	rts


@skip_init:
	; if palette fading is in progress, skip all logic and continue raster display
	lda #sys_MODE_PALETTEFADE
	bit sys_mode
	bne @check_fade_dir

	; run logic
	; todo:  refer to "docs/state machine diagram or whatevs.png"
	lda #KEY_UP|KEY_DOWN|KEY_SELECT
	bit new_keys
	bne @toggle_select

@check_start:
	lda #KEY_START
	bit new_keys
	bne @start_selected
	jmp @skip

@toggle_select:
	lda mode_select
	eor #%00000001
	sta mode_select

	; important: sprite1 is star sprite!
	ldy #4
	lda (shadow_oam_ptr),y
	eor #%00110000
	sta (shadow_oam_ptr),y

	jmp @skip

@start_selected:
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
	
	; clear OAM
	lda #$FF
	ldx #0
@clear_OAM:
	sta OAM_SHADOW_1,x
	sta OAM_SHADOW_2,x
	inx
	bne @clear_OAM
	lda #0
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
	lda #$20
	jsr load_titlescreen

	lda #$20
	jsr set_title_nametable

	; let the NMI handler know that we're done initializing
	; let the NMI handler know that we're fading in
	; let the NMI handler enable OAM and palette
	lda sys_mode
	ora #sys_MODE_INITDONE|sys_MODE_PALETTEFADE|sys_MODE_NMIOAM|sys_MODE_NMIPAL
	sta sys_mode

	; init fade
	lda #fade_amt_max
	sta pal_fade_amt

	; fade in
	lda #fade_dir_in
	sta fade_dir

	; slow fade speed
	lda #4
	sta pal_fade_int
	sta pal_fade_ctr

	; remove if the stuff up here enables NMI
	; enable NMI immediately
	lda #NT_2000|OBJ_1000|BG_0000|VBLANK_NMI
	sta PPUCTRL
	sta s_PPUCTRL
	rts
.endproc 

.proc gallery_subroutine
	lda #sys_MODE_INITDONE
	bit sys_mode
	bne @skip_init
	; load screen, tileset, nametable, and palettes associated
	jsr gallery_init
	rts



@skip_init:
	; if palette fading is in progress, skip all logic and continue raster display
	lda #sys_MODE_PALETTEFADE
	bit sys_mode
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
	beq @skip
	jsr gallery_right

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
	bne @skip ; after fade out is done, bug the system to transfer the new CHR
	
	lda sys_mode
	and #($FF - sys_MODE_INITDONE)
	sta sys_mode

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
.endproc

.proc gallery_init
	; disable rendering
	lda #0
	sta PPUMASK
	sta PPUCTRL

	lda #0
	sta s_A53_CHR_BANK
	a53_set_chr_safe s_A53_CHR_BANK

	lda #$20
	jsr set_gallery_nametable

	lda #$24
	jsr set_gallery_loading_screen
	
	; let the system know we've already initialized the nametables
	; let the NMI handler know that we're transferring CHR
	; enable OAM transfer for sprite 0
	lda sys_mode
	ora #sys_MODE_GALLERYINIT|sys_MODE_GALLERYLOAD
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

.proc update_graphics
	lda #0
	sta PPUMASK				; disable rendering
	sta PPUCTRL				; writes to PPUDATA will increment by 1 to the next PPU address

	; transfer OAM
	lda sys_mode
	and #sys_MODE_NMIOAM
	beq @skip_oam

	lda #0
	sta OAMADDR
	lda shadow_oam_ptr+1
	sta OAM_DMA

@skip_oam:

	; transfer palettes
	lda sys_mode
	and #sys_MODE_NMIPAL
	beq @skip_pal

	jsr transfer_palette
	lda sys_mode
	and #($FF - sys_MODE_NMIPAL)
	sta sys_mode

@skip_pal:
	
	; switch to initial graphics bank
	a53_set_chr_safe s_A53_CHR_BANK

	; update scroll
	jsr update_scrolling

.if ::SKIP_DOT_DISABLE
		; check if sprite 0 hit has already occured
		; if not, skip the PPUADDR hack
		lda sys_mode
		and #sys_MODE_SPRITE0SET
		beq @skip_xy_set
	@wait_vblank_end:
		bit PPUSTATUS
		bvs @wait_vblank_end

		lda #$00
		sta PPUMASK
		;  First    Second
		; /======\ /======\
		; 00yyNNYY YYYXXXXX
		;  ||||||| |||+++++- coarse X scroll
		;  |||||++-+++------ coarse Y scroll
		;  |||++------------ nametable select
		;  +++-------------- fine Y scroll

		; prepare first write
		ldx ppu_scroll_y
		inx ; we're off by one scanline, increment to compensate
		txa
		rol
		rol
		rol
		rol
		tax ; for first 0yy and second YYY
		ror
		and #%00000011
		; YY
		sta temp1_8
		txa
		and #%00110000
		ora temp1_8
		; 0yy
		sta temp1_8
		lda s_PPUCTRL
		and #%00000011
		asl
		asl
		ora temp1_8
		; NN
		sta temp1_8

		; prepare second write
		txa
		and #%11100000
		; YYY
		sta temp2_8
		lda ppu_scroll_x
		lsr
		lsr
		lsr
		ora temp2_8
		; XXXXX
		sta temp2_8
		
		lda temp1_8
		sta PPUADDR
		lda temp2_8
		sta PPUADDR

		; toggle sprite 0 flag occurence
		lda sys_mode
		and #($FF - sys_MODE_SPRITE0SET)
		sta sys_mode

		ldy #$12
	@wait_hblank:
		dey
		bne @wait_hblank
	@skip_xy_set:
.endif

	lda s_PPUCTRL
	sta PPUCTRL

	lda s_PPUMASK
	sta PPUMASK

	rts
.endproc

.proc credits_subroutine
	rts
.endproc

; helper functions

;;
; set pointer using A and X
; this happens quite a lot, so it may save bytes
; on just calling a subroutine instead
; @param A: low byte of address
; @param X: high byte of address
; @param temp1_16: pointer variable
.proc load_ptr_temp1_16
	sta temp1_16+0
	stx temp1_16+1
	rts
.endproc

;;
; wait X amount of frames
; note: NMI must be enabled
.proc wait_x_frames
	lda nmis
@wait_for_nmi:
	cmp nmis
	beq @wait_for_nmi
	dex
	bne @wait_for_nmi
	rts
.endproc
