# Bpr.QiScript — Windows build (JNI)

Windows port of the GND central-personalisation library delivered for Linux as `libBpr.QiScript.so`
(v2.22.31). **The Java side is unchanged** — same package, same class, same native method, same error
codes — so an existing application only swaps the native file.

```
libBpr.QiScript.so   (Linux)   ->   Bpr.QiScript.dll   (Windows)
```

---

## 1. Pick the right DLL — it must match the JVM, not the machine

| Your JVM | Use |
|----------|-----|
| 64-bit (`sun.arch.data.model` = 64) | `windows-64\Bpr.QiScript.dll` |
| 32-bit (`sun.arch.data.model` = 32) | `windows-32\Bpr.QiScript.dll` |

A 64-bit Windows machine often runs a 32-bit JVM. Getting this wrong fails at **load** time with
`UnsatisfiedLinkError: ... Can't load AMD 64-bit .dll on a IA 32-bit platform`. Check with:

```cmd
java -XshowSettings:properties -version 2>&1 | findstr sun.arch.data.model
```

## 2. Place the files in the application directory

```
Bpr.QiScript.dll            <- copy ONE of the two above, renamed to exactly this
qiscript.ini                <- licence key, first line
qiscript.c.perso-bio.dat    <- embossing data (your own file in production)
com\bnprs\jni\qiScript.java
```

No MinGW or Visual C++ runtime is needed — the DLL is statically linked. It imports only `KERNEL32`,
the OS UCRT, and `WinSCard.dll` (the Windows smart-card service, present on every Windows install).

## 3. Set the reader name

Edit `qiScript.java` and set `crName` to the **exact** PC/SC reader name, e.g.:

```java
char[] crName = "OMNIKEY AG 3121 USB 00 00".toCharArray();
```

List the readers actually present on the machine:

```cmd
certutil -scinfo
```

The name must match exactly, including the trailing instance numbers. A wrong name returns
**-2146435063** (`SCARD_E_UNKNOWN_READER`).

`embData`: extract the Qi card data from line 1649 of the original embossing file, and keep
`offset = 1648` as in the sample.

## 4. Compile and run

```cmd
javac com\bnprs\jni\qiScript.java
java -Djava.library.path=. com.bnprs.jni.qiScript
```

(The class declares `package com.bnprs.jni`, so it is run by its full name from the folder that
contains `com\`.)

Success prints `result: 0`. Anything else is an error code — see `ErrorCodes`.

## What the library does

1. reads the licence key from `qiscript.ini` (first non-empty line),
2. builds the APDU script from the embossing record — pure computation, no card involved,
3. connects to the named PC/SC reader,
4. transmits every APDU in order, requiring `9000` (a `61xx` reply is chained with GET RESPONSE,
   `6Cxx` is reissued with the corrected length),
5. returns `0`, or stops at the first failure and returns its code.

## Error codes

Full list in `ErrorCodes`. The ones worth knowing up front:

| Code | Meaning |
|------|---------|
| `0` | success |
| `-301` | invalid keys — check `qiscript.ini` |
| `-303` / `-304` | `CARD_ID` / `CARD_NUM` empty in the embossing data |
| `-401` | script init failed — `qiscript.ini` missing or empty |
| `-402` | `SCardEstablishContext` failed — smart-card service not running |
| `-444` | a card command was rejected (the card answered something other than `9000`) |
| `-2146435063` | unknown reader name |
| `-2146435060` | no card in the reader |
| `-2146435026` | no readers connected |

## Verification status

Built and verified as far as is possible without Windows hardware:

- both DLLs cross-compiled from the same source (mingw-w64, static); the JNI entry point is exported
  **undecorated** on x64 and as **both** `Java_com_bnprs_jni_qiScript_qiCardTransmit` and the
  `@36` stdcall alias on x86, so the JVM's lookup succeeds on either;
- the identical source, built for macOS, was driven by the **unchanged** `qiScript.java` using the real
  `qiscript.ini` and `qiscript.c.perso-bio.dat`: the licence was accepted, the script was generated, the
  PC/SC context was established, and it stopped at `-2146435063` because no OMNIKEY is attached here.

**Not yet verified:** the card transaction itself, and the DLLs have not been run on Windows. The first
run on the target machine should be against a test card.

## Security note

`qiscript.ini` contains the licence key. Keep it out of source control, images and log output.
The generated APDUs embed personalisation data — do not log them.

## Files

```
windows-64\Bpr.QiScript.dll   x86-64 build
windows-32\Bpr.QiScript.dll   x86 build
com\bnprs\jni\qiScript.java   Java class (unchanged from v2.22.31)
com_bnprs_jni_qiScript.h      JNI header (unchanged)
ErrorCodes                    full error-code list
qiscript.ini                  licence key
qiscript.c.perso-bio.dat      sample embossing data
SHA256SUMS.txt                integrity hashes
```
