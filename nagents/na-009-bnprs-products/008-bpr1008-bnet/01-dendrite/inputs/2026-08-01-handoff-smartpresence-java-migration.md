# Handoff — SmartPresence API .NET→Java migration (MR !12)

**To:** na-009/008 bpr1008-bnet · **From:** na-004/001 cpp-face · **Date:** 2026-08-01
**Repo:** `gitlab.bnprs.ai/BPR1004/bpr1004.utms.api.bnet.smartpresence` (project id 34)
**Local clone:** `/Users/bnprs/BPR/GitRepos2/BPR1004_uTms/bpr1004.utms.api.bnet.smartpresence`

Handed over mid-task on the user's instruction. **Nothing is pushed. Read §2 before touching the
clone** — there is uncommitted and unpushed state in it.

---

## 1. What was asked, and where it got to

1. Clone the repo → **done**, on `master`.
2. List branches → **done**, see §4. The repo has migrated .NET→Java and `master` was left on the
   old stack.
3. Create MR from `harani_servicesMigration` → `ai_dev` → **done, MR !12**. I flagged that `ai_dev`
   is the abandoned .NET branch and `bp_dev` the live Java one; the user confirmed `ai_dev` was
   intended.
4. Fix the pom to 2.24.902 → **NOT done**, see §3.
5. Merge MR !12 → **cannot merge**: 52 conflicts. The user then said force-merge and discard
   `ai_dev`'s work; I did that **locally only** (§2) before the handoff.

## 2. ⚠ Uncommitted / unpushed state in the local clone

| | |
|---|---|
| checked-out branch | `ai_dev` |
| local HEAD | **`daaf1b4`** — a merge commit that is NOT on the remote |
| `origin/ai_dev` | `3c90dfd` — untouched |
| working tree | **`pom.xml` modified, uncommitted** — a partial 2.24.902 edit, unverified |
| MR !12 | still `merge_status: conflict`; GitLab has not seen the local merge |

`daaf1b4` was made with `merge -s ours` followed by `read-tree --reset` onto
`harani_servicesMigration`, so it records both parents while its tree is **byte-identical to the
source branch**. All 52 conflicts are resolved by taking the Java side wholesale — **`ai_dev`'s own
49 commits are discarded, not merged.** That was the explicit instruction.

**Recovery:** tag `ai_dev-pre-java-migration-20260801` → `3c90dfd`, pushed. The discarded work is
retrievable from it.

**If you disagree with any of this**, `git reset --hard origin/ai_dev` and nothing is lost — the
remote is untouched.

## 3. The blocker that must be fixed before this branch can build

`pom.xml` on `harani_servicesMigration` (and so on the merge result) declares:

```xml
<artifactId>nativesdk-bpridengine-face</artifactId>
<version>2.24.900</version>
```

**That artifact was deleted from the registry on 2026-08-01**, along with 2.24.901 and both lean
variants. This is the cause of the Maven failure the team reported — though note their error was a
*cached* miss; it is now a genuine 404. Replace with:

```xml
<artifactId>nativesdk-bpridengine</artifactId>   <!-- the -face suffix is GONE -->
<version>2.24.902</version>
```

The surrounding comment needs rewriting too — three of its claims are now false:

| the comment says | true as of 2.24.902 |
|---|---|
| "NEVER also depend on `nativesdk-bpridengine` (the lean build)" | **backwards.** The lean/face split was withdrawn; there is one artifact and it has the T12 extractor. |
| "same 21 symbols" | 22 |
| natives are "linux-x86-64, linux-aarch64, darwin-arm64" | plus `win32-x86-64` and `win32-x86` |

**One code change may be needed, not just the pom.** `BprID_HasTemplate(T12)` now always returns 1,
so it can no longer serve as a readiness check. Use `BprID_Preload(T12)`, which returns
`ModuleError` when the models are not usable — and which was never bound in the 900/901 JNA
wrapper, so it is newly callable. Grep the Java sources for `HasTemplate` before shipping.

Full API reference:
`nagents/na-004-bnprs-biometrics/001-cpp-face/07-axon-terminals/deliverables/2026-08-01-bprface-bprvideo-bprvision-api.md`

## 4. Branch map

| branch | last commit | stack | note |
|---|---|---|---|
| `master` | 2026-03-29 | .NET | stale; what clones by default |
| `bp_dev` | 2026-07-21 | Java | live development line |
| `harani_servicesMigration` | 2026-08-01 | Java | MR !12 source; **16 ahead / 0 behind `bp_dev`** |
| `uat_temp` | 2026-08-01 | Java | |
| `BMT-670-vamsi-migrate-Api` | 2026-07-30 | Java | |
| `cr-nk-I323-harani` | 2026-07-23 | Java | |
| `cr-bmt-i592-harani` | 2026-06-18 | Java | |
| `cr-bmt-i390-ashok` | 2025-09-02 | Java | |
| `ai_dev` | 2025-06-19 | .NET | MR !12 target; 49 commits the merge discards |
| `bp_dev_dotnet` | 2025-08-04 | .NET | |
| `ai_dev` vs source | — | — | 114 ahead / 49 behind, 530 files |

Worth knowing: the same source branch is **16 ahead / 0 behind `bp_dev`** with a 26-file diff. If
the `ai_dev` target ever turns out to have been a misunderstanding, that is the cheap alternative.

## 5. Suggested next steps

1. Decide whether to keep `daaf1b4` or reset and resolve the 52 conflicts deliberately. The
   conflicts are all files present on both sides — `Program.cs`, `appsettings.json`,
   `bNETDbContext.cs`, `UnitOfWork.cs`, `mainGateway/Controllers/*.cs`.
2. Fix `pom.xml` per §3 and confirm `mvn dependency:get` resolves 2.24.902.
3. Grep for `HasTemplate` and switch readiness to `Preload`.
4. Push, confirm MR !12 flips to `mergeable`, then merge.

`ai_dev` is a **protected branch** (push: Maintainers). The `$GITLAB_PAT` on this Mac is root/admin,
so it can push — but that is a deliberate act on a protected branch, not a routine one.
