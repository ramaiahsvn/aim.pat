# nagent-template-2 — Simple 4-Component Agent

A lightweight agent template. No neuron anatomy — just four plain folders.

## Structure

```
01-resources/
  context.yaml      Project description, tasks, git repo URLs, general inputs
  secrets/          Credentials (git-ignored)

02-workflows/       Step-by-step task definitions (one file per workflow)

03-outputs/         Finished work lands here
  deliverables/     Generated files, reports, exports

04-memory/          What the agent remembers
  session/          Scratch notes for the current task
  long-term/        Persistent facts and learned preferences
```

## Scope

This template is **not used** for agents inside the `aim.pat` repo (those use `nagent-template`).
It is intended for external or standalone agent projects.

## When to use this template

Use **nagent-template-2** when the agent has:
- A small, well-defined scope
- No need for skills, checkpoints, or complex reasoning layers
- Simple inputs → process → outputs flow

Use **nagent-template** (the neuron template) when the agent needs
skills, multi-stage reasoning, human-in-the-loop checkpoints, or
separate planning/execution layers.

## Quick Start

1. Copy `CLAUDE.md` — fill in identity, role, and directives
2. Add connectors to `01-resources/connectors/` — plug in your tools
3. Write workflows in `02-workflows/` — one `.yaml` or `.md` per task type
4. Deliver outputs to `03-outputs/deliverables/`
5. Persist facts in `04-memory/long-term/`
