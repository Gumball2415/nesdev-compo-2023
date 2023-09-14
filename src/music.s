.include "global.inc"
.include "nes.inc"
.include "bhop/bhop.inc"

.segment "ZEROPAGE"
music_is_playing:  .res 1

.segment "PRG2_8000"

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
	a53_set_prg_safe #2
	txa
	jsr bhop_init
	lda #1
	sta music_is_playing
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
	a53_set_prg #2
	
	jsr bhop_play
	a53_set_prg s_A53_PRG_BANK
@skip:
	rts
.endproc


