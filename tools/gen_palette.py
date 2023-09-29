#!/usr/bin/env python3
#   MIT No Attribution
#
#   Copyright 2023 Kagamiin~
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

"""Generates a set of background palettes given an input bitmap in NES colors.
The dimensions of the image must be 256x192."""

import os
import sys
import argparse
import numpy as np
from pathlib import Path
from PIL import Image
from typing import List, Tuple, NamedTuple

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
refpal = list(refpal)

def get_pal_color(index: int) -> List[int]:
    return refpal[index * 3: index * 3 + 3]

palette_lumas = list(bytes.fromhex(
    '57201f222724221e262a2f2c29000000'
    'a5524e4f555352535f6469655f000000'
    'ffa19896a19fa2a7b4b8bbb7b2410000'
    'ffd8d4d2d8d5d7dbe2e0e1dfe1b30000'
))

class Args(NamedTuple):
    input_image: Path
    output_dir: Path
    output_types: List[str]
    bgcolor: int

    algorithm_popularity = "popularity"
    algorithm_diversity = "diversity"
    valid_algorithms = [algorithm_popularity, algorithm_diversity]
    algorithm: str


def parse_and_validate_args() -> Args:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input_image", type=Path, help="input image file name")
    parser.add_argument("output_dir", type=Path, help="output directory for file")
    parser.add_argument("--bgcolor", type=int, help="shared background color, defaults to 0x0F (black)", default=0x0f)
    parser.add_argument("--algorithm", choices=Args.valid_algorithms, default=Args.algorithm_popularity, help="algorithm for palette reduction, defaults to 'popularity'")
    
    output_types = parser.add_argument_group("output types", "file types for the palette output")
    output_types.add_argument("--output-asm", action="append_const", const="asm", dest="output_types", help="output palette in assembly format")
    output_types.add_argument("--output-hex", action="append_const", const="hex", dest="output_types", help="output palette in plain hex format")
    output_types.add_argument("--output-bin", action="append_const", const="bin", dest="output_types", help="output palette in binary format")

    args = parser.parse_args()

    if not args.output_types:
        parser.error("must specify at least one output type")

    if not args.input_image.exists():
        parser.error(f"input image path '{args.input_image}' does not exist")
    if not args.input_image.is_file():
        parser.error(f"input image path '{args.input_image}' is not a file")

    if not args.output_dir.exists():
        parser.error(f"output path '{args.output_dir}' does not exist")
    if not args.output_dir.is_dir():
        parser.error(f"output path '{args.output_dir}' is not a directory")

    return Args(input_image=args.input_image,
                output_dir=args.output_dir,
                output_types=args.output_types,
                bgcolor=args.bgcolor,
                algorithm=args.algorithm)

def replace_black(color, default_black=0x0f):
    if color & 0x0e == 0x0e:
        return default_black
    elif color == 0x0d or color == 0x1d:
        return default_black
    return color

def replace_blacks(palette: List, default_black=0x0f):
    new_palette = [replace_black(color) for color in palette]
    return new_palette

def sort_palette(palette: List, bgcolor=0x0f):
    sorted_palette = []
    if bgcolor in palette:
        palette.remove(bgcolor)
        sorted_palette.append(bgcolor)
    else:
        raise AttributeError(f"Background color 0x{bgcolor:02x} ({bgcolor}) missing from palette {palette}")
    palette.sort(key=lambda x: palette_lumas[x])
    sorted_palette.extend(palette)
    return sorted_palette

def reduce_palette_popularity(metatile: Image, bgcolor=0x0f):
    colors = metatile.getcolors()
    # getcolors() return a (count, index) tuple.
    reduced_palette = [bgcolor]
    # Sort by most popular color using tuple's count parameter
    colors.sort(key=lambda t: t[0], reverse=True)
    for i in range(3):
        most_popular_color = colors.pop(0)
        reduced_palette.append(most_popular_color[1])
    return sort_palette(reduced_palette)

def get_most_diverse_color(existing_colors: List[int], new_colors: List[Tuple[int, int]]) -> int:
    current_colors = []
    for index in existing_colors:
        current_colors.append(np.array(get_pal_color(index)))
    most_different_color: Tuple(int, float) = (None, 0.)
    for new_color in new_colors:
        sum_differences: float = 0.
        new_value = np.array(get_pal_color(new_color[1]))
        for existing_value in current_colors:
            sum_differences += np.linalg.norm(existing_value - new_value)
        if sum_differences > most_different_color[1]:
            most_different_color = (new_color[1], sum_differences)
    return most_different_color[0]

def reduce_palette_diversity(metatile: Image, bgcolor=0x0f):
    colors = metatile.getcolors()
    # getcolors() return a (count, index) tuple.
    reduced_palette = [bgcolor]
    # Sort by most popular color using tuple's count parameter
    colors.sort(key=lambda t: t[0], reverse=True)
    # Diversity algorithm: alternate most popular color, then the color that's
    # the most different to the colors chosen so far
    # Step 1/3: Most popular color (like in popularity)
    most_popular_color = colors.pop(0)
    reduced_palette.append(most_popular_color[1])
    # Step 2/3: Most diverse color
    most_diverse_color = get_most_diverse_color(reduced_palette, colors)
    reduced_palette.append(most_diverse_color)
    # Step 3/3: Most popular color (like in popularity)
    most_popular_color = colors.pop(0)
    reduced_palette.append(most_popular_color[1])

    return sort_palette(reduced_palette)

def get_metatile_palette(metatile: Image, reduce_algorithm: str, bgcolor=0x0f):
    colors = metatile.getcolors()
    # getcolors() return a (count, index) tuple.
    colors = list(map(lambda t: (t[0], replace_black(t[1])), colors))
    if len(colors) < 4:
        pal = list(map(lambda t: t[1], colors))
        if not any(map(lambda t: t[1] == bgcolor, colors)):
            pal.append(bgcolor)
        return sort_palette(pal, bgcolor)
    elif len(colors) == 4 and any(map(lambda t: t[1] == bgcolor, colors)):
        pal = list(map(lambda t: t[1], colors))
        return sort_palette(pal, bgcolor)
    else:
        if reduce_algorithm == Args.algorithm_popularity:
            return reduce_palette_popularity(metatile, bgcolor)
        elif reduce_algorithm == Args.algorithm_diversity:
            return reduce_palette_diversity(metatile, bgcolor)
        else:
            raise AttributeError(f"Invalid palette reduction algorithm: {reduce_algorithm}")

def dedupe_palettes(palette_list: List[List[int]]) -> List[Tuple[int]]:
    population: Dict[Tuple, int] = {}
    # First dedupe pass: merge palettes together by population count
    for pal in palette_list:
        pal_tuple = tuple(pal)
        if population.get(pal_tuple) == None:
            population[pal_tuple] = 1
        else:
            population[pal_tuple] += 1
    # Gather deduped palettes sorted by popularity
    deduped_palettes = []
    for t in population.items():
        deduped_palettes.append(t)
    deduped_palettes.sort(key=lambda t: t[1], reverse=True)

    # Sort them again by number of colors, for second dedupe pass
    deduped_palettes.sort(key=lambda t: len(t[0]), reverse=True)

    # Second dedupe pass: merge together smaller palettes that fit in larger ones
    for i in range(len(deduped_palettes) - 1, 0, -1):
        pal = deduped_palettes[i]
        for j in range(i):
            candidate = deduped_palettes[j]
            if all(v in candidate[0] for v in pal[0]):
                deduped_palettes[j] = (candidate[0], candidate[1] + pal[1])
                deduped_palettes.pop(i)
                break

    if len(deduped_palettes) <= 4:
        return [tpl[0] for tpl in deduped_palettes]
    else
        raise NotImplementedError("Palette vector quantization is still not implemented yet")

def pad_palettes(palette_list: List[Tuple[int]], bgcolor=0x0f) -> List[int]:
    dest_array = [bgcolor] * 16
    for i, pal in enumerate(palette_list):
        for j, value in enumerate(pal):
            dest_array[i * 4 + j] = value

    return dest_array

def save_palettes_bin(padded_palette: List[int], output_dir: Path):
    with open(output_dir / "pal.bin", "wb") as outfile:
        outfile.write(bytes(padded_palette))

def save_palettes_hex(padded_palette: List[int], output_dir: Path):
    with open(output_dir / "pal.hex", "w", encoding="utf8") as outfile:
        outfile.write(bytes(padded_palette).hex())
        outfile.write("\n")

def save_palettes_asm(padded_palette: List[int], output_dir: Path):
    with open(output_dir / "pal.asm", "w", encoding="utf8") as outfile:
        for i in range(0, 16, 4):
            pal = padded_palette[i:i+4]
            midstr = ",".join(map(lambda x: f"${x:02X}", pal))
            outfile.write(f"\t.byte {midstr}\n")

def main():
    args = parse_and_validate_args()

    with Image.open(args.input_image) as image:
        if image.size != (256, 192):
            raise ValueError(f"Image '{args.input_image}' is not 256x192")

        if not (image.mode == "P" or image.mode == "PA"):
            raise ValueError(f"Image '{args.input_image}' is not indexed color")

        palette_size = len(image.getpalette()) / 3
        if palette_size != 64:
            raise ValueError(f"Image '{args.input_image}' has {palette_size} colors in palette, should have exactly 64")

        image2 = Image.new("P", (256, 208), None)
        image2.putpalette(image.getpalette(rawmode="RGB"), rawmode="RGB")
        tile0 = image.crop((0, 0, 8, 8))
        for i in range(0, 256, 8):
            image2.paste(tile0, (i, 0))
            image2.paste(tile0, (i, 200))
        image2.paste(image, (0, 8))

        # set reference palette
        image2.putpalette(refpal, rawmode="RGB")

        metatiles = [[image2.crop((x, y, x + 16, y + 16))
                        for x in range(0, 256, 16)]
                    for y in range(0, 208, 16)]

        metatile_colors = [get_metatile_palette(mt, args.algorithm, bgcolor=args.bgcolor) for row in metatiles for mt in row]

        # image3 = Image.new("RGB", (256, 208), None)
        # 
        # metatiles_quantized = []
        # for i, row in enumerate(metatiles):
        #     for j, mt in enumerate(row):
        #         dummy_image = Image.new("P", (16, 16), None)
        #         palette = []
        #         for index in metatile_colors[i][j]:
        #             palette.extend(get_pal_color(index))
        #         dummy_image.putpalette(palette)
        #         rgb_metatile = mt.convert("RGB")
        #         quantized_metatile = rgb_metatile.quantize(method=Image.Quantize.FASTOCTREE, palette=dummy_image, dither=Image.Dither.NONE)
        #         image3.paste(quantized_metatile, (j * 16, i * 16))
        # 
        # image3.save("intermediate_result.png")
        
        palettes = dedupe_palettes(metatile_colors)
        padded_palettes = pad_palettes(palettes, bgcolor=args.bgcolor)
        
        if "asm" in args.output_types:
            save_palettes_asm(padded_palettes, args.output_dir)
        if "bin" in args.output_types:
            save_palettes_bin(padded_palettes, args.output_dir)
        if "hex" in args.output_types:
            save_palettes_hex(padded_palettes, args.output_dir)


if __name__ == "__main__":
    main()
