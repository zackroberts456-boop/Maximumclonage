from pathlib import Path
from PIL import Image, ImageDraw
import sys

root=Path(sys.argv[1])
sprdir=root/'res'/'sprite'

# 16x16 shared impact/muzzle flash, using the existing player-bullet palette.
ref=Image.open(sprdir/'bullet_genesis_v05.png').convert('P')
pal=ref.getpalette()
spark=Image.new('P',(16,16),0); spark.putpalette(pal)
d=ImageDraw.Draw(spark)
d.rectangle((7,1,8,14),fill=15)
d.rectangle((1,7,14,8),fill=15)
d.line((3,3,12,12),fill=14,width=2)
d.line((12,3,3,12),fill=14,width=2)
d.rectangle((6,6,9,9),fill=13)
spark.info['transparency']=0
spark.save(sprdir/'spark_genesis_v11.png')

r=root/'res'/'resources.res'
rs=r.read_text(encoding='ascii')
if 'SPRITE spr_spark ' not in rs:
    rs += 'SPRITE spr_spark "sprite/spark_genesis_v11.png" 2 2 NONE 0 NONE NONE FAST FALSE\n'
r.write_text(rs,encoding='ascii')

g=root/'src'/'game.c'
s=g.read_text(encoding='utf-8')
s=s.replace('Stage 1 vertical slice v1.0','Stage 1 vertical slice v1.1')

def rep(old,new,label,count=1):
    global s
    if old not in s:
        raise SystemExit(f'v11b missing anchor: {label}')
    s=s.replace(old,new,count)

# Runtime effect type/pool.
rep('''} MCBoss;\n\nstatic MCPlayer player;''','''} MCBoss;\n\ntypedef struct {\n    bool active;\n    s16 x,y;\n    u8 timer;\n    u8 variant;\n    Sprite *spr;\n} MCEffect;\n\nstatic MCPlayer player;''','effect typedef')
rep('''static MCBoss boss;\n''','''static MCBoss boss;\nstatic MCEffect effects[4];\n''','effect pool')
rep('''#define SPR_SLOT_ACID        394\n#define SPR_VRAM_REQUIRED    395''','''#define SPR_SLOT_ACID        394\n#define SPR_SLOT_SPARK       395\n#define SPR_VRAM_REQUIRED    399''','spark vram')
rep('''static u16 clearTimer = 0;\n''','''static u16 clearTimer = 0;\nstatic u8 cameraShakeTimer=0;\nstatic u8 cameraShakePower=0;\n''','shake state')

# Helpers directly after hide_sprite().
rep('''static void hide_sprite(Sprite *spr)\n{\n    if (spr) SPR_setPosition(spr, -96, -96);\n}\n''','''static void hide_sprite(Sprite *spr)\n{\n    if (spr) SPR_setPosition(spr, -96, -96);\n}\n\nstatic void trigger_shake(u8 power,u8 timer)\n{\n    if(power>cameraShakePower) cameraShakePower=power;\n    if(timer>cameraShakeTimer) cameraShakeTimer=timer;\n}\n\nstatic s16 render_camera_x(void)\n{\n    if(!cameraShakeTimer) return cameraX;\n    return cameraX + ((frameCounter&1)?(s16)cameraShakePower:-(s16)cameraShakePower);\n}\n\nstatic void spawn_spark(s16 x,s16 y,u8 timer)\n{\n    u16 i;\n    for(i=0;i<4;i++){\n        MCEffect *fx=&effects[i];\n        if(fx->active) continue;\n        fx->active=TRUE;\n        fx->x=x; fx->y=y; fx->timer=timer;\n        fx->variant=(u8)((frameCounter+i)&3);\n        return;\n    }\n}\n\nstatic void spawn_impact_pair(s16 x,s16 y)\n{\n    spawn_spark(x-5,y-4,6);\n    spawn_spark(x+5,y+3,5);\n}\n\nstatic void update_effects(void)\n{\n    u16 i;\n    if(cameraShakeTimer){\n        cameraShakeTimer--;\n        if(!cameraShakeTimer) cameraShakePower=0;\n    }\n    for(i=0;i<4;i++){\n        MCEffect *fx=&effects[i];\n        if(!fx->active) continue;\n        if(fx->timer) fx->timer--;\n        if(!fx->timer){ fx->active=FALSE; hide_sprite(fx->spr); }\n    }\n}\n''','effect helpers')

# Reset visual feedback with projectiles.
rep('''static void clear_projectiles(void)\n{\n    u16 i;\n    for(i=0;i<MAX_PBULLETS;i++) deactivate_bullet(&pbullets[i]);\n    for(i=0;i<MAX_EBULLETS;i++) deactivate_bullet(&ebullets[i]);\n}\n''','''static void clear_projectiles(void)\n{\n    u16 i;\n    for(i=0;i<MAX_PBULLETS;i++) deactivate_bullet(&pbullets[i]);\n    for(i=0;i<MAX_EBULLETS;i++) deactivate_bullet(&ebullets[i]);\n    for(i=0;i<4;i++){ effects[i].active=FALSE; hide_sprite(effects[i].spr); }\n    cameraShakeTimer=0;\n    cameraShakePower=0;\n}\n''','clear feedback')

# Player hit and muzzle feedback.
rep('''    player.hp -= amount;\n    sfx_play_hurt();\n    player.invuln=IFRAMES;''','''    player.hp -= amount;\n    sfx_play_hurt();\n    spawn_impact_pair(FROM_FP(player.x)+PLAYER_W/2,FROM_FP(player.y)+PLAYER_H/2);\n    trigger_shake(3,10);\n    player.invuln=IFRAMES;''','player impact')
rep('''    player.fireCd=SHOTGUN_COOLDOWN;\n    player.shootAnim=6;\n    sfx_play_shot();''','''    player.fireCd=SHOTGUN_COOLDOWN;\n    player.shootAnim=6;\n    sfx_play_shot();\n    spawn_spark(FROM_FP(player.x)+PLAYER_W/2+(player.aimX*15),\n                FROM_FP(player.y)+18+(player.aimY*11),4);''','muzzle flash')

# Projectile impact / enemy kill feedback, exact v1.0 indentation.
rep('''            e->hp-=b->damage;\n            deactivate_bullet(b);''','''            e->hp-=b->damage;\n            spawn_spark(b->x,b->y,5);\n            deactivate_bullet(b);''','enemy bullet hit')
rep('''                e->dead=TRUE;\n                e->active=FALSE;\n                e->anim=2;''','''                e->dead=TRUE;\n                e->active=FALSE;\n                spawn_impact_pair(e->x,e->surfaceY-26);\n                trigger_shake(1,4);\n                e->anim=2;''','enemy death')

# Boss impact; on death clear old projectiles FIRST, then preserve the death FX.
rep('''        boss.hp-=b->damage;\n        sfx_play_boss_hit();\n        deactivate_bullet(b);''','''        boss.hp-=b->damage;\n        sfx_play_boss_hit();\n        spawn_impact_pair(b->x,b->y);\n        trigger_shake(1,3);\n        deactivate_bullet(b);''','boss hit')
rep('''        if(boss.hp<=0){\n            boss.hp=0;\n            boss.dead=TRUE;\n            if(boss.spr) SPR_setAnim(boss.spr,1);\n            hide_sprite(boss.spr);\n            mode=MC_MODE_CLEAR;\n            clearTimer=0;\n            clear_projectiles();\n        }''','''        if(boss.hp<=0){\n            boss.hp=0;\n            boss.dead=TRUE;\n            if(boss.spr) SPR_setAnim(boss.spr,1);\n            hide_sprite(boss.spr);\n            mode=MC_MODE_CLEAR;\n            clearTimer=0;\n            clear_projectiles();\n            spawn_impact_pair(boss.x+32,boss.y+28);\n            trigger_shake(4,28);\n        }''','boss death')

# Render-only camera shake (logic/streaming remains on stable cameraX).
rep('''    const s16 fgTile=cameraX>>3;\n    const s16 bgPixel=cameraX>>1;\n    const s16 bgTile=bgPixel>>3;''','''    const s16 renderCam=render_camera_x();\n    const s16 fgTile=cameraX>>3;\n    const s16 bgPixel=cameraX>>1;\n    const s16 bgTile=bgPixel>>3;''','render world camera')
rep('''    VDP_setHorizontalScroll(BG_A,-cameraX);\n    VDP_setHorizontalScroll(BG_B,-bgPixel);''','''    VDP_setHorizontalScroll(BG_A,-renderCam);\n    VDP_setHorizontalScroll(BG_B,-(renderCam>>1));''','shake scroll')
rep('''    s16 sx=FROM_FP(player.x)-cameraX-14;''','''    const s16 renderCam=render_camera_x();\n    s16 sx=FROM_FP(player.x)-renderCam-14;''','player render camera')
rep('''static void render_entities(void)\n{\n    u16 i;''','''static void render_entities(void)\n{\n    u16 i;\n    const s16 renderCam=render_camera_x();''','entity render camera')
s=s.replace('e->x-cameraX-17','e->x-renderCam-17')
s=s.replace('e->x-cameraX-16','e->x-renderCam-16')
s=s.replace('b->x-cameraX-4','b->x-renderCam-4')
s=s.replace('boss.x-cameraX-12','boss.x-renderCam-12')

rep('''    if(boss.active&&!boss.dead)\n        SPR_setPosition(boss.spr,boss.x-renderCam-12,boss.y);''','''    for(i=0;i<4;i++){\n        MCEffect *fx=&effects[i];\n        if(!fx->active){ hide_sprite(fx->spr); continue; }\n        SPR_setHFlip(fx->spr,(fx->variant&1)!=0);\n        SPR_setVFlip(fx->spr,(fx->variant&2)!=0);\n        if((fx->timer&1) || fx->timer>3)\n            SPR_setPosition(fx->spr,fx->x-renderCam-8,fx->y-8);\n        else hide_sprite(fx->spr);\n    }\n\n    if(boss.active&&!boss.dead)\n        SPR_setPosition(boss.spr,boss.x-renderCam-12,boss.y);''','effect rendering')

# Shared spark tiles and actor pool.
rep('''    VDP_loadTileSet(spr_acid.animations[0]->frames[0]->tileset,\n                    spriteBase+SPR_SLOT_ACID,DMA);''','''    VDP_loadTileSet(spr_acid.animations[0]->frames[0]->tileset,\n                    spriteBase+SPR_SLOT_ACID,DMA);\n    VDP_loadTileSet(spr_spark.animations[0]->frames[0]->tileset,\n                    spriteBase+SPR_SLOT_SPARK,DMA);''','spark tile load')
rep('''    boss.spr=add_manual_sprite(&spr_rotor,-96,-96,PAL3,\n                               spriteBase+SPR_SLOT_ROTOR,TRUE);''','''    for(i=0;i<4;i++){\n        effects[i].spr=add_manual_sprite(&spr_spark,-96,-96,PAL2,\n                                         spriteBase+SPR_SLOT_SPARK,FALSE);\n        if(!effects[i].spr) ok=FALSE;\n        else SPR_setAutoAnimation(effects[i].spr,FALSE);\n        effects[i].active=FALSE;\n    }\n\n    boss.spr=add_manual_sprite(&spr_rotor,-96,-96,PAL3,\n                               spriteBase+SPR_SLOT_ROTOR,TRUE);''','spark actors')

rep('''    update_camera();\n    update_shared_enemy_animations();''','''    update_camera();\n    update_effects();\n    update_shared_enemy_animations();''','effect update')

g.write_text(s,encoding='utf-8')
print('v1.1b impact FX / camera feedback transformation complete')
