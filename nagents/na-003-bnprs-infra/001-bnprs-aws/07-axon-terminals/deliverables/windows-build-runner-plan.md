# Ephemeral Windows Build Runner — Provisioning Plan

> Deliverable owner: **na-003/001 bnprs-aws**
> Requested by: cPerso build need (**na-005/009 bruid-cperso**) — build `BprMces2` (.NET Framework 4.6/4.8, WinForms)
> Status: **PLAN ONLY — nothing provisioned.** Author this, approve, then execute step-by-step.
> Date: 2026-06-08

---

## 1. Purpose

`BprMces2` (repo `trp1002.cperso.mces2`) is **.NET Framework 4.6/4.8 + WinForms** → it can only be built
with **Windows + MSBuild + the Framework targeting packs**. It cannot build on `pat-m4p` (macOS/ARM) or on
any Linux runner. This plan stands up a **cost-minimal, on-demand Windows build runner** that is **only
running while a build is in progress** and **auto-shuts-down afterward**.

## 2. Target account / region / constraints

| Item | Value |
|------|-------|
| AWS account | **891963159778** (BNPRS) |
| Profile | `bnprs` (always `--profile bnprs`) |
| Region | **ap-south-2** (Hyderabad) |
| Instance (floor) | **`t3.medium`** (2 vCPU / 4 GB) — `t3.small` (2 GB) thrashes under VS Build Tools |
| Disk (floor) | **30 GB gp3** — Windows Server base AMI minimum; cannot go meaningfully lower |
| CPU arch | **native x64** Windows Server 2022 — no ARM emulation (unlike a Mac VM) |
| Tags (all resources) | `Project=BNPRS`, `Owner=bnprs`, `Environment=dev`, `Role=win-build-runner` |
| Idle compute cost | **$0** — instance terminated/stopped between builds |

> Note: unlike the ITP account (819144294008), **this account has no `gitlab.bnprs.ai` OIDC provider** yet.
> Pattern B below therefore needs either a new IAM OIDC provider for GitLab CI **or** a Lambda trigger.

## 3. Architecture options

### Pattern A — GitLab Runner Autoscaler (fleeting + AWS plugin) — *true ephemeral*
```
gitlab.bnprs.ai  ──(manager runner, always-on, co-located on GitLab box)──┐
   on job tagged `windows,dotnetfx`:                                       │
   fleeting AWS plugin → launch EC2 from prebaked AMI → run job → TERMINATE (scale to 0)
```
- **Pros:** zero idle compute *and* zero idle EBS (instance is terminated, only the AMI snapshot persists);
  self-healing; concurrency for free.
- **Cons:** more moving parts (manager config, fleeting plugin, IAM for the manager, launch template/ASG);
  manager lives on the GitLab server (na-003/003 domain).

### Pattern B — Wake-on-pipeline stop/start — *simplest* ✅ recommended for low build volume
```
pipeline:
  start_runner  (Linux/shared runner; assume IAM role → ec2 start-instances; wait online)
      ↓
  build         (tag `windows,dotnetfx`; MSBuild on the now-awake Windows runner)
      ↓
  stop_runner   (when: always; ec2 stop-instances)
+ EventBridge rule + Lambda: idle-stop safety net (stop if running >N min with no active job)
```
- **Pros:** one instance to reason about; reuses a normal `gitlab-runner` Windows service; easiest to debug.
- **Cons:** pays for the **30 GB EBS while stopped** (~$2.7/mo); single-concurrency; needs a start/stop
  control path (OIDC role assumed by CI, or a Lambda).

**Recommendation:** **Pattern B** for now (cPerso build volume is low and bursty). Revisit Pattern A if build
frequency or parallelism grows.

## 4. Prerequisites (confirm against live account before building)

- [ ] VPC + subnet in ap-south-2 to host the runner (use default VPC or a dedicated `/28` subnet).
      **Action:** `aws ec2 describe-vpcs / describe-subnets --profile bnprs --region ap-south-2`
- [ ] Outbound internet (NAT or public subnet + EIP-less public IP) so the runner reaches
      `gitlab.bnprs.ai`, NuGet, and Microsoft package CDNs.
- [ ] Latest **Windows Server 2022 English Full Base** AMI id in ap-south-2
      (`aws ssm get-parameters --names /aws/service/ami-windows-latest/Windows_Server-2022-English-Full-Base`).
- [ ] A GitLab **runner registration token** for `trp1002.cperso.mces2` (or a group runner) — **na-003/003 bnprs-gitlab**.
- [ ] Decide start/stop control: (a) new GitLab OIDC provider in this account, or (b) Lambda + CI trigger.

## 5. Step-by-step provisioning (Pattern B)

> Each step is independently verifiable. **Show cost + confirm before any create/modify.**

### 5.1 Security group (isolated)
- Create `sg-win-build-runner`: **egress all** (443/80 + ephemeral), **ingress none** (runner is outbound-only
  to GitLab; no inbound needed). RDP only if a temporary admin rule is added during AMI baking, then removed.
- Tag per §2. **Do not** attach to or modify any prod SG (QI-SMS-GW etc.).

### 5.2 IAM
- **Instance profile** `win-build-runner-role`: minimal — CloudWatch Logs put, SSM (for `ssm get-parameter`
  + Session Manager instead of RDP). No S3/prod access.
- **Start/stop control principal:**
  - Option (a) OIDC: create IAM OIDC provider for `https://gitlab.bnprs.ai`; role `gitlab-ci-ec2-control`
    trust-scoped to the `trp1002.cperso.mces2` project + ref; policy = `ec2:StartInstances`,
    `ec2:StopInstances`, `ec2:DescribeInstances` **resource-scoped by tag** `Role=win-build-runner`.
  - Option (b) Lambda `win-runner-control` with the same EC2 policy; invoked by CI (via API) or a pipeline
    webhook. Avoids an OIDC provider.

### 5.3 Bake the AMI (one-time)
1. Launch a temp `t3.medium`, 30 GB gp3, from the Windows Server 2022 base AMI (temporary RDP/SSM access).
2. Install: **VS Build Tools 2022** (workloads: `.NET desktop build tools` + MSBuild) + **.NET Framework
   4.6 & 4.8 targeting packs** + 4.8 runtime + `git` + `gitlab-runner` (Windows binary).
3. Register `gitlab-runner` as a **Windows service**, executor **shell (PowerShell)**, tags `windows,dotnetfx`,
   `run_untagged=false`, `locked=true`. Configure to **start on boot** and pick up jobs immediately.
4. Sysprep-light / generalize as needed, then **create AMI** `ami-win-build-runner-vYYYYMMDD`.
5. Terminate the temp instance; remove the temporary RDP rule.

> AMI baking makes wake-up ~3–5 min instead of 20+ min of installing VS each build.

### 5.4 Create the persistent (stopped) runner instance
- Launch `t3.medium` from the baked AMI, 30 GB gp3, `sg-win-build-runner`, instance profile from §5.2,
  tag `Role=win-build-runner`. Confirm the runner appears **online** in GitLab, run one smoke build, then
  `ec2 stop-instances`. Idle cost from here = EBS only.

### 5.5 Idle-stop safety net
- EventBridge scheduled rule (every 10 min) → Lambda `win-runner-idle-stop`: if the instance is `running`
  and has had **no active GitLab job for >15 min** (query GitLab jobs API or a CloudWatch custom metric),
  `stop-instances`. Guards against a failed pipeline leaving it running.

### 5.6 CI wiring (owned by na-005/009 in `trp1002.cperso.mces2/.gitlab-ci.yml`)
```yaml
stages: [provision, build, teardown]

start_runner:
  stage: provision
  tags: [linux]                       # any always-on shared runner
  script:
    - aws ec2 start-instances --instance-ids "$WIN_RUNNER_ID" --profile-or-oidc
    - aws ec2 wait instance-running --instance-ids "$WIN_RUNNER_ID"
    - ./scripts/wait-runner-online.sh  # poll GitLab until the windows runner is up

build_bprmces2:
  stage: build
  tags: [windows, dotnetfx]
  script:
    - msbuild BprMces2/Mces2_Dlls.sln /p:Configuration=Debug /p:Platform=x86
    # optional: run Bpr.Tests.Dlls.exe — but it is a WinForms GUI harness (see §7)
  artifacts:
    paths: [BprMces2/Bin/Debug/Components/*.dll]

stop_runner:
  stage: teardown
  tags: [linux]
  when: always                        # always stop, even if build failed
  script:
    - aws ec2 stop-instances --instance-ids "$WIN_RUNNER_ID"
```

## 6. Cost breakdown (ap-south-2, On-Demand Windows, rough)

| Item | Unit | ~100 builds/mo @ 15 min |
|------|------|--------------------------|
| Compute — `t3.medium` Windows | ~$0.07/hr | 25 hr → **~$1.8** |
| EBS — 30 GB gp3 (always, while stopped too) | ~$0.092/GB-mo | **~$2.8** |
| AMI snapshot storage (~30 GB compressed) | ~$0.05/GB-mo | **~$1.0** |
| Data transfer / SSM / Lambda / EventBridge | negligible | **~$0.5** |
| **Total** | | **≈ $6/mo** |
| (contrast) always-on `t3.medium` Windows | ~$0.07/hr × 730 | ~$51/mo |

**Savings vs always-on ≈ 88%.** Pattern A removes the EBS-while-stopped line (~$2.8) → ≈ $4/mo.

## 7. Known limitation — the WinForms test

`Bpr.Tests.Dlls` is an **interactive WinForms GUI** `.exe`. It needs a desktop session and **will not run
headless in CI**. So:
- CI can reliably **build** BprMces2.
- The GUI test stays **manual** (run inside an interactive session on the runner / via Session Manager),
  **or** the test project is refactored to a headless runner (xUnit/NUnit) before it can gate CI.

## 8. Teardown (when no longer needed)
Stop+terminate the instance → delete the AMI + its snapshot → delete the SG, instance profile/role, OIDC
provider (if (a)), Lambda + EventBridge rule. EBS goes with the instance. Leaves zero cost.

## 9. Cross-agent responsibilities

| Step | Owner |
|------|-------|
| VPC/subnet, SG, IAM, AMI bake, instance, Lambda/EventBridge | **na-003/001 bnprs-aws** (this agent) |
| Runner registration token, runner tags, GitLab-side config | **na-003/003 bnprs-gitlab** |
| `.gitlab-ci.yml` build/start/stop jobs, `wait-runner-online.sh` | **na-005/009 bruid-cperso** |

## 10. Open decisions (resolve before execution)
1. **Pattern A vs B** — recommend B for now.
2. **Start/stop control** — OIDC provider (reusable, cleaner) vs Lambda (no new IdP).
3. **Subnet** — default VPC public subnet (simplest) vs dedicated isolated subnet (+ NAT cost).
4. **GUI test** — leave manual, or fund a refactor to headless tests.
5. **Build frequency** — informs A vs B and whether RI/always-on is ever justified (it isn't at low volume).
