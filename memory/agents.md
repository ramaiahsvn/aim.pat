# Agents Memory — aim.pat

> Cross-agent context: active agents, relationships, and inter-agent dependencies.
> Updated automatically when agents are created, retired, or linked.

## Active Agents

| Code | Group       | Name      | Role                                    | Status | Created    |
|------|-------------|-----------|------------------------------------------|--------|------------|
| 01   | na-001      | pat-todo  | Productivity Assistant                  | active | 2026-05-26 |
| 02   | na-001      | pat-fbmi  | Family Health & Nutrition Assistant     | active | 2026-05-26 |
| 03   | na-001      | pat-mfin  | Personal Finance Manager                | active | 2026-05-26 |
| 04   | na-001      | pat-fhbs  | Home Balance Sheet                      | active | 2026-05-26 |
| 05   | na-001      | pat-assets  | Personal Asset Manager                 | active | 2026-05-26 |
| 06   | na-001      | pat-patents | Patents and IP Manager                 | active | 2026-05-26 |

## Group Slot Usage

| Group | ID     | Used | Max |
|-------|--------|------|-----|
| na-001-personal          | na-001 | 6   | 255 |
| na-002-bnprs-core        | na-002 | 0   | 255 |
| na-003-bnprs-infra       | na-003 | 0   | 255 |
| na-004-bnprs-biometrics  | na-004 | 0   | 255 |
| na-005-bnprs-fintech     | na-005 | 0   | 255 |
| na-006-bnprs-deployments | na-006 | 0   | 255 |
| na-007-bnprs-zoo         | na-007 | 0   | 255 |

## Inter-Agent Dependencies

_None defined yet._

## Notes

- 01 pat-todo nucleus (`03-nucleus/CLAUDE.md`) is a template shell — domain and project conventions not yet filled in
- 02 pat-fbmi nucleus (`03-nucleus/CLAUDE.md`) is a template shell — family health, nutrition, doctor advice domain not yet filled in
- 03 pat-mfin nucleus (`03-nucleus/CLAUDE.md`) is a template shell — personal finance, income, expenses domain not yet filled in
- 04 pat-fhbs nucleus (`03-nucleus/CLAUDE.md`) is a template shell — household expenses, family balance sheet domain not yet filled in
- 05 pat-assets nucleus (`03-nucleus/CLAUDE.md`) is a template shell — lands, flats, properties, real estate portfolio domain not yet filled in
- 06 pat-patents nucleus (`03-nucleus/CLAUDE.md`) is a template shell — patents, trademarks, copyrights, IP portfolio domain not yet filled in
