import cv2, numpy as np, glob, json, collections, os, sys
S="/private/tmp/claude-501/-Users-bnprs-BPR-GitRepos1-aim-pat/fef92d97-9c1d-4a20-9280-d5f4aab6ce0a/scratchpad"
SZ=640; CONF=0.5
which=sys.argv[1]
if which=="fight":
    net=cv2.dnn.readNetFromONNX("/Users/bnprs/BPR/GitRepos1/bpr.cpp/.models/bpr.m10006.onnx")
    ids=json.load(open(f"{S}/ids_fight.json")); CLS=1; BUF,MH=8,3; d=f"{S}/pos/fight"
else:
    net=cv2.dnn.readNetFromONNX("/Users/bnprs/BPR/GitRepos1/bpr.cpp/.models/bpr.m10005.onnx")
    ids=json.load(open(f"{S}/ids_smoke.json")); CLS=0; BUF,MH=6,2; d=f"{S}/pos/smoke"
def fires(fr):
    h,w=fr.shape[:2]; s=min(SZ/w,SZ/h); lw,lh=int(round(w*s)),int(round(h*s))
    px,py=(SZ-lw)//2,(SZ-lh)//2
    c=np.full((SZ,SZ,3),114,np.uint8); c[py:py+lh,px:px+lw]=cv2.resize(fr,(lw,lh))
    net.setInput(cv2.dnn.blobFromImage(c,1/255.0,(SZ,SZ),swapRB=True,crop=False))
    o=net.forward()[0].T; sc=o[:,4:]; am=sc.argmax(1); mx=sc.max(1)
    return bool(((mx>=CONF)&(am==CLS)).any())
hit=collections.Counter(); tot=collections.Counter()
for p in sorted(glob.glob(d+"/*.mp4")):
    vid=os.path.basename(p)[:11]; lab=ids.get(vid,"?")
    cap=cv2.VideoCapture(p); fps=cap.get(cv2.CAP_PROP_FPS) or 25.0
    step=max(1,int(round(fps))); i=0; buf=collections.deque([0]*BUF,maxlen=BUF); conf=False
    while True:
        ok,fr=cap.read()
        if not ok: break
        if i%step==0:
            buf.append(1 if fires(fr) else 0)
            if sum(buf)>=MH: conf=True
        i+=1
    cap.release(); tot[lab]+=1; hit[lab]+=conf
print(f"{'class':<28}{'detected':>10}{'total':>7}{'recall':>9}")
for c in sorted(tot):
    print(f"{c:<28}{hit[c]:>10}{tot[c]:>7}{100*hit[c]/tot[c]:>8.0f}%")
print(f"{'ALL':<28}{sum(hit.values()):>10}{sum(tot.values()):>7}{100*sum(hit.values())/sum(tot.values()):>8.1f}%")
