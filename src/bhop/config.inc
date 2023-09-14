.ifndef __BHOP_CONFIG
; ----------------------------------------------------------------------------
; We override bhop's default config.inc parameters here.
; Note that we're basically only overriding BHOP_PLAYER_SEGMENT, but we do need to include all of the rest.

__BHOP_CONFIG = 1
.define BHOP_PLAYER_SEGMENT "PRGFIXED_C000"
.define BHOP_RAM_SEGMENT "BSS"
.define BHOP_ZP_SEGMENT "ZEROPAGE"

.import bhop_music_data

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

.endif ; __BHOP_CONFIG