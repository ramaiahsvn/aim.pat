# Dendrite — Resource Inputs

> Dendrites branch out to receive signals from other neurons and the
> environment. Each branch is an input channel; each spine is a
> specialized receptor for one type of signal.

## Structure

```
dendrite/
  connectors/    # MCP connectors, APIs (each spine = one endpoint)
  inputs/        # User messages, file uploads, form submissions
  sensors/       # Web search, scrapers, RSS feeds, webhooks
```

## Adding a New Connector

1. Copy `connectors/_template.yaml` to `connectors/<name>.yaml`
2. Fill in connection details and capabilities
3. The cell body discovers it at startup
