# 08-memo

What the agent remembers.

| Sub-folder  | What goes here |
|------------|----------------|
| `session/`   | Scratch notes, in-progress state, current task context |
| `long-term/` | Persistent facts, learned preferences, history summaries |

## Usage

- `session/` is cleared at the start of each new task (treat as temp)
- `long-term/` is append-only — never delete, only update or mark outdated
