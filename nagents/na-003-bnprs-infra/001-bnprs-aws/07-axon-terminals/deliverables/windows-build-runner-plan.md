# Ephemeral Windows Build Runner — Provisioning Plan

> Deliverable owner: **na-003/001 bnprs-aws**
> Requested by: cPerso build need (**na-005/009 bruid-cperso**) — build `BprMces2` (.NET Framework 4.6/4.8, WinForms)
> Status: **PLAN ONLY — nothing provisioned.** Author this, approve, then execute step-by-step.
> Date: 2026-06-08
>
> **Decisions locked (2026-06-08):** Pattern **B** (wake-on-pipeline stop/start) · start/stop control via
> **Lambda** (Function URL + shared secret → CI needs **no AWS credentials**). Still open: subnet, GUI test,
> build frequency (§10).

---

## 0. Provisioning log (live)

| # | Resource | ID / value | Status | Date |
|---|----------|-----------|--------|------|
| 1 | Security group `win-build-runner-sg` (egress-only, VPC vpc-0d80a4677ec5ae84d) | `sg-025666a8da99505bb` | ✅ created | 2026-06-08 |
| 2 | IAM instance role + profile / Lambda role | `win-build-runner-role` + `win-build-runner-profile` / `win-runner-control-role` (inline `ec2-start-stop-tagged`) | ✅ created | 2026-06-08 |
| 3 | Lambda `win-runner-control` + **HTTP API** front door | fn `win-runner-control`; api `gb7ez1jj7i` → `https://gb7ez1jj7i.execute-api.ap-south-2.amazonaws.com` | ✅ created + tested (403/404/400 all correct) | 2026-06-08 |
| 4 | AMI `mces2-win-build-runner` (VS Build Tools 2022 + Fx 4.6/4.6.2/4.8 + git + gitlab-runner id14) | `ami-0c6054dcbf22e7214` | ✅ available; runner 14 verified **online** | 2026-06-08 |
| 5 | Persistent runner instance + EventBridge idle-stop | bake instance `i-03563f4ad6ca9abf0` **stopped** (repurpose candidate) | ⏸ **STOP — awaiting go-ahead** | — |
| 6 | `.gitlab-ci.yml` jobs (na-005/009) | — | pending | — |

> **Bake notes:** AMI baked from temp instance `i-03563f4ad6ca9abf0` (t3.medium, 30 GB, subnet
> subnet-07ffb12c916a583a7, AMI ami-011b6d2e9dd60cae4). Install driven entirely via SSM Run Command
> (no RDP). Toolchain verified present: MSBuild at `C:\Program Files (x86)\Microsoft Visual Studio\2022\
> BuildTools\MSBuild\Current\Bin\MSBuild.exe`; targeting packs v4.6/v4.6.2/v4.8; git 2.54 on Machine PATH;
> gitlab-runner service Running with config at `C:\Windows\system32\config.toml`. Instance is now **stopped**.
> **Step-5 option:** repurpose this stopped instance as the persistent runner (retag Role=win-build-runner,
> rename mces2-win-build-runner) rather than launching fresh — keeps the AMI for DR.

> **Regional note:** Lambda **Function URLs are NOT supported in ap-south-2** (Hyderabad) — `create-function-url-config`
> and the function-url auth permission both failed. Substituted an **HTTP API (apigatewayv2)** as the front door
> (quick-create, `$default` route, payload v2.0 — same handler, same curl+secret model, single region). REST
> API (apigateway v1) is also absent in ap-south-2; HTTP API is present.

> GitLab runner already minted by na-003/003: **runner id 14** (project `TRP1002/trp1002.cperso.mces2`,
> tags `windows,dotnetfx`). Default VPC: `vpc-0d80a4677ec5ae84d` (172.31.0.0/16, ap-south-2).

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

### Pattern B — Wake-on-pipeline stop/start — ✅ **CHOSEN**
```
pipeline:
  start_runner  (Linux/shared runner; curl HTTP-API ?action=start; wait online)
      ↓
  build         (tag `windows,dotnetfx`; MSBuild on the now-awake Windows runner)
      ↓
  stop_runner   (when: always; curl HTTP-API ?action=stop)
+ EventBridge rule (rate 10 min) → same Lambda action=idle-stop  (safety net)
```
> Front door is an **HTTP API** (apigatewayv2), not a Lambda Function URL — the latter is unsupported in
> ap-south-2 (see Provisioning log §0). Same `curl + x-runner-token` model.
- **Pros:** one instance to reason about; reuses a normal `gitlab-runner` Windows service; easiest to debug;
  **CI carries no AWS credentials** — it only knows a shared secret + the Function URL.
- **Cons:** pays for the **30 GB EBS while stopped** (~$2.7/mo); single-concurrency.

> Pattern A (autoscaler) is **not** the chosen path; kept above only as a future option if build frequency
> or parallelism grows.

## 4. Prerequisites (confirm against live account before building)

- [ ] VPC + subnet in ap-south-2 to host the runner (use default VPC or a dedicated `/28` subnet).
      **Action:** `aws ec2 describe-vpcs / describe-subnets --profile bnprs --region ap-south-2`
- [ ] Outbound internet (NAT or public subnet + EIP-less public IP) so the runner reaches
      `gitlab.bnprs.ai`, NuGet, and Microsoft package CDNs.
- [ ] Latest **Windows Server 2022 English Full Base** AMI id in ap-south-2
      (`aws ssm get-parameters --names /aws/service/ami-windows-latest/Windows_Server-2022-English-Full-Base`).
- [x] GitLab **runner** minted by na-003/003 (2026-06-08): **runner id 14**, project_type, tags
      `windows,dotnetfx`, locked to `TRP1002/trp1002.cperso.mces2`. Auth token held by user out-of-band
      (not committed) — entered at AMI-bake `gitlab-runner register --token`.
- [x] Start/stop control: **Lambda** (Function URL + shared secret). *Locked.*

## 5. Step-by-step provisioning (Pattern B)

> Each step is independently verifiable. **Show cost + confirm before any create/modify.**

### 5.1 Security group (isolated)
- Create `sg-win-build-runner`: **egress all** (443/80 + ephemeral), **ingress none** (runner is outbound-only
  to GitLab; no inbound needed). RDP only if a temporary admin rule is added during AMI baking, then removed.
- Tag per §2. **Do not** attach to or modify any prod SG (QI-SMS-GW etc.).

### 5.2 IAM
- **Instance profile** `win-build-runner-role`: minimal — CloudWatch Logs put, SSM (for `ssm get-parameter`
  + Session Manager instead of RDP). No S3/prod access.
- **Lambda execution role** `win-runner-control-role`: policy = `ec2:StartInstances`, `ec2:StopInstances`,
  `ec2:DescribeInstances` **resource-scoped by tag** `Role=win-build-runner` (+ `logs:*` for the log group).
  No other account access — blast radius is one tagged instance.

### 5.2a Start/stop Lambda (LOCKED design)
- **Function** `win-runner-control` (Python 3.12), role from §5.2. Env/SSM:
  `INSTANCE_ID` (or resolve by tag), `SHARED_SECRET` (strong, rotatable), `MAX_RUN_MIN` (e.g. 30),
  optional `GITLAB_TOKEN` + `RUNNER_ID` for the active-job check.
- **Invocation = HTTP API (apigatewayv2)** front door with an **in-function shared-secret check**
  (Function URLs are unsupported in ap-south-2). CI calls
  `curl -H "x-runner-token: $SECRET" "$RUNNER_CTL_URL/?action=start|stop"`. **No AWS credentials in CI.**
  - Endpoint: `https://gb7ez1jj7i.execute-api.ap-south-2.amazonaws.com` (api id `gb7ez1jj7i`).
  - Trade-off: the endpoint is internet-reachable, so security rests on the secret. Mitigations: long random
    secret stored as a **masked, protected** GitLab CI variable + Lambda env (or SSM SecureString);
    rotate periodically; function only ever start/stops **one tagged instance** (can't do anything else).
  - Stronger alt if desired later: HTTP API JWT/IAM authorizer — but that complicates the CI call.
- **Actions:**
  - `start` → `start-instances`; return when `running` (CI then polls GitLab until the runner is online).
  - `stop`  → `stop-instances`.
  - `idle-stop` → stop **iff** instance `running` AND (uptime > `MAX_RUN_MIN` OR no active GitLab job on
    the runner). Called by EventBridge (§5.5), not by CI.

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
- EventBridge scheduled rule (rate 10 min) → **same** Lambda `win-runner-control` with `action=idle-stop`
  (§5.2a): stops the instance if `running` and past `MAX_RUN_MIN` / no active job. Guards against a failed
  pipeline (e.g. `stop_runner` never reached) leaving the instance running and billing.

### 5.6 CI wiring (owned by na-005/009 in `trp1002.cperso.mces2/.gitlab-ci.yml`)
```yaml
stages: [provision, build, teardown]

# CI variables (masked, protected): RUNNER_CTL_URL = Lambda Function URL,
#                                    RUNNER_CTL_TOKEN = shared secret. No AWS creds.
start_runner:
  stage: provision
  tags: [linux]                       # any always-on shared runner
  script:
    - curl -fsS -H "x-runner-token: $RUNNER_CTL_TOKEN" "$RUNNER_CTL_URL?action=start"
    - ./scripts/wait-runner-online.sh  # poll GitLab API until the windows runner is online

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
    - curl -fsS -H "x-runner-token: $RUNNER_CTL_TOKEN" "$RUNNER_CTL_URL?action=stop"
```

## 6. Cost breakdown (ap-south-2, On-Demand Windows, rough)

| Item | Unit | ~100 builds/mo @ 15 min |
|------|------|--------------------------|
| Compute — `t3.medium` Windows | ~$0.07/hr | 25 hr → **~$1.8** |
| EBS — 30 GB gp3 (always, while stopped too) | ~$0.092/GB-mo | **~$2.8** |
| AMI snapshot storage (~30 GB compressed) | ~$0.05/GB-mo | **~$1.0** |
| Data transfer / SSM / **Lambda + Function URL + EventBridge** | negligible (well within free tier: ~4.3k EventBridge invokes/mo) | **~$0.5** |
| **Total** | | **≈ $6/mo** |
| (contrast) always-on `t3.medium` Windows | ~$0.07/hr × 730 | ~$51/mo |

**Savings vs always-on ≈ 88%.** The Lambda control plane (Function URL + ~4,300 EventBridge ticks/mo) is
effectively free at this scale.

## 7. Known limitation — the WinForms test

`Bpr.Tests.Dlls` is an **interactive WinForms GUI** `.exe`. It needs a desktop session and **will not run
headless in CI**. So:
- CI can reliably **build** BprMces2.
- The GUI test stays **manual** (run inside an interactive session on the runner / via Session Manager),
  **or** the test project is refactored to a headless runner (xUnit/NUnit) before it can gate CI.

## 8. Teardown (when no longer needed)
Stop+terminate the instance → delete the AMI + its snapshot → delete the SG, instance profile/role,
Lambda (+ Function URL) + its role, EventBridge rule. EBS goes with the instance. Leaves zero cost.

## 9. Cross-agent responsibilities

| Step | Owner |
|------|-------|
| VPC/subnet, SG, IAM, AMI bake, instance, Lambda/EventBridge | **na-003/001 bnprs-aws** (this agent) |
| Runner registration token, runner tags, GitLab-side config | **na-003/003 bnprs-gitlab** |
| `.gitlab-ci.yml` build/start/stop jobs, `wait-runner-online.sh` | **na-005/009 bruid-cperso** |

## 10. Open decisions
1. ~~Pattern A vs B~~ → **B (locked 2026-06-08)**
2. ~~Start/stop control~~ → **Lambda Function URL + shared secret (locked 2026-06-08)**
3. ~~Subnet~~ → **default VPC public subnet (locked 2026-06-08)** — runner gets a public IP, egress-only SG,
   no NAT cost.
4. **GUI test** — leave `Bpr.Tests.Dlls` manual, or fund a refactor to headless tests.
5. **Build frequency** — confirms B stays cheapest (it does at low/bursty volume).

### Remaining blockers before provisioning can start
- **Subnet decision** (recommend default public subnet to avoid NAT cost).
- **GitLab runner registration token** for `trp1002.cperso.mces2` — from **na-003/003 bnprs-gitlab**.
- **Explicit go-ahead to begin creating resources** (cost starts at AMI bake). Per agent guardrails, each
  create/modify step shows cost + confirms before applying.
