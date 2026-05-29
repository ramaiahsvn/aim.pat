# na-010-bna-platform — BNA (BNPRS Neura Agents Platform)

The orchestration layer of aim.pat. BNA agents coordinate the other agent groups
and run the organisation in **auto-pilot** — planning, sequencing, and dispatching
work across the company, then closing the loop on results.

**BNA = BNPRS Neura Agents Platform.**

## Purpose

Where individual groups own a domain (CXOs own strategy, products own roadmaps,
deployments own releases), na-010 owns the **coordination between them**. It is the
conductor that keeps the whole org moving in sync without a human manually routing
every hand-off.

## Coordinated groups

| Group                    | What BNA coordinates                                            |
|--------------------------|----------------------------------------------------------------|
| na-007-bnprs-cxo         | Strategy, priorities, approvals, the Pandava council operating rhythm |
| na-006-bnprs-deployments | Release schedules, environment readiness, production hand-offs |
| na-008-bnprs-team        | Task allocation across the 100 team agents (4 tiers)           |
| na-009-bnprs-products    | Product roadmaps, cross-product dependencies, launch readiness |
| _related_                | na-002 core, na-003 infra, na-004/005 R&D as needed            |

## Autonomy model — propose-then-approve

BNA plans and coordinates autonomously, but **consequential actions are gated**
behind human / CEO (na-007/001 Yudhishthira) approval:

- ✅ Autonomous: status aggregation, planning, scheduling, drafting, routing
  non-binding tasks, surfacing conflicts and risks
- 🔒 Requires approval: production deployments, spend commitments, external
  communications, hiring/headcount, contractual or pricing changes, anything
  crossing a defined risk threshold

This is the default `autonomy` for the group (see `registry.yaml`). It can be
tightened to advisory or expanded toward fuller auto-pilot per agent over time.

## Agents

| Code | Folder              | Name             | Role                                   | Status |
|------|---------------------|------------------|----------------------------------------|--------|
| 001  | 001-bna-orchestrator | BNA Orchestrator | Master Orchestration & Auto-Pilot Conductor | active |

## Group info

| Field      | Value                                          |
|------------|------------------------------------------------|
| Group ID   | na-010                                         |
| Folder     | nagents/na-010-bna-platform                    |
| Domain     | Cross-group orchestration / org auto-pilot     |
| Autonomy   | propose-then-approve                           |
| Max agents | 255                                            |
| Slots used | 1 (001)                                        |
| Next code  | 002                                            |
