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

# convert input 256x192 indexed bitmap tileset into 3 256x64 tilesets

import sys
import os
import argparse
from PIL import Image

parser = argparse.ArgumentParser(description="convert input 256x240 indexed bitmap tileset into 3 256x64 indexed bitmaps.")
parser.add_argument("input_image", type=str, help="input image")
parser.add_argument("output_dir", type=str, help="output_directory")

args = parser.parse_args()

# Load image
with Image.open(args.input_image) as image:
    image_filepath, image_filename = os.path.split(args.input_image)
    print("processing {0}...".format(args.input_image))

    if (image.size != (256, 192)):
        sys.exit("error: {0} is not 256x192".format(args.input_image))

    if not (image.mode == "P") or (image.mode == "PA"):
        sys.exit("error: {0} is not indexed",format(args.input_image))

    # check for sprite 0 
    sprite0_region = image.getpixel((248, 63))
    if (sprite0_region == 0):
        sys.exit("error: sprite 0 background pixel not found")

    # tbh, don't care to check whether first or last tile is blank
    # may allow some artists to do gradient bg where the top is one color,
    # and the bottom is another color

    image.crop((0, 0, 255, 63)).save(args.output_dir+"/bank_0.bmp", "BMP")
    image.crop((0, 64, 255, 127)).save(args.output_dir+"/bank_1.bmp", "BMP")
    image.crop((0, 128, 255, 191)).save(args.output_dir+"/bank_2.bmp", "BMP")