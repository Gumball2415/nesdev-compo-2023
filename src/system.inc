; system state machine stuff
.ifndef SYSTEM_INC
.define SYSTEM_INC

.enum STATE_ID
	sys_TITLESCR
	sys_GALLERYS

	sys_ID_COUNT
.endenum

sys_MODE_CHRTRANSFER = %00000001


.struct img_DATA_PTR
	; PTR: pointer to data
	; LOC: PRG bank number which it resides in
	img_BANK0_PTR .word
	img_BANK0_LOC .byte
	img_BANK1_PTR .word
	img_BANK1_LOC .byte
	img_BANK2_PTR .word
	img_BANK2_LOC .byte
	img_PAL_PTR .word
	img_PAL_LOC .byte
	img_ATTR_PTR .word
	img_ATTR_LOC .byte	
.endstruct
.endif