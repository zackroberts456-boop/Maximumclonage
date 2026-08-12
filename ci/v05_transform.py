from pathlib import Path
from PIL import Image
import sys
root=Path(sys.argv[1])
spr=root/'res'/'sprite'

# Preserve indexed palette exactly; crop transparent padding, scale only when needed,
# bottom-align and add explicit single-frame sleep rows for pooled actors.
def get_bbox_nonzero(im):
    mask=im.point(lambda v: 255 if v else 0, mode='L')
    return mask.getbbox()

def fit_frame(fr, size, maxbox):
    W,H=size; mw,mh=maxbox
    b=get_bbox_nonzero(fr)
    out=Image.new('P',size,0); out.putpalette(fr.getpalette())
    if not b: return out
    fr=fr.crop(b)
    scale=min(1.0,mw/fr.width,mh/fr.height)
    if scale<1.0:
        fr=fr.resize((max(1,round(fr.width*scale)),max(1,round(fr.height*scale))),Image.Resampling.NEAREST)
    x=round((W-fr.width)/2); y=H-fr.height
    out.paste(fr,(x,y)); out.info['transparency']=0
    return out

def split_rows(path, old_size, row_counts):
    im=Image.open(path).convert('P'); fw,fh=old_size
    rows=[]
    for y,count in enumerate(row_counts):
        rows.append([im.crop((x*fw,y*fh,(x+1)*fw,(y+1)*fh)) for x in range(count)])
    return rows

def save_rows(rows,new_size,maxbox,path,sleep_from=None,extra_row_from=None):
    cooked=[]
    for row in rows:
        cooked.append([fit_frame(fr,new_size,maxbox) for fr in row])
    if extra_row_from is not None:
        src=cooked[extra_row_from]
        cooked.append([src[i % len(src)].copy() for i in range(min(4,len(src)))])
    if sleep_from is not None:
        cooked.append([cooked[sleep_from][0].copy()])
    cols=max(len(r) for r in cooked); fw,fh=new_size
    pal=cooked[0][0].getpalette()
    out=Image.new('P',(cols*fw,len(cooked)*fh),0); out.putpalette(pal)
    for y,row in enumerate(cooked):
        for x,fr in enumerate(row): out.paste(fr,(x*fw,y*fh))
    out.info['transparency']=0; out.save(path)

# v0.4 row counts are known from the source generation pass.
rows=split_rows(spr/'nada_genesis_v04.png',(64,64),[4,6,2,6,4,6])
save_rows(rows,(48,56),(46,54),spr/'nada_genesis_v05.png',sleep_from=0)
rows=split_rows(spr/'grunt_genesis_v04.png',(64,56),[8,6])
save_rows(rows,(56,56),(54,52),spr/'grunt_genesis_v05.png',sleep_from=0)
rows=split_rows(spr/'spitter_genesis_v04.png',(64,64),[6,6])
save_rows(rows,(56,56),(54,54),spr/'spitter_genesis_v05.png',sleep_from=0)
rows=split_rows(spr/'feral_genesis_v04.png',(64,48),[6])
# runtime requests anim 1 for lunge; create it from the same supplied-art run row, then sleep row 2.
save_rows(rows,(56,48),(54,46),spr/'feral_genesis_v05.png',extra_row_from=0,sleep_from=0)
rows=split_rows(spr/'rotor_genesis_v04.png',(96,64),[4])
save_rows(rows,(88,64),(84,60),spr/'rotor_genesis_v05.png',sleep_from=0)
for old,new in [('bullet_genesis_v04.png','bullet_genesis_v05.png'),('enemy_bullet_genesis_v04.png','enemy_bullet_genesis_v05.png'),('acid_genesis_v04.png','acid_genesis_v05.png')]:
    Image.open(spr/old).save(spr/new)

(root/'res'/'resources.res').write_text('''# Maximum Clonage Stage 1 v0.5 - APK-derived art, tighter Genesis cells.\nPALETTE bg_palette0 "gfx/bg_palette0.png"\nPALETTE bg_palette1 "gfx/bg_palette1.png"\nTILESET lab_tiles_v05 "gfx/lab_tiles_v04.png" NONE NONE\nSPRITE spr_nada "sprite/nada_genesis_v05.png" 6 7 NONE 7 BOX BALANCED FAST TRUE\nSPRITE spr_grunt "sprite/grunt_genesis_v05.png" 7 7 NONE 8 BOX BALANCED FAST TRUE\nSPRITE spr_spitter "sprite/spitter_genesis_v05.png" 7 7 NONE 9 BOX BALANCED FAST TRUE\nSPRITE spr_feral "sprite/feral_genesis_v05.png" 7 6 NONE 7 BOX BALANCED FAST TRUE\nSPRITE spr_rotor "sprite/rotor_genesis_v05.png" 11 8 NONE 7 BOX BALANCED FAST TRUE\nSPRITE spr_bullet "sprite/bullet_genesis_v05.png" 1 1 NONE 0 NONE NONE FAST FALSE\nSPRITE spr_enemy_bullet "sprite/enemy_bullet_genesis_v05.png" 1 1 NONE 0 NONE NONE FAST FALSE\nSPRITE spr_acid "sprite/acid_genesis_v05.png" 1 1 NONE 0 NONE NONE FAST FALSE\n''',encoding='ascii')

gp=root/'src'/'game.c'; s=gp.read_text(encoding='utf-8')
s=s.replace('v0.4','v0.5')
s=s.replace('&lab_tiles_v04','&lab_tiles_v05')
s=s.replace('SPR_initEx(512);','SPR_initEx(448);')
s=s.replace('s16 sx=FROM_FP(player.x)-cameraX-22;\n    s16 sy=FROM_FP(player.y)+PLAYER_H-64;','s16 sx=FROM_FP(player.x)-cameraX-14;\n    s16 sy=FROM_FP(player.y)+PLAYER_H-56;')
s=s.replace('SPR_setPosition(e->spr,e->x-cameraX-21,e->surfaceY-64);','SPR_setPosition(e->spr,e->x-cameraX-17,e->surfaceY-56);')
s=s.replace('SPR_setPosition(e->spr,e->x-cameraX-20,e->surfaceY-48);','SPR_setPosition(e->spr,e->x-cameraX-16,e->surfaceY-48);')
s=s.replace('SPR_setPosition(e->spr,e->x-cameraX-21,e->surfaceY-56);','SPR_setPosition(e->spr,e->x-cameraX-17,e->surfaceY-56);')
s=s.replace('SPR_setPosition(boss.spr,boss.x-cameraX-16,boss.y);','SPR_setPosition(boss.spr,boss.x-cameraX-12,boss.y);')
s=s.replace('cameraX += (target-cameraX)/4;','''{\n        s16 delta=target-cameraX;\n        s16 step=delta/2;\n        if(delta && step==0) step=(delta>0)?1:-1;\n        step=clamp16(step,-5,5);\n        cameraX += step;\n    }''')
s=s.replace('''static void render_world(void)\n{''','''static void animate_facility_palette(void)\n{\n    if((frameCounter & 7)==0){\n        const u16 phase=(frameCounter>>3)&3;\n        PAL_setColor(16+10,bg_palette1.data[10+phase]);\n        PAL_setColor(16+11,bg_palette1.data[9+phase]);\n    }\n}\n\nstatic void render_world(void)\n{\n    animate_facility_palette();''',1)
s=s.replace('''    if(player.dead){\n        hide_sprite(player.spr);\n        return;\n    }''','''    if(player.dead){\n        set_anim(player.spr,&player.anim,6);\n        hide_sprite(player.spr);\n        return;\n    }''')
s=s.replace('''    e->anim = -1;\n    hide_sprite(e->spr);''','''    e->anim = 2;\n    if(e->spr) SPR_setAnim(e->spr,2);\n    hide_sprite(e->spr);''')
s=s.replace('''        enemies[i].anim=-1;\n        hide_sprite(enemies[i].spr);''','''        enemies[i].anim=2;\n        if(enemies[i].spr) SPR_setAnim(enemies[i].spr,2);\n        hide_sprite(enemies[i].spr);''')
s=s.replace('''            enemies[i].active=FALSE;\n            enemies[i].dead=TRUE;\n            hide_sprite(enemies[i].spr);''','''            enemies[i].active=FALSE;\n            enemies[i].dead=TRUE;\n            enemies[i].anim=2;\n            if(enemies[i].spr) SPR_setAnim(enemies[i].spr,2);\n            hide_sprite(enemies[i].spr);''')
s=s.replace('''            e->active=FALSE;\n            e->dead=TRUE;\n            hide_sprite(e->spr);''','''            e->active=FALSE;\n            e->dead=TRUE;\n            e->anim=2;\n            if(e->spr) SPR_setAnim(e->spr,2);\n            hide_sprite(e->spr);''')
s=s.replace('''                e->dead=TRUE;\n                e->active=FALSE;\n                hide_sprite(e->spr);''','''                e->dead=TRUE;\n                e->active=FALSE;\n                e->anim=2;\n                if(e->spr) SPR_setAnim(e->spr,2);\n                hide_sprite(e->spr);''')
s=s.replace('''    boss.patternCycle=0;\n    hide_sprite(boss.spr);''','''    boss.patternCycle=0;\n    if(boss.spr) SPR_setAnim(boss.spr,1);\n    hide_sprite(boss.spr);''')
s=s.replace('''        boss.active=TRUE;\n        boss.attackCd=52;''','''        boss.active=TRUE;\n        if(boss.spr) SPR_setAnim(boss.spr,0);\n        boss.attackCd=52;''')
s=s.replace('''            boss.dead=TRUE;\n            hide_sprite(boss.spr);''','''            boss.dead=TRUE;\n            if(boss.spr) SPR_setAnim(boss.spr,1);\n            hide_sprite(boss.spr);''')
s=s.replace('''        enemies[i].anim=-1;\n        enemies[i].active=FALSE;''','''        enemies[i].anim=2;\n        if(enemies[i].spr) SPR_setAnim(enemies[i].spr,2);\n        enemies[i].active=FALSE;''')
s=s.replace('''    boss.spr=SPR_addSpriteSafe(&spr_rotor,-96,-96,TILE_ATTR(PAL3,TRUE,FALSE,FALSE));\n    if(!boss.spr) ok=FALSE;''','''    boss.spr=SPR_addSpriteSafe(&spr_rotor,-96,-96,TILE_ATTR(PAL3,TRUE,FALSE,FALSE));\n    if(!boss.spr) ok=FALSE;\n    else SPR_setAnim(boss.spr,1);''')
gp.write_text(s,encoding='utf-8')

mp=root/'src'/'main.c'; m=mp.read_text(encoding='utf-8').replace('int main(void)','int main(bool hardReset)'); mp.write_text(m,encoding='utf-8')
print('v0.5 CI transformation complete')
