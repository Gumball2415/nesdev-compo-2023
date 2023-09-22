from PIL import Image, ImagePalette
import sys
import os
import numpy as np

with open(sys.argv[1], mode="rb") as pal:
    palette_buf = np.transpose(np.frombuffer(pal.read(), dtype=np.uint8))
    imgindex = np.arange(0, 255, dtype=np.uint8)
    img = Image.frombytes('P', (16,int(os.path.getsize(sys.argv[1])/3/16)), imgindex)
    img.putpalette(list(palette_buf), rawmode="RGB")
    img.save((os.path.splitext(sys.argv[1])[0] + ".png"), optimize=True)
