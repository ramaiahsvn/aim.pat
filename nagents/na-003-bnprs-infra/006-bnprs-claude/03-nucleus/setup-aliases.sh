#!/bin/bash
# ============================================================
#  Quick setup: BNPRS session aliases (AID notation)
# ============================================================
#  Generates shell aliases for each agent work home (~/aid.NNN):
#     aNNN  → cd ~/aid.NNN && bnprs-sessions.sh start AID.NNN
#     rs    → bnprs-sessions.sh
#     rsl   → bnprs-sessions.sh list
#  Idempotent: re-running replaces the managed block between the markers.
# ============================================================

SCRIPT="/home/devops/bnprs-sessions.sh"
MAP="/home/devops/aid-eid-map.tsv"
BEGIN="# >>> BNPRS session aliases >>>"
END="# <<< BNPRS session aliases <<<"

eid_for(){ awk -v a="$1" '!/^#/ && $1==a {print $2}' "$MAP" 2>/dev/null | head -1; }

gen(){
    echo "$BEGIN"
    echo "alias rs='${SCRIPT}'"
    echo "alias rsl='${SCRIPT} list'"
    for dir in "$HOME"/aid.[0-9]*; do
        [ -d "$dir" ] || continue
        aid=$(basename "$dir")          # aid.027
        nnn=${aid#aid.}
        eid=$(eid_for "$nnn")
        echo "alias a${nnn}='cd ~/${aid} && ${SCRIPT} start AID.${nnn}'   # ${eid:-fresh}"
    done
    echo "$END"
}

echo ""
echo "Add these to your shell rc (managed block):"
echo ""
gen
echo ""
echo "Then type e.g.:  a027  → cd ~/aid.027 and resume AID.027"
echo "                 rsl   → list sessions"
echo ""

read -rp "Auto-append/refresh in your shell rc file? (y/n): " yn
if [[ "$yn" == "y" ]]; then
    RC="$HOME/.bashrc"; [[ -f "$HOME/.zshrc" ]] && RC="$HOME/.zshrc"
    # remove any prior managed block, then append a fresh one (idempotent)
    if [[ -f "$RC" ]]; then
        sed -i "/${BEGIN}/,/${END}/d" "$RC"
    fi
    { echo ""; gen; } >> "$RC"
    echo "Updated $RC — run: source $RC"
fi
