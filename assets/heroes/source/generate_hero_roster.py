from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
import json, hashlib, zipfile, shutil, math, os, random

# -----------------------------
# Hero roster: 10 new classes
# -----------------------------
ROOT = Path('/mnt/agents/output/repo_ready_branches/art/hero-roster')
if ROOT.exists(): shutil.rmtree(ROOT)
ASSETS = ROOT/'assets'/'heroes'
DOCS = ROOT/'docs'/'art'/'hero-roster'
for p in [ASSETS, DOCS, ASSETS/'source', ASSETS/'previews', ASSETS/'projectiles']:
    p.mkdir(parents=True, exist_ok=True)

S=32
EXPORT=4
FS=S*EXPORT

PAL={
 'outline':'#171722','shade':'#292a38','skin':'#d7a173','skin2':'#a96f4b','hair':'#3b2a24','eye':'#171722',
 'steel':'#8fa0b4','steel2':'#56657a','steel3':'#c7d3e2','gold':'#d7a83c','gold2':'#8a611b','gold3':'#f1d071',
 'leather':'#6e4630','leather2':'#3d2418','cloth':'#34445f','cloth2':'#1e283c','boot':'#25222b','white':'#e9edf3',
 'red':'#a8493f','red2':'#5f252b','blue':'#3f6fa8','blue2':'#20395f','green':'#3f7d52','green2':'#1d3b2a','cyan':'#4cb7ad','cyan2':'#1e6a68','purple':'#7560a8','purple2':'#392d5b','orange':'#c77735','orange2':'#6d3c1c','water':'#4f9fc6','water2':'#225d7a','wood':'#7b4b2d','wood2':'#432a1b','sand':'#c9a96b','sand2':'#7e6840','black':'#101018','bone':'#d8d0bd','bone2':'#8e846f'
}
def C(n): return tuple(int(PAL[n][i:i+2],16) for i in (1,3,5))+(255,)
def canvas(): return Image.new('RGBA',(S,S),(0,0,0,0))
def px(im,x,y,c):
    if 0<=x<S and 0<=y<S: im.putpixel((x,y), C(c) if isinstance(c,str) else c)
def rect(im,x0,y0,x1,y1,c):
    for y in range(max(0,y0),min(S-1,y1)+1):
        for x in range(max(0,x0),min(S-1,x1)+1): px(im,x,y,c)
def hline(im,x0,x1,y,c):
    for x in range(x0,x1+1): px(im,x,y,c)
def vline(im,x,y0,y1,c):
    for y in range(y0,y1+1): px(im,x,y,c)
def line(im,x0,y0,x1,y1,c):
    dx=abs(x1-x0); dy=-abs(y1-y0); sx=1 if x0<x1 else -1; sy=1 if y0<y1 else -1; err=dx+dy; x=x0; y=y0
    while True:
        px(im,x,y,c)
        if x==x1 and y==y1: break
        e2=2*err
        if e2>=dy: err+=dy; x+=sx
        if e2<=dx: err+=dx; y+=sy
def clear_rect(im,x0,y0,x1,y1):
    for y in range(max(0,y0),min(S-1,y1)+1):
        for x in range(max(0,x0),min(S-1,x1)+1): im.putpixel((x,y),(0,0,0,0))
def shift(im,dx=0,dy=0):
    out=canvas()
    for y in range(S):
        for x in range(S):
            p=im.getpixel((x,y))
            if p[3]:
                nx=x+dx; ny=y+dy
                if 0<=nx<S and 0<=ny<S: out.putpixel((nx,ny),p)
    return out
def mirror(im): return im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
def squash(base,scale=1.0,dx=0):
    out=canvas()
    for y in range(S):
        for x in range(S):
            p=base.getpixel((x,y))
            if p[3]:
                nx=x+dx; ny=S-1-int(round((S-1-y)*scale))
                if 0<=nx<S and 0<=ny<S: out.putpixel((nx,ny),p)
    return out
def flash(im,pts,c='white'):
    for x,y in pts: px(im,x,y,c)
    return im

CLASSES=[
 # id, name, build, weapon, primary, secondary, accent, hair, extra
 ('pikeman','Копейщик','armored','spear','steel','steel2','gold','hair','shield'),
 ('hewer','Секирщик','bulky','axe','red','red2','steel3','hair','horns'),
 ('sawyer','Пильщик','bulky','saw','orange','orange2','steel3','hair','goggles'),
 ('duelist','Дуэлянт','slim','dual','blue','blue2','gold','hair','hat'),
 ('gunslinger','Ружейник','armored','gun','leather','leather2','gold','hair','cap'),
 ('siegemaster','Бомбардир','bulky','cannon','cloth','cloth2','orange','hair','bandana'),
 ('maestro','Маэстро','robe','instrument','purple','purple2','gold','hair','feather'),
 ('tempest','Повелитель бурь','robe','whip','cyan','cyan2','purple','hair','circlet'),
 ('skyhunter','Небесный охотник','slim','bow','green','green2','cyan','hair','wings'),
 ('tidemage','Маг приливов','robe','staff','water','water2','cyan','hair','coral'),
]

# Base sprite drawing at internal 32x32.
def draw_head(cfg,im,dirn):
    cid,name,build,weapon,primary,secondary,accent,hair,extra=cfg
    # face / head
    if dirn in ('south','east'):
        rect(im,12,6,19,13,'skin'); rect(im,12,6,19,8,hair)
        if dirn=='south':
            px(im,14,10,'eye'); px(im,17,10,'eye'); px(im,15,12,'skin2'); px(im,16,12,'skin2')
        else:
            px(im,18,10,'eye'); px(im,16,12,'skin2')
    else:
        rect(im,12,6,19,13,hair); rect(im,12,6,19,8,hair)
        if dirn=='north': rect(im,14,9,17,12,primary)
    # helmets / hats / extras
    if extra=='shield': hline(im,10,21,6,primary); rect(im,11,4,20,6,primary); px(im,16,5,accent)
    elif extra=='horns':
        hline(im,10,21,6,secondary); px(im,9,5,'bone'); px(im,22,5,'bone'); px(im,10,4,'bone'); px(im,21,4,'bone')
    elif extra=='goggles':
        hline(im,11,20,7,'black'); px(im,13,7,'cyan'); px(im,18,7,'cyan')
    elif extra=='hat':
        hline(im,9,22,6,secondary); rect(im,12,3,19,5,secondary); px(im,15,3,accent)
    elif extra=='cap':
        rect(im,12,5,19,7,primary); hline(im,18,23,8,primary); px(im,20,7,accent)
    elif extra=='bandana':
        hline(im,11,20,7,'red'); px(im,21,7,'red'); px(im,22,8,'red')
    elif extra=='feather':
        rect(im,12,4,19,6,primary); px(im,20,4,accent); px(im,21,3,accent); px(im,22,2,'cyan')
    elif extra=='circlet':
        hline(im,12,19,6,'gold'); px(im,16,5,'cyan')
    elif extra=='wings':
        rect(im,12,4,19,6,primary); px(im,9,6,accent); px(im,22,6,accent); px(im,8,7,accent); px(im,23,7,accent)
    elif extra=='coral':
        hline(im,11,20,6,'cyan'); px(im,10,5,'water'); px(im,21,5,'water'); px(im,16,4,'cyan')

def draw_body(cfg,im,dirn):
    cid,name,build,weapon,primary,secondary,accent,hair,extra=cfg
    # legs and feet
    if build=='bulky':
        rect(im,11,25,14,31,'boot'); rect(im,17,25,20,31,'boot'); rect(im,11,22,20,24,secondary)
    elif build=='slim':
        rect(im,12,25,14,31,'boot'); rect(im,17,25,19,31,'boot'); rect(im,12,22,19,24,secondary)
    else:
        rect(im,12,25,14,31,'boot'); rect(im,17,25,19,31,'boot'); rect(im,11,22,20,25,secondary)
    # torso
    if build=='armored': rect(im,9,14,22,23,primary); rect(im,9,14,22,15,'steel3'); rect(im,9,16,10,23,secondary); rect(im,21,16,22,23,secondary)
    elif build=='bulky': rect(im,7,14,24,23,primary); rect(im,7,14,24,15,secondary); rect(im,7,16,8,23,secondary); rect(im,23,16,24,23,secondary)
    elif build=='slim': rect(im,11,14,20,23,primary); rect(im,11,14,20,15,accent); rect(im,11,16,12,23,secondary); rect(im,19,16,20,23,secondary)
    else: rect(im,8,14,23,24,primary); rect(im,8,14,23,15,secondary); rect(im,8,16,9,24,secondary); rect(im,22,16,23,24,secondary); rect(im,10,22,21,24,secondary)
    # chest emblem
    if weapon in ('gun','cannon'): rect(im,14,17,17,19,accent)
    elif weapon in ('instrument','staff'): px(im,15,17,accent); px(im,16,18,accent)
    else: px(im,15,17,accent); px(im,16,17,accent)
    # arms
    if dirn in ('south','east'): rect(im,21,15,24,20,'skin')
    if dirn in ('south','west'): rect(im,7,15,10,20,'skin')

def draw_weapon(cfg,im,dirn):
    cid,name,build,weapon,primary,secondary,accent,hair,extra=cfg
    # South / north: carried vertically; east/west: profile/forward.
    if weapon=='spear':
        if dirn in ('south','north'):
            vline(im,25,7,29,'wood'); line(im,25,7,23,3,'steel3'); px(im,25,6,'steel3'); px(im,24,7,'steel2')
        else:
            hline(im,18,30,17,'wood'); px(im,31,17,'steel3'); px(im,30,16,'steel3'); px(im,30,18,'steel3')
    elif weapon=='axe':
        if dirn in ('south','north'):
            vline(im,24,8,29,'wood'); rect(im,22,6,27,10,'steel3'); rect(im,22,6,27,7,accent); px(im,21,8,'steel2'); px(im,28,8,'steel2')
        else:
            hline(im,18,29,17,'wood'); rect(im,27,13,30,21,'steel3'); rect(im,28,13,30,14,accent); px(im,30,12,'steel2'); px(im,30,22,'steel2')
    elif weapon=='saw':
        if dirn in ('south','north'):
            hline(im,22,29,11,'steel3'); hline(im,22,29,12,'steel2')
            for x in range(22,30): px(im,x,13,'steel3' if x%2==0 else 'steel2')
            vline(im,21,10,28,'wood')
        else:
            hline(im,17,30,16,'steel3'); hline(im,17,30,17,'steel2')
            for x in range(18,30): px(im,x,18,'steel3' if x%2==0 else 'steel2')
    elif weapon=='dual':
        if dirn in ('south','north'):
            vline(im,8,10,28,'steel3'); vline(im,23,10,28,'steel3'); px(im,8,9,'steel3'); px(im,23,9,'steel3')
        else:
            line(im,16,15,29,10,'steel3'); line(im,16,19,29,24,'steel3'); px(im,30,9,'steel3'); px(im,30,25,'steel3')
    elif weapon=='gun':
        if dirn in ('south','north'):
            vline(im,24,10,29,'wood'); hline(im,22,27,10,'steel2'); hline(im,22,27,11,'steel3'); px(im,24,8,'gold')
        else:
            hline(im,14,30,16,'wood'); hline(im,20,30,15,'steel2'); hline(im,20,30,17,'steel2'); px(im,30,16,'steel3')
    elif weapon=='cannon':
        if dirn in ('south','north'):
            rect(im,22,10,28,17,'steel2'); rect(im,23,11,29,16,'black'); hline(im,23,29,12,'steel3'); vline(im,24,17,28,'wood')
        else:
            rect(im,18,14,30,20,'steel2'); rect(im,25,15,31,19,'black'); hline(im,25,30,15,'steel3'); px(im,18,21,'wood'); px(im,19,22,'wood')
    elif weapon=='instrument':
        if dirn in ('south','north'):
            line(im,9,15,15,9,'wood'); line(im,10,16,16,10,'wood2'); rect(im,13,7,18,11,primary); hline(im,13,18,8,'gold')
        else:
            line(im,13,17,22,8,'wood'); line(im,14,18,23,9,'wood2'); rect(im,20,5,26,11,primary); hline(im,20,26,6,'gold')
    elif weapon=='whip':
        if dirn in ('south','north'):
            line(im,8,12,13,22,'cyan'); line(im,13,22,9,28,'cyan'); px(im,8,11,'cyan'); px(im,14,21,'cyan2')
        else:
            line(im,11,15,17,12,'cyan'); line(im,17,12,22,16,'cyan'); line(im,22,16,28,13,'cyan'); px(im,29,12,'cyan')
    elif weapon=='bow':
        if dirn in ('south','north'):
            line(im,7,10,10,16,'wood'); line(im,10,16,7,22,'wood'); vline(im,11,10,22,'string'); px(im,6,9,'accent'); px(im,6,23,'accent')
        else:
            line(im,22,7,25,15,'wood'); line(im,25,15,22,23,'wood'); vline(im,26,8,22,'string'); px(im,21,6,'accent'); px(im,21,24,'accent')
    elif weapon=='staff':
        if dirn in ('south','north'):
            vline(im,24,5,29,'wood'); px(im,24,4,'cyan'); px(im,23,4,'water'); px(im,25,4,'water'); px(im,24,3,'cyan')
        else:
            hline(im,16,29,16,'wood'); px(im,30,15,'cyan'); px(im,30,17,'water'); px(im,29,16,'water'); px(im,30,14,'cyan')

def base_sprite(cfg,dirn):
    im=canvas(); draw_weapon(cfg,im,dirn); draw_body(cfg,im,dirn); draw_head(cfg,im,dirn)
    # simple dark outline on lower/head edges
    return im


PAL['string']='#d8d1b8'
def draw_weapon(cfg,im,dirn):
    cid,name,build,weapon,primary,secondary,accent,hair,extra=cfg
    # South / north: carried vertically; east/west: profile/forward.
    if weapon=='spear':
        if dirn in ('south','north'):
            vline(im,25,7,29,'wood'); line(im,25,7,23,3,'steel3'); px(im,25,6,'steel3'); px(im,24,7,'steel2')
        else:
            hline(im,18,30,17,'wood'); px(im,31,17,'steel3'); px(im,30,16,'steel3'); px(im,30,18,'steel3')
    elif weapon=='axe':
        if dirn in ('south','north'):
            vline(im,24,8,29,'wood'); rect(im,22,6,27,10,'steel3'); rect(im,22,6,27,7,accent); px(im,21,8,'steel2'); px(im,28,8,'steel2')
        else:
            hline(im,18,29,17,'wood'); rect(im,27,13,30,21,'steel3'); rect(im,28,13,30,14,accent); px(im,30,12,'steel2'); px(im,30,22,'steel2')
    elif weapon=='saw':
        if dirn in ('south','north'):
            hline(im,22,29,11,'steel3'); hline(im,22,29,12,'steel2')
            for x in range(22,30): px(im,x,13,'steel3' if x%2==0 else 'steel2')
            vline(im,21,10,28,'wood')
        else:
            hline(im,17,30,16,'steel3'); hline(im,17,30,17,'steel2')
            for x in range(18,30): px(im,x,18,'steel3' if x%2==0 else 'steel2')
    elif weapon=='dual':
        if dirn in ('south','north'):
            vline(im,8,10,28,'steel3'); vline(im,23,10,28,'steel3'); px(im,8,9,'steel3'); px(im,23,9,'steel3')
        else:
            line(im,16,15,29,10,'steel3'); line(im,16,19,29,24,'steel3'); px(im,30,9,'steel3'); px(im,30,25,'steel3')
    elif weapon=='gun':
        if dirn in ('south','north'):
            vline(im,24,10,29,'wood'); hline(im,22,27,10,'steel2'); hline(im,22,27,11,'steel3'); px(im,24,8,'gold')
        else:
            hline(im,14,30,16,'wood'); hline(im,20,30,15,'steel2'); hline(im,20,30,17,'steel2'); px(im,30,16,'steel3')
    elif weapon=='cannon':
        if dirn in ('south','north'):
            rect(im,22,10,28,17,'steel2'); rect(im,23,11,29,16,'black'); hline(im,23,29,12,'steel3'); vline(im,24,17,28,'wood')
        else:
            rect(im,18,14,30,20,'steel2'); rect(im,25,15,31,19,'black'); hline(im,25,30,15,'steel3'); px(im,18,21,'wood'); px(im,19,22,'wood')
    elif weapon=='instrument':
        if dirn in ('south','north'):
            line(im,9,15,15,9,'wood'); line(im,10,16,16,10,'wood2'); rect(im,13,7,18,11,primary); hline(im,13,18,8,'gold')
        else:
            line(im,13,17,22,8,'wood'); line(im,14,18,23,9,'wood2'); rect(im,20,5,26,11,primary); hline(im,20,26,6,'gold')
    elif weapon=='whip':
        if dirn in ('south','north'):
            line(im,8,12,13,22,'cyan'); line(im,13,22,9,28,'cyan'); px(im,8,11,'cyan'); px(im,14,21,'cyan2')
        else:
            line(im,11,15,17,12,'cyan'); line(im,17,12,22,16,'cyan'); line(im,22,16,28,13,'cyan'); px(im,29,12,'cyan')
    elif weapon=='bow':
        if dirn in ('south','north'):
            line(im,7,10,10,16,'wood'); line(im,10,16,7,22,'wood'); vline(im,11,10,22,'string'); px(im,6,9,cfg[6]); px(im,6,23,cfg[6])
        else:
            line(im,22,7,25,15,'wood'); line(im,25,15,22,23,'wood'); vline(im,26,8,22,'string'); px(im,21,6,cfg[6]); px(im,21,24,cfg[6])
    elif weapon=='staff':
        if dirn in ('south','north'):
            vline(im,24,5,29,'wood'); px(im,24,4,'cyan'); px(im,23,4,'water'); px(im,25,4,'water'); px(im,24,3,'cyan')
        else:
            hline(im,16,29,16,'wood'); px(im,30,15,'cyan'); px(im,30,17,'water'); px(im,29,16,'water'); px(im,30,14,'cyan')

PAL['string']='#d8d1b8'
BASE={cid:{d:base_sprite(cfg,d) for d in ['south','north','east','west']} for cfg in CLASSES for cid in [cfg[0]]}
CFG={cfg[0]:cfg for cfg in CLASSES}

# Animation helpers.
def idle_dir(cid,d):
    frames=[]; sparks={'pikeman':(24,7),'hewer':(24,5),'sawyer':(25,12),'duelist':(23,9),'gunslinger':(30,16),'siegemaster':(29,12),'maestro':(21,6),'tempest':(29,12),'skyhunter':(21,6),'tidemage':(30,14)}
    for i,dy in enumerate([0,-1,0,0]):
        f=shift(BASE[cid][d],0,dy)
        if i==1: flash(f,[sparks[cid]],CFG[cid][6])
        frames.append(f)
    return frames

def clear_legs(im,build):
    clear_rect(im,7,23,24,31)

def draw_legs(im,cfg,d,phase):
    cid,name,build,weapon,primary,secondary,accent,hair,extra=cfg
    boot='boot'; pants=secondary
    if d in ('south','north'):
        pat=[(-1,1),(0,0),(1,-1),(0,0),(-1,1),(0,0)][phase]
        l,r=pat
        rect(im,12+l,24,14+l,28,pants); rect(im,17+r,24,19+r,28,pants)
        rect(im,12+l,29,15+l,31,boot); rect(im,17+r,29,20+r,31,boot)
    else:
        dx=[1,-1,-1,0,1,0][phase]
        rect(im,12+dx,24,14+dx,28,pants); rect(im,17-dx,24,19-dx,28,pants)
        rect(im,12+dx,29,15+dx,31,boot); rect(im,17-dx,29,20-dx,31,boot)
    if build=='robe': rect(im,9,23,22,25,secondary)

def walk_dir(cid,d):
    cfg=CFG[cid]; frames=[]
    for ph in range(6):
        f=BASE[cid][d].copy(); clear_legs(f,cfg[2]); draw_legs(f,cfg,d,ph)
        frames.append(f)
    return frames

# Side action generic poses.
def clear_weapon_zone(f,cid):
    clear_rect(f,6,4,31,29)

def redraw_arm(f,dirn):
    if dirn=='east': rect(f,21,15,24,20,'skin')
    else: rect(f,7,15,10,20,'skin')

def side_frames(cid,kind):
    cfg=CFG[cid]; weapon=cfg[3]; east=[BASE[cid]['east'].copy() for _ in range(6)]
    if kind=='attack':
        for ph in range(1,6):
            f=east[ph]; clear_weapon_zone(f,cid); redraw_arm(f,'east')
            if weapon=='spear':
                if ph<=2: line(f,18,17,26,15,'wood'); line(f,26,15,30,14,'steel3'); line(f,26,16,30,17,'steel2')
                elif ph==3: line(f,17,17,30,16,'wood'); px(f,31,16,'steel3'); px(f,30,15,'steel3'); px(f,30,17,'steel3')
                else: line(f,18,17,28,17,'wood'); px(f,30,17,'steel3')
            elif weapon=='axe':
                if ph<=2: line(f,18,17,24,12,'wood'); rect(f,23,8,28,13,'steel3'); rect(f,24,8,27,9,cfg[6])
                elif ph==3: line(f,17,17,27,20,'wood'); rect(f,25,18,30,23,'steel3'); px(f,30,17,'steel3')
                else: line(f,18,17,27,18,'wood'); rect(f,26,15,30,20,'steel3')
            elif weapon=='saw':
                if ph<=2: hline(f,17,27,16,'steel3'); hline(f,17,27,17,'steel2')
                elif ph==3: hline(f,16,31,16,'steel3'); hline(f,16,31,17,'steel2'); [px(f,x,18,'steel3') for x in range(17,31,2)]
                else: hline(f,17,29,16,'steel3'); hline(f,17,29,17,'steel2')
            elif weapon=='dual':
                if ph<=2: line(f,15,15,24,10,'steel3'); line(f,15,19,24,24,'steel3')
                elif ph==3: line(f,14,14,30,10,'steel3'); line(f,14,20,30,26,'steel3'); px(f,31,9,cfg[6]); px(f,31,27,cfg[6])
                else: line(f,16,16,28,13,'steel3'); line(f,16,18,28,23,'steel3')
            elif weapon=='gun':
                if ph<=2: hline(f,16,28,16,'wood'); hline(f,22,29,15,'steel2'); hline(f,22,29,17,'steel2')
                elif ph==3: hline(f,15,29,16,'wood'); px(f,30,16,'white'); px(f,31,16,cfg[6]); px(f,30,15,'gold3'); px(f,30,17,'gold3')
                else: hline(f,16,28,16,'wood'); hline(f,22,29,15,'steel2'); hline(f,22,29,17,'steel2')
            elif weapon=='cannon':
                if ph<=2: rect(f,18,14,29,20,'steel2'); rect(f,25,15,30,19,'black')
                elif ph==3: rect(f,16,14,30,20,'steel2'); rect(f,24,15,31,19,'black'); px(f,31,14,'white'); px(f,31,20,cfg[6]); px(f,12,21,'wood'); px(f,13,22,'wood')
                else: rect(f,18,14,29,20,'steel2'); rect(f,25,15,30,19,'black')
            elif weapon=='instrument':
                if ph<=2: line(f,13,17,22,9,'wood'); rect(f,20,6,26,12,cfg[4]); hline(f,20,26,7,cfg[6])
                elif ph==3: line(f,13,17,23,8,'wood'); rect(f,20,5,27,12,cfg[4]); px(f,28,7,cfg[6]); px(f,29,5,cfg[6]); px(f,30,3,cfg[6])
                else: line(f,13,17,22,9,'wood'); rect(f,20,6,26,12,cfg[4])
            elif weapon=='whip':
                if ph<=2: line(f,10,15,17,12,'cyan'); line(f,17,12,23,16,'cyan')
                elif ph==3: line(f,10,15,18,12,'cyan'); line(f,18,12,25,15,'cyan'); line(f,25,15,31,12,'cyan'); px(f,31,11,'white'); px(f,30,13,cfg[6])
                else: line(f,11,15,18,13,'cyan'); line(f,18,13,26,16,'cyan')
            elif weapon=='bow':
                if ph<=2: line(f,22,7,25,15,'wood'); line(f,25,15,22,23,'wood'); vline(f,24,8,22,'string'); hline(f,20,26,15,'string')
                elif ph==3: line(f,22,7,25,15,'wood'); line(f,25,15,22,23,'wood'); vline(f,26,8,22,'string'); hline(f,18,31,15,'string'); px(f,31,15,cfg[6]); px(f,30,14,'white')
                else: line(f,22,7,25,15,'wood'); line(f,25,15,22,23,'wood'); vline(f,25,8,22,'string')
            elif weapon=='staff':
                if ph<=2: hline(f,16,28,16,'wood'); px(f,29,15,'cyan'); px(f,29,17,'water')
                elif ph==3: hline(f,15,29,16,'wood'); hline(f,29,31,16,'cyan'); px(f,30,15,'white'); px(f,30,17,cfg[6])
                else: hline(f,16,28,16,'wood'); px(f,29,15,'cyan')
    elif kind=='skill':
        for ph in range(1,6):
            f=east[ph]; clear_weapon_zone(f,cid); redraw_arm(f,'east')
            if weapon=='spear': line(f,13,18,25,8,'wood'); px(f,26,7,cfg[6]); (px(f,27,6,'white') if ph==3 else None)
            elif weapon=='axe': line(f,14,18,24,25,'wood'); px(f,25,26,cfg[6]); (px(f,26,27,'white') if ph==3 else None)
            elif weapon=='saw': hline(f,14,29,20,'steel2'); px(f,30,20,cfg[6]); (px(f,28,21,'white') if ph==3 else None)
            elif weapon=='dual':
                line(f,12,13,29,23,'steel3'); line(f,12,23,29,13,'steel3')
                if ph==3:
                    px(f,30,12,cfg[6]); px(f,30,24,cfg[6])
            elif weapon=='gun': hline(f,12,29,12,'steel2'); px(f,30,12,cfg[6]); (px(f,28,10,'white') if ph==3 else None)
            elif weapon=='cannon':
                rect(f,18,13,30,21,'steel2')
                if ph==3:
                    px(f,31,12,cfg[6]); px(f,31,22,cfg[6])
            elif weapon=='instrument':
                line(f,12,18,24,6,'wood'); rect(f,22,3,29,10,cfg[4])
                if ph==3:
                    px(f,30,5,cfg[6]); px(f,31,3,'white')
            elif weapon=='whip':
                line(f,9,14,16,8,'cyan'); line(f,16,8,24,12,'cyan'); line(f,24,12,30,7,'cyan')
                if ph==3:
                    px(f,30,5,'white'); px(f,29,8,cfg[6])
            elif weapon=='bow':
                line(f,20,4,27,15,'wood'); line(f,27,15,20,26,'wood'); vline(f,28,6,24,'string')
                if ph==3:
                    px(f,29,5,cfg[6]); px(f,30,3,'white')
            elif weapon=='staff':
                line(f,12,20,22,7,'wood'); px(f,23,6,'cyan'); px(f,24,5,'water')
                if ph==3:
                    px(f,25,4,'white'); px(f,26,3,cfg[6])
    return east

def hit_dir(cid,d):
    b=BASE[cid]['east'] if d=='east' else BASE[cid]['west']
    f1=shift(b,-2,0); flash(f1,[(12,7),(18,7),(15,14),(22,16)],CFG[cid][6])
    f2=shift(b,-4,0); flash(f2,[(10,8),(18,8),(20,15)],'white')
    return [b,f1,f2] if d=='east' else [BASE[cid]['west'],mirror(f1),mirror(f2)]

def down_dir(cid,d):
    b=BASE[cid]['east'] if d=='east' else BASE[cid]['west']
    scales=[1.0,0.88,0.74,0.60,0.48]; dxs=[0,0,2,4,6]
    frames=[squash(b,scales[i],dxs[i]) for i in range(5)]
    return frames if d=='east' else [mirror(f) for f in frames]

def guard_dir(cid,d):
    b=BASE[cid]['east'] if d=='east' else BASE[cid]['west']
    frames=[b]
    for ph in (1,2):
        f=(BASE[cid]['east'] if d=='east' else BASE[cid]['west']).copy(); clear_weapon_zone(f,cid); redraw_arm(f,d)
        if CFG[cid][3] in ('spear','gun','staff'):
            line(f,13,19,27,10,'wood' if CFG[cid][3]!='staff' else CFG[cid][4]); px(f,28,9,CFG[cid][6])
        elif CFG[cid][3] in ('axe','saw','cannon'):
            line(f,13,18,26,22,'wood'); px(f,27,23,CFG[cid][6])
        else:
            line(f,12,13,27,23,CFG[cid][4]); px(f,28,24,CFG[cid][6])
        frames.append(f)
    return frames

def make_clip(cid,clip,d):
    if clip=='idle': return idle_dir(cid,d)
    if clip=='walk': return walk_dir(cid,d)
    if clip in ('attack','skill'):
        east=side_frames(cid,clip)
        return east if d=='east' else [mirror(f) for f in east]
    if clip=='hit': return hit_dir(cid,d)
    if clip=='down': return down_dir(cid,d)
    if clip=='guard': return guard_dir(cid,d)

CLIP_SPECS=[('idle',['south','north','east','west'],4,4,True),('walk',['south','north','east','west'],6,8,True),('attack',['east','west'],6,12,False),('skill',['east','west'],6,10,False),('guard',['east','west'],3,8,False),('hit',['east','west'],3,10,False),('down',['east','west'],5,8,False)]
EVENT={'attack':3,'skill':3}

row_count=sum(len(dirs) for _,dirs,_,_,_ in CLIP_SPECS)
max_frames=max(n for _,_,n,_,_ in CLIP_SPECS)
for cfg in CLASSES:
    cid,name=cfg[0],cfg[1]
    (ASSETS/cid).mkdir(exist_ok=True)
    for d in ['south','north','east','west']:
        BASE[cid][d].resize((FS,FS),Image.Resampling.NEAREST).save(ASSETS/cid/f'{d}.png')
    low_atlas=Image.new('RGBA',(max_frames*S,row_count*S),(0,0,0,0))
    clips=[]; rows=[]; y=0
    for clip,dirs,nframes,fps,loop in CLIP_SPECS:
        for d in dirs:
            frames=make_clip(cid,clip,d)
            assert len(frames)==nframes,(cid,clip,d,len(frames),nframes)
            rects=[]
            for i,f in enumerate(frames):
                low_atlas.paste(f,(i*S,y)); rects.append({'index':i,'x':i*FS,'y':y*EXPORT,'w':FS,'h':FS})
            entry={'animation':clip,'direction':d,'fps':fps,'loop':loop,'anchor':[FS//2,FS-1],'frames':rects,'events':[]}
            if clip in EVENT: entry['events']=[{'frame':EVENT[clip],'type':f'{clip}_event'}]
            if clip in ('guard','down'): entry['hold_last']=True
            clips.append(entry); rows.append({'animation':clip,'direction':d,'row':y,'frames':nframes})
            y+=S
    atlas=low_atlas.resize((low_atlas.width*EXPORT,low_atlas.height*EXPORT),Image.Resampling.NEAREST)
    atlas.save(ASSETS/cid/f'{cid}_atlas_128.png')
    meta={'class_id':cid,'name_ru':name,'frame_size':[FS,FS],'anchor':[FS//2,FS-1],'image':f'assets/heroes/{cid}/{cid}_atlas_128.png','row_order':rows,'clips':clips,'target':'Godot 4.7.2','source_layer_size':[S,S],'export_scale':EXPORT}
    (ASSETS/cid/f'{cid}.animation.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2),encoding='utf-8')
print('roster core generated', len(CLASSES), 'frame', FS)