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
.globalzp nmis

; init.s
.global reset_handler

; main.s
.global main, nmi_handler, irq_handler, reset_handler, load_ptr_temp1_16
.global update_graphics
.globalzp cur_keys, new_keys, oam_used

; music.s
.global start_music, run_music

; pads.s
.global read_pads

; graphics.s
.global transfer_palette, update_scrolling, ppu_clear_nt, clear_chr
.global clear_all_chr, transfer_4k_chr, load_chr_bitmap, universal_tileset
.global set_gallery_nametable, set_gallery_loading_screen
.global gallery_sprite0_data, gallery_sprite0_data_size, update_progress_bar
.globalzp shadow_palette
.globalzp s_PPUCTRL
.globalzp s_PPUMASK
.globalzp ppu_scroll_x
.globalzp ppu_scroll_y
.globalzp img_progress
.globalzp img_index
.globalzp nmi_occured

; tokumaru/decompress.s_PPUCTRL
.global DecompressTokumaru

.endif
