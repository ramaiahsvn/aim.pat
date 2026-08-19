"""Letterbox vs stretch A/B for BprVision smoke/fight detectors.

One decode pass per clip; every sampled frame (1 fps) is scored TWICE:
  stretch   — the published 2.61.1 preprocessing: blobFromImage straight to 640x640
  letterbox — 529a1aa: aspect-preserving resize onto a 114-gray 640x640 canvas
Per-frame best class score is cached, then (threshold x temporal gate) swept offline
for recall (positives) and clip false-alarm rate (negatives) — same method and
operating points as roc.py / the 2026-08-16 accuracy report.
"""
import cv2, numpy as np, glob, collections, os, sys, pickle

S = os.path.dirname(os.path.abspath(__file__))
MODELS = os.path.expanduser("~/BPR/GitRepos1/bpr.cpp/.models")
POSROOT = os.path.expanduser("~/BPR/Datasets/activity-video/vision-eval-positives")
NEG = os.path.expanduser("~/BPR/Datasets/activity-video/UCF101_subset/*/*/*.avi")
SZ = 640

which = sys.argv[1]
if which == "fight":
    model, CLS, POS = f"{MODELS}/bpr.m10006.onnx", 1, f"{POSROOT}/fight/*.mp4"
else:
    model, CLS, POS = f"{MODELS}/bpr.m10005.onnx", 0, f"{POSROOT}/smoke/*.mp4"

net = cv2.dnn.readNetFromONNX(model)

def best(o):
    o = o[0].T; sc = o[:, 4:]; am = sc.argmax(1); mx = sc.max(1)
    v = mx[am == CLS]
    return float(v.max()) if v.size else 0.0

def score_both(fr):
    # stretch — published 2.61.1
    net.setInput(cv2.dnn.blobFromImage(fr, 1/255.0, (SZ, SZ), swapRB=True, crop=False))
    s_stretch = best(net.forward())
    # letterbox — 529a1aa
    h, w = fr.shape[:2]; s = min(SZ/w, SZ/h); lw, lh = int(round(w*s)), int(round(h*s))
    px, py = (SZ-lw)//2, (SZ-lh)//2
    c = np.full((SZ, SZ, 3), 114, np.uint8); c[py:py+lh, px:px+lw] = cv2.resize(fr, (lw, lh))
    net.setInput(cv2.dnn.blobFromImage(c, 1/255.0, (SZ, SZ), swapRB=True, crop=False))
    return s_stretch, best(net.forward())

def scan(pat):
    out = []
    files = sorted(glob.glob(pat))
    for n, p in enumerate(files):
        cap = cv2.VideoCapture(p); fps = cap.get(cv2.CAP_PROP_FPS) or 25.0
        step = max(1, int(round(fps))); i = 0; seq = []
        while True:
            ok, fr = cap.read()
            if not ok: break
            if i % step == 0: seq.append(score_both(fr))
            i += 1
        cap.release()
        if seq: out.append(seq)
        if (n+1) % 50 == 0: print(f"  {n+1}/{len(files)}", flush=True)
    return out

cache = f"{S}/ab_{which}.pkl"
if os.path.exists(cache):
    pos, neg = pickle.load(open(cache, "rb"))
else:
    print("scanning positives...", flush=True); pos = scan(POS)
    print("scanning negatives...", flush=True); neg = scan(NEG)
    pickle.dump((pos, neg), open(cache, "wb"))

def alarms(seqs, idx, thr, buf, mh):
    n = 0
    for sq in seqs:
        d = collections.deque([0]*buf, maxlen=buf)
        for pair in sq:
            d.append(1 if pair[idx] >= thr else 0)
            if sum(d) >= mh: n += 1; break
    return n

print(f"\n{which.upper()}  positives={len(pos)}  negatives={len(neg)}   (A=stretch/2.61.1, B=letterbox/529a1aa)")
print(f"{'gate':<7}{'thr':>5} | {'recall A':>9}{'recall B':>10} | {'FA A':>7}{'FA B':>7}")
gates = [(8, 3), (6, 2)] if which == "fight" else [(6, 2), (8, 3), (8, 4)]
for buf, mh in gates:
    for thr in (0.30, 0.40, 0.50, 0.60, 0.70):
        ra = alarms(pos, 0, thr, buf, mh)/len(pos); rb = alarms(pos, 1, thr, buf, mh)/len(pos)
        fa = alarms(neg, 0, thr, buf, mh)/len(neg); fb = alarms(neg, 1, thr, buf, mh)/len(neg)
        star = " <- current" if (thr == 0.50 and ((which == "fight" and (buf, mh) == (8, 3))
                                                  or (which == "smoke" and (buf, mh) == (6, 2)))) else ""
        print(f"{f'{mh}/{buf}':<7}{thr:>5.2f} | {100*ra:>8.1f}%{100*rb:>9.1f}% | {100*fa:>6.1f}%{100*fb:>6.1f}%{star}")
