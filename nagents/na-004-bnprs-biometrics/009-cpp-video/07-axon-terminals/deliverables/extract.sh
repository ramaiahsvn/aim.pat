set -u
S=/private/tmp/claude-501/-Users-bnprs-BPR-GitRepos1-aim-pat/fef92d97-9c1d-4a20-9280-d5f4aab6ce0a/scratchpad
D=/Users/bnprs/BPR/Datasets/activity-video/kinetics-dataset/k400_targz/train
python3 -c "
import json;print('\n'.join(json.load(open('$S/ids_fight.json'))))" > $S/f_ids.txt
python3 -c "
import json;print('\n'.join(json.load(open('$S/ids_smoke.json'))))" > $S/s_ids.txt
for p in $(seq 0 7); do
  T=$D/part_$p.tar.gz
  [ -f "$T" ] || continue
  tar -tzf "$T" 2>/dev/null | grep '\.mp4$' > $S/list.txt
  # member basename first 11 chars = youtube id
  awk -F'/' '{print $NF}' $S/list.txt | cut -c1-11 > $S/ids_in_part.txt
  paste -d'\t' $S/ids_in_part.txt $S/list.txt > $S/pair.txt
  grep -Ff $S/f_ids.txt $S/pair.txt | cut -f2 > $S/want_f.txt || true
  grep -Ff $S/s_ids.txt $S/pair.txt | cut -f2 > $S/want_s.txt || true
  [ -s $S/want_f.txt ] && tar -xzf "$T" -C $S/pos/fight --strip-components=1 -T $S/want_f.txt 2>/dev/null
  [ -s $S/want_s.txt ] && tar -xzf "$T" -C $S/pos/smoke --strip-components=1 -T $S/want_s.txt 2>/dev/null
  echo "part_$p: fight+$(wc -l < $S/want_f.txt) smoke+$(wc -l < $S/want_s.txt)"
done
echo "TOTAL fight: $(ls $S/pos/fight | wc -l)  smoke: $(ls $S/pos/smoke | wc -l)"
