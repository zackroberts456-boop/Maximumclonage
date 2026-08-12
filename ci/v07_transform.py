from pathlib import Path
from PIL import Image, ImageDraw
import sys

root=Path(sys.argv[1])

# ---------------------------------------------------------------------------
# Expand the original Maximum Clonage lab tiles with original Genesis-native
# detail tiles. These do NOT come from any commercial reference ROM.
# ---------------------------------------------------------------------------
src=root/'res'/'gfx'/'lab_tiles_v04.png'
im=Image.open(src).convert('P')
pal=im.getpalette()
# 16 tiles wide. Grow from 4 rows (64 tiles) to 6 rows (96 tiles).
out=Image.new('P',(128,48),0); out.putpalette(pal); out.paste(im,(0,0))

def tile(index):
    x=(index%16)*8; y=(index//16)*8
    t=Image.new('P',(8,8),3); t.putpalette(pal)
    return x,y,t

def put(index,t):
    x=(index%16)*8; y=(index//16)*8
    out.paste(t,(x,y))

# 64 hazard chevron
t=Image.new('P',(8,8),3); t.putpalette(pal); d=ImageDraw.Draw(t)
for y in range(8):
    for x in range(8):
        if ((x+y)//2)&1: t.putpixel((x,y),14)
        elif (x+y)%4==0: t.putpixel((x,y),15)
put(64,t)
# 65 small warning lamp
t=Image.new('P',(8,8),3); t.putpalette(pal); d=ImageDraw.Draw(t)
d.rectangle((1,1,6,6),fill=6); d.rectangle((2,2,5,5),fill=4); d.rectangle((3,3,4,4),fill=15)
put(65,t)
# 66 vent grille
t=Image.new('P',(8,8),4); t.putpalette(pal); d=ImageDraw.Draw(t)
d.rectangle((0,0,7,7),outline=8); [d.line((2,y,5,y),fill=3) for y in (2,4,6)]; d.point((1,1),fill=13); d.point((6,1),fill=13)
put(66,t)
# 67 riveted plate
t=Image.new('P',(8,8),4); t.putpalette(pal); d=ImageDraw.Draw(t)
d.rectangle((0,0,7,7),outline=5); d.line((1,3,6,3),fill=3); d.point((1,1),fill=13); d.point((6,1),fill=13); d.point((1,6),fill=8); d.point((6,6),fill=8)
put(67,t)
# 68 cracked panel
t=Image.new('P',(8,8),4); t.putpalette(pal); d=ImageDraw.Draw(t)
d.rectangle((0,0,7,7),outline=5); d.line((5,0,3,3,5,4,2,7),fill=8)
put(68,t)
# 69 vertical pipe
t=Image.new('P',(8,8),2); t.putpalette(pal); d=ImageDraw.Draw(t)
d.rectangle((2,0,5,7),fill=6); d.line((2,0,2,7),fill=13); d.line((5,0,5,7),fill=3); d.line((1,2,6,2),fill=8); d.line((1,5,6,5),fill=8)
put(69,t)
# 70 horizontal pipe
t=Image.new('P',(8,8),2); t.putpalette(pal); d=ImageDraw.Draw(t)
d.rectangle((0,2,7,5),fill=6); d.line((0,2,7,2),fill=13); d.line((0,5,7,5),fill=3); d.line((2,1,2,6),fill=8); d.line((5,1,5,6),fill=8)
put(70,t)
# 71 pipe junction
t=Image.new('P',(8,8),2); t.putpalette(pal); d=ImageDraw.Draw(t)
d.rectangle((2,0,5,7),fill=6); d.rectangle((0,2,7,5),fill=6); d.rectangle((2,2,5,5),fill=13); d.rectangle((3,3,4,4),fill=5)
put(71,t)
# 72 small terminal
t=Image.new('P',(8,8),3); t.putpalette(pal); d=ImageDraw.Draw(t)
d.rectangle((0,0,7,7),outline=8); d.rectangle((1,1,6,4),fill=2); d.line((2,2,5,2),fill=15); d.point((2,6),fill=14); d.point((4,6),fill=12); d.point((6,6),fill=8)
put(72,t)
# 73/74/75 clone-vat cap/body/base (palette 1 flag makes the body green)
for idx,kind in [(73,'top'),(74,'mid'),(75,'bot')]:
    t=Image.new('P',(8,8),2); t.putpalette(pal); d=ImageDraw.Draw(t)
    if kind=='top':
        d.rectangle((1,2,6,7),fill=5); d.rectangle((2,3,5,7),fill=10); d.line((1,2,6,2),fill=13)
    elif kind=='mid':
        d.rectangle((1,0,6,7),fill=5); d.rectangle((2,0,5,7),fill=10); d.line((2,0,2,7),fill=13); d.point((4,3),fill=15)
    else:
        d.rectangle((1,0,6,5),fill=5); d.rectangle((2,0,5,4),fill=10); d.line((1,5,6,5),fill=13); d.rectangle((0,6,7,7),fill=6)
    put(idx,t)
# 76 cable bundle
t=Image.new('P',(8,8),1); t.putpalette(pal); d=ImageDraw.Draw(t)
d.line((1,0,2,2,1,5,3,7),fill=8); d.line((4,0,5,3,4,5,6,7),fill=5); d.point((2,3),fill=14)
put(76,t)
# 77 hazard plate / warning sign
t=Image.new('P',(8,8),4); t.putpalette(pal); d=ImageDraw.Draw(t)
d.polygon([(4,1),(7,6),(1,6)],fill=14); d.polygon([(4,2),(6,5),(2,5)],fill=3); d.line((4,3,4,4),fill=15); d.point((4,5),fill=15)
put(77,t)
# 78 conduit block
t=Image.new('P',(8,8),4); t.putpalette(pal); d=ImageDraw.Draw(t)
d.rectangle((0,0,7,7),outline=5); d.arc((1,1,6,6),0,270,fill=13); d.rectangle((3,3,6,6),fill=3); d.point((5,5),fill=15)
put(78,t)
# 79 dark structural brace
t=Image.new('P',(8,8),2); t.putpalette(pal); d=ImageDraw.Draw(t)
d.line((0,7,7,0),fill=6,width=2); d.line((0,0,7,7),fill=4); d.point((1,6),fill=13); d.point((6,1),fill=13)
put(79,t)
# 80 scanline monitor
t=Image.new('P',(8,8),3); t.putpalette(pal); d=ImageDraw.Draw(t)
d.rectangle((0,0,7,7),outline=8); d.rectangle((1,1,6,5),fill=2); d.line((2,2,5,2),fill=12); d.line((2,4,4,4),fill=15); d.rectangle((2,6,5,7),fill=5)
put(80,t)
# 81 chained plate
t=Image.new('P',(8,8),3); t.putpalette(pal); d=ImageDraw.Draw(t)
d.line((1,0,6,7),fill=8); d.line((6,0,1,7),fill=8); d.point((3,3),fill=15); d.point((4,4),fill=14)
put(81,t)
# Fill remaining expansion tiles with subtle alternates rather than blank memory.
for idx in range(82,96):
    t=Image.new('P',(8,8),4 if idx&1 else 3); t.putpalette(pal); d=ImageDraw.Draw(t)
    d.rectangle((0,0,7,7),outline=5 if idx&2 else 6)
    d.point((1,1),fill=8); d.point((6,6),fill=13)
    if idx&4: d.line((1,4,6,4),fill=2)
    if idx&8: d.line((4,1,4,6),fill=8)
    put(idx,t)

out.info['transparency']=0
out.save(root/'res'/'gfx'/'lab_tiles_v07.png')

# Switch the resource name to the expanded tileset.
r=root/'res'/'resources.res'
rs=r.read_text(encoding='ascii')
rs=rs.replace('TILESET lab_tiles_v05 "gfx/lab_tiles_v04.png" NONE NONE','TILESET lab_tiles_v07 "gfx/lab_tiles_v07.png" NONE NONE')
r.write_text(rs,encoding='ascii')

# ---------------------------------------------------------------------------
# Runtime visual composition and HUD cleanup.
# ---------------------------------------------------------------------------
g=root/'src'/'game.c'
s=g.read_text(encoding='utf-8')
s=s.replace('Stage 1 vertical slice v0.6','Stage 1 vertical slice v0.7')
s=s.replace('&lab_tiles_v05','&lab_tiles_v07')

old='''        if(worldCol>=0 && worldCol<MC_STAGE1_VISUAL_W)\n            code=map[(y*MC_STAGE1_VISUAL_W)+worldCol];\n        columnBuffer[y]=TILE_ATTR_FULL('''
new='''        if(worldCol>=0 && worldCol<MC_STAGE1_VISUAL_W)\n            code=map[(y*MC_STAGE1_VISUAL_W)+worldCol];\n\n        /* v0.7: break up plain far-wall repetition with authored procedural\n         * facility motifs. Only replace the old neutral wall tile so the\n         * existing vats, platforms and structural art remain intact. */\n        if(map==mc_stage1_bg_visual && worldCol>=0 && y>=5 && y<=21 && (code&0x7F)==1){\n            const u16 local=(u16)worldCol%40;\n            const u16 zone=((u16)worldCol/40)%5;\n\n            if(zone==0){\n                if(local>=7 && local<=10 && y>=7 && y<=9) code=(y==7)?80:67;\n                else if(local==28 && y>=6 && y<=19) code=69;\n                else if(local==29 && (y==9 || y==15)) code=71;\n            } else if(zone==1){\n                if(local>=18 && local<=21 && y>=8 && y<=15){\n                    if(y==8) code=0x80|73;\n                    else if(y==15) code=0x80|75;\n                    else code=0x80|74;\n                } else if(local==6 && y>=6 && y<=18) code=76;\n                else if(local==7 && y==12) code=65;\n            } else if(zone==2){\n                if(local>=5 && local<=32 && y==16) code=((local>>1)&1)?64:67;\n                else if(local==11 && y>=6 && y<=20) code=69;\n                else if(local>=26 && local<=28 && y>=8 && y<=10) code=72;\n            } else if(zone==3){\n                if(local==9 && y>=5 && y<=20) code=69;\n                else if(local>=10 && local<=27 && (y==6 || y==20)) code=70;\n                else if((local==10 || local==27) && (y==6 || y==20)) code=71;\n                else if(local==31 && y==9) code=77;\n                else if(local==32 && y==9) code=68;\n            } else {\n                if(local>=15 && local<=18 && y>=9 && y<=11) code=80;\n                else if(local==4 && y>=6 && y<=20) code=76;\n                else if(local==30 && y>=7 && y<=18) code=79;\n                else if(local==31 && (y==8 || y==17)) code=78;\n            }\n        }\n\n        columnBuffer[y]=TILE_ATTR_FULL('''
if old not in s: raise SystemExit('visual column anchor not found')
s=s.replace(old,new,1)

s=s.replace('VDP_drawTextFill("KILLING FLOOR",24,0,16);','VDP_drawTextFill("KILL FLOOR 12G",24,0,16);')

oldhud='''    if(bossLive && boss.telegraph){\n        if(hudPattern!=boss.pattern){\n            sprintf(buf,"WARNING: %s",rotor_pattern_name());\n            VDP_drawTextFill(buf,1,1,38);\n            hudPattern=boss.pattern;\n        }\n    } else if(hudPattern!=255){\n        VDP_drawTextFill("",1,1,38);\n        hudPattern=255;\n    } else if(!bossLive && hudMode==255){\n        VDP_drawTextFill("ENTER THE KILLING FLOOR",8,1,31);\n    }'''
newhud='''    if(bossLive && boss.telegraph){\n        if(hudPattern!=boss.pattern){\n            sprintf(buf,"WARNING // %s",rotor_pattern_name());\n            VDP_drawTextFill(buf,1,1,38);\n            hudPattern=boss.pattern;\n        }\n    } else if(!bossLive && frameCounter<180){\n        if(hudPattern!=254){\n            VDP_drawTextFill("STAGE 01 // ENTER THE KILLING FLOOR",1,1,38);\n            hudPattern=254;\n        }\n    } else if(hudPattern!=255){\n        VDP_drawTextFill("",1,1,38);\n        hudPattern=255;\n    }'''
if oldhud not in s: raise SystemExit('HUD banner anchor not found')
s=s.replace(oldhud,newhud,1)

g.write_text(s,encoding='utf-8')

print('v0.7 visual/HUD transformation complete')
