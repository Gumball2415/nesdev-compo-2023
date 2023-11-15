; system state machine stuff and specific flags
.ifndef SYSTEM_INC
.define SYSTEM_INC

; flags

; waits for end of vblank before enabling rendering
; scanline 0 is glitched
SKIP_DOT_DISABLE = 1

; constants

STAR_TILE = $04
.define	MAIN_ROUTINES_BANK_SEGMENT "PRG1_8000"
		MAIN_ROUTINES_BANK = 1
.define BHOP_MUSIC_DATA_BANK_SEGMENT "PRG2_8000"
		BHOP_MUSIC_DATA_BANK = 2

TXT_REGULAR = 0
TXT_HEADING = 1
TXT_BLANKSC = 2

; must be 8 bytes!!
.define NESDEV_TXT_REGULAR $08,$09,$0A,$0B,$0C,$0D,$0E,$00
.define NESDEV_TXT_HEADING $0F,$10,$11,$12,$13,$14,$15,$16
HEADER_TXT_OFFSET = $60

.enum STATE_ID
	sys_TITLE
	sys_GALLERY
	sys_CREDITS

	sys_ID_COUNT
.endenum

OAM_SHADOW_1 = $0700
OAM_SHADOW_2 = $0600

fade_dir_in = $01
fade_dir_stop = $00
fade_dir_out = $FF
fade_amt_max = 4

sys_MODE_CREDITSLOAD = %00000001
sys_MODE_GALLERYLOAD = %00000010
sys_MODE_INITDONE    = %00000100
sys_MODE_GALLERYINIT = %00001000
sys_MODE_NMIPAL      = %00010000
sys_MODE_PALETTEFADE = %00100000
sys_MODE_SPRITE0SET  = %01000000
sys_MODE_NMIOCCURRED = %10000000

.struct img_DATA_PTR
	; PTR: pointer to data
	; LOC: PRG bank number which it resides in
	img_PAL_PTR .addr
	img_ATTR_PTR .addr
	img_OAM_PTR .addr
	img_BANK_0_PTR .addr
	img_BANK_1_PTR .addr
	img_BANK_2_PTR .addr
	img_BANK_S_PTR .addr

	img_PAL_LOC .byte
	img_ATTR_LOC .byte
	img_OAM_LOC .byte
	img_BANK_0_LOC .byte
	img_BANK_1_LOC .byte
	img_BANK_2_LOC .byte
	img_BANK_S_LOC .byte
.endstruct

.struct txt_DATA_PTR
	; PTR: pointer to data
	; LOC: PRG bank number which it resides in
	txt_LOC .byte
	txt_PTR .addr
.endstruct

.endif