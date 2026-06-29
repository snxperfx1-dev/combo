# FALCON OS — Unified Trading Intelligence Platform

A single **modular trading operating system** for MetaTrader 5 that merges three
previously independent codebases into one coherent architecture with a shared
state model and a deterministic execution pipeline:

| Source | Role | Folded into |
| --- | --- | --- |
| **LETRA 37** | Market Intelligence (physics, structure, liquidity, wave, FU, HTF, beliefs, ERF) | Core Market + Intelligence engines |
| **F16 Raptor / Senseei** | Strategic Intelligence (invisible network, curve tree, campaign, Senseei meta-intelligence) | Memory + Intelligence engines |
| **Symphony** | Execution & Risk (DRDWCT, lot, sessions, ARC exit, orders) | Execution engine |

This is **not** a merge of three scripts. It is a redesign into a modular OS
where every subsystem shares **one** market state and **one** event pipeline.
Every calculation exists exactly once; every module consumes shared state.

## Directory layout

```
FalconOS/
├── FalconOS.mq5                 # main EA: inputs, kernel boot, master pipeline
├── README.md                    # this file
└── Include/Falcon/
    ├── Kernel.mqh               # shared state · event bus · scheduler · config · logger
    ├── CoreMarket.mqh           # MODULE 1 — observes  (physics/structure/liquidity/FU/HTF)
    ├── Memory.mqh               # MODULE 2 — remembers (network/curve tree/campaign/participants)
    ├── Intelligence.mqh         # MODULE 3 — reasons + decides (Engine1A/ERF/beliefs/Senseei/decision)
    ├── Execution.mqh            # MODULE 4 — executes (DRDWCT risk/lot/session/orders/trade manager)
    └── Visualization.mqh        # MODULE 5 — displays (one unified tabbed dashboard)
```

## Kernel

A lightweight kernel all modules use:

- **Shared State Manager** — the single `g_state` (`FAL_MarketState`): the one
  source of truth for every market, network, intelligence and execution value.
- **Event Bus** — `FAL_Publish` / `FAL_Fired`: modules react to events instead of
  polling (`CORE_UPDATED`, `WAVE_SPAWN`, `ERF_UPDATED`, `DECISION_BUY`, …).
- **Scheduler** — `FAL_Pipeline()`: a single deterministic per-bar execution order.
- **Configuration Service** — `g_cfg` with `LIVE / BACKTEST / RESEARCH` profiles.
- **Logging & Diagnostics** — `g_diag`: timing metrics, per-module health, events.

## Master pipeline (runs once per new bar, dependency-correct)

```
New Candle
  → Physics / Structure / Fractal stack / FU / HTF      (Core Market — observes)
  → Engine 1A phase  (lifecycle authority = M5 canonical phase)
  → Wave-spawn       (current flip zone / Point-4 / recursion)
  → Liquidity        (heatmap against the now-current flip zone)
  → ERF              (EDE energy dissipation · RE resolution · EAE attractor)
  → Wave intelligence (similarity · beliefs · progress · bayesian prob · grade)
  → Memory: invisible network + recursive curve tree
  → Campaign + participants
  → Senseei meta-intelligence (align · conflict · threat · confidence · intent · opportunity)
  → Decision Engine  (BUY/SELL/WAIT/ATTACK/DEFEND/EXIT/SCALE/NO TRADE + targets)
  → Execution Engine (per-campaign risk · manage exits · open; never decides)
  → Visualization    (one unified dashboard)
```

## Design principles

1. **Single Responsibility** — each module owns one domain.
2. **Single Source of Truth** — no duplicated calculations or state.
3. **Deterministic Pipeline** — every bar follows the same sequence.
4. **Event-Driven Communication** — modules exchange events, not direct calls.
5. **Composable Modules** — each engine can be tested or replaced independently.
6. **Clear Separation** — Market observes · Memory remembers · Intelligence reasons
   · Decision decides · Execution executes · Visualization displays.
7. **Extensibility** — new engines plug into the event bus without touching the pipeline.

## Core laws preserved from the source specs

- **Phases are OUTPUTS, never inputs.** The deep engines create reality; the phase
  label describes it. Decisions gate on continuous probabilities / opportunity /
  ERF readiness — never `if(phase == X)`.
- **Multi-campaign by design.** The book can hold long *and* short campaigns
  simultaneously (hedging). Risk is evaluated **per campaign (per direction) on
  gross exposure**, never netting opposite sides, with a portfolio combined-gross
  backstop. Winner/age protection is direction-agnostic.
- **Owner-driven destinations & recursion.** The recursive curve tree decides who
  owns price; compression sets the recursion budget; the owner curve's destination
  drives the target.

## Usage

1. Copy `FalconOS.mq5` to `MQL5/Experts/FalconOS/` and the `Include/Falcon/*.mqh`
   files to `MQL5/Experts/FalconOS/Include/Falcon/` (the EA uses relative includes).
2. Compile `FalconOS.mq5` in MetaEditor.
3. Attach to a chart (designed/tuned for XAUUSD; the lot model assumes the
   $10/pip gold contract — adjust `EXE_ComputeLots` for other instruments).
4. Pick a `Profile` (RESEARCH disables live orders) and a dashboard `Tab`.

> The lot engine, session windows and liquidity seed levels are inherited from
> Symphony's XAUUSD model. Review them before trading any other symbol.
