# armhf — Raspberry Pi 32-bit cross-compile toolbox

Docker-based cross-compiler for **Linux armv7 hard-float** (Raspberry Pi OS 32-bit, Debian armhf).
Runs from macOS (or any Docker host). Shared across all BPR repos.

## One-time setup

```sh
./build-image.sh
```
Builds `bpr-cross/armhf:bookworm` (debian:bookworm + `g++-arm-linux-gnueabihf`).

Optional — add to PATH so wrappers are callable by bare name:
```sh
echo 'export PATH="/Users/bnprs/BprTools/armhf:$PATH"' >> ~/.zshrc
```

## Usage

From any repo, with the current directory as the source root:

```sh
armhf-g++ -O2 -fPIC -std=c++17 -c src/foo.cpp -o build/foo.o
armhf-ar  rcs build/libfoo.a build/foo.o
armhf-g++ -shared -o build/libfoo.so build/foo.o
```

All paths must be **under $PWD** — the wrappers mount only the current directory
(`$PWD` → `/work`) into the container. If a file you need is outside the repo,
run the wrapper from a common parent directory.

## Verifying output

Inside the container, `file` is installed so you can spot-check:
```sh
docker run --rm -v "$PWD":/work -w /work bpr-cross/armhf:bookworm file build/foo.o
# → ELF 32-bit LSB relocatable, ARM, EABI5 version 1 (SYSV), ...
```

To confirm a specific symbol is exported:
```sh
docker run --rm -v "$PWD":/work -w /work bpr-cross/armhf:bookworm \
    arm-linux-gnueabihf-nm --defined-only build/foo.o | grep my_symbol
```

## Worked example — compile an orphan `.cpp` to `.o` + `.a`

Scenario: a single C++ source file that is **not** part of any existing library
target (no CMake rule, no caller, self-contained includes) and you want to
produce an armhf object file and a static library from it — for example to
ship it to a Raspberry Pi build outside the main tree.

Worked against `bpr.cpp/src/BprScripts/QiScript/apdu_qi_write_central_perso_gnd.cpp`
on 2026-04-14 — compiles clean, no warnings.

```sh
# From the repo root (bpr.cpp in this case)
cd /Users/bnprs/BPR/GitRepos1/bpr.cpp

# 1. Output directory
mkdir -p build/raspberry/standalone

# 2. Compile .cpp → .o (armhf ELF relocatable)
armhf-g++ -O2 -fPIC -std=c++17 -Wno-deprecated-declarations \
    -c src/BprScripts/QiScript/apdu_qi_write_central_perso_gnd.cpp \
    -o build/raspberry/standalone/apdu_qi_write_central_perso_gnd.o

# 3. Archive .o → .a (note the `lib` prefix — required for `-l` linking)
armhf-ar rcs \
    build/raspberry/standalone/libapdu_qi_write_central_perso_gnd.a \
    build/raspberry/standalone/apdu_qi_write_central_perso_gnd.o

# 4. Verify: must report "ELF 32-bit LSB relocatable, ARM"
docker run --rm -v "$PWD":/work -w /work bpr-cross/armhf:bookworm \
    file build/raspberry/standalone/apdu_qi_write_central_perso_gnd.o \
         build/raspberry/standalone/libapdu_qi_write_central_perso_gnd.a
```

**Flag notes:**
- `-fPIC` — required if the `.a` may later be linked into a shared library on the Pi.
- `-std=c++17` — file uses `std::codecvt` headers; fine under C++17 (removed in C++26).
- `-Wno-deprecated-declarations` — belt-and-braces; `std::codecvt_utf8` is deprecated but still available.
- `ar rcs` — **r**eplace members, **c**reate if missing, build **s**ymbol index.

**Naming convention gotcha:**
Keep the `lib` prefix on the `.a` — otherwise GNU `ld -l<name>` won't find it and
consumers must link by absolute path. So the `.a` name differs from the `.cpp` basename:
- Source : `apdu_qi_write_central_perso_gnd.cpp`
- Object : `apdu_qi_write_central_perso_gnd.o`   *(matches source basename)*
- Archive: `libapdu_qi_write_central_perso_gnd.a` *(prefixed with `lib`)*

Link from a downstream program:
```sh
armhf-g++ main.cpp \
    -L build/raspberry/standalone \
    -lapdu_qi_write_central_perso_gnd \
    -o main.armhf
```

## Why Docker instead of native Homebrew toolchain?

The `messense/macos-cross-toolchains` tap provides `arm-unknown-linux-gnueabihf-gcc`,
which works but ships a different triple than Debian (`unknown` vs. Debian's
implicit `linux-gnueabihf`), causing friction with cmake toolchain files written
for the Debian naming. Docker gives the exact Debian toolchain the rest of the
BPR build system expects, identical to CI.

## Files

- `Dockerfile` — image recipe (debian:bookworm-slim + g++-arm-linux-gnueabihf)
- `build-image.sh` — one-shot image build
- `armhf-g++`, `armhf-gcc`, `armhf-ar`, `armhf-strip` — thin wrappers
