"""Deterministic original vector mark rasterization. No external artwork/font."""
from pathlib import Path
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
MOBILE = ROOT / 'apps' / 'mobile'
FOREST, LIGHT = '#245b49', '#edf5d9'

def icon(size, rounded=False):
    scale = 4
    s = size * scale
    image = Image.new('RGB', (s, s), FOREST if not rounded else '#f7f8f4')
    draw = ImageDraw.Draw(image)
    if rounded:
        draw.rounded_rectangle((0, 0, s - 1, s - 1), radius=s * .27, fill=FOREST)
    width = s * .065
    for i, h in enumerate((.2, .38, .55, .38, .2)):
        x = s * (.25 + i * .125)
        y0, y1 = s * (.5 - h / 2), s * (.5 + h / 2)
        draw.rounded_rectangle((x - width / 2, y0 - width / 2, x + width / 2, y1 + width / 2), radius=width / 2, fill=LIGHT)
    return image.resize((size, size), Image.Resampling.LANCZOS)

ios = MOBILE / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
manifest = json.loads((ios / 'Contents.json').read_text())
for asset in manifest['images']:
    if 'filename' not in asset:
        continue
    size = round(float(asset['size'].split('x')[0]) * float(asset['scale'].removesuffix('x')))
    icon(size).save(ios / asset['filename'])
android = MOBILE / 'android/app/src/main/res'
for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
    icon(size, rounded=True).save(android / f'mipmap-{density}' / 'ic_launcher.png')
(ROOT / 'assets/brand').mkdir(parents=True, exist_ok=True)
icon(1024).save(ROOT / 'assets/brand/app-icon.png')
print('Generated original iOS, Android, and 1024px brand icons.')
