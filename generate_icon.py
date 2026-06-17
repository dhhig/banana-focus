#!/usr/bin/env python3
"""
剥香蕉 App Icon — BOLD, LARGE banana filling the frame.
Visible even at 16x16 Dock size.
"""
import os, sys, math
from PIL import Image, ImageDraw, ImageFilter

# Colors
BG      = (255, 225, 130)
YELLOW  = (255, 215, 0)
YELLOW2 = (245, 198, 10)
FLESH   = (255, 250, 235)
PEEL    = (255, 200, 35)
PEEL2   = (240, 185, 25)
STEM    = (130, 90, 40)
TIP     = (110, 75, 25)

def lerp(a,b,t): return tuple(int(x+(y-x)*t) for x,y in zip(a,b))
def rm(size,r):
    m=Image.new('L',(size,size),0)
    ImageDraw.Draw(m).rounded_rectangle([(0,0),(size-1,size-1)],radius=r,fill=255)
    return m

def draw_giant_banana(draw, cx, cy, scale):
    """Banana fills ~85% of the icon. scale = icon_size/1024.0"""
    s = scale * 1.12  # Extra 12% bigger

    # Shadow
    shadow = [
        (cx-350*s,cy-390*s),(cx+270*s,cy-420*s),(cx+420*s,cy-40*s),
        (cx+350*s,cy+370*s),(cx-90*s,cy+430*s),(cx-400*s,cy+120*s),
        (cx-410*s,cy-200*s)
    ]
    ImageDraw.Draw(Image.new('RGBA',(int(2048*s),int(2048*s)),(0,0,0,0)))
    draw.polygon([(x+14*s,y+16*s) for x,y in shadow], fill=(0,0,0,50))

    # ─── MAIN BODY ───
    body = [
        (cx-350*s,cy-390*s),(cx+270*s,cy-420*s),(cx+420*s,cy-40*s),
        (cx+350*s,cy+370*s),(cx-90*s,cy+430*s),(cx-400*s,cy+120*s),
        (cx-410*s,cy-200*s)
    ]
    draw.polygon(body, fill=YELLOW)

    # Right shading
    shade = [
        (cx+40*s,cy-320*s),(cx+380*s,cy-50*s),(cx+330*s,cy+320*s),
        (cx-20*s,cy+350*s),(cx-80*s,cy+120*s),(cx-30*s,cy-160*s)
    ]
    draw.polygon(shade, fill=(225,183,10,100))

    # Left highlight
    hi = [
        (cx-300*s,cy-300*s),(cx-120*s,cy-360*s),(cx-40*s,cy-180*s),
        (cx-120*s,cy+40*s),(cx-260*s,cy+200*s),(cx-350*s,cy+20*s)
    ]
    draw.polygon(hi, fill=(255,240,130,90))

    # ─── FLESH ───
    flesh = [
        (cx-330*s,cy-340*s),(cx+60*s,cy-390*s),(cx+160*s,cy-240*s),
        (cx+80*s,cy-100*s),(cx-40*s,cy-80*s),(cx-180*s,cy-130*s),
        (cx-310*s,cy-200*s),(cx-360*s,cy-270*s)
    ]
    draw.polygon(flesh, fill=FLESH)
    for i in range(3):
        fx=cx-250*s+i*80*s; fy=cy-280*s+i*50*s
        bx=fx-50*s+i*10*s; by=cy-80*s+i*40*s
        draw.line([(fx,fy),(bx,by)],fill=(225,218,190),width=max(2,int(s*7)))

    # ─── PEEL FLAPS ───
    peel1=[
        (cx-300*s,cy-310*s),(cx+20*s,cy-360*s),(cx+100*s,cy-230*s),
        (cx+80*s,cy-100*s),(cx+30*s,cy+20*s),(cx-20*s,cy+60*s),
        (cx-80*s,cy+40*s),(cx-100*s,cy-20*s),(cx-150*s,cy-130*s),
        (cx-230*s,cy-200*s)
    ]
    psh1=[(x+7*s,y+8*s) for x,y in peel1]
    draw.polygon(psh1,fill=(0,0,0,50))
    draw.polygon(peel1,fill=PEEL)

    peel1_in=[
        (cx-220*s,cy-250*s),(cx-60*s,cy-230*s),(cx-30*s,cy-120*s),
        (cx-50*s,cy-30*s),(cx-80*s,cy+10*s),(cx-130*s,cy-30*s),
        (cx-200*s,cy-130*s)
    ]
    draw.polygon(peel1_in,fill=(250,242,210))

    peel2=[
        (cx+50*s,cy-330*s),(cx+180*s,cy-270*s),(cx+180*s,cy-170*s),
        (cx+130*s,cy-150*s),(cx+100*s,cy-180*s),(cx+80*s,cy-240*s)
    ]
    draw.polygon(peel2,fill=PEEL2)

    # ─── STEM ───
    sw,sh=28*s,50*s; sx=cx+30*s; sy=cy-415*s
    draw.rounded_rectangle([(sx-sw,sy-sh),(sx+sw,sy+sh*0.2)],fill=STEM,radius=int(sw))
    draw.rounded_rectangle([(sx-sw*0.4,sy-sh*0.65),(sx+sw*0.1,sy-sh*0.1)],fill=(160,115,60),radius=int(sw*0.3))

    # ─── TIP ───
    tx,ty=cx-30*s,cy+420*s; tr=22*s
    draw.ellipse([(tx-tr,ty-tr),(tx+tr,ty+tr)],fill=TIP)

def render_icon(size=1024):
    img=Image.new('RGBA',(size,size),(0,0,0,0))
    r=int(size*0.225); mask=rm(size,r)

    # Background
    bg=Image.new('RGBA',(size,size))
    for y in range(size):
        ImageDraw.Draw(bg).line([(0,y),(size,y)],fill=lerp(BG,(255,195,100),y/size))
    img.paste(bg,mask=mask)
    draw=ImageDraw.Draw(img,'RGBA')

    # Glow
    glow=Image.new('RGBA',(size,size),(0,0,0,0))
    gd=ImageDraw.Draw(glow)
    gr=int(size*0.4)
    gd.ellipse([(size//2-gr,size//2-gr),(size//2+gr,size//2+gr)],fill=(255,255,255,35))
    glow=glow.filter(ImageFilter.GaussianBlur(size*0.06))
    img.paste(Image.alpha_composite(img,glow),mask=mask)
    draw=ImageDraw.Draw(img,'RGBA')

    # BANANA
    draw_giant_banana(draw,size//2,size//2,size/1024.0)
    return img

def generate_iconset(d):
    os.makedirs(d,exist_ok=True)
    sizes=[(16,"16x16"),(32,"16x16@2x"),(32,"32x32"),(64,"32x32@2x"),
           (128,"128x128"),(256,"128x128@2x"),(256,"256x256"),
           (512,"256x256@2x"),(512,"512x512"),(1024,"512x512@2x")]
    print("🎨 大香蕉 logo...")
    m=render_icon(1024)
    for sz,nm in sizes:
        (m if sz==1024 else m.resize((sz,sz),Image.LANCZOS)).save(os.path.join(d,f"icon_{nm}.png"),"PNG")
        print(f"   ✅ {nm} ({sz}x{sz})")
    print(f"✅ {len(sizes)} sizes")

if __name__=="__main__":
    generate_iconset(sys.argv[1])
