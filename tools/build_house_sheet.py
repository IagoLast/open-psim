"""Compare the nine authored Blender house variants at a consistent card size."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont
root=Path(__file__).resolve().parents[1]
catalog=json.loads((root/'data/model_variants.json').read_text())
background=json.loads((root/'docs/design-style.json').read_text())['palette']['background']
font_path='/System/Library/Fonts/Supplemental/Arial.ttf'
font=lambda size: ImageFont.truetype(font_path,size)
sheet=Image.new('RGB',(1536,1460),background)
draw=ImageDraw.Draw(sheet)
draw.text((48,32),'PONTEVEDRA / CASAS',font=font(32),fill='#5d503c')
draw.text((48,78),'9 variantes · piedra cálida, terracota y madera · Blender',font=font(18),fill='#978163')
for row,(family,label) in enumerate([('house_cottage','01 / HUMILDE'),('house','02 / PRÓSPERA'),('house_tall','03 / MERCANTIL')]):
    top=130+row*442
    draw.text((48,top),label,font=font(17),fill='#978163')
    names=[name for name in catalog['families'][family] if name!=family]
    for col,name in enumerate(names):
        source=Image.open(root/'assets/ui'/f'{name}.png').convert('RGBA')
        source=source.resize((440,440),Image.Resampling.LANCZOS)
        sheet.paste(source,(col*512+36,top+3),source)
        draw.text((col*512+256,top+412),catalog['models'][name]['label'],font=font(19),fill='#65563f',anchor='mt')
sheet.save(root/'art/renders/house-variants.png')
print(root/'art/renders/house-variants.png')
