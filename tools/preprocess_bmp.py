#!/usr/bin/env python3
#   MIT No Attribution
#
#   Copyright 2023 Persune
#
#   Permission is hereby granted, free of charge, to any person obtaining a copy of this
#   software and associated documentation files (the "Software"), to deal in the Software
#   without restriction, including without limitation the rights to use, copy, modify,
#   merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
#   permit persons to whom the Software is furnished to do so.
#
#   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
#   INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
#   PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
#   HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
#   OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
#   SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import sys, os, re
import argparse
from PIL import Image

"""
.sav format
0x0000:0x1000 = 4K tile data
0x1800-0x1BBF = nametable data
0x1BC0-0x1BFF = attribute data
0x1F00-0x1F1F = palette data
"""

# Reference palette by Persune
refpal = bytes.fromhex(
    '57575700166807067b2a00754800594e00214c0000381100'
    '202900003200003800003406002d41000000000000000000'
    'a5a5a5184cbb3837d6681fce8e1ca6991d5c962a1e7a4600'
    '5964002a73000e7a00007536036985000000000000000000'
    'ffffff6da3ff8e8dffc075ffe771fff372b3f08073d39d29'
    'b0bc1180cb1662d33b4dce8c57c1de414141000000000000'
    'ffffffc4daffd2d1ffe6c7fff8c9fffac6e1f9ccc7edd8a9'
    'e2e7a2cceaa1c0edb0b7ebd1bfe9f5b3b3b3000000000000'
)
refpal = [refpal[i:i + 3]
          for i in range(0, len(refpal), 3)]

# override savtool.py functions
def render_tilesheet(chrdata, colorset):
    from savtool import texels_to_pil, chrbank_to_texels
    palette = args.palette
    rgbpalette = [refpal[c & 0x3F] for c in palette]
    tiles = texels_to_pil(chrbank_to_texels(chrdata))
    subpal = rgbpalette[0:1] + rgbpalette[colorset*4+1:colorset*4+4]
    tiles.putpalette(b''.join(subpal) * 64)
    return tiles

def load_bitmap_with_palette(filename, palette, max_tiles=None, attronly=False, chrout=False):
    from pilbmp2nes import pilbmp2chr
    from chnutils import dedupe_chr
    from savtool import colorround, bitmap_to_sav, ensure_pil, default_palette
    ensure_pil()
    im = Image.open(filename)
    (w, h) = im.size
    palettes = [tuple(refpal[i]) for i in palette]
    palettes = [[palettes[0]] + palettes[i + 1:i + 4]
                for i in range(0, 16, 4)]

    if (w != 256 or h != 240):
        i2 = Image.new("RGB", (256, 240), palettes[0][0])
        i2.paste(im, ((256 - w) // 2, (240 - h) // 2))

        # assumes input image is 256x192!
        if chrout or attronly:
            # pad top with bank 0 tile 00
            im_firsttile = im.crop((0, 0, 8, 8))
            imtop = Image.new("RGB", (256, 24), palettes[0][0])
            for i in range(0, (256*24), 8):
                imtop.paste(im_firsttile, (i - (i // w) * w, i // w))
            i2.paste(imtop, (0, 0))

            # pad bottom with bank 0 tile FF
            im_lasttile = im.crop((w - 8, h - 8, w, h))
            imbot = Image.new("RGB", (256, 24), palettes[0][0])
            for i in range(0, (256*24), 8):
                imbot.paste(im_lasttile, (i - (i // w) * w, i // w))
            i2.paste(imbot, (0, 240 - 24))
            (w, h) = i2.size
        im = i2
        im.save(args.output_dir+"/im.bmp", "BMP")
        
    (imf, attrs) = colorround(im, palettes)
    imf.save(args.output_dir+"/imf.bmp", "BMP")
    if len(attrs) % 2:
        attrs.append([0] * len(attrs[0]))
    if chrout:
        i2 = imf.crop(((256 - w) // 2, (240 - h) // 2, (256 + w) // 2, (240 + h) // 2))
        imf = i2
        # assumes input image is 256x192!
        imchr = pilbmp2chr(imf, 8, 8)
        chrdata = b''.join(imchr)
        chrdata = chrdata[0x0600:0x3600]
        return chrdata
    elif not attronly:
        sav = bitmap_to_sav(imf, max_tiles=max_tiles)
    else:
        # Generate empty sav hunks
        chrdata = b'\x00' * 4096
        chrpad = b'\xFF' * 2048
        namdata = b''.join((b'\xFF' * 960, b'\x00' * 64))
        sav = b''.join((chrdata, chrpad,
                    namdata, b'\xFF' * 768,
                    default_palette, default_palette, b'\xFF' * 224))
    attrs = [[row[i] | (row[i + 1] << 2) for i in range(0, 16, 2)]
             for row in attrs]
    attrs = [bytes(tc | (bc << 4) for (tc, bc) in zip(t, b))
             for (t, b) in zip(attrs[0::2], attrs[1::2])]
    attrs = b''.join(attrs)
    return b''.join((sav[0:0x1BC0], attrs, sav[0x1C00:0x1F00],
                         palette, palette, sav[0x1F20:]))

parser = argparse.ArgumentParser(description="convert input 256x192 indexed bitmap tileset into 3 256x64 tilesets.")
parser.add_argument("input_image", type=str, help="input image")
parser.add_argument("output_dir", type=str, help="output_directory")
parser.add_argument("--palette", help="use a 32-character hex palette. see savtool.py")

args = parser.parse_args()

# load palette
# code taken from savtool.py
xdigitRE = re.compile('^\$?([0-9a-fA-F]+)$')
m = args.palette and xdigitRE.match(args.palette)
if m and len(m.group(1)) == 32:
    args.palette = bytes.fromhex(m.group(1))
else:
    sys.exit("error: palette provided is not a 32-character hex palette")

# Load image
with Image.open(args.input_image) as image:
    image_filepath, image_filename = os.path.split(args.input_image)
    print("processing {0}...".format(args.input_image))

    if (image.size != (256, 192)):
        sys.exit("error: {0} is not 256x192".format(args.input_image))

    if not (image.mode == "P") or (image.mode == "PA"):
        sys.exit("error: {0} is not indexed".format(args.input_image))

# from savtool import load_bitmap_with_palette
# extract attribute data
attrsav = load_bitmap_with_palette(args.input_image, args.palette, attronly=True)
with open(args.output_dir+"/attr.bin", 'wb') as outfp:
    outfp.write(attrsav[0x1BC0:0x1C00])

# extract CHR data
imagechr = load_bitmap_with_palette(args.input_image, args.palette, attronly=False, chrout=True)

# check for sprite 0 after conversion
# from savtool import render_tilesheet
image_bank_0 = render_tilesheet(imagechr[:0x1000], 0)
sprite0_region = image_bank_0.getpixel((120, 127))
if (sprite0_region == 0):
    sys.exit("error: sprite 0 background pixel not found")

# split into 3 banks
with open(args.output_dir+"/bank_0.chr", 'wb') as outfp:
    outfp.write(imagechr[0x0000:0x1000])
with open(args.output_dir+"/bank_1.chr", 'wb') as outfp:
    outfp.write(imagechr[0x1000:0x2000])
with open(args.output_dir+"/bank_2.chr", 'wb') as outfp:
    outfp.write(imagechr[0x2000:0x3000])

# tbh, don't care to check whether first or last tile is blank
# may allow some artists to do gradient bg where the top is one color,
# and the bottom is another color
