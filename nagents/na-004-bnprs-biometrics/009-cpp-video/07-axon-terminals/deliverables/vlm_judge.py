"""Qwen2.5-VL as a strict yes/no FIGHT and SMOKE judge, scored like the detector evals.

Samples 8 frames/clip (as vlm_lane.py), asks one binary question, parses YES/NO.
Fight question -> 50 fight positives + 60 negatives; smoke question -> 50 smoke positives +
the same 60 negatives. Recall = yes-rate on positives, FA = yes-rate on negatives.
Per-class breakdown via ids_*.json. Verdicts logged to vlm_judge.jsonl for audit.
"""
import cv2, glob, json, os, sys, time
from pathlib import Path

S = os.path.dirname(os.path.abspath(__file__))
POSROOT = os.path.expanduser("~/BPR/Datasets/activity-video/vision-eval-positives")
NEG = os.path.expanduser("~/BPR/Datasets/activity-video/UCF101_subset/*/*/*.avi")
MODEL = "mlx-community/Qwen2.5-VL-7B-Instruct-4bit"
N_FRAMES, N_POS, N_NEG = 8, 50, 60

Q = {
    "fight": ("These are frames sampled in order from one video clip. Question: does this clip "
              "show a physical fight or violence between people (hitting, punching, wrestling "
              "aggressively, attacking)? Sport practice like basketball, weightlifting or archery "
              "is NOT a fight. Answer with exactly one word: YES or NO."),
    "smoke": ("These are frames sampled in order from one video clip. Question: is smoke or fire "
              "visible in this clip (smoke plumes, flames, burning)? Steam from cooking alone "
              "does not count unless clearly smoke or flame. Answer with exactly one word: "
              "YES or NO."),
}

def stride_sample(files, n):
    files = sorted(files)
    if len(files) <= n: return files
    step = len(files) / n
    return [files[int(i * step)] for i in range(n)]

def sample_frames(video):
    cap = cv2.VideoCapture(str(video))
    total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT)) or 1
    idxs = [int(i * (total - 1) / max(1, N_FRAMES - 1)) for i in range(N_FRAMES)]
    out = []
    for k, i in enumerate(idxs):
        cap.set(cv2.CAP_PROP_POS_FRAMES, i)
        ok, frame = cap.read()
        if ok:
            p = f"{S}/vlmf_{k}.jpg"
            cv2.imwrite(p, frame, [cv2.IMWRITE_JPEG_QUALITY, 90])
            out.append(p)
    cap.release()
    return out

from mlx_vlm import generate, load
from mlx_vlm.prompt_utils import apply_chat_template

t0 = time.perf_counter()
model, processor = load(MODEL)
print(f"model load: {time.perf_counter()-t0:.1f}s", flush=True)
config = model.config

logf = open(f"{S}/vlm_judge.jsonl", "a")
def judge(video, which):
    frames = sample_frames(video)
    if not frames: return None
    prompt = apply_chat_template(processor, config, Q[which], num_images=len(frames))
    out = generate(model, processor, prompt, frames, max_tokens=8, verbose=False)
    text = (out.text if hasattr(out, "text") else str(out)).strip().upper()
    verdict = text.startswith("YES")
    logf.write(json.dumps({"clip": os.path.basename(video), "q": which,
                           "raw": text[:40], "yes": verdict}) + "\n"); logf.flush()
    return verdict

negs = stride_sample(glob.glob(NEG), N_NEG)
for which in ("fight", "smoke"):
    ids = json.load(open(f"{POSROOT}/ids_{which}.json"))
    pos = stride_sample(glob.glob(f"{POSROOT}/{which}/*.mp4"), N_POS)
    t0 = time.perf_counter()
    pv = [(p, judge(p, which)) for p in pos]
    nv = [(p, judge(p, which)) for p in negs]
    dt = time.perf_counter() - t0
    pv = [(p, v) for p, v in pv if v is not None]; nv = [(p, v) for p, v in nv if v is not None]
    rec = sum(v for _, v in pv) / len(pv); fa = sum(v for _, v in nv) / len(nv)
    print(f"\n{which.upper()}: recall {100*rec:.1f}% ({sum(v for _,v in pv)}/{len(pv)})   "
          f"FA {100*fa:.1f}% ({sum(v for _,v in nv)}/{len(nv)})   "
          f"[{dt/ (len(pv)+len(nv)):.1f}s/clip]", flush=True)
    bycls = {}
    for p, v in pv:
        cls = ids.get(os.path.basename(p)[:11], "?")
        bycls.setdefault(cls, []).append(v)
    for cls, vs in sorted(bycls.items()):
        print(f"  {cls:<28} n={len(vs):<3} recall {100*sum(vs)/len(vs):5.1f}%", flush=True)
    fp = [os.path.basename(p) for p, v in nv if v]
    if fp: print(f"  false-positive negatives: {fp[:6]}", flush=True)
