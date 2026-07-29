#!/usr/bin/env python3
"""Create a GitLab project with the BNPRS branch convention already applied.

    export GITLAB_PAT=...            # already in ~/.zshrc on pat-m4p
    ./gitlab-create-project.py --group BPR1004 --name bpr1004.utms.api-go.tms --desc "uTMS API (Go)"
    ./gitlab-create-project.py --group 5       --name some.project --dry-run

WHY THIS EXISTS
    "Make these four branches the default for every new repo" is a Premium feature (custom project
    templates); this instance is CE — `GET /api/v4/version` reports "enterprise": false and
    /api/v4/license returns 404. GitLab CE can set a default branch NAME and default protection, but it
    cannot create bp_dev / bp_rel / ai_dev for you. So the convention lives here instead: one command that
    does the whole thing the same way every time.

WHAT IT DOES, in the order that matters
    1. create the project with a README on master  (branches cannot exist before the first commit)
    2. commit .gitlab-ci.yml — the org approval-check template (2x thumbs-up on bp_dev/bp_rel)
    3. branch bp_dev / bp_rel / ai_dev off master
    4. re-protect ALL FOUR at Maintainer-only push+merge, force push off
       (DELETE first: GitLab auto-protects the default branch at creation, so a bare POST would conflict)
    5. MR settings: delete source branch after merge, require a passing pipeline
    Members are NOT touched: they are inherited from the group, which is where they belong.

VERIFIES ITSELF
    Re-reads the project from the API afterwards and fails loudly if the branches, protection or MR
    settings are not what was asked for — a create call returning 201 is not proof the result is right.
"""
import argparse
import json
import sys
import os
import urllib.error
import urllib.parse
import urllib.request

API = "https://gitlab.bnprs.ai/api/v4"
BRANCHES = ["master", "bp_dev", "bp_rel", "ai_dev"]
MAINTAINER = 40

CI_YML = """workflow:
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'

include:
  - project: 'BPR1000/ci-templates'
    file: 'approval-check.yml'

stages:
  - review
"""


def call(method, path, token, data=None):
    req = urllib.request.Request(
        f"{API}{path}",
        data=urllib.parse.urlencode(data).encode() if data else None,
        method=method,
    )
    req.add_header("PRIVATE-TOKEN", token)
    try:
        with urllib.request.urlopen(req, timeout=90) as r:
            raw = r.read().decode()
            return r.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            return e.code, json.loads(raw)
        except json.JSONDecodeError:
            return e.code, raw


def main():
    ap = argparse.ArgumentParser(description="Create a GitLab project with the BNPRS branch convention.")
    ap.add_argument("--group", required=True, help="group id or path, e.g. 5 or BPR1004")
    ap.add_argument("--name", required=True, help="project path, e.g. bpr1004.utms.api-go.tms")
    ap.add_argument("--desc", default="", help="project description")
    ap.add_argument("--visibility", default="private", choices=["private", "internal", "public"])
    ap.add_argument("--dry-run", action="store_true", help="print the plan, change nothing")
    args = ap.parse_args()

    token = os.environ.get("GITLAB_PAT")
    if not token and not args.dry_run:
        sys.exit("error: GITLAB_PAT is not set")

    if args.dry_run:
        print(f"DRY RUN — would create {args.group}/{args.name} ({args.visibility})")
        print("  1. project with README on master")
        print("  2. .gitlab-ci.yml (approval-check template)")
        print(f"  3. branches: {', '.join(BRANCHES[1:])}")
        print(f"  4. protect {', '.join(BRANCHES)} at {MAINTAINER}/{MAINTAINER}, force push off")
        print("  5. MR settings: remove source branch, require passing pipeline")
        print("  members: inherited from the group, not set here")
        return 0

    # resolve the group so a typo fails here rather than halfway through
    st, grp = call("GET", f"/groups/{urllib.parse.quote(str(args.group), safe='')}", token)
    if st != 200:
        sys.exit(f"error: group '{args.group}' not found ({st})")
    print(f"group: {grp['id']} {grp['full_path']}")

    st, proj = call("POST", "/projects", token, {
        "name": args.name, "path": args.name, "namespace_id": grp["id"],
        "visibility": args.visibility, "description": args.desc,
        "initialize_with_readme": "true", "default_branch": "master",
    })
    if st not in (200, 201):
        sys.exit(f"error: create failed ({st}): {proj}")
    pid = proj["id"]
    print(f"created: {pid} {proj['path_with_namespace']}")

    st, r = call("POST", f"/projects/{pid}/repository/files/{urllib.parse.quote('.gitlab-ci.yml', safe='')}",
                 token, {"branch": "master", "content": CI_YML,
                         "commit_message": "ci: org approval-check template (2x thumbs-up on bp_dev/bp_rel)"})
    print(f"  .gitlab-ci.yml : {'ok' if st in (200, 201) else f'FAILED {st} {r}'}")

    for br in BRANCHES[1:]:
        st, r = call("POST", f"/projects/{pid}/repository/branches?branch={br}&ref=master", token)
        print(f"  branch {br:7}: {'ok' if st in (200, 201) else f'FAILED {st} {r}'}")

    for br in BRANCHES:
        call("DELETE", f"/projects/{pid}/protected_branches/{br}", token)   # clear default protection
        st, r = call("POST", f"/projects/{pid}/protected_branches", token,
                     {"name": br, "push_access_level": MAINTAINER,
                      "merge_access_level": MAINTAINER, "allow_force_push": "false"})
        print(f"  protect {br:6}: {'ok' if st in (200, 201) else f'FAILED {st} {r}'}")

    st, r = call("PUT", f"/projects/{pid}", token,
                 {"remove_source_branch_after_merge": "true",
                  "only_allow_merge_if_pipeline_succeeds": "true"})
    print(f"  MR settings    : {'ok' if st in (200, 201) else f'FAILED {st} {r}'}")

    # ---- verify, do not assume ----
    problems = []
    _, fresh = call("GET", f"/projects/{pid}", token)
    _, brs = call("GET", f"/projects/{pid}/repository/branches", token)
    _, prot = call("GET", f"/projects/{pid}/protected_branches", token)
    have = {b["name"] for b in brs}
    missing = [b for b in BRANCHES if b not in have]
    if missing:
        problems.append(f"missing branches: {missing}")
    plevels = {p["name"]: (p["push_access_levels"][0]["access_level"],
                           p["merge_access_levels"][0]["access_level"],
                           p.get("allow_force_push")) for p in prot}
    for b in BRANCHES:
        if plevels.get(b) != (MAINTAINER, MAINTAINER, False):
            problems.append(f"{b} protection is {plevels.get(b)}, expected ({MAINTAINER}, {MAINTAINER}, False)")
    if not fresh.get("remove_source_branch_after_merge"):
        problems.append("remove_source_branch_after_merge is off")
    if not fresh.get("only_allow_merge_if_pipeline_succeeds"):
        problems.append("only_allow_merge_if_pipeline_succeeds is off")

    if problems:
        print("\nVERIFY FAILED:")
        for p in problems:
            print(f"  - {p}")
        return 1
    print(f"\nverified: 4 branches, all protected {MAINTAINER}/{MAINTAINER} no force push, MR settings on")
    print(f"url: {fresh['web_url']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
