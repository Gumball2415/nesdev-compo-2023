.include "global.inc"
.include "nes.inc"
.include "checked_branches.inc"

.segment "ZEROPAGE"
nmis:        .res 1
cur_keys:    .res 2
new_keys:    .res 2

.segment "PRGFIXED_C000"

.import title_subroutine
.import gallery_subroutine
.import credits_subroutine
program_table_lo:
	.byte .lobyte(title_subroutine)
	.byte .lobyte(gallery_subroutine)
	.byte .lobyte(credits_subroutine)

program_table_hi:
	.byte .hibyte(title_subroutine)
	.byte .hibyte(gallery_subroutine)
	.byte .hibyte(credits_subroutine)

.proc irq_handler
	rti
.endproc

.proc nmi_handler
	pha
	tya
	pha
	txa
	pha

	inc nmis

	lda sys_mode
	and #sys_MODE_PALETTEFADE
	beq @skip_palettefade
	; force palette update when fading
	lda sys_mode
	ora #sys_MODE_NMIPAL
	sta sys_mode
	lda fade_dir
	jsr run_fade

	; check if we're interrupting gallery CHR transfer
@skip_palettefade:
	lda sys_mode
	and #sys_MODE_GALLERYLOAD
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
		bit sys_mode ; sys_MODE_SPRITE0SET
		bvc @skip_xy_set
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

.proc gallery_chr_transfer_interrupt
	lda #NAMETABLE_C
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
	
	; since we are interrupting mainloop, run music here too
	jsr run_music

@check_sprite0:
	bit PPUSTATUS
	bvc @check_sprite0 ; wait for sprite 0 hit

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
	rts
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
	lda #MAIN_ROUTINES_BANK
	sta s_A53_PRG_BANK
	a53_set_prg s_A53_PRG_BANK

@vblankwait2:
	bit PPUSTATUS
	bpl @vblankwait2

	; as we are in vblank, transfer palettes so that we don't linger on a dead screen
	jsr transfer_palette
	
	a53_set_prg <.bank(universal_tileset)
	lda #<universal_tileset
	ldx #>universal_tileset
	jsr load_ptr_temp1_16
	lda #$10
	jsr transfer_4k_chr
	a53_set_prg s_A53_PRG_BANK

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
	lda #0
	jsr start_music
	
	jmp mainloop
.endproc

.proc mainloop
	; read input
	jsr read_pads
	; run music
	jsr run_music
	; run the machine
	jsr run_state_machine
	; run fade algorithm
	lda sys_mode
	and #sys_MODE_PALETTEFADE
	beq @skip_palettefade

	; force palette update when fading
	lda sys_mode
	ora #sys_MODE_NMIPAL
	sta sys_mode
	jsr fade_shadow_palette

@skip_palettefade:
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
	a53_set_prg #MAIN_ROUTINES_BANK
	jmp (temp1_16)

@end:
	; something has gone terribly wrong.
	jmp @end
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
; set pointer using A and X
; this happens quite a lot, so it may save bytes
; on just calling a subroutine instead
; @param A: low byte of address
; @param X: high byte of address
; @param temp2_16: pointer variable
.proc load_ptr_temp2_16
	sta temp2_16+0
	stx temp2_16+1
	rts
.endproc

;;
; set pointer using A and X
; this happens quite a lot, so it may save bytes
; on just calling a subroutine instead
; @param A: low byte of address
; @param X: high byte of address
; @param temp3_16: pointer variable
.proc load_ptr_temp3_16
	sta temp3_16+0
	stx temp3_16+1
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

;;
; far call routine in a different bank
; we can't use temp1_16 because most routines use it as a pointer parameter
; we can't use temp2_16 because interrupt proofing uses it as a PPUADDR tracker
; clobbers A
; @param temp1_8: A param of routine
; @param temp3_8: bank of routine
; @param temp3_16: pointer to routine
.proc far_call_subroutine 
	; push the current bank
	lda s_A53_PRG_BANK
	pha
	; switch banks
	a53_set_prg_safe temp3_8
	; call to target

	; simulate a JSR indirect
	lda #>(far_call_subroutine_return-1)
	pha
	lda #<(far_call_subroutine_return-1)
	pha
	lda temp1_8
	jmp (temp3_16)
	; pull current bank
far_call_subroutine_return:
	pla
	sta s_A53_PRG_BANK
	; switch banks
	a53_set_prg_safe s_A53_PRG_BANK
	rts
.endproc

; TODO; self modifying implementation
; ram: ; place in RAM
  ; jmp $0000

; lda #<dest
; sta ram+1
; lda #>dest
; sta ram+2
; jsr ram