"""Review the finite catalogue using the actual exported Blender thumbnails."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[1]
catalog = json.loads((root/"data/model_variants.json").read_text())
families = {k: v for k, v in catalog["families"].items() if len(v) > 1}
columns = max(map(len, families.values()))
sheet = Image.new("RGB", (columns*320, 70+len(families)*310), "#e5dfce")
draw = ImageDraw.Draw(sheet)
font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 18)
draw.text((24, 20), "OPEN-PSIM / VARIANTES · canónico + semillas", font=font, fill="#41493d")
for row, (family, names) in enumerate(families.items()):
    for col, name in enumerate(names):
        source = Image.open(root/"assets/ui"/(name+".png")).convert("RGBA")
        source.thumbnail((280, 280), Image.Resampling.LANCZOS)
        sheet.paste(source, (col*320+20, row*310+55), source)
        draw.text((col*320+20, row*310+337), name, font=font, fill="#41493d")
path = root/"art/renders/model-variants.png"
sheet.save(path)
print(path)
