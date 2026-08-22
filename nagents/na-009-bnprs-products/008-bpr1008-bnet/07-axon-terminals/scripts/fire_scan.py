"""Rank clips by the m10009 FIRE class (1) - mirror of the production temporal gate (6/2)."""
import cv2, numpy as np, sys, glob, json
CONF, NMS, SZ, BUF, MINHITS = 0.5, 0.45, 640, 6, 2
net = cv2.dnn.readNetFromONNX("/Users/bnprs/BPR/GitRepos1/bpr.cpp/.models/bpr.m10009.onnx")
def fire_score(fr):
    h,w = fr.shape[:2]; s=min(SZ/w,SZ/h); lw,lh=int(round(w*s)),int(round(h*s))
    px,py=(SZ-lw)//2,(SZ-lh)//2
    canvas=np.full((SZ,SZ,3),114,np.uint8); canvas[py:py+lh,px:px+lw]=cv2.resize(fr,(lw,lh))
    net.setInput(cv2.dnn.blobFromImage(canvas,1/255.0,(SZ,SZ),swapRB=True,crop=False))
    d=net.forward()[0].T; sc=d[:,4:]; best=sc.argmax(1); bv=sc.max(1)
    keep=(bv>=CONF)&(best==1)
    return int(keep.sum()), (float(bv[keep].max()) if keep.any() else 0.0)
rows=[]
for path in sorted(glob.glob(sys.argv[1])):
    cap=cv2.VideoCapture(path)
    if not cap.isOpened(): continue
    fps=cap.get(cv2.CAP_PROP_FPS) or 25; step=max(1,int(round(fps)))
    buf=[]; confirmed=0; hits=0; frames=0; peak=0; i=0
    while True:
        ok,fr=cap.read()
        if not ok: break
        if i%step==0:
            n,p=fire_score(fr); frames+=1; peak=max(peak,p)
            buf.append(1 if n>0 else 0); hits+= (1 if n>0 else 0)
            if len(buf)>BUF: buf.pop(0)
            if sum(buf)>=MINHITS: confirmed+=1
        i+=1
    cap.release()
    rows.append((confirmed,hits,frames,peak,path.split('/')[-1]))
rows.sort(reverse=True)
for c,h,f,p,name in rows[:8]: print(f"{name:<48} frames={f:<3} hits={h:<3} confirmed={c:<3} peak={p:.2f}")
