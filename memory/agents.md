# Agents Memory — aim.pat

> Cross-agent context: active agents, relationships, and inter-agent dependencies.
> Updated automatically when agents are created, retired, or linked.

## Active Agents

| Code | Group       | Name      | Role                                    | Status | Created    |
|------|-------------|-----------|------------------------------------------|--------|------------|
| 01   | na-001      | pat-emails-todo | Email and Task Manager            | active | 2026-05-26 |
| 02   | na-001      | pat-fbmi  | Family Health & Nutrition Assistant     | active | 2026-05-26 |
| 03   | na-001      | pat-mfin  | Personal Finance Manager                | active | 2026-05-26 |
| 04   | na-001      | pat-fhbs  | Home Balance Sheet                      | active | 2026-05-26 |
| 05   | na-001      | pat-assets  | Personal Asset Manager                 | active | 2026-05-26 |
| 06   | na-001      | pat-patents | Patents and IP Manager                 | active | 2026-05-26 |
| 01   | na-002      | bnprs-leadership | Leadership and Strategy Advisor   | active | 2026-05-26 |
| 02   | na-002      | bnprs-admin      | Admin, HR, Legal and Compliance   | active | 2026-05-26 |
| 03   | na-002      | bnprs-finance    | Business Finance, Accounting, Tax | active | 2026-05-26 |
| 04   | na-002      | bnprs-sales      | Sales, Marketing and Customer     | active | 2026-05-26 |
| 05   | na-002      | bnprs-websites     | Website and Digital Presence      | active | 2026-05-26 |
| 06   | na-002      | bnprs-social-media | Social Media and Content          | active | 2026-05-26 |
| 07   | na-002      | bnprs-docs         | Business Documents and Templates  | active | 2026-05-26 |
| 08   | na-002      | bnprs-tech-docs    | Technical Products Documentation  | active | 2026-05-26 |

## Group Slot Usage

| Group | ID     | Used | Max |
|-------|--------|------|-----|
| na-001-personal          | na-001 | 6   | 255 |
| na-002-bnprs-core        | na-002 | 8   | 255 |
| na-003-bnprs-infra       | na-003 | 0   | 255 |
| na-004-bnprs-biometrics  | na-004 | 0   | 255 |
| na-005-bnprs-fintech     | na-005 | 0   | 255 |
| na-006-bnprs-deployments | na-006 | 0   | 255 |
| na-007-bnprs-zoo         | na-007 | 0   | 255 |

## Inter-Agent Dependencies

_None defined yet._

## Notes

- 01 pat-emails-todo nucleus (`03-nucleus/CLAUDE.md`) is a template shell — Gmail, Outlook, Zoho Mail, todo tracking domain not yet filled in
- 02 pat-fbmi nucleus (`03-nucleus/CLAUDE.md`) is a template shell — family health, nutrition, doctor advice domain not yet filled in
- 03 pat-mfin nucleus (`03-nucleus/CLAUDE.md`) is a template shell — personal finance, income, expenses domain not yet filled in
- 04 pat-fhbs nucleus (`03-nucleus/CLAUDE.md`) is a template shell — household expenses, family balance sheet domain not yet filled in
- 05 pat-assets nucleus (`03-nucleus/CLAUDE.md`) is a template shell — lands, flats, properties, real estate portfolio domain not yet filled in
- 06 pat-patents nucleus (`03-nucleus/CLAUDE.md`) is a template shell — patents, trademarks, copyrights, IP portfolio domain not yet filled in
- na-002/01 bnprs-leadership nucleus (`03-nucleus/CLAUDE.md`) is a template shell — CEO/CTO vision, strategy, certifications domain not yet filled in
- na-002/02 bnprs-admin nucleus (`03-nucleus/CLAUDE.md`) is a template shell — admin, HR, legal, compliance domain not yet filled in
- na-002/03 bnprs-finance nucleus (`03-nucleus/CLAUDE.md`) is a template shell — business finance, accounting, tax domain not yet filled in
- na-002/04 bnprs-sales nucleus (`03-nucleus/CLAUDE.md`) is a template shell — sales, marketing, customer relations domain not yet filled in
- na-002/05 bnprs-websites nucleus (`03-nucleus/CLAUDE.md`) is a template shell — bnprs.ai, bnprs.in, bnprs.com web presence domain not yet filled in
- na-002/06 bnprs-social-media nucleus (`03-nucleus/CLAUDE.md`) is a template shell — LinkedIn, Twitter, Instagram, YouTube, podcasts domain not yet filled in
- na-002/07 bnprs-docs nucleus (`03-nucleus/CLAUDE.md`) is a template shell — offer letters, NDAs, appointment letters, contracts domain not yet filled in
- na-002/08 bnprs-tech-docs nucleus (`03-nucleus/CLAUDE.md`) is a template shell — technical specs, product docs, API docs, user manuals domain not yet filled in
