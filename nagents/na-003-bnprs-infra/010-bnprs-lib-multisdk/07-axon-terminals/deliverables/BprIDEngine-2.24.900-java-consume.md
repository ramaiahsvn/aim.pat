# BprIDEngine 2.24.900 — Java integration

A working port of the `FaceChainCleaner.cs` face-engine surface onto BprIDEngine, built and run
against the published artifact on `linux/amd64`. Everything here has been executed, not sketched.

```
src/main/java/com/bnprs/facechain/
  FaceEngine.java          all five legacy native calls, remapped. This is the whole migration.
  FaceChainCleaner.java    the workflow above it — unchanged in shape from the .NET original.
```

## 1. Dependency

```xml
<repositories>
  <repository>
    <id>bnprs-libs</id>
    <url>https://gitlab.bnprs.ai/api/v4/projects/230/packages/maven</url>
  </repository>
</repositories>

<dependency>
  <groupId>ai.bnprs</groupId>
  <artifactId>nativesdk-bpridengine-face</artifactId>   <!-- face T12; ~60 MB -->
  <version>2.24.900</version>
</dependency>
```

JNA comes in transitively. Nothing else to install — **no OpenCV on the host, no ONNX files to
deploy, no `LD_LIBRARY_PATH`**. The jar carries the natives for `linux-x86-64`, `linux-aarch64`
and `darwin-aarch64` plus the three models, and stages them to a temp directory at first use.

> **The jar does NOT run on Windows.** It carries no Windows native, and `BprIDEngineNative`
> asks for `libBprIDEngine.so` on any non-macOS platform — so a Windows JVM fails twice over.
> This does not affect **compiling** on Windows: javac needs only the `.class` files, which are
> in the jar, so a Windows workstation deploying to Linux is fine. It bites only when something
> actually calls the engine on Windows — a local run, or a unit test that touches it — and it
> surfaces as `UnsatisfiedLinkError` on first use, not at startup, because the native loads
> lazily. Windows DLLs exist on the release share; folding them into the jar needs 2.24.901.

The lean artifact is `nativesdk-bpridengine` (~497 KB, no face T12). **Never depend on both** —
same library name, same 21 symbols, undefined winner.

### Credentials — and what "Dependency not found" actually means

The registry is private. An unauthenticated request returns **401**, Maven then records the
artifact as `(absent)`, and IntelliJ renders that as *"Dependency
ai.bnprs:nativesdk-bpridengine-face:2.24.900 not found"*. The artifact is published and fine; the
request was rejected. This is nearly always the whole problem.

`~/.m2/settings.xml` — the `<id>` **must** match the `<repository><id>` in the pom (`bnprs-libs`):

```xml
<settings>
  <servers>
    <server>
      <id>bnprs-libs</id>
      <configuration><httpHeaders><property>
        <name>Private-Token</name><value>${env.BNPRS_LIBS_TOKEN}</value>
      </property></httpHeaders></configuration>
    </server>
  </servers>
</settings>
```

**The header name depends on which kind of token you hold**, and the wrong one gives an identical
401:

| token type | header | value |
|---|---|---|
| personal access token (`read_api`) | `Private-Token` | the token |
| deploy token (`read_package_registry`) | `Deploy-Token` | the token value — **not** the username |

The read-only deploy token is `bnprs-libs-readonly`, username `bnprs-libs-ro`, and it lives on the
**group** `BPR1000` rather than on project 230 — group scope covers the project. Deploy-token
values are displayed once at creation and cannot be read back through the API, so if nobody kept
it, mint a new one instead of hunting for it.

### Still "not found" after fixing the token?

Maven caches the failed lookup, so a corrected configuration keeps reporting the old error. Clear
the poisoned entry:

```bash
rm -rf ~/.m2/repository/ai/bnprs/nativesdk-bpridengine-face
mvn -U dependency:resolve
```

**IntelliJ:** Settings -> Build, Execution, Deployment -> Build Tools -> Maven -> *User settings
file*: tick **Override** and point it at your settings.xml — IntelliJ does not reliably pick up
`~/.m2/settings.xml` by itself. Then Maven tool window -> **Reload All Maven Projects**.

Diagnose on the command line before trusting the IDE's one-line message:

```bash
mvn -X dependency:get -Dartifact=ai.bnprs:nativesdk-bpridengine-face:2.24.900
```

## 2. Call mapping

| FaceChainCleaner.cs | BprIDEngine | Change that matters |
|---|---|---|
| `Bpr_FaceRecog_T12_Init(qiCode,…)` → handle | `BprID_SetLicense(qiCode, len)` | **no handle**; call once at startup |
| `Bpr_FaceQuality_T12_Image(…, ref q, …)` | `BprID_Quality(T12, sample, …)` | same 0–100 int in `outRaw`; **no side effect** |
| …its `.t12.yml` write (`save_flag=true`) | `BprID_Extract(T12, sample, …)` | now an explicit call; you persist the bytes |
| `Bpr_FaceRecog_T12_Template(h, pathA, pathB, …)` | `BprID_Match(M12, bytesA, bytesB, …)` | takes **bytes, not paths** |
| `Bpr_FaceRecog_T12_Image(h, imgA, imgB, …)` | *(no equivalent)* extract both, then `BprID_Match` | one call becomes two |
| `Bpr_FaceRecog_T12_DeInit(handle)` | *(nothing)* | no resource to release |

## 3. Your thresholds do not change

The .NET code initialised with `(0.363, 1.128, dist_type: 0)` — cosine — which is exactly this
engine's default. On cosine, `BprID_Match`'s normalised score **is** the legacy `similarityScore`,
so `score * 100 >= SimilarityThreshold` still means what it meant. Quality's `raw` is the same
0–100 integer, so `qualityThreshold` carries over too.

One difference: a negative cosine now clamps to `0.0` instead of going negative. Both are
rejections under any threshold above zero, so no decision changes.

## 4. Four things that will bite

**`qiCode` is now mandatory.** The .NET class passes `string.Empty` (line 48) and the legacy
library accepted it. `Extract`, `Match` and `Quality` return `ERR_LICENSE` (-8) until a real code
is accepted. Version and status strings still answer unlicensed, so a startup banner works even
when the licence is the broken thing.

**Your `.t12.yml` corpus is unreadable.** Legacy templates are OpenCV `FileStorage` YAML keyed
`bpr_face_t12_features`, read from a path. These are 528-byte binary records passed as bytes. The
formats are not interchangeable in either direction — re-enrol, or write a converter. The sample
uses a distinct `.t12b` extension so a stale corpus cannot silently feed the new matcher.

**Scoring no longer enrols.** `Bpr_FaceQuality_T12_Image(save_flag: true)` also extracted the face
and wrote the template. That is how your corpus gets built today, and it is gone. `generateTemplate`
in the sample restores the behaviour explicitly: score, extract, write.

**Image-vs-image is now two calls.** In a loop, extract the gallery side **once** and reuse the
bytes — the old call re-detected both faces on every pair, so this is also a speed-up.

## 5. Verified run

```
$ mvn -s settings.xml package
$ java -cp target/classes:target/lib/* com.bnprs.facechain.FaceChainCleaner <qiCode> faces 20 60

library  BprIDEngine 2.24.900
licensed ok, T12 present

-- score + enrol --
  cam01_20260731120000.jpg     quality=25   -> clean
  cam01_20260731120500.jpg     quality=25   -> clean

chain leader: cam01_20260731120000.jpg (quality 25)

-- dedupe against the leader (template vs template) --
cam01_20260731120000.jpg vs leader
  template match score=1.0000 (x100=100.00) matched=true
cam01_20260731120500.jpg vs leader
  template match score=1.0000 (x100=100.00) matched=true

-- image vs image (extract both, then match) --
  image match score=1.0000 (x100=100.00) matched=true

  cam01_20260731120000_25.t12b   528 bytes
  cam01_20260731120500_25.t12b   528 bytes
```

`quality=25` is the same number the native, the Go binding and the .NET binding return for this
image — the binding does not change the answer.

Depending on the lean jar instead fails at startup rather than at the first extract:

```
library  BprIDEngine 2.24.900
java.lang.IllegalStateException: This is the LEAN BprIDEngine — it has no face T12 extractor,
so it cannot enrol faces. Depend on ai.bnprs:nativesdk-bpridengine-face instead.
```

## 6. Notes for the service

**Call `FaceEngine.init` once**, not per worker. There is no handle; the licence is process-global
and re-validated on every call. The engine serialises its own model access, so the class is safe
to share across threads.

**Capability-detect rather than assume.** `BprID_HasTemplate/HasMatcher/HasQuality` let the same
code run against either variant, and the three failure statuses are deliberately distinct:
`not-present` (wrong package) / `not-implemented` (no assessor for that id — every modality except
T12) / `not-registered` (unknown id).

**Templates are versioned by model, not by file format.** A future model change alters the record
length, which is why `extractTemplate` uses the size-query protocol instead of a fixed 528.
