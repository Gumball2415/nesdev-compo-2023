; system state machine stuff
.ifndef SYSTEM_INC
.define SYSTEM_INC

.enum STATE_ID
	sys_TITLESCR
	sys_GALLERYS

	sys_ID_COUNT
.endenum

sys_MODE_CHRTRANSFER = %00000001
sys_MODE_CHRDONE     = %00000010
sys_MODE_GALLERYINIT = %00000100
sys_MODE_NMIPAL      = %00001000
sys_MODE_NMIOAM      = %00010000

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