.include "action53.inc"
.include "system.inc"

.ifndef GLOBAL_INC
.define GLOBAL_INC

; global zeropage stuff
.globalzp sys_state
.globalzp sys_mode
.globalzp temp1_8
.globalzp temp2_8
.globalzp temp1_16
.globalzp temp2_16
.globalzp temp3_16

; init.s
.global reset_handler

; main.s
.global main, nmi_handler, irq_handler, reset_handler
.globalzp cur_keys, new_keys, oam_used

; pads.s
.global read_pads

; graphics.s
.global transfer_palette, update_scrolling
.globalzp shadow_palette
.globalzp s_PPUCTRL
.globalzp s_PPUMASK
.globalzp ppu_scroll_x
.globalzp ppu_scroll_y

.endif
