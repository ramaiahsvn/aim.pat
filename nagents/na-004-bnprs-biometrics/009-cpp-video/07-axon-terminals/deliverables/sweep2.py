"""Faithful sweep: a box counts only when argmax(class)==violence, as BprYoloDetector does."""
import cv2, numpy as np, glob
SZ=640
net=cv2.dnn.readNetFromONNX("/Users/bnprs/BPR/GitRepos1/bpr.cpp/.models/bpr.m10006.onnx")
best_viol=[]      # per frame: best score among boxes whose argmax is violence
for p in sorted(glob.glob("/Users/bnprs/BPR/Datasets/activity-video/UCF101_subset/*/*/*.avi")):
    cap=cv2.VideoCapture(p); fps=cap.get(cv2.CAP_PROP_FPS) or 25.0
    step=max(1,int(round(fps))); i=0
    while True:
        ok,fr=cap.read()
        if not ok: break
        if i%step==0:
            h,w=fr.shape[:2]; s=min(SZ/w,SZ/h); lw,lh=int(round(w*s)),int(round(h*s))
            px,py=(SZ-lw)//2,(SZ-lh)//2
            c=np.full((SZ,SZ,3),114,np.uint8); c[py:py+lh,px:px+lw]=cv2.resize(fr,(lw,lh))
            net.setInput(cv2.dnn.blobFromImage(c,1/255.0,(SZ,SZ),swapRB=True,crop=False))
            d=net.forward()[0].T
            sc=d[:,4:]; am=sc.argmax(1); mx=sc.max(1)
            v=mx[am==0]
            best_viol.append(float(v.max()) if v.size else 0.0)
        i+=1
    cap.release()
a=np.array(best_viol)
print(f"negative frames: {len(a)}   (ZERO contain violence)")
print("per-frame best VIOLENCE-class score (argmax-faithful):")
for q in (25,50,75,90,95,99): print(f"   p{q:<3} = {np.percentile(a,q):.3f}")
print(f"   max  = {a.max():.3f}")
print(f"\n{'threshold':>10}{'neg frames firing':>20}{'FP rate':>12}")
for t in (0.5,0.6,0.7,0.8,0.85,0.9,0.95):
    n=int((a>=t).sum()); print(f"{t:>10.2f}{n:>20}{100*n/len(a):>11.1f}%")
