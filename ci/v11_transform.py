from pathlib import Path
from PIL import Image, ImageDraw
import sys

root=Path(sys.argv[1])

# ---------------------------------------------------------------------------
# Compact shared spark sprite: 16x16, one frame, four tiles in a single shared
# VRAM slot. Four runtime spark actors can point at the same tile data.
# ---------------------------------------------------------------------------
sprdir=root/'res'/'sprite'
ref=Image.open(sprdir/'bullet_genesis_v05.png').convert('P')
pal=ref.getpalette()
spark=Image.new('P',(16,16),0); spark.putpalette(pal)
d=ImageDraw.Draw(spark)
# Sharp 16-bit starburst: transparent background, bright core and diagonal rays.
d.rectangle((7,2,8,13),fill=15)
d.rectangle((2,7,13,8),fill=15)
d.line((4,4,11,11),fill=14,width=2)
d.line((11,4,4,11),fill=14,width=2)
d.rectangle((6,6,9,9),fill=13)
d.point((7,7),fill=15); d.point((8,8),fill=15)
spark.info['transparency']=0
spark.save(sprdir/'spark_genesis_v11.png')

r=root/'res'/'resources.res'
rs=r.read_text(encoding='ascii')
rs += 'SPRITE spr_spark "sprite/spark_genesis_v11.png" 2 2 NONE 0 NONE NONE FAST FALSE\n'
r.write_text(rs,encoding='ascii')

g=root/'src'/'game.c'
s=g.read_text(encoding='utf-8')
s=s.replace('Stage 1 vertical slice v1.0','Stage 1 vertical slice v1.1')

# Effect structure/pool.
anchor='''typedef struct {\n    bool active;\n    bool dead;\n    s16 x, y;\n    s16 hp, maxHp;\n    s16 vx, vy;\n    s16 attackCd;\n    s16 telegraph;\n    u8 phase;\n    u8 pattern;\n    u8 patternCycle;\n    Sprite *spr;\n} MCBoss;\n'''
insert=r'''

typedef struct {
    bool active;
    s16 x,y;
    u8 timer;
    u8 variant;
    Sprite *spr;
} MCEffect;
'''
if anchor not in s: raise SystemExit('v11 boss typedef anchor not found')
s=s.replace(anchor,anchor+insert,1)

anchor='''static MCBoss boss;\n'''
insert='''static MCEffect effects[4];\n'''
if anchor not in s: raise SystemExit('v11 boss static anchor not found')
s=s.replace(anchor,anchor+insert,1)

# Shared VRAM extends only four tiles.
s=s.replace('#define SPR_SLOT_ACID        394\n#define SPR_VRAM_REQUIRED    395',
            '#define SPR_SLOT_ACID        394\n#define SPR_SLOT_SPARK       395\n#define SPR_VRAM_REQUIRED    399')

# Shake state after frame counters.
anchor='''static u16 clearTimer = 0;\n'''
insert='''static u8 cameraShakeTimer=0;\nstatic u8 cameraShakePower=0;\n'''
if anchor not in s: raise SystemExit('v11 shake state anchor not found')
s=s.replace(anchor,anchor+insert,1)

# Effect helpers after hide_sprite.
anchor='''static void hide_sprite(Sprite *spr)\n{\n    if (spr) SPR_setPosition(spr, -96, -96);\n}\n'''
insert=r'''

static void trigger_shake(u8 power,u8 timer)
{
    if(power>cameraShakePower) cameraShakePower=power;
    if(timer>cameraShakeTimer) cameraShakeTimer=timer;
}

static s16 render_camera_x(void)
{
    if(!cameraShakeTimer) return cameraX;
    return cameraX + ((frameCounter&1)?(s16)cameraShakePower:-(s16)cameraShakePower);
}

static void spawn_spark(s16 x,s16 y,u8 timer)
{
    u16 i;
    for(i=0;i<4;i++){
        MCEffect *fx=&effects[i];
        if(fx->active) continue;
        fx->active=TRUE;
        fx->x=x;
        fx->y=y;
        fx->timer=timer;
        fx->variant=(u8)(frameCounter+i)&3;
        return;
    }
}

static void spawn_impact_pair(s16 x,s16 y)
{
    spawn_spark(x-5,y-4,6);
    spawn_spark(x+5,y+3,5);
}

static void update_effects(void)
{
    u16 i;
    if(cameraShakeTimer){
        cameraShakeTimer--;
        if(!cameraShakeTimer) cameraShakePower=0;
    }

    for(i=0;i<4;i++){
        MCEffect *fx=&effects[i];
        if(!fx->active) continue;
        if(fx->timer) fx->timer--;
        if(!fx->timer){
            fx->active=FALSE;
            hide_sprite(fx->spr);
        }
    }
}
'''
if anchor not in s: raise SystemExit('v11 helper insertion anchor not found')
s=s.replace(anchor,anchor+insert,1)

# Clear effects/reset shake with projectile clear at respawn/restart.
anchor='''static void clear_projectiles(void)\n{\n    u16 i;\n    for(i=0;i<MAX_PBULLETS;i++) deactivate_bullet(&pbullets[i]);\n    for(i=0;i<MAX_EBULLETS;i++) deactivate_bullet(&ebullets[i]);\n}\n'''
repl=r'''static void clear_projectiles(void)
{
    u16 i;
    for(i=0;i<MAX_PBULLETS;i++) deactivate_bullet(&pbullets[i]);
    for(i=0;i<MAX_EBULLETS;i++) deactivate_bullet(&ebullets[i]);
    for(i=0;i<4;i++){
        effects[i].active=FALSE;
        hide_sprite(effects[i].spr);
    }
    cameraShakeTimer=0;
    cameraShakePower=0;
}
'''
if anchor not in s: raise SystemExit('v11 clear_projectiles anchor not found')
s=s.replace(anchor,repl,1)

# Player hurt: flash/shake exactly once per registered hit.
needle='''    player.hp -= amount;\n    sfx_play_hurt();\n    player.invuln=IFRAMES;'''
repl='''    player.hp -= amount;\n    sfx_play_hurt();\n    spawn_impact_pair(FROM_FP(player.x)+PLAYER_W/2,FROM_FP(player.y)+PLAYER_H/2);\n    trigger_shake(3,10);\n    player.invuln=IFRAMES;'''
if needle not in s: raise SystemExit('v11 hurt anchor not found')
s=s.replace(needle,repl,1)

# Muzzle flash after shotgun event. Use world-space aim vector.
needle='''    player.fireCd=SHOTGUN_COOLDOWN;\n    player.shootAnim=6;\n    sfx_play_shot();'''
repl='''    player.fireCd=SHOTGUN_COOLDOWN;\n    player.shootAnim=6;\n    sfx_play_shot();\n    spawn_spark(FROM_FP(player.x)+PLAYER_W/2+(player.aimX*15),\n                FROM_FP(player.y)+18+(player.aimY*11),4);'''
if needle not in s: raise SystemExit('v11 muzzle anchor not found')
s=s.replace(needle,repl,1)

# Every player projectile impact creates feedback before it is deactivated.
# Enemy hit routine contains a single hp decrement path.
needle='''        e->hp-=b->damage;\n        deactivate_bullet(b);'''
repl='''        e->hp-=b->damage;\n        spawn_spark(b->x,b->y,5);\n        deactivate_bullet(b);'''
if needle not in s: raise SystemExit('v11 enemy hit anchor not found')
s=s.replace(needle,repl,1)

# Enemy death adds a second spark and light shake. Match both death branches if present.
s=s.replace('''                e->dead=TRUE;\n                e->active=FALSE;\n                e->anim=2;''',
            '''                e->dead=TRUE;\n                e->active=FALSE;\n                spawn_impact_pair(e->x,e->surfaceY-26);\n                trigger_shake(1,4);\n                e->anim=2;''')
s=s.replace('''            e->active=FALSE;\n            e->dead=TRUE;\n            e->anim=2;''',
            '''            e->active=FALSE;\n            e->dead=TRUE;\n            spawn_impact_pair(e->x,e->surfaceY-26);\n            trigger_shake(1,4);\n            e->anim=2;''')

# Boss hit feedback and death punch.
needle='''        boss.hp-=b->damage;\n        sfx_play_boss_hit();\n        deactivate_bullet(b);'''
repl='''        boss.hp-=b->damage;\n        sfx_play_boss_hit();\n        spawn_impact_pair(b->x,b->y);\n        trigger_shake(1,3);\n        deactivate_bullet(b);'''
if needle not in s: raise SystemExit('v11 boss hit anchor not found')
s=s.replace(needle,repl,1)
s=s.replace('''            boss.dead=TRUE;\n            if(boss.spr) SPR_setAnim(boss.spr,1);''',
            '''            boss.dead=TRUE;\n            spawn_impact_pair(boss.x+32,boss.y+28);\n            trigger_shake(4,28);\n            if(boss.spr) SPR_setAnim(boss.spr,1);''')

# Render with visual camera offset but keep streaming keyed to logical cameraX.
s=s.replace('''    const s16 fgTile=cameraX>>3;\n    const s16 bgPixel=cameraX>>1;\n    const s16 bgTile=bgPixel>>3;''',
            '''    const s16 renderCam=render_camera_x();\n    const s16 fgTile=cameraX>>3;\n    const s16 bgPixel=cameraX>>1;\n    const s16 bgTile=bgPixel>>3;''')
s=s.replace('VDP_setHorizontalScroll(BG_A,-cameraX);\n    VDP_setHorizontalScroll(BG_B,-bgPixel);',
            'VDP_setHorizontalScroll(BG_A,-renderCam);\n    VDP_setHorizontalScroll(BG_B,-(renderCam>>1));')

# Player/entity x positions use render camera during shake.
s=s.replace('''    s16 sx=FROM_FP(player.x)-cameraX-14;''','''    const s16 renderCam=render_camera_x();\n    s16 sx=FROM_FP(player.x)-renderCam-14;''')
# Render entities gets one local renderCam and swaps x-position references.
anchor='''static void render_entities(void)\n{\n    u16 i;'''
repl='''static void render_entities(void)\n{\n    u16 i;\n    const s16 renderCam=render_camera_x();'''
if anchor not in s: raise SystemExit('v11 render entities anchor not found')
s=s.replace(anchor,repl,1)
s=s.replace('e->x-cameraX-17','e->x-renderCam-17')
s=s.replace('e->x-cameraX-16','e->x-renderCam-16')
s=s.replace('b->x-cameraX-4','b->x-renderCam-4')
s=s.replace('boss.x-cameraX-12','boss.x-renderCam-12')

# Append effect rendering before boss sprite rendering in render_entities.
needle='''    if(boss.active&&!boss.dead)\n        SPR_setPosition(boss.spr,boss.x-renderCam-12,boss.y);'''
repl=r'''    for(i=0;i<4;i++){
        MCEffect *fx=&effects[i];
        if(!fx->active){
            hide_sprite(fx->spr);
            continue;
        }
        SPR_setHFlip(fx->spr,(fx->variant&1)!=0);
        SPR_setVFlip(fx->spr,(fx->variant&2)!=0);
        if((fx->timer&1) || fx->timer>3)
            SPR_setPosition(fx->spr,fx->x-renderCam-8,fx->y-8);
        else
            hide_sprite(fx->spr);
    }

    if(boss.active&&!boss.dead)
        SPR_setPosition(boss.spr,boss.x-renderCam-12,boss.y);'''
if needle not in s: raise SystemExit('v11 effect render anchor not found')
s=s.replace(needle,repl,1)

# Setup shared spark tile and four manual actors.
needle='''    VDP_loadTileSet(spr_acid.animations[0]->frames[0]->tileset,\n                    spriteBase+SPR_SLOT_ACID,DMA);'''
repl='''    VDP_loadTileSet(spr_acid.animations[0]->frames[0]->tileset,\n                    spriteBase+SPR_SLOT_ACID,DMA);\n    VDP_loadTileSet(spr_spark.animations[0]->frames[0]->tileset,\n                    spriteBase+SPR_SLOT_SPARK,DMA);'''
if needle not in s: raise SystemExit('v11 spark tileset setup anchor not found')
s=s.replace(needle,repl,1)

needle='''    boss.spr=add_manual_sprite(&spr_rotor,-96,-96,PAL3,\n                               spriteBase+SPR_SLOT_ROTOR,TRUE);'''
insert=r'''    for(i=0;i<4;i++){
        effects[i].spr=add_manual_sprite(&spr_spark,-96,-96,PAL2,
                                         spriteBase+SPR_SLOT_SPARK,FALSE);
        if(!effects[i].spr) ok=FALSE;
        else SPR_setAutoAnimation(effects[i].spr,FALSE);
        effects[i].active=FALSE;
    }

'''
if needle not in s: raise SystemExit('v11 boss setup anchor not found')
s=s.replace(needle,insert+needle,1)

# Per-frame timers update before render.
needle='''    update_camera();\n    update_shared_enemy_animations();'''
repl='''    update_camera();\n    update_effects();\n    update_shared_enemy_animations();'''
if needle not in s: raise SystemExit('v11 frame update anchor not found')
s=s.replace(needle,repl,1)

g.write_text(s,encoding='utf-8')
print('v1.1 combat impact / shared-spark transformation complete')
