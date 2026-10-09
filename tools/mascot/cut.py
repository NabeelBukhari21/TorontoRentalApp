import numpy as np
from PIL import Image

def border_connected(mask):
    """Pixels of `mask` reachable from the image border (4-connected), by
    iterative constrained dilation — a flood fill without scipy."""
    reach=np.zeros_like(mask)
    reach[0,:]=mask[0,:]; reach[-1,:]=mask[-1,:]; reach[:,0]=mask[:,0]; reach[:,-1]=mask[:,-1]
    while True:
        grown=reach.copy()
        grown[1:,:]|=reach[:-1,:]; grown[:-1,:]|=reach[1:,:]
        grown[:,1:]|=reach[:,:-1]; grown[:,:-1]|=reach[:,1:]
        grown&=mask
        if (grown==reach).all(): return reach
        reach=grown

def components(mask):
    """Label 4-connected components (two-pass union-find, vectorised enough)."""
    h,w=mask.shape; lab=np.zeros((h,w),np.int32); parent=[0]; nxt=1
    def find(x):
        while parent[x]!=x: parent[x]=parent[parent[x]]; x=parent[x]
        return x
    for y in range(h):
        row=mask[y]
        for x in np.nonzero(row)[0]:
            up=lab[y-1,x] if y else 0; lf=lab[y,x-1] if x else 0
            if up and lf:
                a,b=find(up),find(lf); lab[y,x]=min(a,b)
                if a!=b: parent[max(a,b)]=min(a,b)
            elif up or lf: lab[y,x]=up or lf
            else: parent.append(nxt); lab[y,x]=nxt; nxt+=1
    roots=np.array([find(i) for i in range(len(parent))]); return roots[lab]

def label_small(mask):
    """Component labels via repeated flood from unlabelled seeds (fine for a
    downscaled mask)."""
    lab=np.zeros(mask.shape,np.int32); k=0
    remaining=mask.copy()
    while remaining.any():
        y,x=np.argwhere(remaining)[0]
        seed=np.zeros_like(mask); seed[y,x]=True
        reach=seed
        while True:
            g=reach.copy()
            g[1:,:]|=reach[:-1,:]; g[:-1,:]|=reach[1:,:]; g[:,1:]|=reach[:,:-1]; g[:,:-1]|=reach[:,1:]
            g&=mask
            if (g==reach).all(): break
            reach=g
        k+=1; lab[reach]=k; remaining&=~reach
    return lab,k
