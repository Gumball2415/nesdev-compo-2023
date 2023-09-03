.include "global.inc"
.include "nes.inc"

.segment "PRGFIXED_C000"

; please refer to "docs/state machine diagram or whatevs.png"

;       | sys_0 | sys_1 |
; sys_0 |   0   |   1   |
; sys_1 |   1   |   0   |
state_transition_lut:
	.byte %01000000
	.byte %10000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
