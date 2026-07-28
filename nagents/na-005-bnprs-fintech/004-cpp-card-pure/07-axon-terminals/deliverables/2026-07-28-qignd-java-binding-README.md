# QiGndPerso — GND central-perso script for Windows, callable from Java

The GND central-personalisation script (`QiScript/gnd`) generates the ordered list of APDUs for one card.
It is **pure computation** — it builds the commands, it never touches a reader. Card I/O stays in the host
application (PC/SC, TP9000, whatever you already use).

This folder adds two things on top of that script:

1. a flat **C ABI** (`qignd_perso.h/.cpp`) so non-C++ languages can call it, and
2. a **Java binding** (`java/`) over that ABI using jnr-ffi.

Why an ABI at all: the underlying entry point returns `std::vector<std::string>` and is C++-name-mangled.
Neither crosses a foreign-function boundary, so Java/C#/Python cannot call it directly.

---

## 1. Build the DLLs

```sh
./build-win.sh                 # both bitnesses -> ./build-win/windows-{32,64}/QiGndPerso.dll
ARCH=64 ./build-win.sh /tmp/out
```

Requires mingw-w64 (`brew install mingw-w64`). Output is fully static — libstdc++ and libgcc are linked in,
so the target machine needs no MinGW runtime DLLs. Imports are `KERNEL32` + the OS UCRT only.

Exported symbols, **undecorated on both bitnesses** (cdecl, so no `_name@n` on x86):

```
qignd_version  qignd_central_perso  qignd_count  qignd_length  qignd_get  qignd_free
```

> **Bitness must match the JVM.** A 64-bit JVM loads `windows-64/QiGndPerso.dll`; a 32-bit JVM needs
> `windows-32/QiGndPerso.dll`. A mismatch fails at load time with `UnsatisfiedLinkError`, not at call time.
> Check with `System.getProperty("sun.arch.data.model")`.

## 2. Build the Java binding

```sh
cd java && mvn package          # -> target/qignd-1.0.0.jar
```

Or compile directly against a jnr-ffi jar; it is a four-class source set with no other dependency.

## 3. Use it

```java
QiGndPerso.loadFrom("C:\\app\\native");            // optional: explicit DLL directory
System.out.println(QiGndPerso.version());          // "qignd 1.0.0 (abi 1)"

List<String> apdus = QiGndPerso.centralPerso(qiCode, cardNumber, embData, 0, 0);
for (String apdu : apdus) {
    ResponseAPDU r = channel.transmit(new CommandAPDU(hexToBytes(apdu)));
    if (r.getSW() != 0x9000) throw new IllegalStateException("card rejected APDU");
}
```

Without `loadFrom`, the DLL is found via `jnr.ffi.library.path`, `java.library.path` or the OS search path:

```sh
java -Djnr.ffi.library.path=. -cp qignd-1.0.0.jar:jnr-ffi.jar ai.bnprs.qignd.Demo .
```

**Parameters**

| Name | Meaning |
|------|---------|
| `qiCode` | licence/key string — rejected input yields `-301` |
| `cardNumber` | card number |
| `embData` | embossing record; the script reads fixed offsets into it |
| `arOffset` | offset applied to those field positions — `0` for a full record |
| `chipProtocol` | `0` = APDUs without a trailing Le byte, `1` = trailing `00` appended |

**Error codes** (thrown as `QiGndException`, `getCode()` returns the raw value)

| Code | Meaning |
|------|---------|
| `0` | success |
| `-300` | general exception while preparing the script |
| `-301` | invalid keys — the `qiCode` licence was rejected |
| `-302` | embossing data could not be parsed |
| `-303` | `CARD_ID` empty in the embossing data |
| `-304` | `CARD_NUM` empty in the embossing data |
| `-390` | null/negative argument caught in the ABI layer |

## 4. Smoke test

```sh
java -cp qignd.jar:<jnr-ffi jars> ai.bnprs.qignd.Demo <dllDir>
java -cp ... ai.bnprs.qignd.Demo <dllDir> <qiCode> <cardNumber> <embDataFile> [arOffset] [protocol]
```

Prints the APDU count and each APDU's length. It deliberately does **not** print the APDU bytes —
they carry personalisation data. `-Dqignd.demo.printApdus=true` shows them; test cards only.

## Notes on the design

- **Memory:** `qignd_central_perso` returns an opaque handle owning the list; read it, then `qignd_free`.
  The Java wrapper frees in a `finally`, so an exception mid-read cannot leak.
- **Exceptions never cross the boundary.** A C++ exception unwinding into the JVM would abort the process,
  so every entry point catches and converts to an error code.
- **Truncation is reported, not silent.** `qignd_get` returns the length that *would* have been needed;
  a value `>= bufLen` means "call again with a bigger buffer". The Java wrapper sizes from `qignd_length`
  first, so it never truncates.
- **PCI:** the generated APDUs embed personalisation data. Do not log them and do not persist them after
  the card is written.

## Files

```
qignd_perso.h / .cpp        the C ABI
build-win.sh                mingw cross-build, both bitnesses, verifies exports + imports
README.md                   this file
java/pom.xml                Maven module (jnr-ffi 2.2.16, JDK 8)
java/src/main/java/ai/bnprs/qignd/
  QiGndLibrary.java         raw jnr-ffi mapping, 1:1 with the header
  QiGndPerso.java           idiomatic front end — List<String>, exceptions, auto-free
  QiGndException.java       typed error with the native code
  Demo.java                 command-line smoke test
```
