# Skill — Go purego + go:embed wrapping

Wrap a native lib as a Go module that embeds the native binary per `GOOS/GOARCH` and
binds it at runtime with purego (no cgo). Proven in the BprFace 2.24.114 pilot.

## Module layout
```
<lib>.go                  # common binding: extract embedded bytes → temp → purego.Dlopen → RegisterLibFunc
embed_darwin_arm64.go     # //go:build darwin && arm64  +  //go:embed lib<Name>.dylib
embed_windows_amd64.go    # //go:build windows && amd64 +  //go:embed <Name>.dll
lib<Name>.dylib / <Name>.dll   # native files beside the build-tagged embed files
go.mod                    # module gitlab.bnprs.ai/BPR1000/bpr1000.bnprs-libs/go/<lib-lower>
```
Build-tagged embed files keep each platform's `//go:embed` out of the other platforms' builds.

## Binding pattern
```go
var bprGLogInit func() int64
func Load() error {
    dir, _ := os.MkdirTemp("", "<lib>-")
    p := filepath.Join(dir, libFileName)
    os.WriteFile(p, nativeLib, 0o755)
    h, err := purego.Dlopen(p, purego.RTLD_NOW|purego.RTLD_GLOBAL)
    if err != nil { return err }
    purego.RegisterLibFunc(&bprGLogInit, h, "Bpr_GLog_Init")
    return nil
}
```
`nativeLib []byte` and `libFileName` come from the build-tagged embed_*.go.

## Build & verify
```
go mod tidy                # fetch github.com/ebitengine/purego (online once)
go build ./... && go vet ./...
# consumer module: require + replace => ../<lib>; go build
```

## Publish — TAG-BASED (key difference)
GitLab's Go module registry has **no upload endpoint**; the Go proxy serves SemVer **git
tags** from a repo. To publish: host the module in a GitLab repo, create tag `v<ver>`.
Consumers set `GOPROXY=https://gitlab.bnprs.ai/api/v4/projects/230/packages/go` + `~/.netrc`
with the `bnprs-libs-readonly` deploy token.

## Pitfalls
- purego maps C types to uintptr/pointers; `RegisterLibFunc` matches Go func signatures to symbols.
- Runtime `Load()` needs a self-contained native binary (deferred for libs that link system deps).
