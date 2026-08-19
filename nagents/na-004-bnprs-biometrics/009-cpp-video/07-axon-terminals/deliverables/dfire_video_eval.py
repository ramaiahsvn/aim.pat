"""D-Fire-tuned yolov8s as a VIDEO alarm, measured like the 2026-08-16/19 evals.

Scores every 1-fps frame of the smoke positives (417) and UCF negatives (405) with the
fine-tuned detector; caches per-frame (smoke_conf, fire_conf); sweeps (threshold x temporal
gate) for recall and clip false-alarm rate; per-class recall via ids_smoke.json.
Comparison target: shipped bpr.m10005 (stretch) = 29.0% recall / 10.4% FA at 2/6 @ 0.50.
"""
import cv2, glob, os, sys, json, pickle, collections
from ultralytics import YOLO

S = os.path.dirname(os.path.abspath(__file__))
W = os.path.expanduser("~/BPR/Datasets/fire-smoke/runs/dfire_yolov8s/weights/best.pt")
POS = os.path.expanduser("~/BPR/Datasets/activity-video/vision-eval-positives/smoke/*.mp4")
IDS = os.path.expanduser("~/BPR/Datasets/activity-video/vision-eval-positives/ids_smoke.json")
NEG = os.path.expanduser("~/BPR/Datasets/activity-video/UCF101_subset/*/*/*.avi")
SMOKE_CLS, FIRE_CLS = 0, 1  # D-Fire convention

model = YOLO(W)

def frame_score(fr):
    r = model(fr, imgsz=640, conf=0.01, verbose=False, device="mps")[0]
    smoke = fire = 0.0
    for b in r.boxes:
        c, conf = int(b.cls), float(b.conf)
        if c == SMOKE_CLS: smoke = max(smoke, conf)
        elif c == FIRE_CLS: fire = max(fire, conf)
    return smoke, fire

def scan(pat):
    out = {}
    files = sorted(glob.glob(pat))
    for n, p in enumerate(files):
        cap = cv2.VideoCapture(p); fps = cap.get(cv2.CAP_PROP_FPS) or 25.0
        step = max(1, int(round(fps))); i = 0; seq = []
        while True:
            ok, fr = cap.read()
            if not ok: break
            if i % step == 0: seq.append(frame_score(fr))
            i += 1
        cap.release()
        if seq: out[os.path.basename(p)] = seq
        if (n+1) % 50 == 0: print(f"  {n+1}/{len(files)}", flush=True)
    return out

cache = f"{S}/dfire_video.pkl"
if os.path.exists(cache):
    pos, neg = pickle.load(open(cache, "rb"))
else:
    print("positives...", flush=True); pos = scan(POS)
    print("negatives...", flush=True); neg = scan(NEG)
    pickle.dump((pos, neg), open(cache, "wb"))

ids = json.load(open(IDS))
def clip_class(name): return ids.get(name[:11], "?")

def alarm(seq, idx, thr, buf, mh):
    d = collections.deque([0]*buf, maxlen=buf)
    for pair in seq:
        d.append(1 if pair[idx] >= thr else 0)
        if sum(d) >= mh: return True
    return False

print(f"\nD-FIRE yolov8s  smoke-positives={len(pos)}  negatives={len(neg)}")
print("SMOKE class alarm (compare shipped m10005 stretch: 2/6@0.50 -> 29.0% recall / 10.4% FA)")
print(f"{'gate':<7}{'thr':>5}{'recall':>9}{'FA':>8}")
for buf, mh in [(6, 2), (8, 3)]:
    for thr in (0.30, 0.40, 0.50, 0.60, 0.70):
        r = sum(alarm(s, 0, thr, buf, mh) for s in pos.values())/len(pos)
        f = sum(alarm(s, 0, thr, buf, mh) for s in neg.values())/len(neg)
        print(f"{f'{mh}/{buf}':<7}{thr:>5.2f}{100*r:>8.1f}%{100*f:>7.1f}%")

print("\nFIRE class alarm on same corpora (per-class recall matters; negatives have no fire)")
for buf, mh in [(6, 2)]:
    for thr in (0.30, 0.50, 0.70):
        r = sum(alarm(s, 1, thr, buf, mh) for s in pos.values())/len(pos)
        f = sum(alarm(s, 1, thr, buf, mh) for s in neg.values())/len(neg)
        print(f"{f'{mh}/{buf}':<7}{thr:>5.2f}{100*r:>8.1f}%{100*f:>7.1f}%")

print("\nPer-class SMOKE recall at 2/6 @ 0.50 (and fire-class recall in parens):")
bycls = collections.defaultdict(list)
for name, seq in pos.items(): bycls[clip_class(name)].append(seq)
for cls, seqs in sorted(bycls.items()):
    rs = sum(alarm(s, 0, 0.50, 6, 2) for s in seqs)/len(seqs)
    rf = sum(alarm(s, 1, 0.50, 6, 2) for s in seqs)/len(seqs)
    print(f"  {cls:<28} n={len(seqs):<4} smoke {100*rs:5.1f}%   (fire {100*rf:5.1f}%)")
