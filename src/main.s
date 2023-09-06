.include "global.inc"
.include "nes.inc"
.include "checked_branches.inc"

.segment "ZEROPAGE"
temp1_8:        .res 1
temp2_8:        .res 1
temp1_16:       .res 2
temp2_16:       .res 2
temp3_16:       .res 2
sys_state:      .res 1
sys_mode:       .res 1

nmis:           .res 1
oam_used:       .res 1  ; starts at 0
cur_keys:       .res 2
new_keys:       .res 2

.segment "PRGFIXED_C000"

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
	
	; run music

	pla
	tax
	pla
	tay
	pla
	rti
.endproc

.proc irq_handler
	pha
	tya
	pha
	txa
	pha

	pla
	tax
	pla
	tay
	pla
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
	sta $300,x
	sta $400,x
	sta $500,x
	sta $600,x
	sta $700,x
	lda #$FF
	sta SHADOW_OAM,x
	lda #0
	inx
	bne @clrmem
	; clean shadow palette

	lda #$0F
	ldx #32
@clrspalette:
	dex
	sta shadow_palette,x
	bne @clrspalette

	; Set PRG bank
	jsr init_action53
	lda #0
	sta s_A53_CHR_BANK
	a53_set_chr s_A53_CHR_BANK
	lda #0
	sta s_A53_PRG_BANK

@vblankwait2:
	bit PPUSTATUS
	bpl @vblankwait2
	
	; transfer palettes so that we don't linger on a dead screen
	jsr transfer_palette

	; clear all CHR RAM, important for doing visual CHR loading
	; jsr clear_all_chr
	
	; load universal tileset in sprite tileset
	a53_set_chr #0
	lda #<universal_tileset
	ldx #>universal_tileset
	jsr load_ptr_temp1_16
	lda #$10
	jsr transfer_4k_chr
	a53_set_chr #1
	lda #<universal_tileset
	ldx #>universal_tileset
	jsr load_ptr_temp1_16
	lda #$10
	jsr transfer_4k_chr
	a53_set_chr #2
	lda #<universal_tileset
	ldx #>universal_tileset
	jsr load_ptr_temp1_16
	lda #$10
	jsr transfer_4k_chr
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

	; enable NMI immediately
	lda #VBLANK_NMI|OBJ_1000
	sta PPUCTRL
	sta s_PPUCTRL

	; enable rendering, will be updated later
	lda #BG_ON|OBJ_ON
	sta s_PPUMASK

	; set system state to title screen
	lda #STATE_ID::sys_GALLERYS
	sta sys_state
	
	lda #0
	sta img_progress
	
	jmp mainloop
.endproc

.proc mainloop
	; read controllers
	; clobbers the three 16-bit variables
	jsr read_pads

	; run the machine
	jsr run_state_machine
	
	lda nmis
wait_for_nmi:
	cmp nmis
	beq wait_for_nmi

	; update graphics
	jsr update_graphics

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

.proc update_graphics
	lda #0
	sta PPUMASK				; disable rendering
	sta PPUCTRL				; writes to PPUDATA will increment by 1 to the next PPU address
	; transfer OAM
	lda #0
	sta OAMADDR
	lda #>SHADOW_OAM
	sta OAM_DMA
	
	; transfer palettes
	jsr transfer_palette
	
	; update scroll
	jsr update_scrolling
	
	; switch to initial graphics bank
	a53_set_chr s_A53_CHR_BANK
	
	lda s_PPUMASK
	sta PPUMASK

	lda s_PPUCTRL
	sta PPUCTRL

	rts
.endproc

.proc title_subroutine
	rts
.endproc

.proc gallery_subroutine
	lda sys_mode
	and #sys_MODE_CHRTRANSFER
	bne @continue
	; load screen, tileset, nametable, and palettes associated
	jsr gallery_init
	rts

@continue:
	; run logic

	; display raster bankswitched image
	jsr gallery_display_kernel
	rts
.endproc

.proc gallery_display_kernel
	; here, we have a budget of 10528 cycles before sprite 0 hits
	; delay for a bit to ensure we're into the visible screen area at this point
	; TODO: remove this if we don't need this delay anymore, if we have stuff to do before the sprite 0 check?
	ldy #0
	:
		nop
		dey
		bne :-

@check_sprite0:
	bit PPUSTATUS
	bvc @check_sprite0  ; spin on sprite 0 hit

	a53_write A53_REG_CHR_BANK, #1

.scope
	; cycle-counted delay to wait before swapping to CHR bank 2 (3rd image slice)
	; exactly 64 scanlines
	ldx #13                          ;    2
	@delay:
		ldy #110                          ;   2
		@inner:
			dey                           ;  2  2
			c_bne @inner                  ;  3  5
			;                             ; -1
		;                                 ; 549 551
		dex                               ;   2 553
		c_bne @delay                      ;   3 556
		;                                 ;  -1
	;                                ; 7227 7229
	ldy #6                           ;    2 7231
	:
		dey        ;  2  2
		c_bne :-   ;  3  5
		;          ; -1
	;                                ;   29 7260
	a53_write A53_REG_CHR_BANK, #2   ;   15 7275
.endscope
	
.scope
	; cycle-counted delay to wait before swapping to CHR bank 3 (status bar)
	; exactly 64 scanlines
	ldx #13                          ;    2
	@delay:
		ldy #110                          ;   2
		@inner:
			dey                           ;  2  2
			c_bne @inner                  ;  3  5
			;                             ; -1
		;                                 ; 549 551
		dex                               ;   2 553
		c_bne @delay                      ;   3 556
		;                                 ;  -1
	;                                ; 7227 7229
	ldy #6                           ;    2 7231
	:
		dey        ;  2  2
		c_bne :-   ;  3  5
		;          ; -1
	;                                ;   29 7260
	a53_write A53_REG_CHR_BANK, #3   ;   15 7275
.endscope
	
	rts
.endproc

.proc gallery_init
	; disable rendering
	lda #0
	sta PPUMASK

	lda #$20
	jsr set_gallery_nametable
	lda #$24
	jsr set_gallery_loading_screen

	jsr load_chr_bitmap
	
	;set up sprite zero in OAM shadow buffer
	ldy #<gallery_sprite0_data_size
	dey
	:
		lda gallery_sprite0_data, y
		sta SHADOW_OAM, y
		dey
		bpl :-

	lda sys_mode
	ora #sys_MODE_CHRTRANSFER
	sta sys_mode
	rts
.endproc

;;
; helper function: set pointer using A and X
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
