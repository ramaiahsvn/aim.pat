# BprFace 2.24.115 — Java on Linux: developer integration guide

Add **one Maven dependency** and get a working, self-contained BprFace. The native
(OpenCV statically bundled) and the encrypted model blob are inside the JAR and auto-extracted
together at load — **you copy no binaries**. Platforms: **linux-x86-64, linux-aarch64**.

## 0. Prerequisites

1. **JDK 11+** (the wrapper is compiled for release 11; JNA loads the native at runtime).
2. **A license `qiCode`** — REQUIRED. Every `*_Init` takes it; the engine will not initialize
   without a valid one. Obtain it from the BNPRS licensing flow (BGL / BprLicBase, na-003/011).
   Treat it as a secret; do not hard-code in source you commit.
3. **Read access to the package registry** — the read-only deploy token `bnprs-libs-readonly`
   (scope `read_package_registry`) on `gitlab.bnprs.ai` project 230. Export it as an env var:
   ```bash
   export GITLAB_READ_TOKEN=<bnprs-libs-readonly token>
   ```

You do NOT need OpenCV, ONNX Runtime, ffmpeg, or any system libraries — the native is
self-contained (verify: `ldd libBprFace.so` shows no `opencv`).

## 1. Configure the Maven registry (`~/.m2/settings.xml`)

```xml
<settings>
  <servers>
    <server>
      <id>gitlab-bnprs-libs</id>
      <configuration>
        <httpHeaders>
          <property>
            <name>Private-Token</name>
            <value>${env.GITLAB_READ_TOKEN}</value>
          </property>
        </httpHeaders>
      </configuration>
    </server>
  </servers>
</settings>
```

## 2. Add the repository + dependency (`pom.xml`)

```xml
<repositories>
  <repository>
    <id>gitlab-bnprs-libs</id>
    <url>https://gitlab.bnprs.ai/api/v4/projects/230/packages/maven</url>
  </repository>
</repositories>

<dependencies>
  <dependency>
    <groupId>ai.bnprs</groupId>
    <artifactId>nativesdk-bprface</artifactId>
    <version>2.24.115</version>
  </dependency>
  <!-- JNA is a transitive dependency of the wrapper; declared here only if you pin it. -->
</dependencies>
```

`mvn -q dependency:resolve` should fetch `nativesdk-bprface-2.24.115.jar` (~87 MB — it carries
both Linux natives + the model).

## 3. Minimal sample — load, version, verify license, compare two faces

```java
import ai.bnprs.nativesdk.bprface.BprFaceLibrary;
import ai.bnprs.nativesdk.bprface.BprFaceNative;
import com.sun.jna.NativeLong;
import com.sun.jna.Pointer;
import java.nio.charset.StandardCharsets;

public class FaceDemo {
    public static void main(String[] args) {
        // 1) load the native + model (co-extracted to a temp dir automatically)
        BprFaceLibrary lib = BprFaceNative.get();
        System.out.println("BprFace version: " + lib.bpr_face_get_version());

        // 2) license
        byte[] qi = System.getenv("BPRFACE_LICENSE").getBytes(StandardCharsets.UTF_8);
        if (!lib.BprLicVerification(qi, new NativeLong(qi.length))) {
            throw new IllegalStateException("BprFace license verification failed");
        }

        // 3) recognition: init -> compare two images -> deinit
        int[] retLen = new int[1];
        int[] err    = new int[1];
        Pointer inst = lib.Bpr_FaceRecog_T12_Init(
                qi, new NativeLong(qi.length),
                /*cosine_threshold*/ 0.35, /*norm2_threshold*/ 1.2, /*dist_type*/ 0,
                retLen, err);
        if (inst == null || err[0] != 0) throw new IllegalStateException("Init failed, err=" + err[0]);

        String q = "query.jpg", g = "gallery.jpg";
        double[] score = new double[1];
        lib.Bpr_FaceRecog_T12_Image(
                inst, /*save_flag*/ false,
                q, new NativeLong(q.getBytes(StandardCharsets.UTF_8).length),
                g, new NativeLong(g.getBytes(StandardCharsets.UTF_8).length),
                /*scoreThr*/ 0, /*scoreType*/ 0, score, err);
        System.out.printf("similarity = %.4f (err=%d)%n", score[0], err[0]);

        lib.Bpr_FaceRecog_T12_DeInit(inst, retLen, err);
    }
}
```

Run with the license in the environment:
```bash
export BPRFACE_LICENSE=<your qiCode>
mvn -q compile exec:java -Dexec.mainClass=FaceDemo
```

## 4. API surface (extern "C", exposed on `BprFaceLibrary`)

- `String bpr_face_get_version()`
- `boolean BprLicVerification(byte[] qiCode, NativeLong len)` · `long Bpr_GLog_Init()`
- **Detect:** `Bpr_FaceDetect_T12_Init(qiCode,len, conf,nms,topK, enableTemplate, retLen,err) -> Pointer`,
  `Bpr_FaceDetect_T12_Process(inst, camSerial,camSerialLen, imgPath,imgPathLen, scale, vis, distThr,qltyThr, retLen,err)`,
  `Bpr_FaceDetect_T12_DeInit(inst, retLen, err)`
- **Recognize:** `Bpr_FaceRecog_T12_Init(qiCode,len, cosThr,norm2Thr,distType, retLen,err) -> Pointer`,
  `Bpr_FaceRecog_T12_Image(inst, save, queryPath,len, galleryPath,len, scoreThr,scoreType, score[],err)`,
  `Bpr_FaceRecog_T12_DeInit(inst, retLen, err)`
- **Quality:** `Bpr_FaceQuality_T12_Image(inst, save, imgPath,len, retLen,err)`
- **T11 templates:** `Bpr_FaceRecog_T11_CosineSimilarity(qT11,len, gT11,len, score[], err)`

Pattern: `*_Init` (with the license) returns an instance `Pointer` → call `*_Process`/`*_Image`
→ `*_DeInit`. `errorCode[0] == 0` means success; a non-null `retStrLen` receives a JSON result
length for calls that return JSON.

## 5. Notes / troubleshooting

- **License is mandatory** — a null/invalid `qiCode` makes `*_Init` fail (`err != 0`) or
  `BprLicVerification` return false. This is the most common integration error.
- **Nothing to copy** — `BprFaceNative.get()` extracts `libBprFace.so` + `bpr.model.onnx` to one
  temp dir and loads from there; the model must sit next to the native and the loader guarantees it.
- **Arch** — the JAR carries `linux-x86-64` and `linux-aarch64`; the loader picks by `os.arch`.
  Other OSes (macOS/Windows) are not in this JAR yet (natives exist; wrappers can be added).
- **Threading** — one engine instance (`Pointer`) per thread of use; init/deinit around your batch.
- **Images** are passed by file path (UTF-8); pass the byte-length of the path, not the char count.
- **Version pinning** — the wrapper version always equals the native SemVer (`2.24.115`);
  a new native ships as a new immutable version.

_Built by bnprs-lib-multisdk (na-003/010). Native by cpp-face (na-004/001). Published: project 230._
