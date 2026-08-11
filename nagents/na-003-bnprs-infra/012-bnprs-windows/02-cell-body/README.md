# Cell Body — Agent Core (LLM + Planning)

> The cell body (soma) is the neuron's control center. It integrates
> all incoming dendritic signals, houses the nucleus, and decides
> whether to fire. In the agent, this is the LLM reasoning engine
> combined with the planning/decision layer.

## Structure

```
cell-body/
  reasoning/     # Reasoning strategies, chain-of-thought templates
  models/        # LLM configurations, fallback chains
  planning/      # Decision gate (the axon hillock function)
    todo/        # Task queue — pending work items
    status/      # Runtime state — what's active now
    priorities/  # Priority rules, firing threshold
```

## How It Works

The cell body receives processed signals from dendrites, consults
the nucleus (system prompt) for identity, reasons through the problem,
and uses the planning layer to decide what to act on and when.
The planning subfolder acts as the "axon hillock" — the threshold
zone that determines whether the agent fires (acts) or inhibits (defers).
