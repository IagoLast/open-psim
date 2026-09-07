"""Review actual civic Blender thumbnails on the collection's cream background."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ENTRIES = [("market", "Mercado"), ("clinic", "Hospital"), ("chapel", "Capilla"),
           ("watch", "Guardia"), ("school", "Escuela"), ("dock", "Muelle comercial"),
           ("depot", "Depósito"), ("firewatch", "Vigías del fuego"),
           ("maintenance", "Maestros de obras"), ("inn", "Hospedería"),
           ("convent", "Convento de San Francisco")]
background = json.loads((ROOT / "docs/design-style.json").read_text())["palette"]["background"]
columns = 4 if len(ENTRIES) > 10 else 5
sheet = Image.new("RGB", (320*columns, 70+360*((len(ENTRIES)+columns-1)//columns)), background)
draw = ImageDraw.Draw(sheet)
font_path = Path("/System/Library/Fonts/Supplemental/Arial.ttf")
font = ImageFont.truetype(str(font_path), 22) if font_path.exists() else ImageFont.load_default()
draw.text((32, 22), "PONTEVEDRA / SERVICIOS Y PUERTO", font=font, fill="#493f31")
draw.text((32, 49), "Miniaturas ajustadas al recuadro · convento: parcela 10 × 8", font=font, fill="#7a6c54")
output = ROOT / "art/renders"
output.mkdir(parents=True, exist_ok=True)
for index, (kind, label) in enumerate(ENTRIES):
    source = Image.open(ROOT / "assets/ui" / f"{kind}.png").convert("RGBA")
    design = Image.new("RGB", source.size, background)
    design.paste(source, (0, 0), source)
    design.save(output / f"{kind}-design.png")
    source.thumbnail((308, 308), Image.Resampling.LANCZOS)
    x, y = (index % columns) * 320 + 6, (index // columns) * 360 + 64
    sheet.paste(source, (x, y), source)
    draw.text((x + 154, y + 307), label, font=font, fill="#584b3a", anchor="mt")
sheet.save(output / "civic-buildings-review.png")
print(output / "civic-buildings-review.png")
