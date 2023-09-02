.include "global.inc"
.include "nes.inc"

.segment "PRGFIXED_C000"
.proc nmi_handler
	pha
	tya
	pha
	txa
	pha

	; transfer OAM
	lda #0
	sta OAMADDR
	lda #>SHADOW_OAM
	sta OAM_DMA

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

	; clean OAM memory
	lda #0
	sta OAMADDR
	lda #>SHADOW_OAM
	sta OAM_DMA

	; Set PRG bank
	jsr init_action53

@vblankwait2:
	bit $2002
	bpl @vblankwait2

	jmp main
.endproc

.segment "PRG0_8000"
.proc main
	jsr run_state_machine
	jmp main
.endproc

.proc run_state_machine
	rts
.endproc
