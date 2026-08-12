from pathlib import Path
import sys

root=Path(sys.argv[1])
g=root/'src'/'game.c'
s=g.read_text(encoding='utf-8')
s=s.replace('Stage 1 vertical slice v0.9','Stage 1 vertical slice v1.0')

# Cache the expensive collision-geometry-derived foreground decoration once at
# stage initialization. v0.8/v0.9 computed it every time a new 8px column was
# streamed, which created avoidable 68000 spikes precisely while scrolling.
anchor='''static u16 columnBuffer[MC_STAGE1_VISUAL_H];\n'''
insert='''static u8 fgVisualCache[MC_STAGE1_VISUAL_W * MC_STAGE1_VISUAL_H];\n'''
if anchor not in s: raise SystemExit('v10 cache anchor not found')
s=s.replace(anchor,anchor+insert,1)

start_marker='''        if(map==mc_stage1_fg_visual && worldCol>=0){\n'''
end_marker='''\n        columnBuffer[y]=TILE_ATTR_FULL(\n'''
start=s.find(start_marker)
if start<0: raise SystemExit('v10 dynamic overlay start not found')
end=s.find(end_marker,start)
if end<0: raise SystemExit('v10 dynamic overlay end not found')
old_block=s[start:end]
replacement='''        if(map==mc_stage1_fg_visual && worldCol>=0 && worldCol<MC_STAGE1_VISUAL_W)\n            code=fgVisualCache[(y*MC_STAGE1_VISUAL_W)+worldCol];\n'''
s=s[:start]+replacement+s[end:]

# Insert one-time cache builder immediately before build_visual_column().
anchor='''static void build_visual_column(const u8 *map, s16 worldCol, bool priority)\n{\n'''
builder=r'''static void build_fg_visual_cache(void)
{
    u16 worldCol,y,i;

    for(worldCol=0;worldCol<MC_STAGE1_VISUAL_W;worldCol++){
        for(y=0;y<MC_STAGE1_VISUAL_H;y++){
            const s16 wx=(s16)worldCol<<3;
            const s16 wy=(s16)y<<3;
            u8 code=mc_stage1_fg_visual[(y*MC_STAGE1_VISUAL_W)+worldCol];

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

            if(worldCol>=354 && worldCol<360 && (wy==192 || wy==200))
                code=((worldCol+y)&1)?107:109;

            fgVisualCache[(y*MC_STAGE1_VISUAL_W)+worldCol]=code;
        }
    }
}

'''
if anchor not in s: raise SystemExit('v10 builder insertion anchor not found')
s=s.replace(anchor,builder+anchor,1)

# Build the cache before sprite allocation and before profiling begins.
needle='''    VDP_loadTileSet(&lab_tiles_v08,WORLD_TILE_BASE,DMA);\n\n    /* v0.6 uses a fixed 448-tile region with shared/manual allocation. */'''
repl='''    VDP_loadTileSet(&lab_tiles_v08,WORLD_TILE_BASE,DMA);\n    build_fg_visual_cache();\n\n    /* v0.6 uses a fixed 448-tile region with shared/manual allocation. */'''
if needle not in s:
    # tolerate older comment text but still require the load line.
    needle2='''    VDP_loadTileSet(&lab_tiles_v08,WORLD_TILE_BASE,DMA);\n'''
    if needle2 not in s: raise SystemExit('v10 cache init anchor not found')
    s=s.replace(needle2,needle2+'    build_fg_visual_cache();\n',1)
else:
    s=s.replace(needle,repl,1)

# Only advance shared enemy animation/tile uploads for states actually present
# on screen. This avoids queueing tile data for unused archetypes/states.
old='''static void update_shared_enemy_animations(void)\n{\n    update_shared_animator(&sharedGrunt[0]);\n    update_shared_animator(&sharedGrunt[1]);\n    update_shared_animator(&sharedSpitter[0]);\n    update_shared_animator(&sharedSpitter[1]);\n    update_shared_animator(&sharedFeral[0]);\n    update_shared_animator(&sharedFeral[1]);\n}\n'''
new=r'''static void update_shared_enemy_animations(void)
{
    bool needGrunt[2]={FALSE,FALSE};
    bool needSpitter[2]={FALSE,FALSE};
    bool needFeral[2]={FALSE,FALSE};
    u16 i;

    for(i=0;i<MAX_ENEMIES;i++){
        MCEnemy *e=&enemies[i];
        u8 state;
        if(!e->active || e->dead) continue;
        if(e->x < cameraX-64 || e->x > cameraX+MC_SCREEN_W+64) continue;
        state=(e->anim==1)?1:0;
        if(e->type==MC_ENEMY_GRUNT) needGrunt[state]=TRUE;
        else if(e->type==MC_ENEMY_SPITTER) needSpitter[state]=TRUE;
        else needFeral[state]=TRUE;
    }

    if(needGrunt[0]) update_shared_animator(&sharedGrunt[0]);
    if(needGrunt[1]) update_shared_animator(&sharedGrunt[1]);
    if(needSpitter[0]) update_shared_animator(&sharedSpitter[0]);
    if(needSpitter[1]) update_shared_animator(&sharedSpitter[1]);
    if(needFeral[0]) update_shared_animator(&sharedFeral[0]);
    if(needFeral[1]) update_shared_animator(&sharedFeral[1]);
}
'''
if old not in s: raise SystemExit('v10 shared animator anchor not found')
s=s.replace(old,new,1)

g.write_text(s,encoding='utf-8')
print('v1.0 cached-visual / demand-driven animation optimization complete')
