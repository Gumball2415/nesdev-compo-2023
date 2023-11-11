.include "global.inc"
.include "nes.inc"
.include "bhop/bhop.inc"

.segment "ZEROPAGE"
music_is_playing:  .res 1

.segment BHOP_MUSIC_DATA_BANK_SEGMENT

bhop_music_data:
	.scope music_data
	.include "../obj/music.asm"
	.endscope
	.export bhop_music_data

.segment "PRGFIXED_C000"
;;
; initializes the bhop music engine and starts playing a song
; @param A song index within the module
.proc start_music
	tax
	lda s_A53_PRG_BANK
	pha
	a53_set_prg_safe #BHOP_MUSIC_DATA_BANK
	txa
	jsr bhop_init
	lda #1
	sta music_is_playing
	pla
	sta s_A53_PRG_BANK
	a53_set_prg_safe s_A53_PRG_BANK
	rts
.endproc

;;
; runs the bhop music engine if a song is playing
.proc run_music
	lda music_is_playing
	beq @skip
	lda s_A53_MUTEX
	bne @skip
	lda s_A53_PRG_BANK
	pha
	a53_set_prg_safe #BHOP_MUSIC_DATA_BANK
	
	jsr bhop_play

	pla
	sta s_A53_PRG_BANK
	a53_set_prg_safe s_A53_PRG_BANK
@skip:
	rts
.endproc


