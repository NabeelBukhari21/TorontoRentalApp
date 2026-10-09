import os
from PIL import Image, ImageDraw, ImageFilter
MASCOT_DIR=os.environ.get('MASCOT_DIR','.')
import math
H=lambda h:tuple(int(h[i:i+2],16) for i in (0,2,4))
C=dict(violet=H('6C5CE7'),violetLight=H('8F83F0'),violetDeep=H('4B3BC9'),coral=H('FF6B6B'),sunny=H('FFD93D'),
       sunnyLight=H('FFF0A8'),mint=H('2ED8A3'),sky=H('4DA8FF'),white=(255,255,255),
       skyLight=H('8CC6FF'),skyDeep=H('2A6BD4'),wallSunny=H('FFE9A6'),wallMint=H('C4F2E3'),wallSky=H('D9ECFF'),wallViolet=H('D9D4FB'))
# --- shared geometry (mirrors RentOSLogoGeometry) ---
GROUND=0.85; CAT=0.72
LEFT=dict(cx=0.165,w=0.28,body=0.23,roof=0.15); RIGHT=dict(cx=0.835,w=0.26,body=0.21,roof=0.14)
CONDO=dict(cx=0.31,w=0.19,h=0.62,rows=5,top='violetLight',bot='violet',cap='violetDeep')
TOWER=dict(cx=0.69,w=0.16,h=0.47,rows=4,top='skyLight',bot='sky',cap='skyDeep'); FLOOR=0.94

def rrect(d,box,r,fill): d.rounded_rectangle(box,radius=r,fill=fill)

def house(d,S,h,wall,roof,door):
    w=h['w']*S; bh=h['body']*S; rh=h['roof']*S; cx=h['cx']*S; gy=GROUND*S
    top_body=gy-bh
    rrect(d,(cx-w/2,top_body,cx+w/2,gy),w*0.07,C[wall])
    # roof (overhang 1.14), slightly overlapping the walls
    rw=w*1.14; rb=top_body+rh*0.08; rt=rb-rh
    d.polygon([(cx-rw/2,rb),(cx,rt),(cx+rw/2,rb)],fill=C[roof])
    # door + window
    dw=w*0.24; dh=bh*0.52; gap=w*0.12; total=dw*2+gap; x0=cx-total/2
    rrect(d,(x0,gy-dh,x0+dw,gy-dh+dw),dw*0.5,C[door]); d.rectangle((x0,gy-dh+dw/2,x0+dw,gy),fill=C[door])
    wx=x0+dw+gap; wy=gy-bh*0.34-dw
    rrect(d,(wx,wy,wx+dw,wy+dw),dw*0.28,C['sunnyLight'])

def condo(img,d,S,T=None):
    T=T or CONDO
    w=T['w']*S; h=T['h']*S; cx=T['cx']*S; gy=GROUND*S; top=gy-h
    grad=Image.new('RGBA',(int(w),int(h)))
    gd=ImageDraw.Draw(grad)
    for y in range(int(h)):
        t=y/max(h-1,1); col=tuple(int(C[T['top']][i]*(1-t)+C[T['bot']][i]*t) for i in range(3))
        gd.line([(0,y),(w,y)],fill=col+(255,))
    mask=Image.new('L',(int(w),int(h)),0); ImageDraw.Draw(mask).rounded_rectangle((0,0,w-1,h-1),radius=w*0.14,fill=255)
    img.paste(grad,(int(cx-w/2),int(top)),mask)
    d.rounded_rectangle((cx-w*0.25,top-w*0.06,cx+w*0.25,top+w*0.06),radius=w*0.06,fill=C[T['cap']])
    ws=w*0.22; gapx=w*0.18; gapy=w*0.14; y=top+w*0.28
    for r in range(T['rows']):
        x=cx-(ws*2+gapx)/2
        for c in range(2):
            rrect(d,(x,y,x+ws,y+ws),ws*0.28,C['sunnyLight'] if (r+c)%3 else C['white']); x+=ws+gapx
        y+=ws+gapy

def ground(img,S):
    w=S*0.92; x0=S*0.04; y=GROUND*S; lw=max(S*0.028,2)
    stops=[C['coral'],C['sunny'],C['mint'],C['sky'],C['violet']]
    line=Image.new('RGBA',(int(S),int(S)),(0,0,0,0)); ld=ImageDraw.Draw(line)
    n=200
    for i in range(n):
        t=i/(n-1); seg=t*(len(stops)-1); k=min(int(seg),len(stops)-2); f=seg-k
        col=tuple(int(stops[k][j]*(1-f)+stops[k+1][j]*f) for j in range(3))
        x=x0+w*t; ld.ellipse((x-lw/2,y-lw/2,x+lw/2,y+lw/2),fill=col+(255,))
    img.alpha_composite(line)

def cat(img,S,pose='sit'):
    side=CAT*S; c=Image.open(os.path.join(MASCOT_DIR,f'mascot_{pose}.png')).resize((int(side),int(side)),Image.LANCZOS)
    top=GROUND*S-side*FLOOR
    # soft contact shadow
    sh=Image.new('RGBA',(int(S),int(S)),(0,0,0,0)); sd=ImageDraw.Draw(sh)
    sw=side*0.52; shh=side*0.065; sd.ellipse((S/2-sw/2,GROUND*S-shh/2,S/2+sw/2,GROUND*S+shh/2),fill=(27,27,47,40))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(side*0.012)))
    img.alpha_composite(c,(int(S/2-side/2),int(top)))

def mark(S, ss=3):
    big=S*ss
    img=Image.new('RGBA',(big,big),(0,0,0,0)); d=ImageDraw.Draw(img)
    ground(img,big); d=ImageDraw.Draw(img)
    condo(img,d,big,CONDO); d=ImageDraw.Draw(img)
    condo(img,d,big,TOWER); d=ImageDraw.Draw(img)
    house(d,big,LEFT,'wallSunny','coral','violet')
    house(d,big,RIGHT,'wallSky','mint','coral')
    cat(img,big)
    return img.resize((S,S),Image.LANCZOS)
