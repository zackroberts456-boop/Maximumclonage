from pathlib import Path
import shutil, sys

src=Path(sys.argv[1])
dst=Path(sys.argv[2])
if dst.exists(): shutil.rmtree(dst)
shutil.copytree(src,dst)

# Keep SGDK's visual frame-load marker in the profile build.
p=dst/'src'/'game.c'
s=p.read_text(encoding='utf-8')
needle='''    reset_stage();\n}\n\nvoid mc_game_frame(void)'''
repl='''    reset_stage();\n    /* Profiling build only: SGDK frame-load marker, averaged over 8 frames. */\n    SYS_showFrameLoad(TRUE);\n}\n\nvoid mc_game_frame(void)'''
if needle not in s:
    raise SystemExit('profile insertion anchor not found')
s=s.replace(needle,repl,1)
p.write_text(s,encoding='utf-8')

# Also instrument the main loop numerically. Sampling GET_VCOUNTER after
# SPR_update includes gameplay + sprite-engine CPU work but occurs before the
# VBlank wait. The displayed values are therefore deliberately excluded from
# the sample they report.
p=dst/'src'/'main.c'
m=p.read_text(encoding='utf-8')
old='''    while (TRUE) {\n        mc_game_frame();\n        SPR_update();\n        SYS_doVBlankProcess();\n    }'''
new='''    {\n        u16 profFrames=0;\n        u16 profWindow=0;\n        u16 profMax=0;\n        u32 profSum=0;\n        char profBuf[40];\n\n        while (TRUE) {\n            u16 load;\n            mc_game_frame();\n            SPR_update();\n\n            load=GET_VCOUNTER;\n            if(load<224){\n                if(load>profMax) profMax=load;\n                profSum+=load;\n                profWindow++;\n            }\n            profFrames++;\n\n            if((profFrames & 31)==0 && profWindow){\n                const u16 avg=(u16)(profSum/profWindow);\n                VDP_setTextPlane(BG_A);\n                VDP_setTextPalette(PAL0);\n                sprintf(profBuf,"LOAD %03u AVG %03u MAX %03u",load,avg,profMax);\n                VDP_drawTextFill(profBuf,8,26,31);\n                VDP_setTextPlane(WINDOW);\n            }\n\n            SYS_doVBlankProcess();\n        }\n    }'''
if old not in m:
    raise SystemExit('profile main-loop anchor not found')
m=m.replace(old,new,1)
p.write_text(m,encoding='utf-8')
print(dst)
