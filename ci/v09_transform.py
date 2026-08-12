from pathlib import Path
import sys

root=Path(sys.argv[1])

# Remove the temporary PCM WAV resources. v0.9 uses the native PSG directly,
# which is lighter and preserves XGM/PCM capacity for future album music.
r=root/'res'/'resources.res'
lines=r.read_text(encoding='ascii').splitlines()
lines=[ln for ln in lines if not ln.startswith('WAV sfx_') and 'v0.8 original compact SFX placeholders' not in ln]
r.write_text('\n'.join(lines)+'\n',encoding='ascii')

g=root/'src'/'game.c'
s=g.read_text(encoding='utf-8')
s=s.replace('Stage 1 vertical slice v0.8','Stage 1 vertical slice v0.9')

old='''#define SFX_SHOT_ID      64\n#define SFX_JUMP_ID      65\n#define SFX_HURT_ID      66\n#define SFX_ENEMY_ID     67\n#define SFX_BOSS_HIT_ID  68\n'''
new=r'''/* v0.9 native PSG action-SFX state.
 * Channels 0..2 are tones, channel 3 is noise. This is intentionally small:
 * no Z80 mixer, no PCM sample DMA, and XGM remains free for later music. */
static u8 sfxTone0Timer;
static u8 sfxTone1Timer;
static u8 sfxTone2Timer;
static u8 sfxNoiseTimer;
static u8 sfxTone1Kind;
static u8 sfxTone2Kind;

static u8 sfx_env_from_timer(u8 timer, u8 full)
{
    if(timer>=full) return 0;
    return (u8)(15-((timer*15)/full));
}

static void sfx_play_shot(void)
{
    sfxTone0Timer=5;
    sfxNoiseTimer=4;
    PSG_setFrequency(0,980);
    PSG_setEnvelope(0,0);
    PSG_setNoise(PSG_NOISE_TYPE_WHITE,PSG_NOISE_FREQ_CLOCK4);
    PSG_setEnvelope(3,2);
}

static void sfx_play_jump(void)
{
    sfxTone1Kind=1;
    sfxTone1Timer=9;
    PSG_setFrequency(1,320);
    PSG_setEnvelope(1,2);
}

static void sfx_play_hurt(void)
{
    sfxTone1Kind=2;
    sfxTone1Timer=10;
    sfxNoiseTimer=7;
    PSG_setFrequency(1,190);
    PSG_setEnvelope(1,0);
    PSG_setNoise(PSG_NOISE_TYPE_WHITE,PSG_NOISE_FREQ_CLOCK8);
    PSG_setEnvelope(3,1);
}

static void sfx_play_enemy(void)
{
    if(sfxTone2Kind==2 && sfxTone2Timer) return;
    sfxTone2Kind=1;
    sfxTone2Timer=6;
    PSG_setFrequency(2,720);
    PSG_setEnvelope(2,4);
}

static void sfx_play_boss_hit(void)
{
    sfxTone2Kind=2;
    sfxTone2Timer=8;
    sfxNoiseTimer=5;
    PSG_setFrequency(2,120);
    PSG_setEnvelope(2,0);
    PSG_setNoise(PSG_NOISE_TYPE_PERIODIC,PSG_NOISE_FREQ_CLOCK8);
    PSG_setEnvelope(3,2);
}

static void sfx_update(void)
{
    if(sfxTone0Timer){
        PSG_setFrequency(0,(u16)(380+(sfxTone0Timer*120)));
        PSG_setEnvelope(0,sfx_env_from_timer(sfxTone0Timer,5));
        sfxTone0Timer--;
        if(!sfxTone0Timer) PSG_setEnvelope(0,PSG_ENVELOPE_MIN);
    }

    if(sfxTone1Timer){
        if(sfxTone1Kind==1)
            PSG_setFrequency(1,(u16)(280+((9-sfxTone1Timer)*65)));
        else
            PSG_setFrequency(1,(u16)(90+(sfxTone1Timer*12)));
        PSG_setEnvelope(1,sfx_env_from_timer(sfxTone1Timer,(sfxTone1Kind==1)?9:10));
        sfxTone1Timer--;
        if(!sfxTone1Timer) PSG_setEnvelope(1,PSG_ENVELOPE_MIN);
    }

    if(sfxTone2Timer){
        if(sfxTone2Kind==1)
            PSG_setFrequency(2,(u16)(330+(sfxTone2Timer*65)));
        else
            PSG_setFrequency(2,(u16)(70+(sfxTone2Timer*7)));
        PSG_setEnvelope(2,sfx_env_from_timer(sfxTone2Timer,(sfxTone2Kind==1)?6:8));
        sfxTone2Timer--;
        if(!sfxTone2Timer) PSG_setEnvelope(2,PSG_ENVELOPE_MIN);
    }

    if(sfxNoiseTimer){
        PSG_setEnvelope(3,sfx_env_from_timer(sfxNoiseTimer,7));
        sfxNoiseTimer--;
        if(!sfxNoiseTimer) PSG_setEnvelope(3,PSG_ENVELOPE_MIN);
    }
}
'''
if old not in s: raise SystemExit('v09 SFX block anchor not found')
s=s.replace(old,new,1)

# Remove PCM registration and reset PSG to a known quiet state.
old='''    /* XGM keeps channel 1 available for future music; action SFX use 2..4. */\n    XGM_setPCM(SFX_SHOT_ID,sfx_shot,sizeof(sfx_shot));\n    XGM_setPCM(SFX_JUMP_ID,sfx_jump,sizeof(sfx_jump));\n    XGM_setPCM(SFX_HURT_ID,sfx_hurt,sizeof(sfx_hurt));\n    XGM_setPCM(SFX_ENEMY_ID,sfx_enemy,sizeof(sfx_enemy));\n    XGM_setPCM(SFX_BOSS_HIT_ID,sfx_boss_hit,sizeof(sfx_boss_hit));'''
new='''    /* Lightweight native PSG SFX; XGM/PCM capacity stays free for music. */\n    PSG_reset();\n    PSG_setEnvelope(0,PSG_ENVELOPE_MIN);\n    PSG_setEnvelope(1,PSG_ENVELOPE_MIN);\n    PSG_setEnvelope(2,PSG_ENVELOPE_MIN);\n    PSG_setEnvelope(3,PSG_ENVELOPE_MIN);'''
if old not in s: raise SystemExit('v09 PCM registration anchor not found')
s=s.replace(old,new,1)

s=s.replace('XGM_startPlayPCM(SFX_HURT_ID,12,SOUND_PCM_CH4);','sfx_play_hurt();')
s=s.replace('XGM_startPlayPCM(SFX_JUMP_ID,8,SOUND_PCM_CH3);','sfx_play_jump();')
s=s.replace('XGM_startPlayPCM(SFX_SHOT_ID,6,SOUND_PCM_CH2);','sfx_play_shot();')
s=s.replace('XGM_startPlayPCM(SFX_ENEMY_ID,3,SOUND_PCM_CH3);','sfx_play_enemy();')
s=s.replace('XGM_startPlayPCM(SFX_BOSS_HIT_ID,9,SOUND_PCM_CH3);','sfx_play_boss_hit();')

needle='''    joyPrev=joyNow;\n    joyNow=JOY_readJoypad(JOY_1);\n    frameCounter++;'''
repl='''    joyPrev=joyNow;\n    joyNow=JOY_readJoypad(JOY_1);\n    frameCounter++;\n    sfx_update();'''
if needle not in s: raise SystemExit('v09 per-frame SFX anchor not found')
s=s.replace(needle,repl,1)

g.write_text(s,encoding='utf-8')
print('v0.9 native-PSG audio optimization complete')
