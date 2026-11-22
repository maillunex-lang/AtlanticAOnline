from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
import json, hashlib, zipfile, shutil, math, os

STATIC = Path('/mnt/agents/output/atlantic_heroes')
OUT = Path('/mnt/agents/output/atlantic_hero_animations')
if OUT.exists():
    shutil.rmtree(OUT)
for d in ['warden','sharpshooter','magus','projectiles','source']:
    (OUT/d).mkdir(parents=True, exist_ok=True)

PAL = {
    'outline': '#17141f', 'shade': '#2b2433', 'skin': '#d9a066', 'skin_shade': '#a66a3f',
    'hair': '#4a2e1f', 'steel': '#8b98a8', 'steel_dark': '#56606e', 'steel_light': '#c7d0d8',
    'ochre': '#c47a2b', 'ochre_dark': '#7a4317', 'ochre_light': '#e0a24a',
    'green': '#2f7a4a', 'green_dark': '#173d28', 'green_light': '#5aa36d',
    'turquoise': '#35b8b2', 'turquoise_dark': '#17746f', 'turquoise_light': '#8be3dc',
    'robe': '#4b3f63', 'robe_dark': '#2b2540', 'boot': '#26202c', 'eye': '#1b1620',
    'wood': '#7a4a26', 'wood_dark': '#452715', 'string': '#d7d1b8', 'flash': '#f1e7c8'
}
def C(name): return tuple(int(PAL[name][i:i+2],16) for i in (1,3,5)) + (255,)
def canvas(): return Image.new('RGBA',(16,16),(0,0,0,0))
def px(im,x,y,c):
    if 0 <= x < 16 and 0 <= y < 16: im.putpixel((x,y), C(c) if isinstance(c,str) else c)
def rect(im,x0,y0,x1,y1,c):
    for y in range(y0,y1+1):
        for x in range(x0,x1+1): px(im,x,y,c)
def hline(im,x0,x1,y,c):
    for x in range(x0,x1+1): px(im,x,y,c)
def vline(im,x,y0,y1,c):
    for y in range(y0,y1+1): px(im,x,y,c)
def line(im,x0,y0,x1,y1,c):
    dx=abs(x1-x0); dy=-abs(y1-y0); sx=1 if x0<x1 else -1; sy=1 if y0<y1 else -1
    err=dx+dy; x,y=x0,y0
    while True:
        px(im,x,y,c)
        if x==x1 and y==y1: break
        e2=2*err
        if e2>=dy: err+=dy; x+=sx
        if e2<=dx: err+=dx; y+=sy
def clear_rect(im,x0,y0,x1,y1):
    for y in range(max(0,y0), min(15,y1)+1):
        for x in range(max(0,x0), min(15,x1)+1): im.putpixel((x,y),(0,0,0,0))
def shift(im,dx=0,dy=0):
    out=canvas()
    for y in range(16):
        for x in range(16):
            r,g,b,a=im.getpixel((x,y))
            if a:
                nx,ny=x+dx,y+dy
                if 0<=nx<16 and 0<=ny<16: out.putpixel((nx,ny),(r,g,b,a))
    return out
def mirror(im): return im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
def squash(base, scale=1.0, dx=0):
    out=canvas()
    for y in range(16):
        for x in range(16):
            r,g,b,a=base.getpixel((x,y))
            if a:
                nx=x+dx
                ny=15 - int(round((15-y)*scale))
                if 0<=nx<16 and 0<=ny<16: out.putpixel((nx,ny),(r,g,b,a))
    return out
def flash(im, pts, color='flash'):
    for x,y in pts: px(im,x,y,color)
    return im

BASE = {h:{d:Image.open(STATIC/h/f'idle_{d}.png').convert('RGBA') for d in ['south','north','east','west']} for h in ['warden','sharpshooter','magus']}
HEROES = [('warden','Страж'),('sharpshooter','Стрелок'),('magus','Маг')]
DIRS4 = [('south','Юг'),('north','Север'),('east','Восток'),('west','Запад')]
SIDES = [('east','Восток'),('west','Запад')]

CLIP_SPECS = [
    ('idle', DIRS4, 4, 4, True),
    ('walk', DIRS4, 6, 8, True),
    ('attack', SIDES, 6, 12, False),
    ('skill', SIDES, 6, 10, False),
    ('hit', SIDES, 3, 10, False),
    ('down', SIDES, 5, 8, False),
    ('guard', SIDES, 3, 8, False),
]

# Generic non-directional motion helpers.
def idle_frames(hero, direction):
    base=BASE[hero][direction]
    dys=[0,-1,0,0]
    sparks={
      'warden': {'south':[(13,6)], 'north':[(13,6)], 'east':[(14,8)], 'west':[(1,8)]},
      'sharpshooter': {'south':[(2,4)], 'north':[(2,4)], 'east':[(13,4)], 'west':[(2,4)]},
      'magus': {'south':[(13,2)], 'north':[(13,2)], 'east':[(14,2)], 'west':[(1,2)]},
    }[hero][direction]
    frames=[]
    for i,dy in enumerate(dys):
        f=shift(base,0,dy)
        if i==1: flash(f,sparks,'steel_light' if hero=='warden' else ('green_light' if hero=='sharpshooter' else 'turquoise_light'))
        frames.append(f)
    return frames

def clear_legs(im, hero, direction):
    clear_rect(im,4,12,12,15)
    return im

def draw_legs(im, hero, direction, phase):
    pants,boot={
        'warden':('steel_dark','boot'),
        'sharpshooter':('green_dark','boot'),
        'magus':('robe_dark','boot')
    }[hero]
    if direction in ('south','north'):
        pattern=[(-1,1),(0,0),(1,-1),(0,0),(-1,1),(0,0)]
        ldx,rdx=pattern[phase]
        rect(im,6+ldx,12,7+ldx,13,pants); rect(im,9+rdx,12,10+rdx,13,pants)
        rect(im,6+ldx,14,7+ldx,15,boot); rect(im,9+rdx,14,10+rdx,15,boot)
    else:
        pattern=[1,-1,-1,0,1,0]
        dx=pattern[phase]
        rect(im,6+dx,12,7+dx,13,pants); rect(im,9-dx,12,10-dx,13,pants)
        rect(im,6+dx,14,7+dx,15,boot); rect(im,9-dx,14,10-dx,15,boot)
    if hero=='magus':
        px(im,5,12,'robe_dark'); px(im,11,12,'robe_dark'); px(im,5,13,'robe'); px(im,11,13,'robe')
    return im

def walk_frames(hero, direction):
    frames=[]
    for phase in range(6):
        f=BASE[hero][direction].copy()
        clear_legs(f,hero,direction)
        draw_legs(f,hero,direction,phase)
        if phase in (1,4) and direction in ('south','north'):
            upper=canvas()
            for yy in range(0,12):
                for xx in range(16):
                    p=f.getpixel((xx,yy))
                    if p[3]: upper.putpixel((xx,yy),p)
            upper=shift(upper,0,-1)
            for yy in range(0,12):
                for xx in range(16): f.putpixel((xx,yy),(0,0,0,0))
            f.alpha_composite(upper)
        frames.append(f)
    return frames

# Warden side-action poses.
def redraw_warden_arm(f):
    rect(f,10,8,11,10,'skin'); px(f,11,10,'skin_shade')
    return f

def warden_attack_east():
    frames=[]
    for phase in range(6):
        f=BASE['warden']['east'].copy()
        if phase==0:
            frames.append(f); continue
        clear_rect(f,8,7,15,12); redraw_warden_arm(f)
        if phase==1: # wind-up, blade back
            hline(f,9,11,9,'wood'); px(f,8,9,'wood_dark')
            line(f,8,10,6,12,'steel'); line(f,8,11,6,13,'steel_dark'); px(f,6,12,'steel_light')
        elif phase==2: # ready thrust
            hline(f,10,11,9,'wood'); hline(f,12,14,9,'steel'); px(f,14,9,'steel_light'); px(f,13,10,'steel_dark')
        elif phase==3: # strike event
            hline(f,10,11,9,'wood'); hline(f,11,15,9,'steel'); px(f,15,9,'steel_light'); px(f,14,10,'steel_dark')
        elif phase==4: # follow-through
            hline(f,10,11,9,'wood'); hline(f,12,14,10,'steel'); px(f,14,10,'steel_light'); px(f,13,11,'steel_dark')
        else:
            hline(f,10,11,9,'wood'); hline(f,12,14,9,'steel'); px(f,14,9,'steel_light')
        frames.append(f)
    return frames

def warden_skill_east():
    frames=[]
    for phase in range(6):
        f=BASE['warden']['east'].copy()
        if phase==0:
            frames.append(f); continue
        clear_rect(f,8,6,15,14); redraw_warden_arm(f)
        if phase in (1,2,3):
            px(f,10,10,'wood'); vline(f,10,6,9,'steel'); vline(f,9,7,9,'steel_dark'); px(f,10,6,'steel_light')
        if phase==3:
            flash(f,[(9,5),(11,5),(10,4),(10,6)],'ochre_light'); px(f,12,6,'ochre_light')
        if phase==4:
            hline(f,10,11,9,'wood'); hline(f,11,13,8,'steel'); px(f,13,8,'steel_light')
        if phase==5:
            hline(f,10,11,9,'wood'); hline(f,12,14,9,'steel')
        frames.append(f)
    return frames

def warden_guard_east():
    frames=[]
    for phase in range(3):
        f=BASE['warden']['east'].copy()
        if phase==0:
            frames.append(f); continue
        clear_rect(f,8,6,15,14); redraw_warden_arm(f)
        px(f,11,10,'wood'); vline(f,12,7,12,'steel'); vline(f,13,8,12,'steel_dark'); px(f,12,7,'steel_light')
        if phase==2:
            px(f,11,9,'ochre_light'); px(f,12,6,'steel_light')
        frames.append(f)
    return frames

def warden_hit_east():
    b=BASE['warden']['east']
    f1=shift(b,-1,0); flash(f1,[(7,3),(10,3),(8,6),(11,8)],'ochre_light')
    f2=shift(b,-2,0); flash(f2,[(6,4),(9,4),(10,7)],'steel_light')
    return [b,f1,f2]

def warden_down_east():
    b=BASE['warden']['east']
    scales=[1.0,0.88,0.75,0.60,0.48]; dxs=[0,0,1,2,3]
    return [squash(b,scales[i],dxs[i]) for i in range(5)]

# Sharpshooter side-action poses.
def redraw_sharpshooter_arm(f):
    rect(f,10,8,11,10,'skin'); px(f,11,9,'skin_shade')
    return f

def draw_bow(f, x=13, y0=5, y1=11, string_x=12, dark=True):
    vline(f,x,y0,y1,'wood')
    px(f,x-1,y0-1,'wood'); px(f,x-1,y1+1,'wood')
    if dark:
        px(f,x-1,y0+1,'wood_dark'); px(f,x-1,y1-1,'wood_dark')
    vline(f,string_x,y0,y1,'string')

def sharpshooter_attack_east():
    frames=[]
    for phase in range(6):
        f=BASE['sharpshooter']['east'].copy()
        if phase==0:
            frames.append(f); continue
        clear_rect(f,9,3,15,13); redraw_sharpshooter_arm(f)
        if phase in (1,2):
            draw_bow(f,13,5,11,11 if phase==1 else 10)
            hline(f,10,13 if phase==2 else 12,9,'string')
            px(f,13 if phase==2 else 12,9,'steel_light'); px(f,12,10,'wood_dark')
        elif phase==3:
            draw_bow(f,13,5,11,12)
            hline(f,10,15,9,'string'); px(f,15,9,'steel_light'); px(f,14,10,'wood_dark')
        elif phase==4:
            draw_bow(f,13,5,11,12)
        else:
            draw_bow(f,13,5,11,12)
        frames.append(f)
    return frames

def sharpshooter_skill_east():
    frames=[]
    for phase in range(6):
        f=BASE['sharpshooter']['east'].copy()
        if phase==0:
            frames.append(f); continue
        clear_rect(f,8,2,15,14); redraw_sharpshooter_arm(f)
        # lifted diagonal bow
        line(f,13,3,10,11,'wood'); line(f,12,4,9,11,'string')
        px(f,13,3,'wood_dark'); px(f,9,11,'wood_dark')
        if phase in (1,2):
            vline(f,11,6,9,'string')
        if phase==3:
            # volley event: three upward tracer pixels
            px(f,11,4,'string'); px(f,12,3,'steel_light'); px(f,13,4,'string'); px(f,14,3,'green_light')
        if phase==4:
            px(f,12,5,'string'); px(f,13,4,'green_light')
        if phase==5:
            draw_bow(f,13,5,11,12)
        frames.append(f)
    return frames

def sharpshooter_guard_east():
    frames=[]
    for phase in range(3):
        f=BASE['sharpshooter']['east'].copy()
        if phase==0:
            frames.append(f); continue
        clear_rect(f,8,4,15,13); redraw_sharpshooter_arm(f)
        draw_bow(f,12,5,11,11)
        px(f,11,6,'green_light'); px(f,11,10,'green_light')
        if phase==2: px(f,13,5,'green_light')
        frames.append(f)
    return frames

def sharpshooter_hit_east():
    b=BASE['sharpshooter']['east']
    f1=shift(b,-1,0); flash(f1,[(7,3),(10,3),(8,6),(11,8)],'green_light')
    f2=shift(b,-2,0); flash(f2,[(6,4),(9,4),(10,7)],'string')
    return [b,f1,f2]

def sharpshooter_down_east():
    b=BASE['sharpshooter']['east']
    scales=[1.0,0.88,0.75,0.60,0.48]; dxs=[0,0,1,2,3]
    return [squash(b,scales[i],dxs[i]) for i in range(5)]

# Magus side-action poses.
def redraw_magus_arm(f):
    rect(f,10,8,11,10,'robe'); px(f,11,9,'skin')
    return f

def draw_staff(f, x0,y0,x1,y1, crystal=(13,3)):
    line(f,x0,y0,x1,y1,'wood'); px(f,x0,y0,'wood_dark')
    cx,cy=crystal
    px(f,cx,cy,'turquoise'); px(f,cx-1,cy,'turquoise_light'); px(f,cx+1,cy,'turquoise_light'); px(f,cx,cy+1,'turquoise_dark')

def magus_attack_east():
    frames=[]
    for phase in range(6):
        f=BASE['magus']['east'].copy()
        if phase==0:
            frames.append(f); continue
        clear_rect(f,10,2,15,14); redraw_magus_arm(f)
        if phase==1:
            line(f,10,9,13,8,'wood'); px(f,10,9,'wood_dark'); draw_staff(f,10,9,13,8,(14,7))
        elif phase==2:
            line(f,10,9,12,8,'wood'); draw_staff(f,10,9,12,8,(13,7)); px(f,14,8,'turquoise_dark')
        elif phase==3:
            line(f,10,9,13,9,'wood'); px(f,13,9,'turquoise'); hline(f,14,15,9,'turquoise_light'); px(f,15,8,'turquoise'); px(f,14,10,'turquoise_dark')
        elif phase==4:
            line(f,10,9,12,9,'wood'); draw_staff(f,10,9,12,9,(13,8)); px(f,14,9,'turquoise_dark')
        else:
            line(f,10,9,13,9,'wood'); draw_staff(f,10,9,13,9,(14,8))
        frames.append(f)
    return frames

def magus_skill_east():
    frames=[]
    for phase in range(6):
        f=BASE['magus']['east'].copy()
        if phase==0:
            frames.append(f); continue
        clear_rect(f,9,2,15,14); redraw_magus_arm(f)
        if phase in (1,2,3):
            line(f,10,9,11,5,'wood'); draw_staff(f,10,9,11,5,(11,4))
        if phase==3:
            # activation event: staff nova cross
            px(f,11,2,'turquoise_light'); px(f,10,3,'turquoise'); px(f,12,3,'turquoise'); px(f,11,4,'turquoise_dark'); px(f,9,4,'turquoise_light'); px(f,13,4,'turquoise_light')
        if phase in (4,5):
            line(f,10,9,12,7,'wood'); draw_staff(f,10,9,12,7,(13,6)); px(f,12,8,'turquoise_light')
        frames.append(f)
    return frames

def magus_guard_east():
    frames=[]
    for phase in range(3):
        f=BASE['magus']['east'].copy()
        if phase==0:
            frames.append(f); continue
        clear_rect(f,9,2,15,14); redraw_magus_arm(f)
        line(f,9,10,13,6,'wood'); draw_staff(f,9,10,13,6,(13,5))
        px(f,12,8,'turquoise'); px(f,12,9,'turquoise_dark')
        if phase==2: px(f,13,7,'turquoise_light')
        frames.append(f)
    return frames

def magus_hit_east():
    b=BASE['magus']['east']
    f1=shift(b,-1,0); flash(f1,[(7,4),(10,4),(8,7),(11,9)],'turquoise_light')
    f2=shift(b,-2,0); flash(f2,[(6,5),(9,5),(10,8)],'robe')
    return [b,f1,f2]

def magus_down_east():
    b=BASE['magus']['east']
    scales=[1.0,0.88,0.75,0.60,0.48]; dxs=[0,0,1,2,3]
    return [squash(b,scales[i],dxs[i]) for i in range(5)]

SIDE_EAST_GENERATORS={
    'warden': {'attack':warden_attack_east,'skill':warden_skill_east,'hit':warden_hit_east,'down':warden_down_east,'guard':warden_guard_east},
    'sharpshooter': {'attack':sharpshooter_attack_east,'skill':sharpshooter_skill_east,'hit':sharpshooter_hit_east,'down':sharpshooter_down_east,'guard':sharpshooter_guard_east},
    'magus': {'attack':magus_attack_east,'skill':magus_skill_east,'hit':magus_hit_east,'down':magus_down_east,'guard':magus_guard_east},
}

def make_clip_frames(hero, clip, direction, count):
    if clip=='idle': return idle_frames(hero,direction)
    if clip=='walk': return walk_frames(hero,direction)
    east= SIDE_EAST_GENERATORS[hero][clip]()
    return east if direction=='east' else [mirror(f) for f in east]

def event_for(hero, clip):
    if clip=='attack':
        return {'frame':3,'type':{'warden':'sword_hit','sharpshooter':'arrow_release','magus':'staff_bolt'}[hero]}
    if clip=='skill':
        return {'frame':3,'type':{'warden':'rally_flash','sharpshooter':'volley_release','magus':'staff_nova'}[hero]}
    return None

# Generate frames, atlases and JSON metadata.
all_metadata={}
for hero, hero_name in HEROES:
    clip_entries=[]
    rows=[]
    max_frames=max(len(dirs)*0 + n for _,_,n,_,_ in CLIP_SPECS) if False else max(n for _,_,n,_,_ in CLIP_SPECS)
    row_count=sum(len(dirs) for _,dirs,_,_,_ in CLIP_SPECS)
    atlas=Image.new('RGBA',(max_frames*16,row_count*16),(0,0,0,0))
    y=0
    for clip, dirs, nframes, fps, loop in CLIP_SPECS:
        for direction, dir_name in dirs:
            frames=make_clip_frames(hero,clip,direction,nframes)
            assert len(frames)==nframes, (hero,clip,direction,len(frames),nframes)
            rects=[]
            for i,f in enumerate(frames):
                atlas.paste(f,(i*16,y))
                rects.append({'index':i,'x':i*16,'y':y,'w':16,'h':16})
            entry={'animation':clip,'direction':direction,'fps':fps,'loop':loop,'anchor':[8,15],'frames':rects,'events':[]}
            ev=event_for(hero,clip)
            if ev: entry['events']=[ev]
            if clip in ('down','guard'): entry['hold_last']=True
            clip_entries.append(entry)
            rows.append({'animation':clip,'direction':direction,'row':y//16,'frames':nframes})
            y+=16
    atlas_path=OUT/hero/f'{hero}_atlas.png'
    atlas.save(atlas_path)
    meta={
        'hero':hero,
        'name_ru':hero_name,
        'image':f'{hero}/{hero}_atlas.png',
        'frame_size':[16,16],
        'anchor':[8,15],
        'row_order':rows,
        'clips':clip_entries,
        'target':'Godot 4.7.2',
        'source_static':'../atlantic_heroes/{hero}/idle_{direction}.png'
    }
    (OUT/hero/f'{hero}.animation.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2),encoding='utf-8')
    all_metadata[hero]=meta
print('generated heroes', {h:len(all_metadata[h]['clips']) for h in all_metadata})