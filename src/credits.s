.include "global.inc"
.include "nes.inc"
.include "checked_branches.inc"

.export credits_subroutine

.macro txtmacro TXT_TYPE, credits_line_str
.scope

; one of the most batshit insane ways to make a pointer list of structs.
.segment "PRG_CREDITS_LIST"
	.addr credits_line

; when compiled, this is what it looks like
; 	credits_text:
; 		.addr credits_line_80
; 		.addr credits_line_79
; 		.addr credits_line_78
; 	...

.segment "PRG1_8000"
	credits_line_data:
		.byte TXT_TYPE
		.byte credits_line_str
		.byte $FF ; string terminated with $FF

; when compiled, this is what it looks like:
;	credits_line_data_80:
;		.byte TXT_TYPE
;		.byte <string literal>
;		.byte $FF ; string terminated with $FF
;	credits_line_data_79:
;		.byte TXT_TYPE
;		.byte <string literal>
;		.byte $FF ; string terminated with $FF
;	credits_line_data_78:
;		.byte TXT_TYPE
;		.byte <string literal>
;		.byte $FF ; string terminated with $FF
;	...

; one of the most batshit insane ways to make an array of struct pointers.
.segment "PRGFIXED_C000"
	credits_line:
		.byte <.bank(credits_line_data)
		.addr credits_line_data

; when compiled, this is what it looks like
;	credits_line_80:
;		.byte <.bank(credits_line_data_80)
;		.addr credits_line_data_80
;	credits_line_79:
;		.byte <.bank(credits_line_data_79)
;		.addr credits_line_data_79
;	credits_line_78:
;		.byte <.bank(credits_line_data_78)
;		.addr credits_line_data_78
;	...

.endscope
.endmacro

.segment "ZEROPAGE"

credits_ptr:  .tag txt_DATA_PTR
y_scroll_pos: .res 2
y_frac_count: .res 1
line_counter: .res 1

.segment "PRG_CREDITS_LIST"

credits_text:
; txtmacro  TXT_type, "============================"
txtmacro TXT_HEADING, "       project SHVTERA"
txtmacro TXT_REGULAR, "a random art slideshow which"
txtmacro TXT_REGULAR, "is also a 2bpp plane demo."
txtmacro TXT_REGULAR, ""
txtmacro TXT_REGULAR, ""
txtmacro TXT_REGULAR, ""
txtmacro TXT_HEADING, "Main programming:"
txtmacro TXT_REGULAR, "  - Kagamiin~"
txtmacro TXT_REGULAR, "  - Persune"
txtmacro TXT_REGULAR, ""
txtmacro TXT_HEADING, "Assistance/Consulting:"
txtmacro TXT_REGULAR, "  - Kagamiin~"
txtmacro TXT_REGULAR, "  - Kasumi"
txtmacro TXT_REGULAR, "  - Fiskbit"
txtmacro TXT_REGULAR, "  - lidnariq"
txtmacro TXT_REGULAR, "  - zeta0134"
txtmacro TXT_REGULAR, ""
txtmacro TXT_HEADING, "Art & Artists"
txtmacro TXT_REGULAR, ""
txtmacro TXT_REGULAR, {"  - ", NESDEV_TXT_REGULAR, "Discord Icon"}
txtmacro TXT_REGULAR, "      - logotype by tokumaru"
txtmacro TXT_REGULAR, "      - design by Persune"
txtmacro TXT_REGULAR, ""
txtmacro TXT_REGULAR, "  - Electric Space"
txtmacro TXT_REGULAR, "      - px art by Lockster"
txtmacro TXT_REGULAR, ""
txtmacro TXT_REGULAR, "  - Minae Zooming By"
txtmacro TXT_REGULAR, "      - lineart & coloring"
txtmacro TXT_REGULAR, "        by forple"
txtmacro TXT_REGULAR, "      - px render by Persune"
txtmacro TXT_REGULAR, "      - attr. overlay assist"
txtmacro TXT_REGULAR, "        by Kasumi"
txtmacro TXT_REGULAR, ""
txtmacro TXT_REGULAR, "  - Dagga Says Cheese <:3 )~"
txtmacro TXT_REGULAR, "      - lineart by yoeynsf"
txtmacro TXT_REGULAR, "      - px render by Persune"
txtmacro TXT_REGULAR, "      - color consult from"
txtmacro TXT_REGULAR, "        Cobalt Teal"
txtmacro TXT_REGULAR, "      - attr. overlay layout"
txtmacro TXT_REGULAR, "        by Kagamiin~"
txtmacro TXT_REGULAR, ""
txtmacro TXT_HEADING, "External libraries"
txtmacro TXT_REGULAR, ""
txtmacro TXT_REGULAR, "  - bhop"
txtmacro TXT_REGULAR, "      - licensed under the"
txtmacro TXT_REGULAR, "        MIT-0 license."
txtmacro TXT_REGULAR, "        Copyright 2023"
txtmacro TXT_REGULAR, "        zeta0134."
txtmacro TXT_REGULAR, ""
txtmacro TXT_REGULAR, "  - Donut"
txtmacro TXT_REGULAR, "      - licensed under the"
txtmacro TXT_REGULAR, "        Unlicense License."
txtmacro TXT_REGULAR, "        Copyright 2023"
txtmacro TXT_REGULAR, "        Johnathan Roatch."
txtmacro TXT_REGULAR, ""
txtmacro TXT_REGULAR, "  - savtool.py"
txtmacro TXT_REGULAR, "      - licensed under the"
txtmacro TXT_REGULAR, "        GNU All-Permissive"
txtmacro TXT_REGULAR, "        License."
txtmacro TXT_REGULAR, "        Copyright 2012-2018"
txtmacro TXT_REGULAR, "        Damian Yerrick."
txtmacro TXT_REGULAR, ""
txtmacro TXT_REGULAR, "  - pilbmp2nes.py"
txtmacro TXT_REGULAR, "      - licensed under the"
txtmacro TXT_REGULAR, "        GNU All-Permissive"
txtmacro TXT_REGULAR, "        License."
txtmacro TXT_REGULAR, "        Copyright 2014-2015"
txtmacro TXT_REGULAR, "        Damian Yerrick."
txtmacro TXT_REGULAR, ""
txtmacro TXT_REGULAR, "  - preprocess_bmp.py"
txtmacro TXT_REGULAR, "      - licensed under the"
txtmacro TXT_REGULAR, "        MIT-0 license."
txtmacro TXT_REGULAR, "        Copyright 2023"
txtmacro TXT_REGULAR, "        Persune & Kagamiin~."
txtmacro TXT_REGULAR, ""
txtmacro TXT_REGULAR, "  - Action53 mapper config &"
txtmacro TXT_REGULAR, "    helper functions"
txtmacro TXT_REGULAR, "      - licensed under the"
txtmacro TXT_REGULAR, "        MIT license."
txtmacro TXT_REGULAR, "        Copyright 2023"
txtmacro TXT_REGULAR, "        zeta0134."
txtmacro TXT_REGULAR, ""
txtmacro TXT_REGULAR, "  - nrom_template"
txtmacro TXT_REGULAR, "      - licensed under the"
txtmacro TXT_REGULAR, "        GNU All-Permissive"
txtmacro TXT_REGULAR, "        License."
txtmacro TXT_REGULAR, "        Copyright 2011-2016"
txtmacro TXT_REGULAR, "        Damian Yerrick."
txtmacro TXT_REGULAR, ""
txtmacro TXT_HEADING, "Special thanks:"
txtmacro TXT_REGULAR, "  - yoeynsf"
txtmacro TXT_REGULAR, "  - forple"
txtmacro TXT_REGULAR, "  - Lockster"
txtmacro TXT_REGULAR, "  - Kagamiin~"
txtmacro TXT_REGULAR, "  - Lumi"
txtmacro TXT_REGULAR, "  - nyanpasu64"
txtmacro TXT_REGULAR, "  - my cat"
txtmacro TXT_REGULAR, "  - Fiskbit"
txtmacro TXT_REGULAR, "  - lidnariq"
txtmacro TXT_REGULAR, "  - zeta0134"
txtmacro TXT_REGULAR, "  - PinoBatch"
txtmacro TXT_REGULAR, "  - Johnathan Roatch"
txtmacro TXT_REGULAR, "  - jekuthiel"
txtmacro TXT_REGULAR, ""
txtmacro TXT_REGULAR, {"shvtera group ", STAR_TILE, " ", NESDEV_TXT_REGULAR, " 2023"}

.segment "PRG_CREDITS_LIST"

credits_text_size := * - credits_text

.segment MAIN_ROUTINES_BANK_SEGMENT


; TODO: how to do this on a scrolling screen?
.proc credits_display_kernel_ntsc
	dec y_frac_count
	bne @dont_scroll

	; reset y fractional counter
	lda #4
	sta y_frac_count

	; increment y scroll position and check if past nametable boundary
	inc y_scroll_pos
	lda y_scroll_pos
	; store it in PPU scroll shadow to apply scrolling
	sta ppu_scroll_y
	cmp #240
	bne @no_carry

	; reset fine y scroll position and increment page number
	lda #0
	sta y_scroll_pos
	; store it in PPU scroll shadow to apply scrolling
	sta ppu_scroll_y
	inc y_scroll_pos+1

	; extract Y nametable index bit from page number and
	; write it to PPUCTRL shadow
	lda y_scroll_pos+1
	asl a
	and #%00000010
	sta temp3_8
	lda s_PPUCTRL
	and #%11111101
	ora temp3_8
	sta s_PPUCTRL

@no_carry:
@dont_scroll:
	rts
.endproc

.proc credits_subroutine
	lda sys_mode
	and #sys_MODE_INITDONE
	bne @skip_init
	; load screen, tileset, nametable, and palettes associated
	jsr credits_init
	rts

@skip_init:
	; if palette fading is in progress, skip all logic and continue raster display
	lda sys_mode
	and #sys_MODE_PALETTEFADE
	bne @check_fade_dir

	; run logic
	; todo:  refer to "docs/state machine diagram or whatevs.png"
	lda #KEY_B
	bit new_keys
	bne @toggle_b
	
	jmp @skip

@toggle_b:
	lda #3
	jsr start_music
	lda #fade_dir_out
	sta fade_dir
	lda sys_mode
	ora #sys_MODE_PALETTEFADE
	sta sys_mode
	jmp @skip

@check_fade_dir:
	lda fade_dir
	bpl @skip ; do nothing else on fade in
	lda pal_fade_amt
	cmp #fade_amt_max
	bne @skip

	; after fade out is done, reset back to title
	; after fade out is done, go back to title
	lda #STATE_ID::sys_TITLE
	sta sys_state
	lda sys_mode
	and #($FF - sys_MODE_INITDONE)
	sta sys_mode

@skip:
	jsr credits_display_kernel_ntsc
	rts
.endproc

.proc credits_init
	; disable rendering
	lda #0
	sta PPUMASK
	sta PPUCTRL

	; init line counter, PPU scroll and y scroll pos
	sta line_counter
	sta ppu_scroll_x
	sta ppu_scroll_y
	sta y_scroll_pos
	sta y_scroll_pos+1
	
	; init y fractional counter
	lda #4
	sta y_frac_count
	
	; clear OAM
	lda #$FF
	ldx #0
@clear_OAM:
	sta OAM_SHADOW_1,x
	sta OAM_SHADOW_2,x
	inx
	bne @clear_OAM

	lda #2
	jsr start_music

	; set CHR bank to universal tileset
	a53_set_chr_safe #3
	
	; init credits scroll
	lda #NAMETABLE_A
	ldx #NAMETABLE_C
	jsr load_credits_screens

	; let the NMI handler know that we're done initializing
	; let the NMI handler know that we're fading in
	; let the NMI handler enable OAM and palette
	lda sys_mode
	ora #sys_MODE_INITDONE|sys_MODE_PALETTEFADE|sys_MODE_NMIPAL
	sta sys_mode

	; init fade
	lda #fade_amt_max
	sta pal_fade_amt

	; fade in
	lda #fade_dir_in
	sta fade_dir

	; slow fade speed
	lda #(4-1)
	sta pal_fade_int
	sta pal_fade_ctr

	; remove if the stuff up here enables NMI
	; enable NMI immediately
	lda #NT_2000|OBJ_1000|BG_1000|VBLANK_NMI
	sta PPUCTRL
	sta s_PPUCTRL
	rts
.endproc

.exportzp credits_ptr, line_counter
.export credits_text, credits_text_size
