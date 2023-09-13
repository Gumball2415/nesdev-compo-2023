.include "global.inc"
.include "nes.inc"
.include "checked_branches.inc"

; waits for end of vblank before enabling rendering
; scanline 0 is glitched
SKIP_DOT_DISABLE = 1

.segment "ZEROPAGE"
nmis:           .res 1
cur_keys:       .res 2
new_keys:       .res 2

.segment "PRGFIXED_C000"

; these routines are sensitive to page crosses
.proc gallery_display_kernel_ntsc
	; here, we have a budget of 10528 cycles before sprite 0 hits

	; delay until it's ok to poll for sprite 0
@wait_sprite0_reset:
	bit PPUSTATUS
	bvs @wait_sprite0_reset

@wait_vblank_end:
	bit PPUSTATUS
	bvs @wait_vblank_end

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

program_table_lo:
	.byte .lobyte(title_subroutine)
	.byte .lobyte(gallery_subroutine)

program_table_hi:
	.byte .hibyte(title_subroutine)
	.byte .hibyte(gallery_subroutine)

.proc nmi_handler
	pha
	tya
	pha
	txa
	pha

	inc nmis

	; check if we're interrupting CHR transfer
	lda sys_mode
	and #sys_MODE_CHRTRANSFER
	beq @not_chr_transfer

	jsr chrtransfer_interrupt
	jmp @skip_update_graphics

@not_chr_transfer:
	jsr update_graphics

@skip_update_graphics:
	jsr read_pads
	jsr run_music

	pla
	tax
	pla
	tay
	pla
	rti
.endproc

.proc chrtransfer_interrupt
	lda #$24
	jsr update_progress_bar
	; use shadow oam 2 for sprite 0 hit
	lda #$06
	sta shadow_oam_ptr+1
	; overwrite PPUCTRL and s_A53_CHR_BANK
	lda s_PPUCTRL
	pha
	lda s_A53_CHR_BANK
	pha
	lda #3
	sta s_A53_CHR_BANK
	lda #NT_2400|OBJ_8X16|BG_1000|VBLANK_NMI
	sta s_PPUCTRL
	jsr update_graphics

@wait_sprite0_reset:
	bit PPUSTATUS
	bvs @wait_sprite0_reset

@check_sprite0:
	bit PPUSTATUS
	bvc @check_sprite0  ; spin on sprite 0 hit

	; prepare for partial CHR load
	lda #0
	sta PPUMASK
	pla
	sta s_A53_CHR_BANK
	pla
	sta s_PPUCTRL
	sta PPUCTRL
	a53_set_chr s_A53_CHR_BANK
	lda #$07
	sta shadow_oam_ptr+1
	lda sys_mode
	ora #sys_MODE_NMIOCCURRED
	sta sys_mode
	bit PPUSTATUS
	lda temp2_16+1
	sta PPUADDR
	lda temp2_16+0
	sta PPUADDR
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
	sta $0700,x
	sta $0600,x
	lda #0
	inx
	bne @clrmem

	; set shadow OAM page
	lda #$07
	sta shadow_oam_ptr+1

	; Set PRG and CHR bank
	jsr init_action53
	lda #0
	sta s_A53_CHR_BANK
	a53_set_chr s_A53_CHR_BANK
	lda #0
	sta s_A53_PRG_BANK

@vblankwait2:
	bit PPUSTATUS
	bpl @vblankwait2
	
	; load universal tileset and palette
	lda #<universal_pal
	ldx #>universal_pal
	jsr load_ptr_temp1_16
	jsr transfer_img_pal
	
	; as we are in vblank, transfer palettes so that we don't linger on a dead screen
	jsr transfer_palette

	; clear current nametable
	lda #$00
	ldx #$20
	ldy #$00
	jsr ppu_clear_nt

	; set up universal bank
	a53_set_chr #3
	lda #<universal_tileset
	ldx #>universal_tileset
	jsr load_ptr_temp1_16
	lda #$00
	jsr transfer_4k_chr
	lda #<universal_tileset
	ldx #>universal_tileset
	jsr load_ptr_temp1_16
	lda #$10
	jsr transfer_4k_chr

	a53_set_chr s_A53_CHR_BANK

	; initialize NMI handler flags
	lda sys_mode
	ora #sys_MODE_NMIOAM|sys_MODE_NMIPAL
	sta sys_mode

	; enable NMI immediately
	lda #NT_2000|OBJ_8X16|BG_0000|VBLANK_NMI
	sta PPUCTRL
	sta s_PPUCTRL

	; enable rendering, will be updated later
	lda #BG_ON|OBJ_ON
	sta s_PPUMASK

	; set system state to title screen
	lda #STATE_ID::sys_GALLERYS
	sta sys_state

	; start music with song id #0
	lda #2
	sta img_index
	lda #0
	jsr start_music
	
	jmp mainloop
.endproc

.proc mainloop
	; run the machine
	jsr run_state_machine

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
	rts
.endproc

.proc gallery_subroutine
	lda sys_mode
	and #sys_MODE_CHRDONE
	bne @skip_init
	; load screen, tileset, nametable, and palettes associated
	jsr gallery_init
	rts



@skip_init:
	; run logic
	; todo:  refer to "docs/state machine diagram or whatevs.png"
	lda cur_keys
	and #KEY_LEFT
	beq @check_right

	jsr gallery_left
	jmp @img_index_epilogue

@check_right:
	lda cur_keys
	and #KEY_RIGHT
	beq @skip
	jsr gallery_right

@img_index_epilogue:
	; bug the system to transfer the new CHR
	lda sys_mode
	and #($FF - sys_MODE_CHRDONE)
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

	lda #$20
	jsr set_gallery_nametable

	lda #$24
	jsr set_gallery_loading_screen
	
	; let the system know we've already initialized the nametables
	; let the NMI handler know that we're transferring CHR
	lda sys_mode
	ora #sys_MODE_GALLERYINIT|sys_MODE_CHRTRANSFER
	sta sys_mode

	jsr load_chr_bitmap

	; let the NMI handler know that we're done transferring CHR
	lda sys_mode
	and #($FF - sys_MODE_CHRTRANSFER)
	ora #sys_MODE_CHRDONE
	sta sys_mode
	rts
.endproc

.proc update_graphics
	lda #0
	sta PPUMASK				; disable rendering
	sta PPUCTRL				; writes to PPUDATA will increment by 1 to the next PPU address

	; transfer palettes
	lda sys_mode
	and #sys_MODE_NMIPAL
	beq @skip_pal

	jsr transfer_palette
	lda sys_mode
	and #($FF - sys_MODE_NMIPAL)
	sta sys_mode

@skip_pal:
	; transfer OAM
	lda sys_mode
	and #sys_MODE_NMIOAM
	beq @skip_oam

	lda #0
	sta OAMADDR
	lda shadow_oam_ptr+1
	sta OAM_DMA

@skip_oam:
	
	; switch to initial graphics bank
	a53_set_chr s_A53_CHR_BANK

	; update scroll
	jsr update_scrolling

.if ::SKIP_DOT_DISABLE
@wait_vblank_end:
	bit PPUSTATUS
	bvs @wait_vblank_end

	lda #$00
	sta PPUMASK
	; zero out PPUADDR to avoid messing with the scroll
	sta PPUADDR
	sta PPUADDR

	ldy #$13
@wait_dotskip_pixel:
	dey
	bne @wait_dotskip_pixel
.endif

	lda s_PPUMASK
	sta PPUMASK

	lda s_PPUCTRL
	sta PPUCTRL

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
