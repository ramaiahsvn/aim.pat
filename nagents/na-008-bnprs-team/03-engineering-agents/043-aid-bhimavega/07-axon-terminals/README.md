# Axon Terminals — Outputs & Actions

> Axon terminals (synaptic boutons) release neurotransmitters into
> the synaptic cleft to affect the next cell. These are the agent's
> output channels — actions that impact the outside world.

## Structure

```
axon-terminals/
  actions/          # What the agent CAN do (action definitions)
  deliverables/     # What the agent DID (output files land here)
  notifications/    # Messages sent to users or systems
```

## How It Works

The signal from the axon triggers a terminal action: creating a file,
sending a message, calling an API, or notifying the user. Each output
(neurotransmitter) crosses the interface (synaptic cleft) to reach
the target — the user, another system, or the next agent in a chain.
