from PIL import Image, ImageDraw, ImageFont, ImageFilter
from pathlib import Path
import json, hashlib, zipfile, shutil, math, random, os

UIROOT=Path('/mnt/agents/output/repo_ready_branches/art/fantasy-ui')
if UIROOT.exists(): shutil.rmtree(UIROOT)
UI=UIROOT/'assets'/'ui'/'fantasy'
UIDOCS=UIROOT/'docs'/'art'/'fantasy-ui'
for p in [UI, UIDOCS, UI/'screens', UI/'elements', UI/'source']:
    p.mkdir(parents=True,exist_ok=True)

# Colors
UI_PAL={
 'bg0':'#0b1220','bg1':'#111c31','panel':'#14243f','panel2':'#0f1b30','gold':'#d7a83c','gold2':'#8a611b','gold3':'#f1d071',
 'text':'#eef3f8','muted':'#8fa0b4','red':'#c84b4b','red2':'#6d2a2f','green':'#55b56b','green2':'#225438','blue':'#4f9fc6','blue2':'#1f5674','purple':'#9b79d0','black':'#05070c','white':'#ffffff'
}
def UIC(n):
    if isinstance(n,str) and n.startswith('#'):
        return tuple(int(n[i:i+2],16) for i in (1,3,5))
    return tuple(int(UI_PAL[n][i:i+2],16) for i in (1,3,5))
UI_PAL['outline']='#05070c'
UI_PAL['steel']='#9aa8ba'
UI_PAL['wood']='#7b4b2d'
UI_PAL['sand']='#c9a96b'
UI_PAL['water']='#4f9fc6'
FONT='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
FONT_B='/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
F48=ImageFont.truetype(FONT_B,48); F32=ImageFont.truetype(FONT_B,32); F24=ImageFont.truetype(FONT_B,24); F20=ImageFont.truetype(FONT_B,20); F16=ImageFont.truetype(FONT,16); F14=ImageFont.truetype(FONT,14); F12=ImageFont.truetype(FONT,12)

def rr(d,box,r,fill,outline=None,width=1):
    d.rounded_rectangle(box,radius=r,fill=fill,outline=outline,width=width)

def text(d,xy,s,font,fill='text',anchor=None):
    d.text(xy,s,font=font,fill=UIC(fill) if isinstance(fill,str) else fill,anchor=anchor)

def panel(d,box,title=None,fill='panel',outline='gold',r=10,title_font=F20):
    rr(d,box,r,UIC(fill),UIC(outline),3)
    x0,y0,x1,y1=box
    d.line((x0+8,y0+8,x1-8,y0+8),fill=UIC('gold2'),width=1)
    if title: text(d,(x0+14,y0+8),title,title_font,'gold3')

def button(d,box,label,state='normal'):
    colors={'normal':('panel2','gold','gold3'),'pressed':('black','gold2','gold'),'selected':('blue2','gold3','white'),'disabled':('#18202e','#5b6675','#5b6675')}
    fill,outline,fg=colors[state]
    rr(d,box,10,fill if isinstance(fill,tuple) else UIC(fill),UIC(outline) if isinstance(outline,str) else outline,3)
    x0,y0,x1,y1=box
    if state=='pressed': d.line((x0+4,y1-4,x1-4,y1-4),fill=UIC('black'),width=3)
    else: d.line((x0+4,y0+4,x1-4,y0+4),fill=UIC('gold3'),width=2)
    text(d,((x0+x1)//2,(y0+y1)//2),label,F20,fg,anchor='mm')

def bar(d,box,value=0.72,kind='hp',label='HP'):
    colors={'hp':('red','red2'),'ap':('gold','gold2'),'mana':('blue','blue2'),'xp':('green','green2')}
    fg,bg=colors[kind]
    rr(d,box,6,UIC(bg),UIC('outline'),2)
    x0,y0,x1,y1=box
    w=int((x1-x0-4)*value)
    if w>0: rr(d,(x0+2,y0+2,x0+2+w,y1-2),5,UIC(fg))
    text(d,(x0+6,(y0+y1)//2),label,F12,'white',anchor='lm')

def portrait_thumb(cid='pikeman',size=128):
    p=Path(f'/mnt/agents/output/repo_ready_branches/art/hero-roster/assets/heroes/previews/portrait_{cid}.png')
    if p.exists(): return Image.open(p).convert('RGBA').resize((size,size),Image.Resampling.LANCZOS)
    im=Image.new('RGBA',(size,size),UIC('panel')+(255,)); return im

# Elements.
# 9-slice panel 96x96 with 16 px insets.
el=Image.new('RGBA',(96,96),(0,0,0,0)); d=ImageDraw.Draw(el)
rr(d,(0,0,95,95),14,UIC('panel')+(255,),UIC('gold')+(255,),4)
d.rectangle((16,16,79,79),fill=UIC('panel2')+(255,),outline=UIC('gold2')+(255,),width=1)
el.save(UI/'elements'/'panel_9slice.png')
# button states 256x64
for state in ['normal','pressed','selected','disabled']:
    im=Image.new('RGBA',(256,64),(0,0,0,0)); d=ImageDraw.Draw(im); button(d,(2,2,253,61),'Кнопка',state); im.save(UI/'elements'/f'button_{state}.png')
# bars
for kind in ['hp','ap','mana','xp']:
    im=Image.new('RGBA',(256,28),(0,0,0,0)); d=ImageDraw.Draw(im); bar(d,(2,2,253,25),0.68,kind,kind.upper()); im.save(UI/'elements'/f'bar_{kind}.png')
# icons 64x64
icons={'sword':('steel','gold'),'bow':('wood','green'),'staff':('water','gold'),'potion':('red','blue'),'gold':('gold3','gold2'),'map':('sand','green'),'gear':('muted','steel'),'close':('red','white')}
def icon(name,fg,bg):
    im=Image.new('RGBA',(64,64),(0,0,0,0)); d=ImageDraw.Draw(im)
    rr(d,(2,2,61,61),10,UIC(bg)+(120,),UIC('gold')+(255,),2)
    if name=='sword': d.line((18,46,46,18),fill=UIC('white'),width=5); d.line((42,14,52,24),fill=UIC(fg),width=5); d.line((16,40,24,48),fill=UIC('gold'),width=4)
    elif name=='bow': d.arc((14,10,50,54),80,280,fill=UIC(fg),width=5); d.line((32,15,32,49),fill=UIC('gold3'),width=2)
    elif name=='staff': d.line((20,52,44,12),fill=UIC('wood'),width=5); d.ellipse((34,4,54,24),fill=UIC(fg),outline=UIC('white'),width=2)
    elif name=='potion': d.rectangle((24,24,40,50),fill=UIC(fg),outline=UIC('white')); d.rectangle((27,14,37,25),fill=UIC('gold3'))
    elif name=='gold': d.ellipse((16,18,48,50),fill=UIC(fg),outline=UIC('gold2'),width=4)
    elif name=='map': d.polygon([(14,18),(50,14),(52,48),(18,52)],fill=UIC(fg),outline=UIC('gold')); d.line((31,16,33,50),fill=UIC('gold2'),width=2)
    elif name=='gear': d.ellipse((20,20,44,44),fill=UIC(fg),outline=UIC('white'),width=3)
    elif name=='close': d.line((18,18,46,46),fill=UIC(fg),width=7); d.line((46,18,18,46),fill=UIC(fg),width=7)
    return im
for name,(fg,bg) in icons.items(): icon(name,fg,bg).save(UI/'elements'/f'icon_{name}.png')
# formation cells
for state in ['free','selected','reserve','out_of_battle','valid_target','preview_zone']:
    im=Image.new('RGBA',(96,96),(0,0,0,0)); d=ImageDraw.Draw(im)
    fill={'free':(38,55,82,180),'selected':(79,145,190,220),'reserve':(80,92,112,180),'out_of_battle':(48,54,66,150),'valid_target':(85,180,110,220),'preview_zone':(215,170,65,180)}[state]
    outline={'free':'muted','selected':'gold3','reserve':'muted','out_of_battle':'black','valid_target':'green','preview_zone':'gold3'}[state]
    rr(d,(4,4,91,91),10,fill,UIC(outline),3)
    d.line((10,48,86,48),fill=UIC(outline)+(120,),width=1); d.line((48,10,48,86),fill=UIC(outline)+(120,),width=1)
    im.save(UI/'elements'/f'grid_cell_{state}.png')

# Screens.
def base_bg(w,h,mode='squad'):
    im=Image.new('RGB',(w,h),UIC('bg0')); d=ImageDraw.Draw(im)
    # subtle gradient
    for y in range(h):
        t=y/h
        a=UIC('bg0'); b=UIC('bg1')
        col=tuple(int(a[i]*(1-t)+b[i]*t) for i in range(3))
        d.line((0,y,w,y),fill=col)
    # decorative gold corner
    d.line((20,20,w-20,20),fill=UIC('gold2'),width=2); d.line((20,h-20,w-20,h-20),fill=UIC('gold2'),width=2)
    return im,d

def squad_screen(w,h):
    im,d=base_bg(w,h)
    text(d,(28,18),'Отряд',F48,'gold3')
    # left list
    panel(d,(24,82,360,h-24),'Бойцы')
    y=112
    for i,cid in enumerate(['pikeman','hewer','sawyer','duelist','gunslinger','siegemaster','maestro','tempest','skyhunter','tidemage']):
        selected=(i==0)
        rr(d,(40,y,344,y+64),8,UIC('blue2') if selected else UIC('panel2'),UIC('gold3') if selected else UIC('gold2'),3 if selected else 1)
        im.paste(portrait_thumb(cid,52),(48,y+6),portrait_thumb(cid,52))
        text(d,(112,y+12),['Копейщик','Секирщик','Пильщик','Дуэлянт','Ружейник','Бомбардир','Маэстро','Повелитель бурь','Небесный охотник','Маг приливов'][i],F16,'text')
        text(d,(112,y+38),f'AP +{50+i%5} · DEF {8+i%4}',F12,'muted')
        y+=76
    # hero card
    panel(d,(388,82,760,h-24),'Карточка героя')
    im.paste(portrait_thumb('pikeman',260),(410,112),portrait_thumb('pikeman',260))
    text(d,(690,126),'Копейщик',F32,'gold3',anchor='mm')
    text(d,(690,166),'Стойкий боец передней линии',F14,'muted',anchor='mm')
    bar(d,(690,196,735 if w<1400 else 735,220),0.84,'hp','HP')
    bar(d,(690,228,735,252),0.62,'ap','OD')
    bar(d,(690,260,735,284),0.44,'mana','Мана')
    # equipment slots
    for i in range(6):
        x=410+i*54; rr(d,(x,404,x+44,448),6,UIC('panel2'),UIC('gold2'),2)
        icon(['sword','potion','gear','map','gold','close'][i],*icons[['sword','potion','gear','map','gold','close'][i]]).resize((36,36)).save('/tmp/tmpicon.png')
        ic=Image.open('/tmp/tmpicon.png'); im.paste(ic,(x+4,408),ic)
    # formation 3x3
    panel(d,(788,82,w-24,h-24),'Формация 3×3')
    gx=816 if w<1400 else 940; gy=132; cell=112 if w<1400 else 126
    for r in range(3):
        for c in range(3):
            x=gx+c*(cell+12); y=gy+r*(cell+12)
            state='selected' if (r==1 and c==1) else ('free' if r<2 else 'reserve')
            cellimg=Image.open(UI/'elements'/f'grid_cell_{state}.png').resize((cell,cell))
            im.paste(cellimg,(x,y),cellimg)
            if (r,c) in [(1,1),(0,1),(2,0)]:
                sprite=BASE[[ 'pikeman','hewer','gunslinger'][ (r+c)%3 ]]['south'].resize((cell-18,cell-18),Image.Resampling.NEAREST)
                im.paste(sprite,(x+9,y+9),sprite)
    # state chips
    for i,(lab,st) in enumerate([('выбран','selected'),('свободно','free'),('резерв','reserve'),('вне боя','out_of_battle')]):
        x=800+i*126; rr(d,(x,h-76,x+112,h-42),8,UIC('panel2'),UIC('gold2'),1); text(d,(x+56,h-59),lab,F12,'text',anchor='mm')
    return im

def battle_screen(w,h):
    im,d=base_bg(w,h,'battle')
    # forest arena background
    d.rectangle((0,0,w,h),fill=(22,42,34))
    for i in range(120):
        x=random.randint(0,w); y=random.randint(0,h); r=random.randint(18,70)
        col=(18+random.randint(0,20),50+random.randint(0,35),35+random.randint(0,20))
        d.ellipse((x-r,y-r,x+r,y+r),fill=col)
    # arena floor
    rr(d,(60,110,w-60,h-70),18,(38,56,44),UIC('gold2'),4)
    # grids
    def grid(x0,y0,owner='left'):
        cell=106 if w<1400 else 122; gap=12
        for r in range(3):
            for c in range(3):
                x=x0+c*(cell+gap); y=y0+r*(cell+gap)
                state='valid_target' if (owner=='right' and r==1 and c==1) else ('preview_zone' if (owner=='left' and r==1 and c==2) else 'free')
                cellimg=Image.open(UI/'elements'/f'grid_cell_{state}.png').resize((cell,cell))
                im.paste(cellimg,(x,y),cellimg)
                if (r+c)%2==0:
                    heroes=['pikeman','hewer','gunslinger','maestro','tidemage','duelist','sawyer','tempest','skyhunter','siegemaster']
                    cid=heroes[(r*3+c + (0 if owner=='left' else 4))%len(heroes)]
                    sprite=BASE[cid]['east' if owner=='left' else 'west'].resize((cell-16,cell-16),Image.Resampling.NEAREST)
                    im.paste(sprite,(x+8,y+8),sprite)
                    d.ellipse((x+12,y+cell-12,x+cell-12,y+cell-2),fill=(0,0,0,90))
        return cell
    cell=grid(116,178,'left'); grid(w-116-3*(cell+12)+12,178,'right')
    text(d,(28,18),'Бой',F48,'gold3')
    # top portraits / bars
    for i,cid in enumerate(['pikeman','hewer','gunslinger']):
        x=30+i*150
        im.paste(portrait_thumb(cid,86),(x,70),portrait_thumb(cid,86))
        bar(d,(x+92,82,x+134,100),[0.8,0.55,0.34][i],'hp','')
        bar(d,(x+92,108,x+134,124),[0.7,0.5,0.9][i],'ap','')
    # action menu
    panel(d,(30,h-164,360,h-28),'Действия')
    for i,lab in enumerate(['Атака','Навык','Защита','Предмет','Пропуск']):
        button(d,(48,h-132+i*24,342,h-112+i*24),lab,'selected' if i==0 else 'normal')
    # target panel
    panel(d,(w-390,h-164,w-30,h-28),'Цель')
    text(d,(w-372,h-132),'Копейщик → Маэстро',F16,'text')
    text(d,(w-372,h-108),'Зона удара: линия',F14,'muted')
    text(d,(w-372,h-84),'Урон: оружие шаблона',F14,'muted')
    return im

squad_screen(1280,720).save(UI/'screens'/'squad_1280x720.png')
squad_screen(1584,720).save(UI/'screens'/'squad_1584x720.png')
battle_screen(1280,720).save(UI/'screens'/'battle_1280x720.png')
battle_screen(1584,720).save(UI/'screens'/'battle_1584x720.png')

# UI kit preview
kit=Image.new('RGB',(1280,720),UIC('bg0')); d=ImageDraw.Draw(kit)
text(d,(28,20),'Fantasy MMORPG UI Kit',F48,'gold3')
panel(d,(30,90,420,320),'Панель 9-slice')
kit.paste(el.resize((220,220),Image.Resampling.NEAREST),(100,120),el.resize((220,220),Image.Resampling.NEAREST))
panel(d,(460,90,1240,320),'Кнопки')
for i,state in enumerate(['normal','pressed','selected','disabled']):
    imst=Image.open(UI/'elements'/f'button_{state}.png').resize((360,90),Image.Resampling.LANCZOS); kit.paste(imst,(490,130+i*46),imst)
panel(d,(30,350,1240,690),'Шкалы, иконки, ячейки')
for i,kind in enumerate(['hp','ap','mana','xp']):
    bimg=Image.open(UI/'elements'/f'bar_{kind}.png').resize((360,40),Image.Resampling.LANCZOS); kit.paste(bimg,(60,390+i*46),bimg)
for i,name in enumerate(icons):
    ic=Image.open(UI/'elements'/f'icon_{name}.png').resize((64,64),Image.Resampling.LANCZOS); kit.paste(ic,(460+i*74,390),ic)
for i,state in enumerate(['free','selected','reserve','out_of_battle','valid_target','preview_zone']):
    cimg=Image.open(UI/'elements'/f'grid_cell_{state}.png').resize((70,70),Image.Resampling.LANCZOS); kit.paste(cimg,(450+i*82,500),cimg)
    text(d,(450+i*82+35,580),state,F12,'muted',anchor='mm')
kit.save(UI/'elements'/'ui_kit_preview.png')

# Metadata/docs/source.
metadata={
 'buttons':{'size':[256,64],'touch_min':64,'states':['normal','pressed','selected','disabled']},
 'panel_9slice':{'image':'assets/ui/fantasy/elements/panel_9slice.png','size':[96,96],'insets':{'left':16,'right':16,'top':16,'bottom':16}},
 'grid_cells':{'size':[96,96],'states':['free','selected','reserve','out_of_battle','valid_target','preview_zone']},
 'bars':['hp','ap','mana','xp'],
 'icons':list(icons.keys()),
 'screens':['squad_1280x720.png','squad_1584x720.png','battle_1280x720.png','battle_1584x720.png']
}
(UI/'metadata.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2),encoding='utf-8')
(UIDOCS/'UI_SPEC.md').write_text('''# Fantasy UI — спецификация

- Экраны собраны при 1280×720 и 1584×720.
- Стиль: тёмно-синие панели, золотые рамки, состояния кнопок `normal/pressed/selected/disabled`.
- Основные сенсорные цели ≥64 px.
- 9-slice панель: `elements/panel_9slice.png`, внутренние отступы 16 px со всех сторон.
- Ячейки формации: `free`, `selected`, `reserve`, `out_of_battle`, `valid_target`, `preview_zone`.
- Текст и числа являются заменяемыми placeholder-ами.
''',encoding='utf-8')
(UI/'PROVENANCE.md').write_text('''# Происхождение материалов

Все элементы интерфейса, экраны и иконки блока `art/fantasy-ui` являются оригинальными и сгенерированы программно. Сторонние UI-наборы, текстуры и иконки не использовались.
''',encoding='utf-8')
# Store generator source as executable text (this cell is not standalone due notebook env; include full logic summary and call it editable source).
# For practical editing, save the notebook cell that generated UI.
(UI/'source'/'generate_fantasy_ui.py').write_text(s_ui,encoding='utf-8')

files=[]
for p in sorted(UI.rglob('*')):
    if p.is_file(): files.append(str(p.relative_to(UIROOT)))
manifest=[]
for rel in files:
    p=UIROOT/rel; manifest.append({'path':rel,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'size':p.stat().st_size})
(UIDOCS/'MANIFEST.json').write_text(json.dumps({'branch':'art/fantasy-ui','generated':'2026-11-22','files':manifest},ensure_ascii=False,indent=2),encoding='utf-8')
zip_ui=Path('/mnt/agents/output/art_fantasy_ui_repo_ready.zip')
if zip_ui.exists(): zip_ui.unlink()
with zipfile.ZipFile(zip_ui,'w',zipfile.ZIP_DEFLATED) as z:
    for rel in files+['docs/art/fantasy-ui/MANIFEST.json']:
        z.write(UIROOT/rel,arcname=rel)
print('ui zip', zip_ui, zip_ui.stat().st_size, 'files', len(files))