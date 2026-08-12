from pathlib import Path
import shutil, sys

src=Path(sys.argv[1])
dst=Path(sys.argv[2])
if dst.exists(): shutil.rmtree(dst)
shutil.copytree(src,dst)
p=dst/'src'/'game.c'
s=p.read_text(encoding='utf-8')
needle='''    reset_stage();\n}\n\nvoid mc_game_frame(void)'''
repl='''    reset_stage();\n    /* Profiling build only: SGDK frame-load marker, averaged over 8 frames. */\n    SYS_showFrameLoad(TRUE);\n}\n\nvoid mc_game_frame(void)'''
if needle not in s:
    raise SystemExit('profile insertion anchor not found')
s=s.replace(needle,repl,1)
p.write_text(s,encoding='utf-8')
print(dst)
