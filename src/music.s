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
	;.export bhop_music_data

.segment "PRGFIXED_E000"
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

; ----------------------------------------------------------------------------
; We override bhop's default config.inc parameters here.
; Note that we're basically only overriding BHOP_PLAYER_SEGMENT, but we do need to include all of the rest.

__BHOP_CONFIG = 1
.define BHOP_PLAYER_SEGMENT "PRGFIXED_E000"
.define BHOP_RAM_SEGMENT "BSS"
.define BHOP_ZP_SEGMENT "ZEROPAGE"

;.import bhop_music_data

BHOP_MUSIC_BASE = bhop_music_data
BHOP_DPCM_BANKING = 0
BHOP_PATTERN_BANKING = 0

.if ::BHOP_DPCM_BANKING
.import bhop_apply_dpcm_bank
BHOP_DPCM_SWITCH_ROUTINE = bhop_apply_dpcm_bank
.endif

.if ::BHOP_PATTERN_BANKING
.import bhop_apply_music_bank
BHOP_PATTERN_SWITCH_ROUTINE = bhop_apply_music_bank
.endif

BHOP_ZSAW_ENABLED = 0
BHOP_MMC5_ENABLED = 0

; ----------------------------------------------------------------------------

; bhop driver is included here, with overridden parameters
.include "bhop/bhop.s"

