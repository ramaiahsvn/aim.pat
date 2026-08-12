# Axon — Workflows & Execution Pipeline

> The axon is the long projection that carries the action potential
> from the cell body to the terminals. It is the execution highway —
> once the cell body decides to fire, the signal travels down the
> axon through defined workflow steps.

## Structure

```
axon/
  workflows/     # Multi-step execution definitions
  pipelines/     # Composite workflows chaining multiple stages
```

## How It Works

Each workflow defines a sequence of steps the agent executes.
The signal passes through myelin-sheath segments (skills) for speed
and node-of-ranvier gaps (checkpoints) for verification along the way.
