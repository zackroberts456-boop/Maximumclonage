from pathlib import Path
from PIL import Image, ImageDraw
import math, random, struct, sys, wave

root=Path(sys.argv[1])

# ---------------------------------------------------------------------------
# 1) Platform/readability tiles — build on v0.7 without touching user sprites.
# ---------------------------------------------------------------------------
src=root/'res'/'gfx'/'lab_tiles_v07.png'
im=Image.open(src).convert('P')
pal=im.getpalette()
out=Image.new('P',(128,64),0); out.putpalette(pal); out.paste(im,(0,0))

def put(idx, drawfn, bg=3):
    t=Image.new('P',(8,8),bg); t.putpalette(pal)
    d=ImageDraw.Draw(t); drawfn(d,t)
    x=(idx%16)*8; y=(idx//16)*8
    out.paste(t,(x,y))

# solid floor left/mid/right and body
def solid_left(d,t):
    d.rectangle((0,0,7,7),fill=4); d.line((0,0,7,0),fill=15); d.line((0,1,7,1),fill=13); d.line((0,7,7,7),fill=2); d.point((2,4),fill=8); d.point((6,4),fill=8)
def solid_mid(d,t):
    d.rectangle((0,0,7,7),fill=4); d.line((0,0,7,0),fill=15); d.line((0,1,7,1),fill=13); d.line((0,7,7,7),fill=2); d.point((1,4),fill=8); d.point((6,4),fill=8)
def solid_right(d,t):
    solid_left(d,t); d.line((7,0,7,7),fill=8)
def solid_body(d,t):
    d.rectangle((0,0,7,7),fill=4); d.rectangle((1,1,6,6),outline=5); d.line((1,4,6,4),fill=3); d.point((2,2),fill=8); d.point((5,5),fill=13)
put(96,solid_left); put(97,solid_mid); put(98,solid_right); put(99,solid_body)

# one-way catwalk: brighter lip and visible underside
put(100,lambda d,t:(d.rectangle((0,0,7,2),fill=13),d.line((0,0,7,0),fill=15),d.line((0,3,7,3),fill=6),d.line((1,4,3,7),fill=5)))
put(101,lambda d,t:(d.rectangle((0,0,7,2),fill=13),d.line((0,0,7,0),fill=15),d.line((0,3,7,3),fill=6),d.line((0,6,7,6),fill=3)))
put(102,lambda d,t:(d.rectangle((0,0,7,2),fill=13),d.line((0,0,7,0),fill=15),d.line((0,3,7,3),fill=6),d.line((4,4,6,7),fill=5)))

# ladder rung + top/bottom joints
put(103,lambda d,t:(d.line((1,0,1,7),fill=13),d.line((6,0,6,7),fill=13),[d.line((1,y,6,y),fill=15) for y in (1,4,7)]),bg=2)
put(104,lambda d,t:(d.rectangle((0,0,7,1),fill=8),d.line((1,1,1,7),fill=13),d.line((6,1,6,7),fill=13),[d.line((1,y,6,y),fill=15) for y in (3,6)]),bg=2)

# toxic surface and checkpoint marker
put(105,lambda d,t:([d.line((x,7,x+3,1),fill=10 if (x//2)&1 else 15) for x in range(-2,8,4)],d.line((0,0,7,0),fill=14)),bg=3)
put(106,lambda d,t:(d.rectangle((2,0,5,7),fill=6),d.rectangle((1,1,6,4),outline=13),d.rectangle((2,1,5,3),fill=15),d.point((3,2),fill=14)),bg=2)

# boss approach / door accents
put(107,lambda d,t:([d.line((x,7,x+4,0),fill=14) for x in (-4,2,8)],d.line((0,0,7,0),fill=15)),bg=3)
put(108,lambda d,t:(d.rectangle((0,0,7,7),fill=2),d.rectangle((1,0,6,7),outline=8),d.line((3,0,3,7),fill=5),d.line((5,0,5,7),fill=5),d.point((2,3),fill=15)),bg=2)
put(109,lambda d,t:(d.rectangle((0,0,7,7),fill=3),d.polygon([(4,1),(7,6),(1,6)],fill=14),d.line((4,3,4,5),fill=15)),bg=3)

# support beam / foreground cable details
put(110,lambda d,t:(d.rectangle((2,0,5,7),fill=5),d.line((2,0,2,7),fill=13),d.line((5,0,5,7),fill=2),d.line((1,3,6,3),fill=8)),bg=2)
put(111,lambda d,t:(d.line((0,7,7,0),fill=6,width=2),d.line((0,0,7,7),fill=4),d.point((1,6),fill=13),d.point((6,1),fill=13)),bg=2)

# alternate platform/body variants 112..127
for idx in range(112,128):
    def mk(d,t,idx=idx):
        d.rectangle((0,0,7,7),fill=4 if idx&1 else 3)
        d.rectangle((0,0,7,7),outline=5)
        if idx&2: d.line((0,1,7,1),fill=13)
        if idx&4: d.line((1,5,6,5),fill=2)
        if idx&8: d.point((2,3),fill=8); d.point((5,3),fill=13)
    put(idx,mk)

out.info['transparency']=0
out.save(root/'res'/'gfx'/'lab_tiles_v08.png')

r=root/'res'/'resources.res'
rs=r.read_text(encoding='ascii')
rs=rs.replace('TILESET lab_tiles_v07 "gfx/lab_tiles_v07.png" NONE NONE','TILESET lab_tiles_v08 "gfx/lab_tiles_v08.png" NONE NONE')

# ---------------------------------------------------------------------------
# 2) Original lightweight Genesis PCM SFX. These are deliberately compact and
#    act as production placeholders until album/music audio assets are supplied.
# ---------------------------------------------------------------------------
sfxdir=root/'res'/'sfx'; sfxdir.mkdir(parents=True,exist_ok=True)
RATE=14000

def write_wav(name, seconds, generator):
    n=max(1,int(RATE*seconds))
    rng=random.Random(0xC10A + len(name))
    vals=[]
    for i in range(n):
        t=i/RATE
        v=max(-1.0,min(1.0,generator(t,i,n,rng)))
        vals.append(int(v*32767))
    with wave.open(str(sfxdir/name),'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(b''.join(struct.pack('<h',v) for v in vals))

def shot(t,i,n,rng):
    e=(1-i/n)**2.3
    noise=(rng.random()*2-1)*0.72
    thump=math.sin(2*math.pi*(120-50*i/n)*t)*0.65
    click=math.sin(2*math.pi*1200*t)*0.18
    return e*(noise+thump+click)*0.72

def jump(t,i,n,rng):
    x=i/n; e=math.sin(math.pi*min(1,x*1.25))*(1-x)
    f=170+430*x
    return (math.sin(2*math.pi*f*t)*0.52 + (rng.random()*2-1)*0.12)*e

def hurt(t,i,n,rng):
    x=i/n; e=(1-x)**1.8
    return e*(0.48*math.sin(2*math.pi*(150+40*math.sin(t*30))*t)+(rng.random()*2-1)*0.42)

def enemy(t,i,n,rng):
    x=i/n; e=(1-x)**1.6
    return e*(0.44*math.sin(2*math.pi*(420-210*x)*t)+(rng.random()*2-1)*0.34)

def boss_hit(t,i,n,rng):
    x=i/n; e=(1-x)**2.0
    return e*(0.48*math.sin(2*math.pi*95*t)+0.34*math.sin(2*math.pi*760*t)+(rng.random()*2-1)*0.32)

write_wav('shot.wav',0.085,shot)
write_wav('jump.wav',0.11,jump)
write_wav('hurt.wav',0.13,hurt)
write_wav('enemy.wav',0.09,enemy)
write_wav('boss_hit.wav',0.10,boss_hit)

rs += '\n# v0.8 original compact SFX placeholders\nWAV sfx_shot "sfx/shot.wav" XGM\nWAV sfx_jump "sfx/jump.wav" XGM\nWAV sfx_hurt "sfx/hurt.wav" XGM\nWAV sfx_enemy "sfx/enemy.wav" XGM\nWAV sfx_boss_hit "sfx/boss_hit.wav" XGM\n'
r.write_text(rs,encoding='ascii')

# ---------------------------------------------------------------------------
# 3) Runtime platform/readability overlay + event SFX.
# ---------------------------------------------------------------------------
g=root/'src'/'game.c'
s=g.read_text(encoding='utf-8')
s=s.replace('Stage 1 vertical slice v0.7','Stage 1 vertical slice v0.8')
s=s.replace('&lab_tiles_v07','&lab_tiles_v08')

# Add constants after shared animator declarations.
anchor='''static MCSharedAnimator sharedFeral[2];\n'''
insert='''\n#define SFX_SHOT_ID      64\n#define SFX_JUMP_ID      65\n#define SFX_HURT_ID      66\n#define SFX_ENEMY_ID     67\n#define SFX_BOSS_HIT_ID  68\n'''
if anchor not in s: raise SystemExit('v08 SFX constant anchor not found')
s=s.replace(anchor,anchor+insert,1)

# Foreground overlay inserted after v0.7 background motif block and before tile attrs.
needle='''        columnBuffer[y]=TILE_ATTR_FULL(\n            (code&0x80)?PAL1:PAL0,'''
overlay=r'''        if(map==mc_stage1_fg_visual && worldCol>=0){
            const s16 wx=worldCol<<3;
            const s16 wy=(s16)y<<3;
            u16 i;

            /* Bright, readable top surfaces derived from actual collision geometry. */
            for(i=0;i<mc_stage1_platform_count;i++){
                const MCPlatform *p=&mc_stage1_platforms[i];
                if(wx+8<=p->x || wx>=p->x+p->w) continue;

                if(wy==p->y){
                    const bool leftEdge=(wx<=p->x);
                    const bool rightEdge=(wx+8>=p->x+p->w);
                    if(p->kind==MC_PLATFORM_ONEWAY)
                        code=leftEdge?100:(rightEdge?102:101);
                    else
                        code=leftEdge?96:(rightEdge?98:97);
                } else if(p->kind==MC_PLATFORM_SOLID && wy>p->y && wy<p->y+p->h){
                    code=((worldCol+y)&3)==0?112:99;
                }
            }

            for(i=0;i<mc_stage1_ladder_count;i++){
                const MCLadder *l=&mc_stage1_ladders[i];
                if(wx+8<=l->x || wx>=l->x+l->w) continue;
                if(wy>=l->top && wy<l->bottom)
                    code=(wy==l->top)?104:103;
            }

            for(i=0;i<mc_stage1_hazard_count;i++){
                const MCHazard *h=&mc_stage1_hazards[i];
                if(wx+8>h->x && wx<h->x+h->w && wy==h->y)
                    code=0x80|105;
            }

            for(i=1;i<mc_stage1_checkpoint_count;i++){
                const MCCheckpoint *cp=&mc_stage1_checkpoints[i];
                if(wx<=cp->x && wx+8>cp->x && wy>=160 && wy<200)
                    code=106;
            }

            /* Boss approach reads as a deliberate transition, not more hallway. */
            if(worldCol>=354 && worldCol<360 && (wy==192 || wy==200))
                code=((worldCol+y)&1)?107:109;
        }

        columnBuffer[y]=TILE_ATTR_FULL(
            (code&0x80)?PAL1:PAL0,'''
if needle not in s: raise SystemExit('v08 foreground overlay anchor not found')
s=s.replace(needle,overlay,1)

# Register SFX alongside input setup.
needle='''    initFailed=!setup_sprites();\n    JOY_init();'''
repl='''    initFailed=!setup_sprites();\n    JOY_init();\n\n    /* XGM keeps channel 1 available for future music; action SFX use 2..4. */\n    XGM_setPCM(SFX_SHOT_ID,sfx_shot,sizeof(sfx_shot));\n    XGM_setPCM(SFX_JUMP_ID,sfx_jump,sizeof(sfx_jump));\n    XGM_setPCM(SFX_HURT_ID,sfx_hurt,sizeof(sfx_hurt));\n    XGM_setPCM(SFX_ENEMY_ID,sfx_enemy,sizeof(sfx_enemy));\n    XGM_setPCM(SFX_BOSS_HIT_ID,sfx_boss_hit,sizeof(sfx_boss_hit));'''
if needle not in s: raise SystemExit('v08 PCM init anchor not found')
s=s.replace(needle,repl,1)

# Hurt event.
needle='''    player.hp -= amount;\n    player.invuln=IFRAMES;'''
repl='''    player.hp -= amount;\n    XGM_startPlayPCM(SFX_HURT_ID,12,SOUND_PCM_CH4);\n    player.invuln=IFRAMES;'''
if needle not in s: raise SystemExit('v08 hurt anchor not found')
s=s.replace(needle,repl,1)

# Jump from ladder and ground.
needle='''    } else if(pressed(BUTTON_C) && player.onLadder){\n        player.onLadder=FALSE;\n        player.vy=JUMP_SPEED;\n    } else if(pressed(BUTTON_C) && player.grounded){\n        player.vy=JUMP_SPEED;\n        player.grounded=FALSE;\n    }'''
repl='''    } else if(pressed(BUTTON_C) && player.onLadder){\n        player.onLadder=FALSE;\n        player.vy=JUMP_SPEED;\n        XGM_startPlayPCM(SFX_JUMP_ID,8,SOUND_PCM_CH3);\n    } else if(pressed(BUTTON_C) && player.grounded){\n        player.vy=JUMP_SPEED;\n        player.grounded=FALSE;\n        XGM_startPlayPCM(SFX_JUMP_ID,8,SOUND_PCM_CH3);\n    }'''
if needle not in s: raise SystemExit('v08 jump anchor not found')
s=s.replace(needle,repl,1)

# Shot event.
needle='''    player.fireCd=SHOTGUN_COOLDOWN;\n    player.shootAnim=6;'''
repl='''    player.fireCd=SHOTGUN_COOLDOWN;\n    player.shootAnim=6;\n    XGM_startPlayPCM(SFX_SHOT_ID,6,SOUND_PCM_CH2);'''
if needle not in s: raise SystemExit('v08 shot anchor not found')
s=s.replace(needle,repl,1)

# Enemy fire: low priority so movement/hurt feedback wins.
needle='''static void enemy_fire(MCEnemy *e)\n{\n    const s16 px='''
repl='''static void enemy_fire(MCEnemy *e)\n{\n    XGM_startPlayPCM(SFX_ENEMY_ID,3,SOUND_PCM_CH3);\n    const s16 px='''
if needle not in s: raise SystemExit('v08 enemy fire anchor not found')
s=s.replace(needle,repl,1)

# Boss hit event.
needle='''        boss.hp-=b->damage;\n        deactivate_bullet(b);'''
repl='''        boss.hp-=b->damage;\n        XGM_startPlayPCM(SFX_BOSS_HIT_ID,9,SOUND_PCM_CH3);\n        deactivate_bullet(b);'''
if needle not in s: raise SystemExit('v08 boss hit anchor not found')
s=s.replace(needle,repl,1)

g.write_text(s,encoding='utf-8')
print('v0.8 platform-readability and audio transformation complete')
