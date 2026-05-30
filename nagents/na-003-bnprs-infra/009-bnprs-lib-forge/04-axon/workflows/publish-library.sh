#!/usr/bin/env bash
# =============================================================================
#  publish-library.sh — bnprs-lib-forge (na-003 / 009)
# =============================================================================
#  Publish a PRE-BUILT BPR shared library to the GitLab Generic Package Registry.
#  This agent does NOT build — it only publishes artifacts produced by builder
#  agents under  <bpr-root>/build/bnprs-libs/<Lib>/v<ver>/<platform>/.
#
#  Pipeline:  collect → sha256 → manifest.json → upload → verify
#
#  Registry:  project BPR1000/bpr1000.bnprs-libs (id 230), Generic Packages
#  Scheme  :  package=<Lib>  version=<SemVer>  file=<platform>/<file>
#
#  Usage:
#    GITLAB_PAT=...  ./publish-library.sh --lib BprICBA --version 2.58.1
#    ./publish-library.sh --lib BprCardQi --version 2.56.3 --platform windows-64
#    ./publish-library.sh --lib BprICBA --version 2.58.1 --dry-run
#
#  Options:
#    --lib NAME           library name (e.g. BprICBA)                 [required]
#    --version X.Y.Z      SemVer, no 'v' prefix                       [required]
#    --platform P         publish only platform P (repeatable; default: all)
#    --project ID         GitLab project id                          [default: 230]
#    --bpr-root DIR       bpr.cpp checkout                  [default: ~/BPR/GitRepos1/bpr.cpp]
#    --built-by TEXT      provenance note for manifest    [default: "bpr.cpp build on pat-m4p"]
#    --force              overwrite an already-published version (DISCOURAGED)
#    --dry-run            do everything except upload
#
#  Auth: GITLAB_PAT env var (scope: api / write_package_registry). Never printed.
# =============================================================================
set -euo pipefail

API="${GITLAB_API:-https://gitlab.bnprs.ai/api/v4}"
PROJECT_ID="${PROJECT_ID:-230}"
BPR_CPP_ROOT="${BPR_CPP_ROOT:-$HOME/BPR/GitRepos1/bpr.cpp}"
BUILT_BY="bpr.cpp build on pat-m4p"
LIB="" ; VERSION="" ; FORCE=0 ; DRY_RUN=0
PLATFORMS=()

err(){ echo "ERROR: $*" >&2; exit 1; }
info(){ printf '  %s\n' "$*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lib)      LIB="$2"; shift 2 ;;
    --version)  VERSION="$2"; shift 2 ;;
    --platform) PLATFORMS+=("$2"); shift 2 ;;
    --project)  PROJECT_ID="$2"; shift 2 ;;
    --bpr-root) BPR_CPP_ROOT="$2"; shift 2 ;;
    --built-by) BUILT_BY="$2"; shift 2 ;;
    --force)    FORCE=1; shift ;;
    --dry-run)  DRY_RUN=1; shift ;;
    -h|--help)  sed -n '2,40p' "$0"; exit 0 ;;
    *) err "unknown option: $1" ;;
  esac
done

# ---- preconditions -------------------------------------------------------
[[ -n "$LIB"     ]] || err "--lib is required"
[[ -n "$VERSION" ]] || err "--version is required"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || err "version must be SemVer X.Y.Z (no 'v'): got '$VERSION'"
[[ -n "${GITLAB_PAT:-}" ]] || err "GITLAB_PAT not set in environment"
[[ "$LIB" == "BprQiEmv" ]] && err "BprQiEmv is deprecated — refusing to publish"
for t in shasum curl python3; do command -v "$t" >/dev/null || err "missing tool: $t"; done

SRC="$BPR_CPP_ROOT/build/bnprs-libs/$LIB/v$VERSION"
[[ -d "$SRC" ]] || err "artifact dir not found: $SRC  (has a builder agent produced it?)"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AGENT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPORT_DIR="$AGENT_DIR/07-axon-terminals/deliverables/publish-reports"
mkdir -p "$REPORT_DIR"

# platforms = explicit list, or every subdir of SRC
if [[ ${#PLATFORMS[@]} -eq 0 ]]; then
  while IFS= read -r d; do PLATFORMS+=("$(basename "$d")"); done \
    < <(find "$SRC" -mindepth 1 -maxdepth 1 -type d | sort)
fi
[[ ${#PLATFORMS[@]} -gt 0 ]] || err "no platform subdirectories under $SRC"

PKG_BASE="$API/projects/$PROJECT_ID/packages/generic/$LIB/$VERSION"

echo "============================================================"
echo "  Publish $LIB $VERSION  →  project $PROJECT_ID"
echo "  Source   : $SRC"
echo "  Platforms: ${PLATFORMS[*]}"
echo "  Mode     : $([[ $DRY_RUN -eq 1 ]] && echo DRY-RUN || echo LIVE)"
echo "============================================================"

# ---- immutability guard --------------------------------------------------
existing=$(curl -s --header "PRIVATE-TOKEN: $GITLAB_PAT" \
  "$API/projects/$PROJECT_ID/packages?package_name=$LIB&per_page=100")
clash=$(printf '%s' "$existing" | python3 -c '
import sys,json
try: d=json.load(sys.stdin)
except Exception: d=[]
v=sys.argv[1]
print("yes" if any(p.get("version")==v for p in d) else "no")
' "$VERSION")
if [[ "$clash" == "yes" && $FORCE -ne 1 ]]; then
  err "$LIB $VERSION already published (immutable). Bump PATCH in source, or pass --force to override."
fi
[[ "$clash" == "yes" ]] && info "WARNING: version exists; --force given, will overwrite."

# ---- source commit (provenance) ------------------------------------------
SRC_COMMIT="unknown"; SRC_DIRTY=""
if git -C "$BPR_CPP_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  SRC_COMMIT="$(git -C "$BPR_CPP_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  git -C "$BPR_CPP_ROOT" diff --quiet 2>/dev/null || SRC_DIRTY=" (working tree dirty)"
fi

# ---- collect + sha256 (build a platform|file|sha index) ------------------
INDEX="$(mktemp)"; trap 'rm -f "$INDEX"' EXIT
echo "" ; echo "[1/4] collect + checksum"
for plat in "${PLATFORMS[@]}"; do
  pdir="$SRC/$plat"
  [[ -d "$pdir" ]] || err "platform dir missing: $pdir"
  while IFS= read -r f; do
    base="$(basename "$f")"
    case "$base" in *.sha256|manifest.json) continue ;; esac   # skip sidecars
    sha="$(shasum -a 256 "$f" | awk '{print $1}')"
    printf '%s  %s\n' "$sha" "$base" > "$f.sha256"             # sidecar (standard format)
    printf '%s\t%s\t%s\n' "$plat" "$base" "$sha" >> "$INDEX"
    info "$plat/$base  sha256=${sha:0:12}…"
  done < <(find "$pdir" -mindepth 1 -maxdepth 1 -type f | sort)
done
[[ -s "$INDEX" ]] || err "no publishable files found under $SRC"

# ---- manifest.json -------------------------------------------------------
echo "" ; echo "[2/4] manifest.json"
MANIFEST="$SRC/manifest.json"
PUBLISHED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
python3 - "$INDEX" "$MANIFEST" <<PY
import sys, json, collections
index, out = sys.argv[1], sys.argv[2]
plats = collections.OrderedDict()
for line in open(index):
    plat, fn, sha = line.rstrip("\n").split("\t")
    plats.setdefault(plat, []).append({"file": fn, "sha256": sha})
doc = {
    "library": "$LIB",
    "version": "$VERSION",
    "source_repo": "bpr.cpp",
    "source_commit": "$SRC_COMMIT$SRC_DIRTY",
    "built_by": "$BUILT_BY",
    "published_by": "bnprs-lib-forge (na-003/009)",
    "published_at": "$PUBLISHED_AT",
    "registry_project_id": $PROJECT_ID,
    "platforms": plats,
}
json.dump(doc, open(out, "w"), indent=2)
print("  wrote", out)
PY

# ---- upload --------------------------------------------------------------
echo "" ; echo "[3/4] upload"
upload(){ # $1 local file, $2 remote path under PKG_BASE
  local lf="$1" rp="$2"
  if [[ $DRY_RUN -eq 1 ]]; then info "DRY-RUN would PUT $rp"; return 0; fi
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' --request PUT \
    --header "PRIVATE-TOKEN: $GITLAB_PAT" --upload-file "$lf" "$PKG_BASE/$rp")
  [[ "$code" == "201" ]] || err "upload failed ($code) for $rp"
  info "PUT $rp → $code"
}
while IFS=$'\t' read -r plat base sha; do
  upload "$SRC/$plat/$base"          "$plat/$base"
  upload "$SRC/$plat/$base.sha256"   "$plat/$base.sha256"
done < "$INDEX"
upload "$MANIFEST" "manifest.json"

# ---- verify (download back + compare sha256) -----------------------------
echo "" ; echo "[4/4] verify"
if [[ $DRY_RUN -eq 1 ]]; then
  info "DRY-RUN: skipping verify"
else
  while IFS=$'\t' read -r plat base sha; do
    tmp="$(mktemp)"
    code=$(curl -s -o "$tmp" -w '%{http_code}' --header "PRIVATE-TOKEN: $GITLAB_PAT" \
      "$PKG_BASE/$plat/$base")
    got="$(shasum -a 256 "$tmp" | awk '{print $1}')"; rm -f "$tmp"
    [[ "$code" == "200" ]] || err "verify GET failed ($code) for $plat/$base"
    [[ "$got" == "$sha" ]] || err "checksum mismatch for $plat/$base (local $sha, remote $got)"
    info "$plat/$base  ✓ 200, sha256 matches"
  done < "$INDEX"
fi

# ---- report --------------------------------------------------------------
REPORT="$REPORT_DIR/$LIB-$VERSION.md"
{
  echo "# Publish report — $LIB $VERSION"
  echo ""
  echo "- Published at: $PUBLISHED_AT"
  echo "- Registry project: $PROJECT_ID (BPR1000/bpr1000.bnprs-libs)"
  echo "- Source: bpr.cpp @ $SRC_COMMIT$SRC_DIRTY"
  echo "- Built by: $BUILT_BY"
  echo "- Mode: $([[ $DRY_RUN -eq 1 ]] && echo DRY-RUN || echo LIVE)"
  echo ""
  echo "| Platform | File | sha256 |"
  echo "|----------|------|--------|"
  while IFS=$'\t' read -r plat base sha; do echo "| $plat | $base | \`$sha\` |"; done < "$INDEX"
} > "$REPORT"

echo ""
echo "============================================================"
echo "  DONE — $LIB $VERSION ($([[ $DRY_RUN -eq 1 ]] && echo dry-run || echo published))"
echo "  Report: $REPORT"
echo "  Consume base: $PKG_BASE/<platform>/<file>"
echo "============================================================"
