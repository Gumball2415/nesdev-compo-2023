.include "global.inc"
.include "nes.inc"
.include "checked_branches.inc"

.exportzp credits_ptr, line_index, blank_counter
.export credits_text, credits_text_size, credits_subroutine

PX_PER_FRAME = 6

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

credits_ptr:	.tag txt_DATA_PTR
y_scroll_pos:	.res 2	; shadow variables to be written to PPUSCROLL and PPUCTRL
y_frac_count:	.res 1	; counter for fractional scrolling
line_index: 	.res 1	; credits text index
line_pos: 		.res 1	; credits text line position
blank_counter: 	.res 1	; counter for full screen blank text
tile_counter: 	.res 1	; counter for checking if tiles has been sufficiently scrolled
kill_switch: 	.res 1	; 1 = end program

.segment "PRG_CREDITS_LIST"

credits_text:
; txtmacro  TXT_type, "============================"
txtmacro TXT_BLANKSC, "nov 16... our hearts became consubstantial"
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
txtmacro TXT_REGULAR, "  - All rights & copyrights"
txtmacro TXT_REGULAR, "    of art & related graphic"
txtmacro TXT_REGULAR, "    resources used are"
txtmacro TXT_REGULAR, "    reserved to their"
txtmacro TXT_REGULAR, "    respective owners"
txtmacro TXT_REGULAR, "    credited above."
txtmacro TXT_REGULAR, ""
txtmacro TXT_HEADING, "External libraries"
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
txtmacro TXT_HEADING, "Special thanks (in no order)"
txtmacro TXT_REGULAR, "  - forple"
txtmacro TXT_REGULAR, "  - Lockster"
txtmacro TXT_REGULAR, "  - Kasumi"
txtmacro TXT_REGULAR, "  - yoeynsf"
txtmacro TXT_REGULAR, "  - Kagamiin~"
txtmacro TXT_REGULAR, "  - Lumigado"
txtmacro TXT_REGULAR, "  - nyanpasu64"
txtmacro TXT_REGULAR, "  - enid"
txtmacro TXT_REGULAR, "  - mai"
txtmacro TXT_REGULAR, "  - my cat"
txtmacro TXT_REGULAR, "  - Fiskbit"
txtmacro TXT_REGULAR, "  - lidnariq"
txtmacro TXT_REGULAR, "  - zeta0134"
txtmacro TXT_REGULAR, "  - NewRisingSun"
txtmacro TXT_REGULAR, "  - PinoBatch"
txtmacro TXT_REGULAR, "  - Johnathan Roatch"
txtmacro TXT_REGULAR, "  - jekuthiel"
txtmacro TXT_REGULAR, ""
txtmacro TXT_REGULAR, ""
txtmacro TXT_REGULAR, ""
txtmacro TXT_REGULAR, {"shvtera group ", STAR_TILE, " ", NESDEV_TXT_REGULAR, "2023"}
txtmacro TXT_REGULAR, ""
txtmacro TXT_REGULAR, "mind the gap        -persune"
txtmacro TXT_BLANKSC, "i hope you're happy now where you are and where you will be."
txtmacro TXT_BLANKSC, ""

.segment "PRG_CREDITS_LIST"

credits_text_size := * - credits_text

.segment MAIN_ROUTINES_BANK_SEGMENT


; TODO: how to do this on a scrolling screen?
.proc credits_display_kernel_ntsc
	lda tile_counter
	cmp #8
	bne @skip_tile_load

	lda sys_mode
	ora #sys_MODE_CREDITSLOAD
	sta sys_mode
	lda #0
	sta tile_counter

@skip_tile_load:
	dec y_frac_count
	bne @dont_scroll

	; reset y fractional counter
	lda #PX_PER_FRAME
	sta y_frac_count

	; increment y scroll position and check if past nametable boundary
	inc tile_counter
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
	lda kill_switch
	bne @toggle_exit
	lda #KEY_B
	bit new_keys
	bne @toggle_exit
	
	jmp @skip

@toggle_exit:
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
	sta kill_switch
	sta tile_counter
	sta line_pos
	sta line_index
	sta ppu_scroll_x
	sta ppu_scroll_y
	sta y_scroll_pos
	sta y_scroll_pos+1
	
	; init y fractional counter
	lda #PX_PER_FRAME
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

	; remove if the stuff up here enables NMI
	; enable NMI immediately
	lda #NT_2000|OBJ_1000|BG_1000
	sta PPUCTRL
	sta s_PPUCTRL
	
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

;;
; prints credits text to the nametable address specifed
; 	- set base nametable addr to temp2_16 before calling.
; 	- base nametable addr will shift to next line after calling.
; line_index will be decremented after calling if in blank screen mode.
; 	- this can be used in a loop where a certain amount of lines is specified.
; @param temp1_16 pointer to credits text data
; @param line_index current credit line index
; @param line_pos current credit line position
; @param credits_ptr pointer to credit line
; clobbers A, X, and Y
.export print_credits_line
.include "bhop/longbranch.inc"
.proc print_credits_line
CREDITS_TEXT_LINES = <(credits_text_size/2)
TEXT_LENGTH = 28

	; push X to stack
	txa
	pha

	; check if we're crossing a nametable
	lda line_pos
	cmp #30
	bne @skip_nametable_cross_check
	
	lda #$00
	sta line_pos
	
	; offset one attr table and one whole nametable to temp2_16
	clc
	lda temp2_16
	adc #<(64+1024)
	sta temp2_16
	lda temp2_16+1
	adc #>(64+1024)
	; wrap back to $2000
	cmp #$2F
	bcc @skip_nametable_modulo
	sbc #$10
@skip_nametable_modulo:
	sta temp2_16+1

@skip_nametable_cross_check:

	; check if we're still printing a blank screen
	lda blank_counter
	jne @tick_blank_counter

	; index into the credits line table
	lda line_index
	cmp #CREDITS_TEXT_LINES
	; exit when index is out of bounds
	jcs @kill_credits

	asl a
	tax
	lda credits_text,x
	sta temp1_16+0
	lda credits_text+1,x
	sta temp1_16+1

	ldy #0
@ptr_load:
	lda (temp1_16),y
	sta credits_ptr,y
	iny
	cpy #.sizeof(txt_DATA_PTR)
	bne @ptr_load

	ldy #0

	; switch to text bank
	lda s_A53_PRG_BANK
	pha
	a53_set_prg_safe z:credits_ptr+txt_DATA_PTR::txt_LOC

@set_nametable:

	; set final nametable address
	bit PPUADDR
	lda temp2_16+1
	sta PPUADDR
	lda temp2_16+0
	sta PPUADDR

	; set temp1_16 as pointer to raw text data
	lda z:credits_ptr+txt_DATA_PTR::txt_PTR
	ldx z:credits_ptr+txt_DATA_PTR::txt_PTR+1
	jsr load_ptr_temp1_16
	lda (temp1_16),y
	cmp #TXT_REGULAR
	beq @charprint_regular
	cmp #TXT_HEADING
	beq @charprint_heading
	cmp #TXT_BLANKSC
	beq @charprint_blanksc
	jmp @end_of_line


@charprint_regular:
	iny
:	lda (temp1_16),y
	bmi @end_of_line ; end loop if $FF is encountered
	sta PPUDATA
	iny
	jmp :-


@charprint_heading:
	iny
:	lda (temp1_16),y
	bmi @end_of_line ; end loop if $FF is encountered
	clc
	adc #HEADER_TXT_OFFSET
	sta PPUDATA
	iny
	jmp :-

@charprint_blanksc:
	lda #(30-1)
	sta blank_counter
	dec line_index
	jmp @end_of_line


@tick_blank_counter:
	inc line_pos
	dec blank_counter
	beq @skip_decrement

	dec line_index

@skip_decrement:

	; reset final nametable address
	bit PPUADDR
	lda temp2_16+1
	sta PPUADDR
	lda temp2_16+0
	sta PPUADDR

	; fill rest of line with blank tiles
	lda #0
	ldy #0
:	sta PPUDATA
	iny
	cpy #(TEXT_LENGTH)
	bne :-
	jmp @skip

@end_of_line:
	inc line_pos
	; switch back to current bank
	pla
	sta s_A53_PRG_BANK
	a53_set_prg_safe s_A53_PRG_BANK

	; fill rest of line with blank tiles
	cpy #(TEXT_LENGTH+1)
	beq @skip
	lda #0
@finish_line:
	sta PPUDATA
	iny
	cpy #(TEXT_LENGTH+1)
	bne @finish_line
	jmp @skip

@kill_credits:
	lda #1
	sta kill_switch
@skip:
	; increment +$0020 on pointer
	clc
	lda temp2_16+0
	adc #$20
	sta temp2_16+0
	lda temp2_16+1
	adc #$00
	sta temp2_16+1

	; restore X
	pla
	tax

	lda sys_mode
	and #($FF - sys_MODE_CREDITSLOAD)
	sta sys_mode

	rts
.endproc
