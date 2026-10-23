"""Reject a blank release frame, excluding Android status/navigation bars."""
import sys
from PIL import Image

image = Image.open(sys.argv[1]).convert('RGB')
width, height = image.size
frame = image.crop((int(width * .04), int(height * .12),
                    int(width * .96), int(height * .90))).resize((120, 160))
pixels = list(frame.getdata())
dark = sum(max(pixel) < 160 for pixel in pixels) / len(pixels)
colorful = sum(max(pixel) - min(pixel) > 45 for pixel in pixels) / len(pixels)
colors = len({tuple(channel // 24 for channel in pixel) for pixel in pixels})
print(f'Frame check: dark={dark:.4f}, colorful={colorful:.4f}, colors={colors}')
if dark < .005 or colorful < .005 or colors < 20:
    raise SystemExit('Blank or incomplete Android startup frame; inspect QA screenshot')
