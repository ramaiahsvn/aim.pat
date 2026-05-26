# 02-workflows

One file per task type. Claude reads the relevant file before starting a multi-step task.

## File naming

```
<verb>-<subject>.yaml     # e.g. generate-report.yaml
<verb>-<subject>.md       # prose-style workflows are fine too
```

## Workflow file structure (yaml)

```yaml
id: <workflow-id>
name: "<Workflow Name>"
description: "<What this workflow does>"
trigger: "<manual | scheduled | event>"

steps:
  - id: step-1
    name: "<Step name>"
    action: "<what to do>"
    inputs: []
    outputs: []
    on_failure: stop   # or: continue | retry

  - id: step-2
    ...

output: "<Where final output lands — usually 03-outputs/deliverables/>"
```
