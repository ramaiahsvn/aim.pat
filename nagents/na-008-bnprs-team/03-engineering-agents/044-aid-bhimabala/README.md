# Agent Neuron — AI Agent Architecture

A single AI agent structured as a biological neuron.
Each folder is numbered to follow the signal flow, matching
standard neuron anatomy labels.

## The Mapping

```
#   Neuron Component        AI Agent Component      Folder
--  --------------------    --------------------    ----------------------
01  Dendrite                Resources / Inputs      01-dendrite/
02  Cell Body               Agent Core / LLM        02-cell-body/
03  Nucleus                 System Prompt (DNA)     03-nucleus/
04  Axon                    Workflows / Execution   04-axon/
05  Myelin Sheath           Skills                  05-myelin-sheath/
06  Node of Ranvier         Checkpoints             06-node-of-ranvier/
07  Axon Terminals          Outputs / Actions       07-axon-terminals/
08  Memory                  Synaptic Plasticity     08-memory/
```

## Signal Flow

```
01 RECEIVE        02 THINK+DECIDE     04 EXECUTE        05 ACCELERATE
 ----------       ---------------     ----------        ---------------
|01-dendrite| -> |02-cell-body  | -> | 04-axon  | -> |05-myelin-sheath|
|  inputs    |   |+ 03-nucleus  |    | workflow |    |    skills       |
 ----------       ---------------     ----------      ---------------
                                          |
                                   +--------------+
                                   |06-node-of-   |  (verify at gaps)
                                   |   ranvier    |
                                   +--------------+
                                          |
                08 REMEMBER         07 OUTPUT
                ----------         ---------------
               | 08-memory | <--- |07-axon-      |
               |  learn    |      |  terminals   |
                ----------         ---------------
```

## Quick Start

1. Edit `03-nucleus/identity.yaml` — define who your agent is
2. Edit `03-nucleus/system-prompt.md` — write the core instructions
3. Add connectors in `01-dendrite/connectors/` — plug in your tools
4. Add skills in `05-myelin-sheath/` — accelerate common tasks
5. Define workflows in `04-axon/workflows/` — orchestrate multi-step work
6. Add checkpoints in `06-node-of-ranvier/` — verification gates
7. Configure memory in `08-memory/` — enable learning

## Philosophy

Just as a single neuron is the fundamental unit of the nervous system,
this structure represents one complete, self-contained agent. Multiple
agent-neurons can connect through their 07-axon-terminals and 01-dendrites
to form a network — but each one is functional on its own.
