.include "action53.inc"
.include "system.inc"

.ifndef GLOBAL_INC
.define GLOBAL_INC

; TODO: clean this up. curse you ca65!!!

; global zeropage stuff
.globalzp temp1_8
.globalzp temp2_8
.globalzp temp3_8
.globalzp temp1_16
.globalzp temp2_16
.globalzp temp3_16
.globalzp sys_state
.globalzp sys_mode
.globalzp nmis

; init.s
.global reset_handler

; main.s
.global main, nmi_handler, irq_handler, reset_handler
.global load_ptr_temp1_16
.global load_ptr_temp2_16
.global load_ptr_temp3_16
.global far_call_subroutine
.global update_graphics, wait_x_frames
.globalzp cur_keys, new_keys, oam_used, shadow_oam_ptr

; music.s
.globalzp music_is_playing
.global start_music, run_music

; pads.s
.global read_pads

; graphics.s
.global set_title_nametable, load_titlescreen, run_fade, fade_shadow_palette
.global transfer_palette, update_scrolling, ppu_clear_nt, clear_chr, init_oam
.global clear_all_chr, transfer_4k_chr, load_chr_bitmap, universal_tileset
.global set_gallery_nametable, set_gallery_loading_screen, transfer_img_pal
.global gallery_sprite0_data, gallery_sprite0_data_size, update_progress_bar
.global sync_ppuaddr_ptr, inc_ppuaddr_ptr, inc_ppuaddr_ptr_chr, universal_pal
.global img_table_size
.global load_credits_screens
.globalzp pal_fade_int
.globalzp pal_fade_ctr
.globalzp pal_fade_amt
.globalzp fade_dir
.globalzp shadow_palette_primary
.globalzp shadow_palette_secondary
.globalzp s_PPUCTRL
.globalzp s_PPUMASK
.globalzp ppu_scroll_x
.globalzp ppu_scroll_y
.globalzp img_progress
.globalzp img_index
.globalzp nmi_occured
.globalzp oam_size

; bhop.s -- NOTE: not included in the file
.global s_dmc_4010

; credits.s
.global print_credits_line
.globalzp line_index

.endif
