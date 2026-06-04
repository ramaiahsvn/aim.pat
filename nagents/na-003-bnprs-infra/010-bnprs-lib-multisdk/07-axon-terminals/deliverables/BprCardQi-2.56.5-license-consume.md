# Consuming the BprCardQi 2.56.5 BGL-license wrappers

Wrappers built by na-003/010 lib-multisdk; published to GitLab project 230 by na-003/009 lib-forge.
**Scope:** the BGL license/activation API only. **Native:** win-x64 (run the app as **x64**). Verify/
activate only — no signing on the client. Bindings are **provisional** until load-tested on Windows.

API (all ecosystems): `hwid()`, `activate(token[, appid])`→0==OK, `isLicensed()`→bool,
`activateFromStore([dir])`→0==OK (reads `C:\ProgramData\BprCardQi\<hwid>.lic`), `licensePath()`.

---
## .NET (NuGet) — `Bnprs.NativeSdk.BprCardQi` 2.56.5

Works on **.NET Framework 4.6.1–4.8** and **.NET Core/5+**. On .NET Framework, **use a
PackageReference-style csproj** (not packages.config) so the bundled `build/*.targets` copies the
native DLL to your output. Build as **x64**.

`nuget.config`:
```xml
<configuration>
  <packageSources>
    <add key="bnprs" value="https://gitlab.bnprs.ai/api/v4/projects/230/packages/nuget/index.json" />
  </packageSources>
  <packageSourceCredentials>
    <bnprs>
      <add key="Username" value="bnprs-libs-readonly" />
      <add key="ClearTextPassword" value="%BNPRS_LIBS_DEPLOY_TOKEN%" />
    </bnprs>
  </packageSourceCredentials>
</configuration>
```
`.csproj` (PackageReference; x64):
```xml
<PropertyGroup>
  <PlatformTarget>x64</PlatformTarget>          <!-- native is win-x64 -->
</PropertyGroup>
<ItemGroup>
  <PackageReference Include="Bnprs.NativeSdk.BprCardQi" Version="2.56.5" />
</ItemGroup>
```
Code:
```csharp
using Bnprs.NativeSdk.BprCardQi;

string hwid = License.Hwid();                 // 64-hex, send to issuer if enrolling manually
int reason  = License.Activate(token);        // 0 == OK (bgl_reason)
bool ok     = License.IsLicensed();           // re-verified live
int r2      = License.ActivateFromStore();    // load C:\ProgramData\BprCardQi\<hwid>.lic + activate
string path = License.LicensePath();          // default <store>\<hwid>.lic
```
> .NET Framework note: if you must use `packages.config`, the native won't auto-deploy — either
> migrate to PackageReference, or copy `libBprCardQi.dll` next to your exe manually.

---
## Java (Maven, JNA) — `ai.bnprs:nativesdk-bprcardqi:2.56.5`

`~/.m2/settings.xml` (GitLab Maven registry auth):
```xml
<servers><server>
  <id>bnprs</id>
  <configuration><httpHeaders><property>
    <name>Deploy-Token</name><value>${env.BNPRS_LIBS_DEPLOY_TOKEN}</value>
  </property></httpHeaders></configuration>
</server></servers>
```
`pom.xml`:
```xml
<repositories><repository>
  <id>bnprs</id>
  <url>https://gitlab.bnprs.ai/api/v4/projects/230/packages/maven</url>
</repository></repositories>
<dependency>
  <groupId>ai.bnprs</groupId><artifactId>nativesdk-bprcardqi</artifactId><version>2.56.5</version>
</dependency>
```
Code (run on Windows x64):
```java
import ai.bnprs.nativesdk.bprcardqi.License;

String hwid = License.hwid();
int reason  = License.activate(token, null);   // 0 == OK
boolean ok  = License.isLicensed();
int r2      = License.activateFromStore(null);  // default store
String path = License.licensePath();
```

---
## Go (purego) — `…/go/bprcardqi@v2.56.5`

```
export GOPRIVATE=gitlab.bnprs.ai
export GOPROXY=https://bnprs-libs-readonly:$BNPRS_LIBS_DEPLOY_TOKEN@gitlab.bnprs.ai/api/v4/projects/230/packages/go,direct
go get gitlab.bnprs.ai/BPR1000/bpr1000.bnprs-libs/go/bprcardqi@v2.56.5
```
Code (build `GOOS=windows GOARCH=amd64`):
```go
import bprcardqi "gitlab.bnprs.ai/BPR1000/bpr1000.bnprs-libs/go/bprcardqi"

hwid, _ := bprcardqi.Hwid()
reason, _ := bprcardqi.Activate(token, "")     // 0 == OK
ok, _ := bprcardqi.IsLicensed()
r2, _ := bprcardqi.ActivateFromStore("")        // default store
path, _ := bprcardqi.LicensePath()
```

---
**Token:** `$BNPRS_LIBS_DEPLOY_TOKEN` = the group read-only deploy token `bnprs-libs-readonly`
(from lib-forge). **Bitness:** all three bundle the **win-x64** native — the host process must be x64.
Other RIDs/platforms ship when na-005/002 builds them.
