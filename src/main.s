.include "global.inc"
.include "nes.inc"

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
	lda #3
	sta s_A53_CHR_BANK
	a53_set_chr s_A53_CHR_BANK
	lda #0
	sta s_A53_PRG_BANK

@vblankwait2:
	bit PPUSTATUS
	bpl @vblankwait2
	
	; transfer palettes so that we don't linger on a dead screen
	jsr transfer_palette

	; clear nametables
	lda #$00
	ldx #$20
	tay
	jsr ppu_clear_nt
	ldx #$24
	jsr ppu_clear_nt
	ldx #$28
	jsr ppu_clear_nt
	ldx #$2C
	jsr ppu_clear_nt

	; clear all CHR RAM, important for doing visual CHR loading
	; jsr clear_all_chr
	
	; load universal palette
	lda #<universal_tileset
	sta temp1_16+0
	lda #>universal_tileset
	sta temp1_16+1
	lda #0
	jsr transfer_4k_chr

	; enable NMI immediately, set scroll to 0
	lda #VBLANK_NMI
	sta PPUCTRL
	sta s_PPUCTRL

	; enable rendering, will be updated later
	lda #BG_ON|OBJ_ON
	sta s_PPUMASK

	; set system state to title screen
	lda #STATE_ID::sys_GALLERYS
	sta sys_state
	
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
	
	lda s_PPUMASK
	sta PPUMASK

	lda s_PPUCTRL				; enable NMI immediately
	sta PPUCTRL

	rts
.endproc

.proc title_subroutine
	rts
.endproc

.proc gallery_subroutine
	jsr sys_state_init
	; ?
	; load screen
	; load tileset, nametable, and palettes associated
	rts
.endproc

.proc sys_state_init
	lda sys_mode
	and #sys_MODE_CHRTRANSFER
	bne @end
	; todo: lookup tables for chr depending on current index
	jsr load_chr_bitmap

	lda sys_mode
	ora #sys_MODE_CHRTRANSFER
	sta sys_mode
@end:
	rts
.endproc