;
; NES controller reading code
; Copyright 2009-2011 Damian Yerrick
;
; Modification 2023 Persune
;
; Copying and distribution of this file, with or without
; modification, are permitted in any medium without royalty provided
; the copyright notice and this notice are preserved in all source
; code copies.  This file is offered as-is, without any warranty.
;

;
; 2011-07: Damian Yerrick added labels for the local variables and
;          copious comments and made USE_DAS a compile-time option
;
; 2023-11: Modified read_pads to sync on OAM DMA

.include "nes.inc"
.include "checked_branches.inc"

.export read_pads
.importzp cur_keys, new_keys, shadow_oam_ptr
.segment "ZEROPAGE"
thisRead:      .res 2
lastFrameKeys: .res 2


JOY1      = $4016
JOY2      = $4017

; turn USE_DAS on to enable autorepeat support
.ifndef USE_DAS
USE_DAS = 0
.endif

; time until autorepeat starts making keypresses
DAS_DELAY = 15
; time between autorepeat keypresses
DAS_SPEED = 3

.segment "PRGFIXED_C000"

.proc read_pads_once  ; jsr 6, put
  ; see https://www.nesdev.org/wiki/Controller_reading_code#DPCM_Safety_using_OAM_DMA
  ; for details on OAM DMA timing

  ; Bits from the controllers are shifted into thisRead and
  ; thisRead+1.  In addition, thisRead+1 serves as the loop counter:
  ; once the $01 gets shifted left eight times, the 1 bit will
  ; end up in carry, terminating the loop.
  ldx #$01            ; 2, put
  stx z:thisRead      ; 3, get
  ; Write 1 then 0 to JOY1 to send a latch signal, telling the
  ; controllers to copy button states into a shift register
  stx JOY1            ; 4, get
  dex                 ; 2, get
  stx JOY1            ; 4, get
  loop:
    ; On NES and AV Famicom, button presses always show up in D0.
    ; On the original Famicom, presses on the hardwired controllers
    ; show up in D0 and presses on plug-in controllers show up in D1.
    ; D2-D7 consist of data from the Zapper, Power Pad, Vs. System
    ; DIP switches, and bus capacitance; ignore them.

    ; read player 2's controller
    lda JOY2          ; 4, GET!
    ; ignore D2-D7
    and #$03          ; 2, get
    ; CLC if A=0, SEC if A>=1
    cmp #1            ; 2, get
    ; put one bit in the register
    rol z:thisRead+1,x; 6, get
    ; read player 1's controller the same way
    lda JOY1          ; 4, GET!
    and #$03          ; 2, get
    cmp #1            ; 2, get
    rol z:thisRead    ; 5, put
    ; once $01 has been shifted 8 times, we're done
    c_bcc loop        ; 2 +1, put [get on branch]
  rts
.endproc

.proc read_pads
  ; store the current keypress state to detect key-down later
  lda cur_keys
  sta lastFrameKeys
  lda cur_keys+1
  sta lastFrameKeys+1

  ; Read the joypads synced to OAM DMA to prevent DMC DMA causing a clock glitch.
  lda shadow_oam_ptr+1
  sta OAM_DMA
  jsr read_pads_once

  ; transfer reads
  lda thisRead
  sta cur_keys
  lda thisRead+1
  sta cur_keys+1
  
  lda lastFrameKeys     ; A = keys that were down last frame
  eor #$FF              ; A = keys that were up last frame
  and cur_keys          ; A = keys down now and up last frame
  sta new_keys
  rts
.endproc


; Optional autorepeat handling

.if USE_DAS
.export autorepeat
.importzp das_keys, das_timer

;;
; Computes autorepeat (delayed-auto-shift) on the gamepad for one
; player, ORing result into the player's new_keys.
; @param X which player to calculate autorepeat for
.proc autorepeat
  lda cur_keys,x
  beq no_das
  lda new_keys,x
  beq no_restart_das
  sta das_keys,x
  lda #DAS_DELAY
  sta das_timer,x
  bne no_das
no_restart_das:
  dec das_timer,x
  bne no_das
  lda #DAS_SPEED
  sta das_timer,x
  lda das_keys,x
  and cur_keys,x
  ora new_keys,x
  sta new_keys,x
no_das:
  rts
.endproc

.endif
