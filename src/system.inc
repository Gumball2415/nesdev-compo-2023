; system state machine stuff
.ifndef SYSTEM_INC
.define SYSTEM_INC

.enum STATE_ID
	sys_TITLE
	sys_GALLERY
	sys_CREDITS

	sys_ID_COUNT
.endenum

OAM_SHADOW_1 = $0700
OAM_SHADOW_2 = $0600

sys_MODE_GALLERYLOAD = %00000001
sys_MODE_INITDONE    = %00000010
sys_MODE_GALLERYINIT = %00000100
sys_MODE_NMIPAL      = %00001000
sys_MODE_NMIOAM      = %00010000
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
.endif