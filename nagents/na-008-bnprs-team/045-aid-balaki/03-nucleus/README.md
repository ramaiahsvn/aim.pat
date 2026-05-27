# Nucleus — System Prompt & Identity (DNA)

> The nucleus contains the cell's DNA — the fundamental genetic code
> that defines what the cell is and how it behaves. This holds the
> agent's system prompt, identity, and behavioral guardrails.

## Structure

```
nucleus/
  system-prompt.md     # Core identity and instructions
  identity.yaml        # Name, role, persona configuration
  guardrails.yaml      # Safety boundaries and behavioral limits
```

## How It Works

The nucleus is read-only at runtime — like DNA, it defines what the
agent IS, not what it does moment-to-moment. The cell body consults
the nucleus before every decision to stay aligned with its core identity.
