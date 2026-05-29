# Memory — Synaptic Plasticity

> Memory in the brain emerges from the strengthening of synaptic
> connections over time (long-term potentiation). It isn't stored
> in one place — it spans the entire network. Agent memory works
> the same way, improving every component with experience.

## Structure

```
memory/
  short-term/             # Session context, conversation buffer
  long-term/              # Persistent knowledge across sessions
  learned-preferences/    # User patterns discovered over time
```

## Memory Lifecycle

1. New information enters short-term memory (working memory)
2. Important/repeated patterns promote to long-term (LTP)
3. Stale or contradicted memories are pruned
4. Preferences are extracted from behavioral patterns (Hebbian learning)
