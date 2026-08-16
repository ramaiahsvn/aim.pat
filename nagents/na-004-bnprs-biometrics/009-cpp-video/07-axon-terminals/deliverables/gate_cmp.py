"""Same per-frame smoke detections, different temporal gates — isolates the gate's contribution."""
import cv2, numpy as np, glob, collections, os
SZ=640; CONF=0.5
net=cv2.dnn.readNetFromONNX("/Users/bnprs/BPR/GitRepos1/bpr.cpp/.models/bpr.m10005.onnx")
def fires(fr):
    h,w=fr.shape[:2]; s=min(SZ/w,SZ/h); lw,lh=int(round(w*s)),int(round(h*s))
    px,py=(SZ-lw)//2,(SZ-lh)//2
    c=np.full((SZ,SZ,3),114,np.uint8); c[py:py+lh,px:px+lw]=cv2.resize(fr,(lw,lh))
    net.setInput(cv2.dnn.blobFromImage(c,1/255.0,(SZ,SZ),swapRB=True,crop=False))
    d=net.forward()[0].T; sc=d[:,4:]
    return bool((sc.max(1)>=CONF).any())
seqs=[]; byclass=collections.Counter(); tot=collections.Counter()
for p in sorted(glob.glob("/Users/bnprs/BPR/Datasets/activity-video/UCF101_subset/*/*/*.avi")):
    cap=cv2.VideoCapture(p); fps=cap.get(cv2.CAP_PROP_FPS) or 25.0
    step=max(1,int(round(fps))); i=0; seq=[]
    while True:
        ok,fr=cap.read()
        if not ok: break
        if i%step==0: seq.append(1 if fires(fr) else 0)
        i+=1
    cap.release(); seqs.append((p,seq))
    cls=os.path.basename(p).split('_')[1]; tot[cls]+=1
    if sum(seq): byclass[cls]+=1

def clip_alarms(seqs,buf,mh):
    n=0
    for _,s in seqs:
        d=collections.deque([0]*buf,maxlen=buf)
        for v in s:
            d.append(v)
            if sum(d)>=mh: n+=1; break
    return n
N=len(seqs)
print(f"clips={N}   (none contain smoke)")
for buf,mh,lbl in ((6,2,"smoke's gate 2/6  (current)"),(8,3,"fight's gate 3/8"),(8,4,"4/8"),(10,5,"5/10")):
    a=clip_alarms(seqs,buf,mh)
    print(f"  {lbl:<28} clip false-alarm rate = {a:>3}/{N} = {100*a/N:>4.1f}%")
print("\nclips with >=1 firing frame, by activity class:")
for c,n in byclass.most_common():
    print(f"  {c:<18}{n:>3}/{tot[c]:<3} ({100*n/tot[c]:.0f}%)")
