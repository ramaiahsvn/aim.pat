#!/usr/bin/env bash
#
# package-mces2-release.sh — assemble a BprMces2 release into the ZohoWorkDrive
# release folder along with its runtime dependencies.
#
# Runs on pat-m4p (the Zoho path is a local sync folder; the Windows CI runner
# cannot reach it). The C# DLLs are Windows-only and come from the CI runner's
# ci_artifacts/; the native libBprCardQi.dll (32-bit) is built locally via
# `make BprCardQi-windows-32` in bpr.cpp. See the agent nucleus "MCES2 release
# packaging" convention and long-term mem on the x86-only MCES2 framework.
#
# Usage:
#   package-mces2-release.sh --ci-artifacts <dir> --version vX.YY.ZZ [options]
#
# Required:
#   --ci-artifacts <dir>   Folder holding the CI-built BprMces2*.dll + globalplatform.net.dll
#                          (use the x86 build for --arch 32, the x64 build for --arch 64)
#   --version vX.YY.ZZ     Aggregate Mces2 release label (parent subfolder name)
#
# Options:
#   --arch 32|64             Target bitness (default: 32). Output goes to
#                            <release-root>/<version>/windows-<arch>/; deps come from
#                            Dlls-<arch>bit and libBprCardQi windows-<arch>.
#   --native-version X.Y.Z   libBprCardQi version to pull (default: 2.56.8)
#   --mces2-repo <path>      trp1002.cperso.mces2 checkout (default below)
#   --bpr-cpp <path>         bpr.cpp checkout (default below)
#   --release-root <path>    Zoho Mces2 release root (default below)
#   --force                  Overwrite an existing target version folder
#   --dry-run                Show what would be copied; copy nothing
#   -h | --help              This help
#
set -euo pipefail

# ---- defaults -------------------------------------------------------------
NATIVE_VERSION="2.56.8"
ARCH="32"
MCES2_REPO="/Users/bnprs/BPR/GitRepos2/TRP1002_cPerso/trp1002.cperso.mces2"
BPR_CPP="/Users/bnprs/BPR/GitRepos1/bpr.cpp"
RELEASE_ROOT="/Users/bnprs/Library/CloudStorage/ZohoWorkDriveTrueSync-bnprs/Z_RELEASE/TRP1002-cPerso/Mces2"
CI_ARTIFACTS=""
VERSION=""
FORCE=0
DRY_RUN=0

# Managed DLLs produced by the CI build (copied from --ci-artifacts).
# PersoCC is required; the rest are copied if present (the buildable set evolves).
BUILT_REQUIRED=( "BprMces2PersoCC.dll" )
BUILT_OPTIONAL=(
  "BprMces2PrePersoCC.dll"
  "BprMces2PersoCL.dll"
  "BprMces2DataExchangeCL.dll"
  "globalplatform.net.dll"
)

# Framework dependencies (x86) from the repo's Dlls-32bit/ — all required.
DEP_DLLS=(
  "BaseLib.dll"
  "Bpr.Card.Core.dll"
  "ChipCodingBaseLib.dll"
  "GS.Apdu.dll"
  "GS.HexLibrary.dll"
  "LightCore.dll"
  "log4net.dll"
)

# ---- arg parsing ----------------------------------------------------------
usage() { sed -n '2,40p' "$0"; exit "${1:-0}"; }
while [ $# -gt 0 ]; do
  case "$1" in
    --ci-artifacts)   CI_ARTIFACTS="$2"; shift 2;;
    --version)        VERSION="$2"; shift 2;;
    --arch)           ARCH="$2"; shift 2;;
    --native-version) NATIVE_VERSION="$2"; shift 2;;
    --mces2-repo)     MCES2_REPO="$2"; shift 2;;
    --bpr-cpp)        BPR_CPP="$2"; shift 2;;
    --release-root)   RELEASE_ROOT="$2"; shift 2;;
    --force)          FORCE=1; shift;;
    --dry-run)        DRY_RUN=1; shift;;
    -h|--help)        usage 0;;
    *) echo "ERROR: unknown arg: $1" >&2; usage 1;;
  esac
done

[ -n "$CI_ARTIFACTS" ] || { echo "ERROR: --ci-artifacts is required" >&2; usage 1; }
[ -n "$VERSION" ]      || { echo "ERROR: --version is required" >&2; usage 1; }
case "$VERSION" in v*) ;; *) echo "ERROR: --version should look like vX.YY.ZZ (got '$VERSION')" >&2; exit 1;; esac
case "$ARCH" in 32) ARCHFOLDER="windows-32";; 64) ARCHFOLDER="windows-64";; *) echo "ERROR: --arch must be 32 or 64 (got '$ARCH')" >&2; exit 1;; esac

DLLS_DIR="$MCES2_REPO/BprMces2/Dlls-${ARCH}bit"
NATIVE_DLL="$BPR_CPP/build/bnprs-libs/BprCardQi/v$NATIVE_VERSION/windows-$ARCH/libBprCardQi.dll"
CONFIG_XML="$MCES2_REPO/BprMces2/BprMces2Config.xml"
TARGET="$RELEASE_ROOT/$VERSION/$ARCHFOLDER"

echo "=== package-mces2-release ==="
echo "  ci-artifacts : $CI_ARTIFACTS"
echo "  version      : $VERSION"
echo "  arch         : ${ARCH}-bit  (deps: Dlls-${ARCH}bit)"
echo "  native       : libBprCardQi $NATIVE_VERSION (windows-$ARCH)"
echo "  target       : $TARGET"
[ "$DRY_RUN" -eq 1 ] && echo "  MODE         : DRY-RUN (no files copied)"
echo

# ---- validate sources (fail fast) ----------------------------------------
MISSING=0
need() { # need <abs-path> <label>
  if [ -f "$1" ]; then echo "  ok   $2  ($1)"; else echo "  MISS $2  ($1)" >&2; MISSING=$((MISSING+1)); fi
}

echo "-- required built DLLs (from ci-artifacts) --"
for f in "${BUILT_REQUIRED[@]}"; do need "$CI_ARTIFACTS/$f" "$f"; done
echo "-- dependency DLLs (Dlls-${ARCH}bit) --"
for f in "${DEP_DLLS[@]}"; do need "$DLLS_DIR/$f" "$f"; done
echo "-- native + config --"
need "$NATIVE_DLL" "libBprCardQi.dll"
need "$CONFIG_XML" "BprMces2Config.xml"

if [ "$MISSING" -gt 0 ]; then
  echo "ERROR: $MISSING required source(s) missing — aborting." >&2
  exit 2
fi

# Optional built DLLs (warn only)
OPTIONAL_PRESENT=()
for f in "${BUILT_OPTIONAL[@]}"; do
  if [ -f "$CI_ARTIFACTS/$f" ]; then OPTIONAL_PRESENT+=( "$f" ); else echo "  warn (optional missing): $f" >&2; fi
done

# ---- target folder --------------------------------------------------------
if [ -d "$TARGET" ]; then
  if [ "$FORCE" -eq 1 ]; then
    echo "NOTE: target exists; --force given, will overwrite."
  else
    echo "ERROR: target already exists: $TARGET (use --force to overwrite)" >&2
    exit 3
  fi
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo
  echo "DRY-RUN: would copy the above into $TARGET and write manifest.txt"
  exit 0
fi

mkdir -p "$TARGET"

MANIFEST="$TARGET/manifest.txt"
{
  echo "BprMces2 release $VERSION ($ARCHFOLDER)"
  echo "packaged-from : $(hostname)"
  echo "arch          : ${ARCH}-bit"
  echo "native        : libBprCardQi $NATIVE_VERSION (windows-$ARCH)"
  echo "ci-artifacts  : $CI_ARTIFACTS"
  echo "----------------------------------------------------------------"
  printf "%-34s %10s  %s\n" "file" "bytes" "sha256"
} > "$MANIFEST"

copy_one() { # copy_one <src> <category>
  local src="$1" cat="$2" base sz sum
  base="$(basename "$src")"
  cp -f "$src" "$TARGET/$base"
  sz=$(stat -f%z "$TARGET/$base" 2>/dev/null || wc -c < "$TARGET/$base")
  sum=$(shasum -a 256 "$TARGET/$base" | awk '{print $1}')
  printf "%-34s %10s  %s  [%s]\n" "$base" "$sz" "$sum" "$cat" >> "$MANIFEST"
  echo "  + $base  [$cat]"
}

echo
echo "-- copying --"
for f in "${BUILT_REQUIRED[@]}"; do copy_one "$CI_ARTIFACTS/$f" "built"; done
for f in "${OPTIONAL_PRESENT[@]}"; do copy_one "$CI_ARTIFACTS/$f" "built"; done
for f in "${DEP_DLLS[@]}"; do copy_one "$DLLS_DIR/$f" "dep"; done
copy_one "$NATIVE_DLL" "native"
copy_one "$CONFIG_XML" "config"

echo
echo "manifest: $MANIFEST"
echo "=== done: $VERSION packaged into $TARGET ==="
