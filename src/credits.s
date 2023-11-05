; credits
.include "global.inc"
.include "nes.inc"
TXT_REGULAR = 0
TXT_HEADING = 1

; must be 8 bytes!!
.define NESDEV_TXT_REGULAR $08,$09,$0A,$0B,$0C,$0D,$0E,$00
.define NESDEV_TXT_HEADING $0F,$10,$11,$12,$13,$14,$15,$16

.macro txtmacro TXT_TYPE, credits_line_str
.scope

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

; one of the most batshit insane ways to make a pointer list of structs.
.segment "PRG_CREDITS_LIST"
	.addr credits_line

; when compiled, this is what it looks like
; 	credits_text:
; 		.addr credits_line_80
; 		.addr credits_line_79
; 		.addr credits_line_78
; 	...

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

credits_line: .tag txt_DATA_PTR

.segment "PRG_CREDITS_LIST"
credits_text:
; txtmacro  TXT_type, "============================"
txtmacro TXT_HEADING, "Main programming:"           
txtmacro TXT_REGULAR, "  - Kagamiin~"               
txtmacro TXT_REGULAR, "  - Persune"                 
txtmacro TXT_HEADING, "Assistance/Consulting:"      
txtmacro TXT_REGULAR, "  - Kagamiin~"               
txtmacro TXT_REGULAR, "  - Kasumi"                  
txtmacro TXT_REGULAR, "  - Fiskbit"                 
txtmacro TXT_REGULAR, "  - lidnariq"                
txtmacro TXT_REGULAR, "  - zeta0134"                
txtmacro TXT_HEADING, "External libraries"          
txtmacro TXT_REGULAR, "  - bhop"                    
txtmacro TXT_REGULAR, "      - licensed under the"  
txtmacro TXT_REGULAR, "        MIT-0 license."      
txtmacro TXT_REGULAR, "        Copyright 2023"      
txtmacro TXT_REGULAR, "        zeta0134."           
txtmacro TXT_REGULAR, "  - Donut"                   
txtmacro TXT_REGULAR, "      - licensed under the"  
txtmacro TXT_REGULAR, "        Unlicense License."  
txtmacro TXT_REGULAR, "        Copyright 2023"      
txtmacro TXT_REGULAR, "        Johnathan Roatch."   
txtmacro TXT_REGULAR, "  - savtool.py"              
txtmacro TXT_REGULAR, "      - licensed under the"  
txtmacro TXT_REGULAR, "        GNU All-Permissive"  
txtmacro TXT_REGULAR, "        License."            
txtmacro TXT_REGULAR, "        Copyright 2012-2018" 
txtmacro TXT_REGULAR, "        Damian Yerrick."     
txtmacro TXT_REGULAR, "  - pilbmp2nes.py"           
txtmacro TXT_REGULAR, "      - licensed under the"  
txtmacro TXT_REGULAR, "        GNU All-Permissive"  
txtmacro TXT_REGULAR, "        License."            
txtmacro TXT_REGULAR, "        Copyright 2014-2015" 
txtmacro TXT_REGULAR, "        Damian Yerrick."     
txtmacro TXT_REGULAR, "  - preprocess_bmp.py"       
txtmacro TXT_REGULAR, "      - licensed under the"  
txtmacro TXT_REGULAR, "        MIT-0 license."      
txtmacro TXT_REGULAR, "        Copyright 2023"      
txtmacro TXT_REGULAR, "        Persune & Kagamiin~."
txtmacro TXT_REGULAR, "  - Action53 mapper config &"
txtmacro TXT_REGULAR, "    helper functions"        
txtmacro TXT_REGULAR, "      - licensed under the"  
txtmacro TXT_REGULAR, "        MIT license."        
txtmacro TXT_REGULAR, "        Copyright 2023"      
txtmacro TXT_REGULAR, "        zeta0134."           
txtmacro TXT_REGULAR, "  - nrom_template"           
txtmacro TXT_REGULAR, "      - licensed under the"  
txtmacro TXT_REGULAR, "        GNU All-Permissive"  
txtmacro TXT_REGULAR, "        License."            
txtmacro TXT_REGULAR, "        Copyright 2011-2016" 
txtmacro TXT_REGULAR, "        Damian Yerrick."
txtmacro TXT_HEADING, "Art & Artists"
txtmacro TXT_REGULAR, {"  - ", NESDEV_TXT_HEADING, "Discord Icon"}
txtmacro TXT_REGULAR, "      - logotype by tokumaru"
txtmacro TXT_REGULAR, "      - design by Persune"   
txtmacro TXT_REGULAR, "  - Electric Space"          
txtmacro TXT_REGULAR, "      - px art by Lockster"  
txtmacro TXT_REGULAR, "  - Minae Zooming By"        
txtmacro TXT_REGULAR, "      - lineart & coloring"  
txtmacro TXT_REGULAR, "        by forple"           
txtmacro TXT_REGULAR, "      - px render by Persune"
txtmacro TXT_REGULAR, "      - attr. overlay assist"
txtmacro TXT_REGULAR, "        by Kasumi"           
txtmacro TXT_REGULAR, "  - Dagga Says Cheese <:3 )~"
txtmacro TXT_REGULAR, "      - lineart by yoeynsf"  
txtmacro TXT_REGULAR, "      - px render by Persune"
txtmacro TXT_REGULAR, "      - color consult from"  
txtmacro TXT_REGULAR, "        Cobalt Teal"         
txtmacro TXT_REGULAR, "      - attr. overlay layout"
txtmacro TXT_REGULAR, "        by Kagamiin~"        
txtmacro TXT_HEADING, "Special thanks:"
txtmacro TXT_REGULAR, "  - yoeynsf"
txtmacro TXT_REGULAR, "  - forple"
txtmacro TXT_REGULAR, "  - Lockster"
txtmacro TXT_REGULAR, "  - Kagamiin~"
txtmacro TXT_REGULAR, "  - Lumi"
txtmacro TXT_REGULAR, "  - nyanpasu64"
txtmacro TXT_REGULAR, "  - Fiskbit"
txtmacro TXT_REGULAR, "  - lidnariq"
txtmacro TXT_REGULAR, "  - zeta0134"
txtmacro TXT_REGULAR, "  - PinoBatch"
txtmacro TXT_REGULAR, "  - Johnathan Roatch"
txtmacro TXT_REGULAR, "  - jekuthiel"
txtmacro TXT_REGULAR, ""
txtmacro TXT_REGULAR, {"shvtera group ", STAR_TILE, " ", NESDEV_TXT_REGULAR, " 2023"}

credits_text_size := * - credits_text

.segment "PRGFIXED_C000"
.proc print_line
	lda z:credits_line+txt_DATA_PTR::txt_LOC
	rts
.endproc
