"""A review sheet of actual Blender renders, without changing source images."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

root=Path(__file__).resolve().parents[1]
rows=[
    ("RECURSOS", [("wood","Madera"),("grain","Cereal"),("fish","Sardina"),("salt","Sal"),("salted_fish","Salazón"),("coins","Monedas"),("population","Población"),("happiness","Bienestar")]),
    ("ARQUITECTURA", [("house_cottage","Casa pequeña"),("house","Casa con soportal"),("house_tall","Casa de dos plantas"),("well","Pozo"),("farm","Campo de cereal"),("lumber","Leñadores"),("fishery","Pesquería"),("saltery","Taller de salazón")]),
    ("ENTORNO", [("warehouse","Almacén portuario"),("sailboat","Barca de vela"),("rowboat","Barca de remos"),("tree_oak","Roble"),("tree_cypress","Ciprés"),("citizen","Vecino")]),
    ("INTERFAZ", [("category_housing","Viviendas"),("category_services","Servicios"),("category_food","Alimentación"),("category_materials","Materias primas"),("select","Seleccionar"),("demolish","Demoler"),("road","Camino de piedra")]),
]
background=json.loads((root/'docs/design-style.json').read_text())["palette"]["background"]
sheet=Image.new("RGB",(1920,1260),background)
draw=ImageDraw.Draw(sheet)
font_path=Path('/System/Library/Fonts/Supplemental/Arial.ttf')
font=lambda size: ImageFont.truetype(str(font_path),size) if font_path.exists() else ImageFont.load_default()
draw.text((38,25),"PONTEVEDRA / COLECCIÓN LOW POLY",font=font(30),fill="#493f31")
draw.text((38,69),"Modelos originales creados en Blender · geometría y miniaturas compartidas",font=font(17),fill="#887b64")
for row,(section,entries) in enumerate(rows):
    top=112+row*283
    draw.line((38,top,1882,top),fill="#ded6c5",width=1)
    draw.text((38,top+12),section,font=font(14),fill="#927e5b")
    for column,(name,label) in enumerate(entries):
        source=Image.open(root/'assets/ui'/f'{name}.png').convert('RGBA')
        source.thumbnail((220,220),Image.Resampling.LANCZOS)
        x=column*235+20+(235-source.width)//2
        y=top+36+(220-source.height)//2
        sheet.paste(source,(x,y),source)
        draw.text((column*235+137,top+258),label,font=font(15),fill="#584b3a",anchor='mt')
output=root/'art/renders/ui-collection.png'
sheet.save(output)
print(output)

# Larger architectural review and unlabelled cream-background subject renders.
review=Image.new("RGB",(1536,1024),background)
for index,name in enumerate(["house_cottage","house","house_tall","well","farm","saltery"]):
    source=Image.open(root/'assets/ui'/f'{name}.png').convert('RGBA')
    review.paste(source,((index%3)*512,(index//3)*512),source)
    single=Image.new("RGB",source.size,background)
    single.paste(source,(0,0),source)
    single.save(root/'art/renders'/f'{name}-design.png')
review.save(root/'art/renders/architecture-review.png')

# At the intended icon size, compare silhouettes without scaling them up.
readability=Image.new("RGB",(8*96,2*106),background)
for index,name in enumerate(["wood","grain","fish","salt","salted_fish","coins","population","happiness",
                             "house_cottage","house","house_tall","well","farm","lumber","fishery","saltery"]):
    source=Image.open(root/'assets/ui'/f'{name}.png').convert('RGBA').resize((64,64),Image.Resampling.LANCZOS)
    readability.paste(source,((index%8)*96+16,(index//8)*106+21),source)
readability.save(root/'art/renders/readability-64.png')
