; action53.inc
; Copyright © 2022 zeta0134
; 
; Permission is hereby granted, free of charge, to any person obtaining a copy
; of this software and associated documentation files (the “Software”), to deal
; in the Software without restriction, including without limitation the rights
; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
; copies of the Software, and to permit persons to whom the Software is
; furnished to do so, subject to the following conditions:
; 
; The above copyright notice and this permission notice shall be included in all
; copies or substantial portions of the Software.
; 
; THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
; SOFTWARE.

A53_REG_SELECT = $5000
A53_REG_VALUE = $8000

A53_REG_CHR_BANK = $00
A53_REG_INNER_BANK = $01
A53_REG_MODE = $80
A53_REG_OUTER_BANK = $81

;                                 $80: Mode
;                                 76543210
;                                   SSPPMM
;                                   ||||++ Nametable mirroring mode
;                                   ||++-- PRG bank mode
;                                   ++---- PRG outer bank size
A53_MIRRORING_ONE_SCREEN_LOWER = %00000000
A53_MIRRORING_ONE_SCREEN_UPPER = %00000001
A53_MIRRORING_VERTICAL =         %00000010
A53_MIRRORING_HORIZONTAL =       %00000011
A53_PRG_BANK_MODE_32K =          %00000000
A53_PRG_BANK_MODE_FIXED_8000 =   %00001000
A53_PRG_BANK_MODE_FIXED_C000 =   %00001100
A53_PRG_OUTER_BANK_32K       =   %00000000
A53_PRG_OUTER_BANK_64K       =   %00010000
A53_PRG_OUTER_BANK_128K      =   %00100000
A53_PRG_OUTER_BANK_256K      =   %00110000

.macro a53_write register, value
        lda #register
        sta action53_shadow
        sta A53_REG_SELECT
        lda value
        sta A53_REG_VALUE
.endmacro

.macro a53_set_prg bank_number
        a53_write A53_REG_INNER_BANK, bank_number
.endmacro

; note: we use vertical mirroring, so we won't bother to set the
; mirroring mode bit here; it's ignored
.macro a53_set_chr bank_number
        a53_write A53_REG_CHR_BANK, bank_number
.endmacro

.global init_action53
.globalzp action53_shadow