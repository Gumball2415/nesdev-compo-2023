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

; these routines are sensitive to page crosses
.proc gallery_display_kernel
	; here, we have a budget of 10528 cycles before sprite 0 hits
	; delay for a bit to ensure we're into the visible screen area at this point
	; TODO: remove this if we don't need this delay anymore, if we have stuff to do before the sprite 0 check?
	ldy #$C8
	:
		nop
		iny
		bne :-

	inc s_A53_MUTEX
	; splitting the a53_write macro in half for timing reasons 1/2
	lda #A53_REG_CHR_BANK
	sta z:s_A53_REG_SELECT

@check_sprite0:
	bit PPUSTATUS
	bvc @check_sprite0  ; spin on sprite 0 hit

	; splitting the a53_write macro in half for timing reasons 2/2
	sta A53_REG_SELECT
	lda #1
	sta A53_REG_VALUE

	; cycle-counted delay to wait before swapping to CHR bank 2 (3rd image slice)
	; exactly 64 scanlines
	lda #%00010000                   ;    2    2  DMC active status bit
	and SNDCHN                       ;    4    6
	c_bne @skip_pre_delay            ;    3    9  compensate for cycles stolen by DMC DMA
	;                                ;   -1    8    (measured approx. 32-36 cycles)
	ldy #7                           ;    2   10
	@loop:
		dey         ;  2  2
		c_bne @loop ;  3  5
		;           ; -1
	;                                ;   34   44

@skip_pre_delay:
	ldx #12                          ;    2   46
	@delay:
		ldy #119                          ;   2   2
		@inner:
			dey                           ;  2  2
			c_bne @inner                  ;  3  5
			;                             ; -1
		;                                 ; 594 596
		dex                               ;   2 598
		c_bne @delay                      ;   3 601
		;                                 ;  -1
	;                                ; 7211 7257
	ldx #0                           ;    3 7260  dummy
	a53_write A53_REG_CHR_BANK, #2   ;   15 7275

	dec s_A53_MUTEX
	rts
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

	jsr update_graphics
	; overwrite PPUCTRL
	lda #NT_2400|OBJ_1000|BG_1000|VBLANK_NMI
	sta PPUCTRL
	ldy #0

@loopwait:
	nop
	dey
	bne @loopwait

@check_sprite0:
	bit PPUSTATUS
	bvc @check_sprite0  ; spin on sprite 0 hit

	; partial CHR load here
	lda #0
	sta PPUMASK
	lda s_PPUCTRL
	sta PPUCTRL
	a53_set_chr s_A53_CHR_BANK
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

	; clear all CHR RAM?
	; jsr clear_all_chr
	
	; load universal tileset and palette

	lda #<universal_pal
	ldx #>universal_pal
	jsr load_ptr_temp1_16
	jsr transfer_img_pal
	
	; transfer palettes so that we don't linger on a dead screen
	jsr transfer_palette

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

	lda sys_mode
	ora #sys_MODE_NMIOAM|sys_MODE_NMIPAL
	sta sys_mode

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
	
	; start music with song id #0
	jsr start_music
	
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
	bne @continue
	; load screen, tileset, nametable, and palettes associated
	jsr gallery_init
	rts

@continue:
	; run logic
	; todo:  refer to "docs/state machine diagram or whatevs.png" 
	lda cur_keys
	and #KEY_LEFT|KEY_RIGHT|KEY_UP|KEY_DOWN
	beq @skip

	; change the image index
	
	; bug the system to transfer the new CHR
	lda sys_mode
	and #($FF - sys_MODE_CHRDONE)
	sta sys_mode

@skip:
	; display raster bankswitched image

	jsr gallery_display_kernel
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

	;set up sprite zero in OAM shadow buffer
	ldy #<gallery_sprite0_data_size
	dey
	@copy:
		lda gallery_sprite0_data, y
		sta SHADOW_OAM, y
		dey
		bpl @copy

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
	lda #>SHADOW_OAM
	sta OAM_DMA

@skip_oam:
	lda sys_mode
	and #sys_MODE_NMIPAL
	beq @skip_pal

	; transfer palettes
	jsr transfer_palette
	lda sys_mode
	and #($FF - sys_MODE_NMIPAL)
	sta sys_mode

@skip_pal:

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
