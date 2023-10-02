; action53.s
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

.include "global.inc"
.include "nes.inc"

.zeropage
s_A53_REG_SELECT: .res 1
s_A53_CHR_BANK: .res 1
s_A53_PRG_BANK: .res 1
s_A53_MUTEX: .res 1

.segment "PRGFIXED_C000"

.proc init_action53
	; 32k PRG
	a53_write A53_REG_OUTER_BANK, #$1F
	a53_write A53_REG_MODE, #(A53_MIRRORING_HORIZONTAL | A53_PRG_BANK_MODE_FIXED_C000 | A53_PRG_OUTER_BANK_64K)
	a53_write A53_REG_CHR_BANK, #0
	a53_write A53_REG_INNER_BANK, #0
	rts
.endproc
