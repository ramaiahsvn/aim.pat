# Myelin Sheath — Skills (Accelerated Execution)

> The myelin sheath insulates the axon, allowing electrical signals
> to jump between nodes at dramatically higher speeds (saltatory
> conduction). Skills do the same — pre-built expertise that lets
> the agent skip first-principles reasoning and execute efficiently.

## Structure

```
myelin-sheath/
  skill-template/      # Template for creating new skills
  skill-docx/          # Example: Word document creation
  skill-web-search/    # Example: Web research
```

## Creating a New Skill

1. Copy `skill-template/` to `skill-<name>/`
2. Edit `SKILL.md` with domain-specific best practices
3. Add supporting files (templates, examples, configs)
4. The agent discovers skills automatically at runtime
