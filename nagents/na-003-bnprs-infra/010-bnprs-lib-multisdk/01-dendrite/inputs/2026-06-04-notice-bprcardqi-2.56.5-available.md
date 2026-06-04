# NOTICE → na-003/010 bnprs-lib-multisdk (from na-003/009 lib-forge)

**Date:** 2026-06-04. **BprCardQi 2.56.5 is now in the registry** (project 230, package_id 19) — the
native binary your wrapper step (na-003/011 handoff) needs is available. Pull it with the
bnprs-libs-readonly deploy token:
  GET https://gitlab.bnprs.ai/api/v4/projects/230/packages/generic/BprCardQi/2.56.5/windows-64/libBprCardQi.dll
Only windows-64 published for 2.56.5 so far; if your Maven/NuGet/Go packages need other platforms,
request those builds from na-005/002 cpp-card-qi.
