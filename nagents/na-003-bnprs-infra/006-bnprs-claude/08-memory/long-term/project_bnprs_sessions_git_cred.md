---
name: project-bnprs-sessions-git-cred
description: bnprs-claude EC2 devops git auth — info_bnprs now ISOLATED in its own credential store so product-repo ops can't evict it
metadata: 
  node_type: memory
  type: project
  originSessionId: bdcd411e-047a-480c-97e9-e90391ac7be4
---

On the bnprs-claude EC2 (devops user), `bnprs-sessions.sh` clones/pulls/pushes the
agent memory repos at `gitlab.bnprs.ai/aim1001/<tier>/aim1001.aid.NNN` as
**info_bnprs** over HTTPS, non-interactively (`GIT_TERMINAL_PROMPT=0`).

**Symptom → real cause.** `bnprs-sessions.sh` reports `Repo not found/inaccessible:
https://info_bnprs@gitlab.bnprs.ai/...`. GitLab returns **401/404** for a *private*
repo when the caller is unauthenticated — so "not found" almost always means
**bad/absent credential, NOT a missing repo**. Verify the repo exists via the root
API (`GET /projects/:url-encoded-path` with `$GITLAB_PAT` — see
[[reference_gitlab_root_admin]]); if it exists, it's auth.

**The recurring eviction (root cause, fixed 2026-05-31).** The agent work homes
(`/home/devops/aid.NNN`) also hold **product repos** with remotes like
`https://gitlab.bnprs.ai/BPR10xx/...` — some with *other users'* creds embedded in
the URL (`Mohan:glpat-...`, `venkatesh1117`, `satya_krishna`, `charan`). During a
session, a git op on one of those made git's **shared `store`** hand over
info_bnprs; the product repo 401'd; git's `reject` then **ERASED info_bnprs from
`~/.git-credentials`**. Next aim1001 op → no credential → 404. This recurred every
session and is why re-priming the shared store kept "working then breaking."

**Durable fix — credential isolation (in `ensure_git_auth()`):** give the aim1001
group URL its OWN store file, selected by a path-scoped config section with the
inherited helper reset, username pinned:
```
git config --global credential.https://gitlab.bnprs.ai/aim1001.helper ""        # reset inherited
git config --global --add credential.https://gitlab.bnprs.ai/aim1001.helper "store --file=$HOME/.git-credentials-aim1001"
git config --global credential.https://gitlab.bnprs.ai/aim1001.username info_bnprs
umask 077; printf 'https://info_bnprs:<PW>@gitlab.bnprs.ai\n' > ~/.git-credentials-aim1001; chmod 600 ~/.git-credentials-aim1001
```
Product-repo ops don't match the `/aim1001` path, so they can neither read nor
erase this file. The generic `~/.git-credentials` still serves everything else
(charan etc. may live there — harmless). `ensure_git_auth()` re-asserts this
(idempotent) on every `sync`/`start`/`init`; primes the file from
`$BNPRS_GIT_PASSWORD` only (env-only, never written to a repo). Committed in
`bnprs-sessions.sh` as of 2026-05-31 (aim.pat `6f8a3df`). Verified: simulated the
reject/evict sequence + a competing charan entry → aim1001 stays OK.

**Manual re-prime (if ever needed), to the DEDICATED file:**
`umask 077; printf 'https://info_bnprs:<PW>@gitlab.bnprs.ai\n' > ~/.git-credentials-aim1001; chmod 600 ~/.git-credentials-aim1001`
The info_bnprs git password is valid (a normal account git password, not a PAT).
Never write the value into any repo file — see [[feedback_key_material]].

**Gotchas:**
- Checking persistence by `grep 'info_bnprs@gitlab' ~/.git-credentials` gives a FALSE
  negative — the stored line is `//info_bnprs:<pw>@host`, so grep `'//info_bnprs:'`.
- This Mac (pat-m4p) has **no `timeout`/`gtimeout`** — `timeout ssh ...` silently
  exits 127 and ssh never runs. Use ssh's own `-o ConnectTimeout=N -o BatchMode=yes`.
- `git push ... | tail` checks tail's exit code, not git's. Use `git status -sb`.
- info_bnprs must be **Maintainer on group `aim1001`** to push protected `master`.

Reach the EC2 via [[project-bnprs-claude-vpn]] (SG is VPN-IP-only); transfer via
ssh-stdin (scp disabled, [[project-bnprs-claude-scp]]). Related:
[[project_bnprs_sessions]], [[feedback_github_push]].
