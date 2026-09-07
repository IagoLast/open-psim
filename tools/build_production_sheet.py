"""Compose a review sheet from the actual production-building thumbnail renders."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ENTRIES = [
    ("saltworks", "Salinas"), ("quarry", "Cantera"), ("claypit", "Barrero"),
    ("mine", "Mina"), ("sheep", "Redil"), ("vineyard", "Viñedo"),
    ("mill", "Molino hidráulico"), ("bakery", "Panadería"), ("winery", "Bodega"),
    ("potter", "Alfarería"), ("smith", "Herrería"), ("weaver", "Tejeduría"),
]
background = json.loads((ROOT / "docs/design-style.json").read_text())["palette"]["background"]
font_path = Path("/System/Library/Fonts/Supplemental/Arial.ttf")
font = lambda size: ImageFont.truetype(str(font_path), size) if font_path.exists() else ImageFont.load_default()
sheet = Image.new("RGB", (1536, 1280), background)
draw = ImageDraw.Draw(sheet)
draw.text((35, 24), "PONTEVEDRA / EDIFICIOS DE PRODUCCIÓN", font=font(29), fill="#493f31")
draw.text((35, 65), "Doce modelos originales de Blender · misma geometría en GLB y miniatura", font=font(17), fill="#887b64")
for i, (name, label) in enumerate(ENTRIES):
    source = Image.open(ROOT / "assets/ui" / f"{name}.png").convert("RGBA")
    single = Image.new("RGB", source.size, background)
    single.paste(source, (0, 0), source)
    single.save(ROOT / "art/renders" / f"{name}-design.png")
    source.thumbnail((360, 350), Image.Resampling.LANCZOS)
    left, top = (i % 4) * 384, 105 + (i // 4) * 390
    sheet.paste(source, (left + (384-source.width)//2, top), source)
    draw.text((left+192, top+354), label, font=font(20), fill="#584b3a", anchor="mt")
sheet.save(ROOT / "art/renders/production-buildings.png")
print(ROOT / "art/renders/production-buildings.png")
