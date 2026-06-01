# Skill — Maven JNA wrapping

Wrap a native lib as a Maven JAR with native binaries bundled under JNA resource-prefix
folders and a typed JNA binding. Proven in the BprFace 2.24.114 pilot.

## Binding pattern
```java
public interface <Lib>Library extends Library {
    <Lib>Library INSTANCE = Native.load("<Name>", <Lib>Library.class);
    long Bpr_GLog_Init();
    void Bpr_FaceRecog_T11_CosineSimilarity(byte[] q, NativeLong qlen, byte[] g, NativeLong glen,
                                            double[] score, int[] err);
}
```
Type map: `char*`→`byte[]`/`String`, `size_t`/`int*`→`NativeLong`/`int[]`, `double*`→`double[]`.

## JAR layout (JNA resource prefixes)
```
ai/bnprs/nativesdk/<lib>/<Lib>Library.class
darwin-aarch64/lib<Name>.dylib
win32-x86-64/<Name>.dll          # NOTE: no 'lib' prefix on Windows for Native.load("<Name>")
win32-x86-64/<deps>.dll
linux-x86-64/lib<Name>.so
```
Prefix map: windows-64→`win32-x86-64`, windows-32→`win32-x86`, linux-x64→`linux-x86-64`,
linux-arm64→`linux-aarch64`, macos-arm64→`darwin-aarch64`, macos-x64→`darwin-x86-64`.

## pom essentials
- `groupId=ai.bnprs`, `artifactId=nativesdk-<lib-lower>`, `version=<native SemVer>`, `packaging=jar`.
- dependency `net.java.dev.jna:jna` (5.14.0); `maven.compiler.release=8`.

## Build & verify
```
mvn package                                   # online once for plugins + JNA
unzip -Z1 target/<artifact>-<ver>.jar         # confirm <prefix>/ dirs + <Lib>Library.class
```

## Publish (lib-forge) & consume
- Publish: `curl --request PUT --header "Private-Token: $GITLAB_PAT" --upload-file <f>` for the
  jar and the pom to `…/packages/maven/<group-path>/<artifact>/<ver>/<file>` → HTTP 200.
- Consume: `settings.xml` `<server>` with `httpHeaders` `Private-Token` = `bnprs-libs-readonly`
  token; declare the GitLab `<repository>` in the consumer pom.

## Pitfalls
- JNA extracts only the named lib; co-deps must be in the same prefix folder (and findable).
- Windows resource must be `<Name>.dll`, not `lib<Name>.dll`.
