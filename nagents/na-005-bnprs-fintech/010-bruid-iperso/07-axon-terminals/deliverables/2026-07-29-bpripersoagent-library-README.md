# BprIPersoAgent — instant personalisation as a library call

Replaces the agent-as-a-process deployment. There is **no background exe, no localhost port and no batch
file**: the kiosk application loads `BprIPersoAgent.dll` and calls one function when a card should be
personalised.

```
before :  kiosk app -> start-agent.cmd -> perso-kiosk-agent.exe -> TCP 127.0.0.1:9098 -> bureau
now    :  kiosk app -> BprIPersoAgent.dll (one call)                                  -> bureau
```

One DLL serves both hosts:

| Host | Binding | Entry points |
|------|---------|--------------|
| C# / C / C++ | C ABI, cdecl | `bpriperso_version`, `bpriperso_run`, `bpriperso_free` |
| Java | JNI | `com.bnprs.jni.iPersoAgent.version()`, `.runPerso(String)` |

## Pick the DLL by HOST PROCESS bitness

| Host process | Use |
|---|---|
| 64-bit JVM / 64-bit .NET | `windows-64\BprIPersoAgent.dll` |
| 32-bit JVM / 32-bit .NET | `windows-32\BprIPersoAgent.dll` |

A mismatch fails at **load** time — `UnsatisfiedLinkError` in Java, `BadImageFormatException` in .NET.
Check with `sun.arch.data.model` or `Environment.Is64BitProcess`. The DLL is statically linked: it needs no
MinGW or Visual C++ runtime, and imports only `KERNEL32`, `WS2_32`, `WinSCard`, `CRYPT32`, `ADVAPI32`,
`USER32`.

## C#

```csharp
string request = @"{
  ""bureauHost"":""98.130.14.127"", ""bureauPort"":9099, ""token"":""…"",
  ""tls"":true, ""cert"":""certs\\kiosk.pem"", ""key"":""certs\\kiosk.key"", ""ca"":""certs\\ca.pem"",
  ""hardwareId"":""KIOSK-DXB-014"",
  ""transport"":""tp9000-pcsc"", ""reader"":""SYNIC"",
  ""scheme"":""auto"", ""inputType"":""dpi"", ""dpiB64"":""" + dpiB64 + @""", ""commit"":true
}";

string result = IPersoAgent.Run(request, line => Log.Info(line));   // blocking — worker thread
```

## Java

```java
iPersoAgent agent = new iPersoAgent();
String result = agent.runPerso(request);    // blocking — worker thread
```

`System.loadLibrary("BprIPersoAgent")` finds the DLL on `java.library.path` or beside the executable.

## The request

One JSON object carries the bureau connection and the card request:

| Field | Meaning |
|---|---|
| `bureauHost`, `bureauPort`, `token` | where the bureau is |
| `tls`, `cert`, `key`, `ca` | PROD mutual-TLS material (omit for plain UAT) |
| `hardwareId` | this kiosk's id |
| `transport` | `tp9000-pcsc` (feeder + encoder), `pcsc`, `tp9000`, `mock` |
| `reader`, `moves`, `settleMs`, `contactsOn` | `tp9000-pcsc` positioning |
| `scheme` | `auto` — the bureau asks the card; `visa`/`mc` force it |
| `inputType`, `dpiB64` | the encrypted DPI for this card |
| `commit` | `false` = non-destructive preflight, `true` = live perso |

## The result

```json
{ "status": "ok", "detail": "...", "atr": "3BFE13...",
  "bureau": { "dgisAccepted": 42, "dgisTotal": 42, "secured": true, ... },
  "output": { "print": {...}, "magstripe": {...} } }
```

`output` appears only after a successful live perso — feed it to the printer and magstripe encoder.
Check `status` first; a card-level failure is reported there, not as an exception.

## Behaviour worth knowing

- **Blocking.** A live perso takes tens of seconds. Always call from a worker thread.
- **One call, one card.** The API deliberately has no "measure then fetch" form — that would run the
  session twice and consume two cards for one request.
- **A dropped link rejects the card.** If the bureau connection fails mid-session while a card is in hand,
  the card is rejected, never ejected as good.
- **Nothing throws across the boundary.** A C++ exception reaching a C#/Java host would terminate the
  process; every failure comes back as `status`/an error code instead.
- **Threads.** No shared state between calls; concurrent sessions are fine if they use different readers.

## PCI

`output.print` and `output.magstripe` contain PAN and track data. Use them transiently for the printer and
encoder — do not log them and do not persist them after the card is produced.

## Verification status

Verified on macOS builds of the identical source, against a live bureau:

- **C host** — `bpriperso_run` drove a full session with progress callbacks and returned the result JSON.
- **Java host** — the unchanged `iPersoAgent` class loaded the library and ran a session through JNI.
- Both Windows DLLs cross-compile with the C ABI exported **undecorated** (cdecl, so P/Invoke binds) and
  the JNI names exported plainly (so `System.loadLibrary` binds on x86 too).

**Not yet verified:** the DLLs have not run on Windows, and no card has been personalised through the
library path on the kiosk. First run should be a **preflight** (`"commit": false`) against a test card.

## Files

```
windows-64\BprIPersoAgent.dll      x86-64 build (+ import lib)
windows-32\BprIPersoAgent.dll      x86 build (+ import lib)
include\bpriperso_agent.h          the C ABI header
hosts\csharp\IPersoAgent.cs        C# P/Invoke wrapper
hosts\java\com\bnprs\jni\iPersoAgent.java   Java JNI class
SHA256SUMS.txt
```
