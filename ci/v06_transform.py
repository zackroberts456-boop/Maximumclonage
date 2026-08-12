from pathlib import Path
import sys

root=Path(sys.argv[1])
p=root/'src'/'game.c'
s=p.read_text(encoding='utf-8')

s=s.replace('Maximum Clonage — SGDK Stage 1 vertical slice v0.5.','Maximum Clonage — SGDK Stage 1 vertical slice v0.6.')
s=s.replace(' * v0.5 engineering targets:',' * v0.6 engineering targets:')

anchor='static MCBoss boss;\n'
insert=r'''
/*
 * v0.6 manual/shared sprite VRAM layout.
 *
 * Detailed APK-derived sprites are too expensive if every pooled actor reserves
 * its own max-frame tile block. Player and boss keep automatic tile upload in
 * fixed manual slots; common-enemy animation states and projectiles share VRAM.
 */
#define SPR_SLOT_PLAYER       0
#define SPR_SLOT_GRUNT_WALK  40
#define SPR_SLOT_GRUNT_FIRE  90
#define SPR_SLOT_SPIT_IDLE   140
#define SPR_SLOT_SPIT_FIRE   190
#define SPR_SLOT_FERAL_RUN   240
#define SPR_SLOT_FERAL_LUNGE 284
#define SPR_SLOT_ROTOR       328
#define SPR_SLOT_PBULLET     392
#define SPR_SLOT_EBULLET     393
#define SPR_SLOT_ACID        394
#define SPR_VRAM_REQUIRED    395

typedef struct {
    const SpriteDefinition *definition;
    u8 anim;
    u8 frame;
    u8 tick;
    u8 period;
    u16 tileIndex;
} MCSharedAnimator;

static MCSharedAnimator sharedGrunt[2];
static MCSharedAnimator sharedSpitter[2];
static MCSharedAnimator sharedFeral[2];
'''
if anchor not in s: raise SystemExit('v06 anchor boss not found')
s=s.replace(anchor,anchor+insert,1)

anchor2='''static void hide_sprite(Sprite *spr)\n{\n    if (spr) SPR_setPosition(spr, -96, -96);\n}\n'''
insert2=r'''

static const Animation *shared_animation(const MCSharedAnimator *a)
{
    return a->definition->animations[a->anim];
}

static const AnimationFrame *shared_frame(const MCSharedAnimator *a)
{
    const Animation *anim=shared_animation(a);
    return anim->frames[a->frame];
}

static void init_shared_animator(MCSharedAnimator *a,
                                 const SpriteDefinition *definition,
                                 u8 anim, u8 period, u16 tileIndex)
{
    a->definition=definition;
    a->anim=anim;
    a->frame=0;
    a->tick=0;
    a->period=period;
    a->tileIndex=tileIndex;
    VDP_loadTileSet(shared_frame(a)->tileset,tileIndex,DMA);
}

static void update_shared_animator(MCSharedAnimator *a)
{
    const Animation *anim;

    a->tick++;
    if(a->tick<a->period) return;
    a->tick=0;

    anim=shared_animation(a);
    a->frame++;
    if(a->frame>=anim->numFrame) a->frame=0;

    /* One queued upload services every actor currently using this state. */
    VDP_loadTileSet(shared_frame(a)->tileset,a->tileIndex,DMA_QUEUE);
}

static void update_shared_enemy_animations(void)
{
    update_shared_animator(&sharedGrunt[0]);
    update_shared_animator(&sharedGrunt[1]);
    update_shared_animator(&sharedSpitter[0]);
    update_shared_animator(&sharedSpitter[1]);
    update_shared_animator(&sharedFeral[0]);
    update_shared_animator(&sharedFeral[1]);
}

static MCSharedAnimator *shared_animator_for_enemy(const MCEnemy *e)
{
    const u8 state=(e->anim==1)?1:0;
    if(e->type==MC_ENEMY_GRUNT) return &sharedGrunt[state];
    if(e->type==MC_ENEMY_SPITTER) return &sharedSpitter[state];
    return &sharedFeral[state];
}

static void sync_enemy_shared_frame(MCEnemy *e)
{
    MCSharedAnimator *a;
    if(!e->spr || !e->active || e->dead) return;

    a=shared_animator_for_enemy(e);

    if(e->spr->animInd!=(s16)a->anim || e->spr->frameInd!=(s16)a->frame)
        SPR_setAnimAndFrame(e->spr,a->anim,a->frame);

    if((e->spr->attribut&TILE_INDEX_MASK)!=a->tileIndex)
        SPR_setVRAMTileIndex(e->spr,(s16)a->tileIndex);
}
'''
if anchor2 not in s: raise SystemExit('v06 anchor hide not found')
s=s.replace(anchor2,anchor2+insert2,1)

old='''        SPR_setHFlip(e->spr,e->facing<0);\n        if(e->type==MC_ENEMY_SPITTER)'''
new='''        sync_enemy_shared_frame(e);\n        SPR_setHFlip(e->spr,e->facing<0);\n        if(e->type==MC_ENEMY_SPITTER)'''
if old not in s: raise SystemExit('v06 render sync anchor not found')
s=s.replace(old,new,1)

start=s.index('static bool setup_sprites(void)\n{')
end=s.index('\nvoid mc_game_init(void)',start)
setup=r'''static Sprite *add_manual_sprite(const SpriteDefinition *def, s16 x, s16 y,
                                 u16 palette, u16 tileIndex, bool autoUpload)
{
    u16 flags=SPR_FLAG_AUTO_VISIBILITY|SPR_FLAG_FAST_AUTO_VISIBILITY;
    Sprite *spr;

    if(autoUpload) flags|=SPR_FLAG_AUTO_TILE_UPLOAD;

    spr=SPR_addSpriteExSafe(def,x,y,
            TILE_ATTR_FULL(palette,TRUE,FALSE,FALSE,tileIndex),flags);
    return spr;
}

static bool setup_sprites(void)
{
    u16 i;
    bool ok=TRUE;
    const u16 spriteBase=TILE_SPRITE_INDEX;

    if(SPR_VRAM_REQUIRED>448) return FALSE;

    init_shared_animator(&sharedGrunt[0],&spr_grunt,0,7,spriteBase+SPR_SLOT_GRUNT_WALK);
    init_shared_animator(&sharedGrunt[1],&spr_grunt,1,5,spriteBase+SPR_SLOT_GRUNT_FIRE);
    init_shared_animator(&sharedSpitter[0],&spr_spitter,0,9,spriteBase+SPR_SLOT_SPIT_IDLE);
    init_shared_animator(&sharedSpitter[1],&spr_spitter,1,6,spriteBase+SPR_SLOT_SPIT_FIRE);
    init_shared_animator(&sharedFeral[0],&spr_feral,0,4,spriteBase+SPR_SLOT_FERAL_RUN);
    init_shared_animator(&sharedFeral[1],&spr_feral,1,3,spriteBase+SPR_SLOT_FERAL_LUNGE);

    VDP_loadTileSet(spr_bullet.animations[0]->frames[0]->tileset,
                    spriteBase+SPR_SLOT_PBULLET,DMA);
    VDP_loadTileSet(spr_enemy_bullet.animations[0]->frames[0]->tileset,
                    spriteBase+SPR_SLOT_EBULLET,DMA);
    VDP_loadTileSet(spr_acid.animations[0]->frames[0]->tileset,
                    spriteBase+SPR_SLOT_ACID,DMA);

    player.spr=add_manual_sprite(&spr_nada,-96,-96,PAL2,
                                 spriteBase+SPR_SLOT_PLAYER,TRUE);
    if(!player.spr) ok=FALSE;
    player.anim=-1;

    for(i=0;i<MAX_ENEMIES;i++){
        const SpriteDefinition *def;
        u16 initialTile;

        if(i<ENEMY_SPITTER_BASE){
            enemies[i].type=MC_ENEMY_GRUNT;
            def=&spr_grunt;
            initialTile=sharedGrunt[0].tileIndex;
        } else if(i<ENEMY_FERAL_BASE){
            enemies[i].type=MC_ENEMY_SPITTER;
            def=&spr_spitter;
            initialTile=sharedSpitter[0].tileIndex;
        } else {
            enemies[i].type=MC_ENEMY_FERAL;
            def=&spr_feral;
            initialTile=sharedFeral[0].tileIndex;
        }

        enemies[i].spr=add_manual_sprite(def,-96,-96,PAL3,initialTile,FALSE);
        if(!enemies[i].spr) ok=FALSE;
        else SPR_setAutoAnimation(enemies[i].spr,FALSE);

        enemies[i].anim=2;
        enemies[i].active=FALSE;
        enemies[i].dead=TRUE;
        hide_sprite(enemies[i].spr);
    }

    for(i=0;i<MAX_PBULLETS;i++){
        pbullets[i].spr=add_manual_sprite(&spr_bullet,-96,-96,PAL2,
                                          spriteBase+SPR_SLOT_PBULLET,FALSE);
        if(!pbullets[i].spr) ok=FALSE;
        else SPR_setAutoAnimation(pbullets[i].spr,FALSE);
    }

    for(i=0;i<ENEMY_SHOT_SLOTS;i++){
        ebullets[i].spr=add_manual_sprite(&spr_enemy_bullet,-96,-96,PAL3,
                                          spriteBase+SPR_SLOT_EBULLET,FALSE);
        if(!ebullets[i].spr) ok=FALSE;
        else SPR_setAutoAnimation(ebullets[i].spr,FALSE);
    }

    for(;i<MAX_EBULLETS;i++){
        ebullets[i].spr=add_manual_sprite(&spr_acid,-96,-96,PAL3,
                                          spriteBase+SPR_SLOT_ACID,FALSE);
        if(!ebullets[i].spr) ok=FALSE;
        else SPR_setAutoAnimation(ebullets[i].spr,FALSE);
    }

    boss.spr=add_manual_sprite(&spr_rotor,-96,-96,PAL3,
                               spriteBase+SPR_SLOT_ROTOR,TRUE);
    if(!boss.spr) ok=FALSE;
    else SPR_setAnim(boss.spr,1);

    return ok;
}
'''
s=s[:start]+setup+s[end:]

s=s.replace('/* v0.5 tightened metaprites enough to lower the sprite VRAM reservation. */\n    SPR_initEx(448);','/* v0.6 uses a fixed 448-tile region with shared/manual allocation. */\n    SPR_initEx(448);')

needle='    update_camera();\n\n    render_world();'
if needle not in s: raise SystemExit('v06 update anchor not found')
s=s.replace(needle,'    update_camera();\n    update_shared_enemy_animations();\n\n    render_world();',1)

p.write_text(s,encoding='utf-8')
print('v0.6 shared-VRAM transformation complete')
