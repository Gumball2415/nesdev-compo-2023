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

import sys
import os
import argparse

parser = argparse.ArgumentParser(description="generate label linking information for image list.")
parser.add_argument("--input_images", type=str, help="input image names", nargs="+")
parser.add_argument("--obj_dir", type=str, help="object directory")
parser.add_argument("-v", "--verbose", action="store_true", help="enable verbose logs")

args = parser.parse_args()
bank_size = 2**14
img_index_s_txt = ""
img_index_size = (bank_size * 3) # let linker tell you if you fucked up
img_index_bank = 0
img_index_ptr = 0

def print_bank_split():
    global img_index_s_txt, img_index_bank
    if img_index_bank > 3:
        sys.exit("exceeded memory capacity!")
    img_index_s_txt += ".segment \"PRG{0}_8000\"\n".format(img_index_bank)

def increment_bank_size(size):
    global img_index_ptr, img_index_size, img_index_bank
    # check if adding the file will overflow the bank size
    if (((bank_size) - (img_index_ptr + size)) < size):
        # increment bank
        img_index_bank += 1
        print_bank_split()
        img_index_ptr = 0
    img_index_ptr += size
    img_index_size -= size

    if args.verbose:
        print("blob size: {0}".format(size))
        print("bank number: {0}".format(img_index_bank))
        print("bank size remaining: {0}".format((bank_size) - img_index_ptr))
        print("total size remaining: {0}\n".format(img_index_size))


def check_file_size(file_path):
    global img_index_ptr
    if os.path.splitext(os.path.basename(file_path))[0] == "pal":
        increment_bank_size(32)
    elif os.path.splitext(os.path.basename(file_path))[0] == "attr":
        increment_bank_size(64)
    elif os.path.splitext(os.path.basename(file_path))[0] == "oam":
        increment_bank_size(256)
    else:
        increment_bank_size(os.path.getsize(file_path))
    # print("pointer: {0}".format(img_index_ptr))

def place_data_chunk(obj_dir, input_img, file_path):
    global img_index_s_txt, img_index_ptr
    img_index_s_txt += "\t{0}_{1}:\n\t\t.incbin \"../{3}/{0}/{2}\"\n".format(input_img, os.path.splitext(file_path)[0], file_path, obj_dir)
    check_file_size("{0}/{1}/{2}".format(obj_dir, input_img, file_path))

def place_asm_chunk(obj_dir, input_img, file_path):
    global img_index_s_txt
    img_index_s_txt += "\t{0}_{1}:\n\t\t.include \"../{3}/{0}/{2}\"\n".format(input_img, os.path.splitext(file_path)[0], file_path, obj_dir)
    check_file_size("{0}/{1}/{2}".format(obj_dir, input_img, file_path))

# we assume that the universal palette and the image title is already included
# universal_tileset:
	# .incbin "../obj/universal.donut"
check_file_size("{0}/universal.donut".format(args.obj_dir))
# universal_pal:
	# .include "../obj/universal_pal.s"
increment_bank_size(32)

# img_title_nam:
	# .incbin "../obj/img_title/img_title_nam.donut"
check_file_size("{0}/img_title/img_title_nam.donut".format(args.obj_dir))
# img_title_oam:
	# .include "../obj/img_title/oam.s"
check_file_size("{0}/img_title/oam.s".format(args.obj_dir))
# img_title_bank_0:
	# .incbin "../obj/img_title/bank_0.donut"
check_file_size("{0}/img_title/bank_0.donut".format(args.obj_dir))

print_bank_split()

for input_img in args.input_images:
    # <img>_pal:
        # .include "../obj/<img>/pal.s"
    place_asm_chunk(args.obj_dir, input_img, "pal.s")
    # <img>_attr:
        # .incbin "../obj/<img>/attr.bin"
    place_data_chunk(args.obj_dir, input_img, "attr.bin")
    # <img>_oam:
        # .include "../obj/<img>/oam.s"
    place_asm_chunk(args.obj_dir, input_img, "oam.s")
    # <img>_bank_0:
        # .incbin "../obj/<img>/bank_0.donut"
    place_data_chunk(args.obj_dir, input_img, "bank_0.donut")
    # <img>_bank_1:
        # .incbin "../obj/<img>/bank_1.donut"
    place_data_chunk(args.obj_dir, input_img, "bank_1.donut")
    # <img>_bank_2:
        # .incbin "../obj/<img>/bank_2.donut"
    place_data_chunk(args.obj_dir, input_img, "bank_2.donut")
    # <img>_bank_s:
        # .incbin "../obj/<img>/bank_s.donut"
    place_data_chunk(args.obj_dir, input_img, "bank_s.donut")

img_index_s_txt += ".segment \"PRGFIXED_C000\"\n"
for input_img in args.input_images:
    # <img>:
    img_index_s_txt += "\t{0}:\n".format(input_img)
        # .addr <img>_pal
    img_index_s_txt += "\t\t.addr {0}_pal\n".format(input_img)
        # .addr <img>_attr
    img_index_s_txt += "\t\t.addr {0}_attr\n".format(input_img)
        # .addr <img>_oam
    img_index_s_txt += "\t\t.addr {0}_oam\n".format(input_img)
        # .addr <img>_bank_0
    img_index_s_txt += "\t\t.addr {0}_bank_0\n".format(input_img)
        # .addr <img>_bank_1
    img_index_s_txt += "\t\t.addr {0}_bank_1\n".format(input_img)
        # .addr <img>_bank_2
    img_index_s_txt += "\t\t.addr {0}_bank_2\n".format(input_img)
        # .addr <img>_bank_s
    img_index_s_txt += "\t\t.addr {0}_bank_s\n".format(input_img)

        # .byte <.bank(<img>_pal)
    img_index_s_txt += "\t\t.byte <.bank({0}_pal)\n".format(input_img)
        # .byte <.bank(<img>_attr)
    img_index_s_txt += "\t\t.byte <.bank({0}_attr)\n".format(input_img)
        # .byte <.bank(<img>_oam)
    img_index_s_txt += "\t\t.byte <.bank({0}_oam)\n".format(input_img)
        # .byte <.bank(<img>_bank_0)
    img_index_s_txt += "\t\t.byte <.bank({0}_bank_0)\n".format(input_img)
        # .byte <.bank(<img>_bank_1)
    img_index_s_txt += "\t\t.byte <.bank({0}_bank_1)\n".format(input_img)
        # .byte <.bank(<img>_bank_2)
    img_index_s_txt += "\t\t.byte <.bank({0}_bank_2)\n".format(input_img)
        # .byte <.bank(<img>_bank_s)
    img_index_s_txt += "\t\t.byte <.bank({0}_bank_s)\n".format(input_img)

img_index_s_txt += "\timg_table:\n"

for input_img in args.input_images:
    img_index_s_txt += "\t\t.addr {0}\n".format(input_img)

img_index_s_txt += "\timg_table_size := * - img_table\n"


with open("{0}/img_index.s".format(args.obj_dir), "w", encoding="utf-8") as img_index_s:
    img_index_s.write(img_index_s_txt)
