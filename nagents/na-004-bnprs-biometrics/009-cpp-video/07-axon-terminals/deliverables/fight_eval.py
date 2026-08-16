"""Measure BprFightDetect's false-alarm rate on known-negative footage.

Replicates the production path exactly:
  - BprYoloDetector::detect  letterbox preprocessing, conf 0.5, NMS 0.45
  - BprVideoRunStream        throttleSecs = 1.0  -> ~1 analysed frame per second
  - BprFightDetect           bufferSize 8, minHits 3  (class 0 = "violence")
A clip counts as a FALSE ALARM if the temporal gate ever confirms.
"""
import cv2, numpy as np, sys, os, glob, json, collections

CONF, NMS, SZ = 0.5, 0.45, 640
BUF, MINHITS = 8, 3
net = cv2.dnn.readNetFromONNX("/Users/bnprs/BPR/GitRepos1/bpr.cpp/.models/bpr.m10006.onnx")
net.setPreferableBackend(cv2.dnn.DNN_BACKEND_OPENCV)

def detect_violence(frame):
    h, w = frame.shape[:2]
    s = min(SZ/w, SZ/h); lw, lh = int(round(w*s)), int(round(h*s))
    px, py = (SZ-lw)//2, (SZ-lh)//2
    canvas = np.full((SZ, SZ, 3), 114, np.uint8)
    canvas[py:py+lh, px:px+lw] = cv2.resize(frame, (lw, lh))
    net.setInput(cv2.dnn.blobFromImage(canvas, 1/255.0, (SZ, SZ), swapRB=True, crop=False))
    d = net.forward()[0].T
    sc = d[:, 4:]; best = sc.argmax(1); bv = sc.max(1)
    keep = (bv >= CONF) & (best == 0)          # class 0 = violence
    return int(keep.sum()), (float(bv[keep].max()) if keep.any() else 0.0)

def eval_clip(path):
    cap = cv2.VideoCapture(path)
    if not cap.isOpened(): return None
    fps = cap.get(cv2.CAP_PROP_FPS) or 25.0
    step = max(1, int(round(fps)))             # ~1 analysed frame/sec
    buf = collections.deque([0]*BUF, maxlen=BUF)
    n = hits = confirmed = 0; peak = 0.0; i = 0
    while True:
        ok, fr = cap.read()
        if not ok: break
        if i % step == 0:
            c, cf = detect_violence(fr)
            buf.append(1 if c else 0); n += 1
            hits += (1 if c else 0); peak = max(peak, cf)
            if sum(buf) >= MINHITS: confirmed += 1
        i += 1
    cap.release()
    return dict(frames=n, framehits=hits, confirmed=confirmed, peak=peak)

if __name__ == "__main__":
    clips = []
    for a in sys.argv[1:]:
        clips += sorted(glob.glob(a)) if any(ch in a for ch in "*?[") else [a]
    tot = fa = 0; fh = ft = 0
    print(f"{'clip':<52}{'frames':>7}{'fp_frames':>10}{'confirmed':>10}{'peak':>7}")
    print("-"*88)
    for c in clips:
        r = eval_clip(c)
        if not r: continue
        tot += 1; ft += r['frames']; fh += r['framehits']
        alarm = r['confirmed'] > 0
        fa += alarm
        if alarm or r['framehits']:
            print(f"{os.path.basename(c)[:50]:<52}{r['frames']:>7}{r['framehits']:>10}"
                  f"{r['confirmed']:>10}{r['peak']:>7.2f}{'  <<< FALSE ALARM' if alarm else ''}")
    print("-"*88)
    print(f"clips={tot}  clips_with_confirmed_alarm={fa} ({100*fa/max(tot,1):.1f}%)  "
          f"analysed_frames={ft}  frames_firing={fh} ({100*fh/max(ft,1):.2f}%)")
