.import nmi_handler, reset_handler, irq_handler

; iNES 1.0
.segment "HEADER"
  ; comments regarding header format taken from
  ; https://wiki.nesdev.org/w/index.php?title=INES#iNES_file_format
  ; Flag 0-3
  .byte "NES", $1A
  ; Flag 4
  .byte $01                       ; n * 16KB PRG ROM
  ; Flag 5
  .byte $01                       ; n * 8KB CHR ROM

  ; Flag 6
  .byte %00000000
  ;      ||||||||
  ;      |||||||+- Mirroring: 0: horizontal (vertical arrangement) (CIRAM A10 = PPU A11)
  ;      |||||||              1: vertical (horizontal arrangement) (CIRAM A10 = PPU A10)
  ;      ||||||+-- 1: Cartridge contains battery-backed PRG RAM ($6000-7FFF) or other persistent memory
  ;      |||||+--- 1: 512-byte trainer at $7000-$71FF (stored before PRG data)
  ;      ||||+---- 1: Ignore mirroring control or above mirroring bit; instead provide four-screen VRAM
  ;      ++++----- Lower nybble of mapper number

  ; Flag 7
  .byte %00000000
  ;      ||||||||
  ;      |||||||+- VS Unisystem
  ;      ||||||+-- PlayChoice-10 (8KB of Hint Screen data stored after CHR data)
  ;      ||||++--- If equal to 2, flags 8-15 are in NES 2.0 format
  ;      ++++----- Upper nybble of mapper number

  ; Flag 8
  .byte $00                      ; PRG-RAM size (rarely used extension)

  ; Flag 9
  .byte %00000000
  ;      ||||||||
  ;      |||||||+- TV system (0: NTSC; 1: PAL)
  ;      +++++++-- Reserved, set to zero

  ; Flag 10-15; unused
  .byte $00, $00, $00, $00, $00, $00

.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler