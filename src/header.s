.include "global.inc"
.include "nes.inc"
.import nmi_handler, reset_handler, irq_handler

.segment "ZEROPAGE"
temp1_8:        .res 1
temp2_8:        .res 1
temp1_16:       .res 2
temp2_16:       .res 2
sys_state:      .res 1
sys_mode:       .res 1

; iNES 2.0
.segment "HEADER"
	; comments regarding header format taken from
	; https://www.nesdev.org/wiki/index.php?title=INES#iNES_file_format
	; https://www.nesdev.org/wiki/NES_2.0#File_Structure
	; Flag 0-3
	.byte "NES", $1A
	; Flag 4
	.byte $04                       ; n * 16KB PRG ROM
	; Flag 5
	.byte $00                       ; n * 8KB CHR ROM

	; Flag 6
	.byte %11000000
	;      |||||||+- Mirroring: 0: horizontal (vertical arrangement) (CIRAM A10 = PPU A11)
	;      |||||||              1: vertical (horizontal arrangement) (CIRAM A10 = PPU A10)
	;      ||||||+-- 1: Cartridge contains battery-backed PRG RAM ($6000-7FFF) or other persistent memory
	;      |||||+--- 1: 512-byte trainer at $7000-$71FF (stored before PRG data)
	;      ||||+---- 1: Ignore mirroring control or above mirroring bit; instead provide four-screen VRAM
	;      ++++----- Lower nybble of mapper number

	; Flag 7
	.byte %00011000
	;      ||||||++-- Console type
	;      ||||||      0: Nintendo Entertainment System/Family Computer
	;      ||||||      1: Nintendo Vs. System
	;      ||||||      2: Nintendo Playchoice 10
	;      ||||||      3: Extended Console Type
	;      ||||++---- NES 2.0 identifier
	;      ++++------ Mapper Number D4..D7

	; Flag 8-10
	.byte $00, $00, $00

	; Flag 11
	.byte $09
	;      cC
	;      |+----- CHR-RAM size (volatile) shift count
	;      +------ CHR-NVRAM size (non-volatile) shift count
	;     If the shift count is zero, there is no CHR-(NV)RAM.
	;     If the shift count is non-zero, the actual size is
	;     "64 << shift count" bytes, i.e. 8192 bytes for a shift count of 7.

	; Flag 12-15; unused
	.byte $00, $00, $00, $00


.segment "UNUSED"
	.incbin "../obj/2A03_MEMORY_DUMP_TRACKED_DATA"

.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler