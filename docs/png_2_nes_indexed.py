from PIL import Image, ImagePalette
import sys
import os
import numpy as np

with open(sys.argv[1], mode="rb") as master_pal:
    with Image.open(sys.argv[2]) as img:
        palette_buf = np.transpose(np.frombuffer(master_pal.read(), dtype=np.uint8))
        nespal = ImagePalette.ImagePalette(mode="RGB", palette=list(palette_buf))
        imgpal = Image.new('P',(1,1))
        imgpal.putpalette(nespal)
        img = img.convert(mode="RGB").quantize(colors=256, palette=imgpal, dither=Image.Dither.NONE)
        img.save((os.path.splitext(sys.argv[2])[0] + "_conv.png"), optimize=True)
 