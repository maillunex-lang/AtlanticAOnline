from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
import os, json, math, shutil, zipfile, textwrap

OUT = Path('/mnt/agents/output/atlantic_heroes')
if OUT.exists():
    shutil.rmtree(OUT)
for d in ['warden','sharpshooter','magus']:
    (OUT/d).mkdir(parents=True, exist_ok=True)
(OUT/'source').mkdir(exist_ok=True)

# Palette: original, no borrowed pixels/assets.
PAL = {
    'outline': '#17141f',
    'shade': '#2b2433',
    'skin': '#d9a066',
    'skin_shade': '#a66a3f',
    'hair': '#4a2e1f',
    'steel': '#8b98a8',
    'steel_dark': '#56606e',
    'steel_light': '#c7d0d8',
    'ochre': '#c47a2b',
    'ochre_dark': '#7a4317',
    'ochre_light': '#e0a24a',
    'green': '#2f7a4a',
    'green_dark': '#173d28',
    'green_light': '#5aa36d',
    'turquoise': '#35b8b2',
    'turquoise_dark': '#17746f',
    'turquoise_light': '#8be3dc',
    'robe': '#4b3f63',
    'robe_dark': '#2b2540',
    'boot': '#26202c',
    'eye': '#1b1620',
    'wood': '#7a4a26',
    'wood_dark': '#452715',
    'string': '#d7d1b8',
}

def C(name):
    return tuple(int(PAL[name][i:i+2],16) for i in (1,3,5)) + (255,)

def canvas():
    return Image.new('RGBA',(16,16),(0,0,0,0))

def px(im,x,y,c):
    if 0 <= x < 16 and 0 <= y < 16:
        im.putpixel((x,y), C(c) if isinstance(c,str) else c)

def rect(im,x0,y0,x1,y1,c):
    for y in range(y0,y1+1):
        for x in range(x0,x1+1):
            px(im,x,y,c)

def hline(im,x0,x1,y,c):
    for x in range(x0,x1+1): px(im,x,y,c)

def vline(im,x,y0,y1,c):
    for y in range(y0,y1+1): px(im,x,y,c)

def line(im,x0,y0,x1,y1,c):
    dx=abs(x1-x0); dy=-abs(y1-y0)
    sx=1 if x0<x1 else -1
    sy=1 if y0<y1 else -1
    err=dx+dy
    x,y=x0,y0
    while True:
        px(im,x,y,c)
        if x==x1 and y==y1: break
        e2=2*err
        if e2>=dy:
            err+=dy; x+=sx
        if e2<=dx:
            err+=dx; y+=sy

def outline_sprite(im):
    # add dark outline to opaque non-outline pixels adjacent to transparency
    src=im.load(); out=im.copy(); dst=out.load()
    for y in range(16):
        for x in range(16):
            if src[x,y][3]==0:
                found=False
                for nx,ny in ((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
                    if 0<=nx<16 and 0<=ny<16 and src[nx,ny][3]:
                        found=True; break
                if found: dst[x,y]=C('outline')
    return out

def mirror(im):
    return im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)

# ---------- Warden ----------
def warden_south():
    im=canvas(); g='green' # unused
    # sword behind/right
    vline(im,13,8,13,'steel'); vline(im,12,8,13,'steel_dark'); px(im,13,7,'steel_light'); px(im,12,7,'steel_dark')
    hline(im,11,13,8,'wood'); px(im,11,7,'wood_dark')
    # boots/legs
    rect(im,6,13,7,15,'boot'); rect(im,9,13,10,15,'boot')
    rect(im,6,11,10,12,'steel_dark'); hline(im,6,10,11,'ochre_dark')
    # torso, broad
    rect(im,5,7,11,11,'steel'); rect(im,5,7,11,7,'steel_light'); rect(im,5,8,5,11,'steel_dark'); rect(im,11,8,11,11,'steel_dark')
    rect(im,7,8,9,10,'steel_light'); hline(im,5,11,11,'ochre_dark')
    # round left pauldron / accent
    rect(im,3,7,4,9,'ochre'); px(im,3,6,'ochre_light'); px(im,4,6,'ochre_light'); px(im,4,10,'ochre_dark'); px(im,3,10,'ochre_dark')
    # right arm
    rect(im,11,8,12,11,'skin'); px(im,12,11,'skin_shade')
    # head
    rect(im,6,3,10,6,'skin'); rect(im,6,3,10,4,'hair'); px(im,7,5,'eye'); px(im,9,5,'eye'); px(im,8,6,'skin_shade')
    # helmet brim / guard
    hline(im,5,11,3,'steel_dark'); hline(im,6,10,4,'steel')
    return outline_sprite(im)

def warden_north():
    im=canvas()
    # sword visible right side, pointing down
    vline(im,13,8,13,'steel'); vline(im,12,8,13,'steel_dark'); hline(im,11,13,8,'wood'); px(im,12,7,'steel_dark'); px(im,13,7,'steel_light')
    rect(im,6,13,7,15,'boot'); rect(im,9,13,10,15,'boot')
    rect(im,5,7,11,12,'steel'); hline(im,5,11,11,'ochre_dark'); rect(im,5,7,11,7,'steel_light'); rect(im,5,8,5,12,'steel_dark'); rect(im,11,8,11,12,'steel_dark')
    rect(im,3,7,4,9,'ochre'); px(im,3,6,'ochre_light'); px(im,4,6,'ochre_light'); px(im,4,10,'ochre_dark')
    # helmet/back head
    rect(im,6,3,10,6,'steel'); rect(im,6,3,10,4,'steel_light'); hline(im,5,11,3,'steel_dark'); rect(im,7,5,9,6,'steel_dark')
    # cape/back accent
    rect(im,6,8,10,10,'ochre_dark'); px(im,7,8,'ochre'); px(im,9,8,'ochre')
    return outline_sprite(im)

def warden_east():
    im=canvas()
    # body profile
    rect(im,5,13,7,15,'boot'); rect(im,8,13,9,15,'boot')
    rect(im,5,8,10,12,'steel'); hline(im,5,10,11,'ochre_dark'); rect(im,5,8,10,8,'steel_light'); rect(im,5,9,5,12,'steel_dark')
    # face/head profile
    rect(im,7,3,10,6,'skin'); rect(im,7,3,10,4,'hair'); px(im,10,5,'eye'); px(im,9,6,'skin_shade'); rect(im,7,6,10,6,'skin_shade')
    # pauldron toward viewer
    rect(im,4,7,5,9,'ochre'); px(im,4,6,'ochre_light'); px(im,5,6,'ochre_light'); px(im,5,10,'ochre_dark')
    # arm and sword forward
    rect(im,10,8,11,10,'skin'); px(im,11,10,'skin_shade')
    hline(im,10,14,9,'steel'); hline(im,12,14,10,'steel_dark'); px(im,14,9,'steel_light')
    hline(im,9,11,8,'wood'); px(im,8,8,'wood_dark')
    return outline_sprite(im)

def warden_west(): return mirror(warden_east())

# ---------- Sharpshooter ----------
def sharpshooter_south():
    im=canvas()
    # bow on left: vertical arc and string
    vline(im,2,5,11,'wood'); px(im,3,4,'wood'); px(im,3,12,'wood'); px(im,3,6,'wood_dark'); px(im,3,10,'wood_dark')
    vline(im,4,5,11,'string')
    # boots and slim legs
    rect(im,6,13,7,15,'boot'); rect(im,9,13,10,15,'boot')
    rect(im,6,11,10,12,'green_dark')
    # cloak/tunic
    rect(im,5,7,11,11,'green'); rect(im,5,7,11,7,'green_light'); rect(im,5,8,5,11,'green_dark'); rect(im,11,8,11,11,'green_dark')
    hline(im,6,10,11,'green_dark'); px(im,8,8,'green_light'); px(im,8,9,'green_dark')
    # quiver on right/back
    rect(im,12,6,13,10,'wood'); px(im,12,5,'wood_dark'); px(im,13,5,'string')
    # head/hood
    rect(im,6,3,10,6,'skin'); rect(im,6,3,10,5,'green'); px(im,7,6,'eye'); px(im,9,6,'eye'); px(im,8,7,'skin_shade')
    px(im,5,4,'green_dark'); px(im,11,4,'green_dark'); px(im,5,5,'green_dark'); px(im,11,5,'green_dark')
    # right arm holding bow hand at left
    rect(im,4,8,5,10,'skin'); px(im,3,9,'skin')
    return outline_sprite(im)

def sharpshooter_north():
    im=canvas()
    # bow left
    vline(im,2,5,11,'wood'); px(im,3,4,'wood'); px(im,3,12,'wood'); px(im,3,6,'wood_dark'); px(im,3,10,'wood_dark'); vline(im,4,5,11,'string')
    rect(im,6,13,7,15,'boot'); rect(im,9,13,10,15,'boot')
    rect(im,5,7,11,11,'green'); rect(im,5,7,11,7,'green_light'); rect(im,5,8,5,11,'green_dark'); rect(im,11,8,11,11,'green_dark')
    hline(im,6,10,11,'green_dark')
    # quiver
    rect(im,12,6,13,10,'wood'); px(im,12,5,'wood_dark'); px(im,13,5,'string')
    # hood back
    rect(im,6,3,10,6,'green'); rect(im,6,3,10,4,'green_light'); rect(im,7,5,9,6,'green_dark'); px(im,5,4,'green_dark'); px(im,11,4,'green_dark')
    rect(im,6,8,10,10,'green_dark'); px(im,7,8,'green'); px(im,9,8,'green')
    rect(im,4,8,5,10,'skin')
    return outline_sprite(im)

def sharpshooter_east():
    im=canvas()
    # body profile
    rect(im,5,13,7,15,'boot'); rect(im,8,13,9,15,'boot')
    rect(im,5,7,10,12,'green'); rect(im,5,7,10,7,'green_light'); rect(im,5,8,5,12,'green_dark'); hline(im,5,10,11,'green_dark')
    # head profile/hood
    rect(im,7,3,10,6,'skin'); rect(im,7,3,10,5,'green'); px(im,10,6,'eye'); px(im,9,7,'skin_shade'); px(im,6,4,'green_dark'); px(im,11,4,'green_dark')
    # quiver back
    rect(im,4,6,5,10,'wood'); px(im,4,5,'wood_dark'); px(im,5,5,'string')
    # arm and bow forward
    rect(im,10,8,11,10,'skin'); px(im,11,9,'skin_shade')
    vline(im,13,5,11,'wood'); px(im,12,4,'wood'); px(im,12,12,'wood'); px(im,12,6,'wood_dark'); px(im,12,10,'wood_dark')
    vline(im,12,5,11,'string')
    return outline_sprite(im)

def sharpshooter_west(): return mirror(sharpshooter_east())

# ---------- Magus ----------
def magus_south():
    im=canvas()
    # staff right with turquoise crystal
    vline(im,13,5,13,'wood'); hline(im,12,14,6,'wood_dark'); px(im,13,4,'turquoise_dark')
    px(im,13,3,'turquoise'); px(im,12,3,'turquoise_light'); px(im,14,3,'turquoise_light'); px(im,13,2,'turquoise_light')
    # boots under robe
    rect(im,6,13,7,15,'boot'); rect(im,9,13,10,15,'boot')
    # wide robe
    rect(im,5,7,11,12,'robe'); rect(im,4,11,12,12,'robe_dark'); rect(im,5,7,11,7,'robe_dark'); rect(im,5,8,5,12,'robe_dark'); rect(im,11,8,11,12,'robe_dark')
    # turquoise clasp/accent
    px(im,8,8,'turquoise'); px(im,8,9,'turquoise_dark'); px(im,7,8,'turquoise_light')
    # sleeves/arms
    rect(im,4,8,5,10,'robe'); rect(im,11,8,12,10,'robe'); px(im,12,9,'skin')
    # head + pointed hat
    rect(im,6,4,10,7,'skin'); px(im,7,6,'eye'); px(im,9,6,'eye'); px(im,8,7,'skin_shade')
    hline(im,5,11,4,'robe_dark'); rect(im,7,2,9,3,'robe'); px(im,8,1,'robe'); px(im,8,4,'robe_dark')
    return outline_sprite(im)

def magus_north():
    im=canvas()
    # staff right
    vline(im,13,5,13,'wood'); hline(im,12,14,6,'wood_dark'); px(im,13,4,'turquoise_dark')
    px(im,13,3,'turquoise'); px(im,12,3,'turquoise_light'); px(im,14,3,'turquoise_light'); px(im,13,2,'turquoise_light')
    rect(im,6,13,7,15,'boot'); rect(im,9,13,10,15,'boot')
    rect(im,5,7,11,12,'robe'); rect(im,4,11,12,12,'robe_dark'); rect(im,5,7,11,7,'robe_dark'); rect(im,5,8,5,12,'robe_dark'); rect(im,11,8,11,12,'robe_dark')
    px(im,8,8,'turquoise'); px(im,8,9,'turquoise_dark')
    rect(im,4,8,5,10,'robe'); rect(im,11,8,12,10,'robe'); px(im,12,9,'skin')
    # back head + hat
    rect(im,6,4,10,7,'robe_dark'); hline(im,5,11,4,'robe_dark'); rect(im,7,2,9,3,'robe'); px(im,8,1,'robe'); px(im,8,5,'robe')
    return outline_sprite(im)

def magus_east():
    im=canvas()
    # robe profile
    rect(im,5,13,7,15,'boot'); rect(im,8,13,9,15,'boot')
    rect(im,4,7,10,12,'robe'); rect(im,3,11,10,12,'robe_dark'); rect(im,4,7,10,7,'robe_dark'); rect(im,4,8,4,12,'robe_dark')
    px(im,7,8,'turquoise'); px(im,7,9,'turquoise_dark')
    # head profile/hat
    rect(im,7,4,10,7,'skin'); px(im,10,6,'eye'); px(im,9,7,'skin_shade'); hline(im,6,11,4,'robe_dark'); rect(im,8,2,9,3,'robe'); px(im,8,1,'robe')
    # arm forward and staff ahead
    rect(im,10,8,11,10,'robe'); px(im,11,9,'skin')
    vline(im,13,5,13,'wood'); hline(im,12,14,6,'wood_dark'); px(im,13,4,'turquoise_dark')
    px(im,13,3,'turquoise'); px(im,12,3,'turquoise_light'); px(im,14,3,'turquoise_light'); px(im,13,2,'turquoise_light')
    return outline_sprite(im)

def magus_west(): return mirror(magus_east())

sprites = {
 'warden': {'south':warden_south(), 'north':warden_north(), 'east':warden_east(), 'west':warden_west()},
 'sharpshooter': {'south':sharpshooter_south(), 'north':sharpshooter_north(), 'east':sharpshooter_east(), 'west':sharpshooter_west()},
 'magus': {'south':magus_south(), 'north':magus_north(), 'east':magus_east(), 'west':magus_west()},
}
for hero, dirs in sprites.items():
    for dirn, img in dirs.items():
        assert img.size == (16,16)
        img.save(OUT/hero/f'idle_{dirn}.png')
print('saved sprites', len(list(OUT.glob('*/*.png'))))