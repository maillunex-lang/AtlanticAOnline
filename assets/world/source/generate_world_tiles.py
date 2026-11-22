from PIL import Image, ImageDraw, ImageFilter
from pathlib import Path
import json, hashlib, zipfile, shutil, random, math, os

WROOT=Path('/mnt/agents/output/repo_ready_branches/art/world-tiles')
if WROOT.exists(): shutil.rmtree(WROOT)
WAS=WROOT/'assets'/'world'
WDOCS=WROOT/'docs'/'art'/'world-tiles'
for p in [WAS,WDOCS,WAS/'tiles_64',WAS/'tiles_128',WAS/'maps',WAS/'layers',WAS/'source']:
    p.mkdir(parents=True,exist_ok=True)
T=64
random.seed(42)

WPAL={
 'grass':'#4f8a45','grass2':'#3c6f37','grass3':'#6aa653','dirt':'#8a6742','dirt2':'#654832','gravel':'#8f8a7a','gravel2':'#67645a','cobble':'#7e8790','cobble2':'#535b64',
 'water':'#2d7fa3','water2':'#1d5577','foam':'#b8e5ef','sand':'#c7ad72','wood':'#7b4b2d','wood2':'#4b2d1c','leaf':'#2f6d3b','leaf2':'#1f4a2b','pine':'#245a38','flower':'#d56fa3','flower2':'#f1d071','mush':'#c85b4f','stone':'#7d8589','stone2':'#4c5459','moss':'#5d8b4a','shadow':'#07100c','light':'#f4e7b0'
}
def WC(n): return tuple(int(WPAL[n][i:i+2],16) for i in (1,3,5))
def rgba(n,a=255): return WC(n)+(a,)
def tile_bg(fill='grass'):
    im=Image.new('RGBA',(T,T),rgba(fill)); d=ImageDraw.Draw(im)
    for _ in range(110):
        x=random.randrange(T); y=random.randrange(T); c=random.choice(['grass2','grass3','grass']) if fill.startswith('grass') else random.choice([fill,'dirt2' if fill=='dirt' else fill])
        d.point((x,y),fill=rgba(c,120))
    return im

def ground_tile(name):
    im=tile_bg('grass'); d=ImageDraw.Draw(im)
    if name.startswith('grass'):
        base='grass' if name!='grass_low' else 'grass2'
        im=tile_bg(base); d=ImageDraw.Draw(im)
        if 'flowers' in name:
            for _ in range(8):
                x=random.randrange(8,58); y=random.randrange(8,58); d.ellipse((x,y,x+3,y+3),fill=rgba(random.choice(['flower','flower2'])))
        if 'high' in name:
            for _ in range(24):
                x=random.randrange(T); y=random.randrange(18,T); d.line((x,y,x+2,y-8),fill=rgba('grass3'),width=1)
    elif name.startswith('dirt') or name.startswith('path'):
        im=tile_bg('dirt'); d=ImageDraw.Draw(im)
        # path variants: h/v/corner/intersection
        if 'h' in name: d.rectangle((0,22,T,42),fill=rgba('dirt'))
        if 'v' in name: d.rectangle((22,0,42,T),fill=rgba('dirt'))
        if 'corner_ne' in name:
            d.rectangle((0,22,T,42),fill=rgba('dirt')); d.rectangle((22,0,42,42),fill=rgba('dirt'))
        if 'corner_sw' in name:
            d.rectangle((0,22,T,42),fill=rgba('dirt')); d.rectangle((22,22,42,T),fill=rgba('dirt'))
        if 'intersection' in name:
            d.rectangle((0,22,T,42),fill=rgba('dirt')); d.rectangle((22,0,42,T),fill=rgba('dirt'))
        for _ in range(25): d.point((random.randrange(T),random.randrange(T)),fill=rgba('dirt2',120))
    elif name.startswith('gravel'):
        im=tile_bg('gravel'); d=ImageDraw.Draw(im)
        for _ in range(70):
            x=random.randrange(T); y=random.randrange(T); r=random.choice([1,1,2]); d.ellipse((x-r,y-r,x+r,y+r),fill=rgba(random.choice(['gravel','gravel2','stone'])))
    elif name.startswith('cobble'):
        im=tile_bg('cobble'); d=ImageDraw.Draw(im)
        for yy in range(0,T,12):
            for xx in range(0,T,16):
                off=8 if (yy//12)%2 else 0
                d.rounded_rectangle((xx+off,yy,xx+off+13,yy+10),radius=3,fill=rgba(random.choice(['cobble','stone'])),outline=rgba('cobble2'))
    elif name.startswith('water'):
        im=tile_bg('water'); d=ImageDraw.Draw(im)
        for _ in range(35):
            x=random.randrange(T); y=random.randrange(T); d.line((x,y,x+random.choice([4,7]),y),fill=rgba('foam',100),width=1)
        if 'deep' in name: im=tile_bg('water2')
    return im

def object_tile(name):
    im=Image.new('RGBA',(T,T),(0,0,0,0)); d=ImageDraw.Draw(im)
    # contact shadow helper
    def shadow(cx,cy,rx,ry): d.ellipse((cx-rx,cy-ry,cx+rx,cy+ry),fill=(0,0,0,70))
    if name=='tree_oak':
        shadow(32,52,22,7); d.rectangle((27,28,36,57),fill=rgba('wood'),outline=rgba('wood2')); d.ellipse((10,4,54,38),fill=rgba('leaf'),outline=rgba('leaf2')); d.ellipse((19,12,45,34),fill=rgba('grass3'))
    elif name=='tree_pine':
        shadow(32,54,18,6); d.rectangle((29,32,35,58),fill=rgba('wood2')); d.polygon([(32,2),(8,32),(56,32)],fill=rgba('pine')); d.polygon([(32,18),(12,48),(52,48)],fill=rgba('pine'))
    elif name=='tree_birch':
        shadow(32,54,16,5); d.rectangle((29,18,34,58),fill=rgba('sand')); d.ellipse((12,4,52,32),fill=rgba('grass3'),outline=rgba('leaf2')); d.line((30,22,36,18),fill=rgba('wood2'),width=2)
    elif name=='bush': shadow(32,47,18,5); d.ellipse((10,26,54,50),fill=rgba('leaf'),outline=rgba('leaf2')); d.ellipse((20,20,44,42),fill=rgba('grass3'))
    elif name=='flowers':
        for _ in range(7):
            x=random.randrange(10,54); y=random.randrange(18,54); d.line((x,y,x,y+8),fill=rgba('grass2')); d.ellipse((x-3,y-3,x+3,y+3),fill=rgba(random.choice(['flower','flower2'])))
    elif name=='fern':
        for i in range(7):
            x=16+i*6; d.arc((x-8,24,x+14,56),200,320,fill=rgba('leaf'),width=2)
    elif name=='mushrooms':
        for _ in range(5):
            x=random.randrange(12,54); y=random.randrange(28,54); d.rectangle((x,y,x+3,y+8),fill=rgba('sand')); d.ellipse((x-4,y-6,x+7,y+1),fill=rgba('mush'),outline=rgba('wood2'))
    elif name=='roots':
        d.line((6,52,22,34),fill=rgba('wood2'),width=5); d.line((22,34,38,42),fill=rgba('wood2'),width=4); d.line((38,42,58,30),fill=rgba('wood2'),width=4)
    elif name=='stump':
        shadow(32,46,16,5); d.ellipse((17,24,47,48),fill=rgba('wood'),outline=rgba('wood2')); d.ellipse((23,29,41,42),fill=rgba('sand'))
    elif name=='reeds':
        for i in range(9):
            x=12+i*5; h=random.randrange(22,42); d.line((x,58,x+2,58-h),fill=rgba('grass3'),width=2); d.rectangle((x,58-h,x+3,58-h+5),fill=rgba('sand'))
    elif name=='boulder':
        shadow(34,48,22,8); d.polygon([(12,48),(20,20),(44,12),(58,34),(50,54),(24,58)],fill=rgba('stone'),outline=rgba('stone2')); d.polygon([(22,28),(38,18),(48,32),(32,42)],fill=rgba('moss'))
    elif name=='rocks':
        for _ in range(8):
            x=random.randrange(8,56); y=random.randrange(32,58); r=random.randrange(3,7); d.ellipse((x-r,y-r,x+r,y+r),fill=rgba(random.choice(['stone','stone2','moss'])))
    elif name=='dock_planks':
        d.rectangle((0,18,T,46),fill=rgba('wood'),outline=rgba('wood2')); d.line((0,28,T,28),fill=rgba('wood2'),width=2); d.line((0,38,T,38),fill=rgba('wood2'),width=2)
        for x in range(0,T,12): d.line((x,18,x,46),fill=rgba('wood2'),width=2)
    elif name=='barrel':
        shadow(32,50,16,6); d.ellipse((16,18,48,52),fill=rgba('wood'),outline=rgba('wood2')); d.line((16,35,48,35),fill=rgba('wood2'),width=3); d.line((22,20,22,50),fill=rgba('wood2'),width=2); d.line((42,20,42,50),fill=rgba('wood2'),width=2)
    elif name=='crate':
        shadow(32,49,17,6); d.rectangle((14,18,50,52),fill=rgba('wood'),outline=rgba('wood2'),width=3); d.line((14,18,50,52),fill=rgba('wood2'),width=2); d.line((50,18,14,52),fill=rgba('wood2'),width=2)
    elif name=='net':
        d.rectangle((10,20,54,50),outline=rgba('sand'),width=2)
        for i in range(0,45,8): d.line((10+i,20,10+i,50),fill=rgba('sand',160),width=1); d.line((10,20+i,54,20+i),fill=rgba('sand',160),width=1)
    elif name=='rope_fence':
        d.rectangle((10,20,14,56),fill=rgba('wood2')); d.rectangle((50,20,54,56),fill=rgba('wood2')); d.line((12,30,52,26),fill=rgba('sand'),width=3); d.line((12,44,52,40),fill=rgba('sand'),width=3)
    elif name=='lantern':
        shadow(32,52,10,4); d.rectangle((29,16,35,56),fill=rgba('wood2')); d.ellipse((24,6,40,22),fill=rgba('light'),outline=rgba('wood2')); d.line((32,22,32,30),fill=rgba('wood2'),width=2)
    elif name=='signpost':
        shadow(32,50,12,4); d.rectangle((29,18,35,56),fill=rgba('wood2')); d.rectangle((8,18,56,32),fill=rgba('wood'),outline=rgba('wood2')); d.line((14,25,48,25),fill=rgba('wood2'),width=2)
    elif name=='broken_wall':
        shadow(32,49,24,6); d.rectangle((6,24,58,52),fill=rgba('stone'),outline=rgba('stone2')); d.polygon([(6,24),(18,10),(30,24),(42,12),(58,24)],fill=rgba('stone')); d.rectangle((12,31,24,52),fill=rgba('moss'))
    elif name=='column':
        shadow(32,52,18,6); d.rectangle((20,10,44,54),fill=rgba('stone'),outline=rgba('stone2')); d.rectangle((14,8,50,16),fill=rgba('stone')); d.rectangle((16,48,48,56),fill=rgba('stone')); d.line((28,16,28,50),fill=rgba('stone2'),width=2); d.line((36,16,36,50),fill=rgba('stone2'),width=2); d.rectangle((20,28,44,34),fill=rgba('moss'))
    elif name=='moss_stone':
        shadow(32,46,18,5); d.rectangle((10,22,54,50),fill=rgba('stone2'),outline=rgba('stone')); d.rectangle((16,18,48,28),fill=rgba('moss'))
    return im

ground_names=['grass_dense','grass_low','grass_flower','grass_high','dirt_h','dirt_v','dirt_corner_ne','dirt_corner_sw','dirt_intersection','gravel','cobble','water_shallow','water_deep']
object_names=['tree_oak','tree_pine','tree_birch','bush','flowers','fern','mushrooms','roots','stump','reeds','boulder','rocks','dock_planks','barrel','crate','net','rope_fence','lantern','signpost','broken_wall','column','moss_stone']
modules=[]
# water animation frames
for i in range(3):
    im=ground_tile('water_shallow')
    d=ImageDraw.Draw(im)
    for _ in range(12):
        x=random.randrange(T); y=random.randrange(T); d.line((x,y,x+10,y),fill=rgba('foam',110),width=2)
    im.save(WAS/'tiles_64'/f'water_anim_{i}.png')

for name in ground_names:
    im=ground_tile(name); im.save(WAS/'tiles_64'/f'{name}.png')
    modules.append({'id':name,'type':'ground','file':f'assets/world/tiles_64/{name}.png','size':[64,64],'anchor':[0,0],'draw_order':0,'collision':'none'})
for name in object_names:
    im=object_tile(name); im.save(WAS/'tiles_64'/f'{name}.png')
    collision='solid' if name in ['tree_oak','tree_pine','tree_birch','boulder','barrel','crate','broken_wall','column'] else 'none'
    modules.append({'id':name,'type':'object','file':f'assets/world/tiles_64/{name}.png','size':[64,64],'anchor':[32,56],'draw_order':10 if 'tree' in name else 5,'collision':collision})

# 128 upscaled exports
for p in sorted((WAS/'tiles_64').glob('*.png')):
    Image.open(p).resize((128,128),Image.Resampling.NEAREST).save(WAS/'tiles_128'/p.name)

# Atlases
def make_atlas(folder,names,path):
    cols=6; rows=math.ceil(len(names)/cols)
    atlas=Image.new('RGBA',(cols*128,rows*128),(0,0,0,0))
    for i,name in enumerate(names):
        im=Image.open(folder/f'{name}.png').resize((128,128),Image.Resampling.NEAREST)
        atlas.paste(im,((i%cols)*128,(i//cols)*128))
    atlas.save(path)
    return {'cols':cols,'tile':128,'order':names}
atlas64=make_atlas(WAS/'tiles_64',ground_names,WAS/'tiles_128'/'ground_atlas_128.png')
atlas_obj=make_atlas(WAS/'tiles_64',object_names,WAS/'tiles_128'/'objects_atlas_128.png')

# Maps
TILE={name:Image.open(WAS/'tiles_64'/f'{name}.png').convert('RGBA') for name in ground_names+object_names}
def put(im,name,x,y): im.paste(TILE[name],(x*T,y*T),TILE[name])

def test_map():
    W,H=1280,720; im=Image.new('RGB',(W,H),WC('grass')); d=ImageDraw.Draw(im)
    # base grass grid
    for y in range(11):
        for x in range(20):
            name='grass_dense' if (x+y)%3 else 'grass_low'
            im.paste(ground_tile(name),(x*T,y*T))
    # path
    for x in range(3,17): put(im,'dirt_h',x,5)
    put(im,'dirt_corner_ne',3,4); put(im,'dirt_v',3,4); put(im,'dirt_v',3,6)
    put(im,'dirt_intersection',10,5)
    # shore/water and dock
    for x in range(0,6):
        for y in range(8,11): put(im,'water_shallow',x,y)
    for x in range(0,6): put(im,'sand' if 'sand' in TILE else 'gravel',x,7)
    for x in range(1,5): put(im,'dock_planks',x,7)
    # forest cluster
    for name,x,y in [('tree_oak',13,1),('tree_pine',15,2),('tree_birch',17,1),('bush',12,3),('flowers',14,4),('fern',16,4),('mushrooms',13,5),('stump',17,5),('roots',18,4),('grass_high',12,2),('grass_high',15,5)]:
        put(im,name,x,y)
    # ruins
    for name,x,y in [('broken_wall',8,2),('column',9,1),('moss_stone',10,3),('rocks',7,3),('signpost',5,4),('barrel',2,6),('crate',1,6),('net',0,6),('rope_fence',4,7),('lantern',5,6)]:
        put(im,name,x,y)
    # soft light on transparent overlay
    light=Image.new('RGBA', im.size, (0,0,0,0)); ld=ImageDraw.Draw(light)
    for _ in range(25):
        x=random.randrange(W); y=random.randrange(H); r=random.randrange(25,70); ld.ellipse((x-r,y-r,x+r,y+r),fill=(244,231,176,22))
    im=Image.alpha_composite(im.convert('RGBA'), light).convert('RGB'); d=ImageDraw.Draw(im)
    # frame
    d.rectangle((0,0,W-1,H-1),outline=WC('wood2'),width=4)
    return im

def arena_map():
    W,H=1280,720; im=Image.new('RGB',(W,H),(31,57,43)); d=ImageDraw.Draw(im)
    # forest floor
    for _ in range(500):
        x=random.randrange(W); y=random.randrange(H); r=random.choice([1,2,3]); d.ellipse((x-r,y-r,x+r,y+r),fill=random.choice([WC('grass2'),WC('grass'),WC('moss')]))
    # arena floor
    d.rounded_rectangle((70,110,W-70,H-80),radius=20,fill=(45,70,52),outline=WC('dirt2'),width=5)
    # cell grids
    cell=118; gap=14
    def grid(x0,y0):
        for r in range(3):
            for c in range(3):
                x=x0+c*(cell+gap); y=y0+r*(cell+gap)
                d.rounded_rectangle((x,y,x+cell,y+cell),radius=10,fill=(62,91,68,190),outline=(215,168,60),width=3)
                d.line((x+10,y+cell-8,x+cell-10,y+cell-8),fill=(0,0,0,80),width=5)
    grid(130,190); grid(W-130-3*(cell+gap)+gap,190)
    # trees around
    for x,y,name in [(35,25,'tree_pine'),(1200,25,'tree_oak'),(35,610,'tree_oak'),(1190,600,'tree_pine'),(250,40,'tree_birch'),(1010,620,'tree_birch')]:
        TILE[name].resize((128,128),Image.Resampling.NEAREST)
        im.paste(TILE[name],(x,y),TILE[name])
    # light shafts and contact shadows on a subtle transparent overlay
    light=Image.new('RGBA', im.size, (0,0,0,0)); ld=ImageDraw.Draw(light)
    for x in [220,640,1030]:
        ld.polygon([(x,0),(x+90,0),(x+30,H),(x-60,H)],fill=(244,231,176,18))
    im=Image.alpha_composite(im.convert('RGBA'), light).convert('RGB')
    return im

test_map().save(WAS/'maps'/'test_area_1280x720.png')
arena_map().save(WAS/'maps'/'forest_arena_1280x720.png')

# lighting layers
light=Image.new('RGBA',(1280,720),(0,0,0,0)); ld=ImageDraw.Draw(light)
for x in [220,640,1030]: ld.polygon([(x,0),(x+90,0),(x+30,720),(x-60,720)],fill=(244,231,176,34))
for _ in range(30):
    x=random.randrange(1280); y=random.randrange(720); r=random.randrange(25,80); ld.ellipse((x-r,y-r,x+r,y+r),fill=(244,231,176,12))
light.save(WAS/'layers'/'forest_light_shafts.png')
shadow=Image.new('RGBA',(1280,720),(0,0,0,0)); sd=ImageDraw.Draw(shadow)
for _ in range(80):
    x=random.randrange(1280); y=random.randrange(500,720); rx=random.randrange(12,35); ry=random.randrange(4,10); sd.ellipse((x-rx,y-ry,x+rx,y+ry),fill=(0,0,0,45))
shadow.save(WAS/'layers'/'contact_shadows.png')

# Docs/source/manifest.
(WAS/'PROVENANCE.md').write_text('''# Происхождение материалов

Все тайлы, объекты, карты, слои света и исходники блока `art/world-tiles` являются оригинальными и сгенерированы программно для Atlantic Online. Сторонние текстуры, тайлсеты и справочные изображения не использовались.
''',encoding='utf-8')
(WDOCS/'WORLD_TILES_SPEC.md').write_text('''# World tiles — спецификация

- Базовый размер тайла: 64×64.
- Дополнительный экспорт: 128×128 целочисленным масштабом ×2 без сглаживания.
- Рекомендуемый фильтр в Godot: Nearest.
- Модули описаны в `assets/world/modules.json`: размер, якорь, порядок отрисовки и коллизия.
- Вода представлена кадрами `water_anim_0..2.png` для короткого цикла.
- Тестовый участок собран из ground/object-тайлов; лесная арена отдельным PNG и слоями света/теней.
''',encoding='utf-8')
# Save source from this cell.
(WAS/'source'/'generate_world_tiles.py').write_text(s_world,encoding='utf-8')
# But _ih[-1] is current patch? It is this cell during execution; in IPython _ih[-1] may be previous? We'll overwrite after execution below if needed.

# modules metadata includes atlases and animation.
modules_meta={'tile_size':64,'export_128':True,'filter':'nearest','atlas_128':{'ground':atlas64,'objects':atlas_obj},'water_animation':{'frames':['water_anim_0','water_anim_1','water_anim_2'],'fps':4,'loop':True},'modules':modules}
(WAS/'modules.json').write_text(json.dumps(modules_meta,ensure_ascii=False,indent=2),encoding='utf-8')

files=[]
for p in sorted(WAS.rglob('*')):
    if p.is_file(): files.append(str(p.relative_to(WROOT)))
manifest=[]
for rel in files:
    p=WROOT/rel; manifest.append({'path':rel,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'size':p.stat().st_size})
(WDOCS/'MANIFEST.json').write_text(json.dumps({'branch':'art/world-tiles','generated':'2026-11-22','files':manifest},ensure_ascii=False,indent=2),encoding='utf-8')
zip_w=Path('/mnt/agents/output/art_world_tiles_repo_ready.zip')
if zip_w.exists(): zip_w.unlink()
with zipfile.ZipFile(zip_w,'w',zipfile.ZIP_DEFLATED) as z:
    for rel in files+['docs/art/world-tiles/MANIFEST.json']:
        z.write(WROOT/rel,arcname=rel)
print('world zip', zip_w, zip_w.stat().st_size, 'files', len(files))