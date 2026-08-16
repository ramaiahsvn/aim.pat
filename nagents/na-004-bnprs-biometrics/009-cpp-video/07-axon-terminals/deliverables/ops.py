"""Convert rates into operator experience: false alarms per camera per hour/day,
counting distinct alarm ONSETS over the negative corpus (1 analysis/sec => 1 frame ~ 1 s)."""
import pickle, collections
S="/private/tmp/claude-501/-Users-bnprs-BPR-GitRepos1-aim-pat/fef92d97-9c1d-4a20-9280-d5f4aab6ce0a/scratchpad"
def onsets(seqs, thr, buf, mh):
    ev=0; secs=0
    for s in seqs:
        secs+=len(s)
        d=collections.deque([0]*buf,maxlen=buf); armed=False
        for v in s:
            d.append(1 if v>=thr else 0)
            hot = sum(d)>=mh
            if hot and not armed: ev+=1; armed=True
            elif not hot: armed=False
    return ev, secs
def recall(seqs,thr,buf,mh):
    n=0
    for s in seqs:
        d=collections.deque([0]*buf,maxlen=buf)
        for v in s:
            d.append(1 if v>=thr else 0)
            if sum(d)>=mh: n+=1; break
    return n/len(seqs)
for name,pts in (("FIGHT",[(0.50,8,3,"current"),(0.40,8,3,"proposed"),(0.30,8,3,"")]),
                 ("SMOKE",[(0.50,6,2,"current"),(0.30,8,3,"proposed"),(0.50,8,4,"")])):
    pos,neg=pickle.load(open(f"{S}/roc_{name.lower()}.pkl","rb"))
    print(f"=== {name} ===  (negatives: ordinary activity, no target event present)")
    print(f"{'point':<16}{'recall':>8}{'FA/hour':>10}{'FA/day':>9}{'FA/day x50cam':>15}")
    for thr,buf,mh,tag in pts:
        ev,secs = onsets(neg,thr,buf,mh)
        per_h = ev/(secs/3600.0)
        r = recall(pos,thr,buf,mh)
        print(f"{f'{mh}/{buf}@{thr:.2f} {tag}':<16}{100*r:>7.1f}%{per_h:>10.1f}{per_h*24:>9.0f}{per_h*24*50:>15,.0f}")
    print()
