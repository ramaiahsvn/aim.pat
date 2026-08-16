"""One inference pass; cache per-frame best score for the target class; then sweep
(threshold x temporal gate) offline for BOTH recall and false-alarm rate."""
import cv2, numpy as np, glob, json, collections, os, sys, pickle
S="/private/tmp/claude-501/-Users-bnprs-BPR-GitRepos1-aim-pat/fef92d97-9c1d-4a20-9280-d5f4aab6ce0a/scratchpad"
SZ=640
which=sys.argv[1]
if which=="fight":
    model, CLS, POS = ".models/bpr.m10006.onnx", 1, f"{S}/pos/fight/*.mp4"
else:
    model, CLS, POS = ".models/bpr.m10005.onnx", 0, f"{S}/pos/smoke/*.mp4"
NEG="/Users/bnprs/BPR/Datasets/activity-video/UCF101_subset/*/*/*.avi"
net=cv2.dnn.readNetFromONNX(model)
def frame_score(fr):
    h,w=fr.shape[:2]; s=min(SZ/w,SZ/h); lw,lh=int(round(w*s)),int(round(h*s))
    px,py=(SZ-lw)//2,(SZ-lh)//2
    c=np.full((SZ,SZ,3),114,np.uint8); c[py:py+lh,px:px+lw]=cv2.resize(fr,(lw,lh))
    net.setInput(cv2.dnn.blobFromImage(c,1/255.0,(SZ,SZ),swapRB=True,crop=False))
    o=net.forward()[0].T; sc=o[:,4:]; am=sc.argmax(1); mx=sc.max(1)
    v=mx[am==CLS]
    return float(v.max()) if v.size else 0.0
def scan(pat):
    out=[]
    for p in sorted(glob.glob(pat)):
        cap=cv2.VideoCapture(p); fps=cap.get(cv2.CAP_PROP_FPS) or 25.0
        step=max(1,int(round(fps))); i=0; seq=[]
        while True:
            ok,fr=cap.read()
            if not ok: break
            if i%step==0: seq.append(frame_score(fr))
            i+=1
        cap.release()
        if seq: out.append(seq)
    return out
cache=f"{S}/roc_{which}.pkl"
if os.path.exists(cache):
    pos,neg=pickle.load(open(cache,"rb"))
else:
    pos=scan(POS); neg=scan(NEG); pickle.dump((pos,neg),open(cache,"wb"))
def alarms(seqs,thr,buf,mh):
    n=0
    for s in seqs:
        d=collections.deque([0]*buf,maxlen=buf)
        for v in s:
            d.append(1 if v>=thr else 0)
            if sum(d)>=mh: n+=1; break
    return n
print(f"{which.upper()}   positives={len(pos)}  negatives={len(neg)}")
print(f"{'gate':<8}{'thr':>6}{'recall':>10}{'false-alarm':>14}")
gates=[(8,3),(6,2)] if which=="fight" else [(6,2),(8,3),(8,4)]
for buf,mh in gates:
    for thr in (0.30,0.40,0.50,0.60,0.70):
        r=alarms(pos,thr,buf,mh)/len(pos); f=alarms(neg,thr,buf,mh)/len(neg)
        star=" <- current" if (thr==0.50 and ((which=="fight" and (buf,mh)==(8,3)) or (which=="smoke" and (buf,mh)==(6,2)))) else ""
        print(f"{f'{mh}/{buf}':<8}{thr:>6.2f}{100*r:>9.1f}%{100*f:>13.1f}%{star}")
