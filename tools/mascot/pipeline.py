import sys, os, argparse
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cut import border_connected, label_small
from PIL import Image, ImageFilter
import numpy as np, json

ap=argparse.ArgumentParser(description="Cut out mascot poses onto a shared, aligned 1024² canvas.")
ap.add_argument("--pose", nargs=2, action="append", metavar=("NAME","IMAGE"), required=True,
                help="pose name and source image, e.g. --pose sit cat_sit.png (repeatable; first pose is the scale reference)")
ap.add_argument("--pocket", nargs=3, action="append", default=[], metavar=("NAME","X","Y"),
                help="seed point inside an enclosed background gap (e.g. between tail and body)")
ap.add_argument("--out", default=".", help="output directory")
args=ap.parse_args()
SRC={n:f for n,f in args.pose}
POCKETS={n:[] for n in SRC}
for n,x,y in args.pocket: POCKETS[n].append((int(x),int(y)))
OUT=args.out

def matte(name):
    im=Image.open(SRC[name]).convert("RGB"); rgb=np.array(im).astype(np.float32)
    a=rgb.astype(int); mn=a.min(axis=2); spread=a.max(axis=2)-mn; h,w=mn.shape
    strict=border_connected((mn>=248)&(spread<=10))
    ymax=np.nonzero(~strict)[0].max(); rows=np.arange(h)[:,None]
    band=np.broadcast_to(rows>=ymax-int(0.075*h),(h,w))
    # per-column: shadow may only be removed BELOW the lowest dark contact pixel
    dark=(mn<222)&band
    lowest=np.where(dark.any(axis=0), h-1-np.argmax(dark[::-1],axis=0), -1)
    below=rows>lowest[None,:]
    shadow=border_connected(((mn>=225)&(spread<=25)&band&below)|strict)&~strict
    bg=strict|shadow
    # enclosed pockets at the verified seeds
    flat=(mn>=250)&(spread<=6)&~bg
    for (cx,cy) in POCKETS[name]:
        seed=np.zeros_like(flat); seed[cy,cx]=flat[cy,cx]
        if not seed.any():
            ys,xs=np.nonzero(flat); i=np.argmin((xs-cx)**2+(ys-cy)**2); seed[ys[i],xs[i]]=True
        reach=seed
        while True:
            g=reach.copy(); g[1:,:]|=reach[:-1,:]; g[:-1,:]|=reach[1:,:]; g[:,1:]|=reach[:,:-1]; g[:,:-1]|=reach[:,1:]
            g&=flat
            if (g==reach).all(): break
            reach=g
        bg|=reach
    opaque=~bg
    # keep only the cat: largest component (drops the baked motion dashes)
    small=opaque[::4,::4]; lab,k=label_small(small)
    sizes=[(lab==i).sum() for i in range(1,k+1)]; keep=1+int(np.argmax(sizes))
    keep_mask=np.array(Image.fromarray(((lab==keep)*255).astype(np.uint8)).resize((w,h),Image.NEAREST))>0
    keep_mask=np.array(Image.fromarray((keep_mask*255).astype(np.uint8)).filter(ImageFilter.MaxFilter(9)))>0
    opaque&=keep_mask
    # soft edge: 1px feather, then decontaminate white from edge pixels (colour-to-alpha vs white)
    alpha=np.array(Image.fromarray((opaque*255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))).astype(np.float32)/255
    alpha[~opaque]=np.minimum(alpha[~opaque],0.0)  # never resurrect background
    edge=(alpha>0)&(np.array(Image.fromarray((opaque*255).astype(np.uint8)).filter(ImageFilter.MinFilter(5)))==0)
    c2a=np.clip((255-rgb).max(axis=2)/255*1.6,0,1)      # how "non-white" the pixel is
    alpha=np.where(edge,np.minimum(alpha,np.maximum(c2a,0.0)),alpha)
    a3=np.clip(alpha,1e-4,1)[...,None]
    fg=np.where(edge[...,None],np.clip((rgb-255*(1-a3))/a3,0,255),rgb)
    rgba=np.dstack([fg,alpha*255]).astype(np.uint8)
    # pupils (two largest very dark blobs) -> head scale + centre
    darkp=(a.max(axis=2)<70)&opaque
    dl,dk=label_small(darkp[::2,::2])
    blobs=sorted([((dl==i).sum(),np.argwhere(dl==i).mean(axis=0)*2) for i in range(1,dk+1)],key=lambda b:-b[0])[:2]
    (_,p1),(_,p2)=blobs
    eyes=sorted([p1[::-1],p2[::-1]],key=lambda p:p[0])     # (x,y)
    ys,xs=np.nonzero(alpha>0.5)
    return Image.fromarray(rgba,"RGBA"), dict(floor=float(ys.max()), eyes=[list(map(float,e)) for e in eyes],
               bbox=[int(xs.min()),int(ys.min()),int(xs.max()),int(ys.max())])

res={n:matte(n) for n in SRC}
ref=args.pose[0][0]; dref=np.hypot(*np.subtract(*res[ref][1]["eyes"]))
CANVAS=1024; FLOOR=0.94*CANVAS
# common scale: fit the taller pose (after eye-normalisation) into the canvas
scales={}
for n,(img,m) in res.items():
    d=np.hypot(*np.subtract(*m["eyes"])); scales[n]=dref/d
heights=[ (m["floor"]-m["bbox"][1])*scales[n] for n,(img,m) in res.items() ]
widths =[ (m["bbox"][2]-m["bbox"][0])*scales[n] for n,(img,m) in res.items() ]
k=min((FLOOR-0.04*CANVAS)/max(heights), 0.92*CANVAS/max(widths))
meta={}
for n,(img,m) in res.items():
    s=scales[n]*k
    big=img.resize((round(img.width*s),round(img.height*s)),Image.LANCZOS)
    ex=(m["eyes"][0][0]+m["eyes"][1][0])/2*s   # eye midpoint x in scaled image
    ox=round(CANVAS/2-ex); oy=round(FLOOR-m["floor"]*s)
    canvas=Image.new("RGBA",(CANVAS,CANVAS),(0,0,0,0)); canvas.alpha_composite(big,(ox,oy)) if ox>=0 and oy>=0 else canvas.paste(big,(ox,oy),big)
    canvas.save(os.path.join(OUT,f"mascot_{n}.png"),optimize=True)
    ey=(m["eyes"][0][1]+m["eyes"][1][1])/2*s+oy
    meta[n]=dict(eyeMidY=round(ey/CANVAS,4), headTopY=round((m["bbox"][1]*s+oy)/CANVAS,4))
meta["floorY"]=round(FLOOR/CANVAS,4); meta["eyeMidX"]=0.5
json.dump(meta,open(os.path.join(OUT,"meta.json"),"w"),indent=1); print(json.dumps(meta,indent=1))
