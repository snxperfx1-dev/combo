# FALCON OS — Handoff Brief & Settings-Tuning Task

**For:** the next Claude session
**Repo:** `snxperfx1-dev/combo`  ·  **Branch:** `falcon-os-platform`
**Single-file build:** `FalconOS_AllInOne.mq5` (current **v5.16**)
**Raw:** https://raw.githubusercontent.com/snxperfx1-dev/combo/falcon-os-platform/FalconOS_AllInOne.mq5

---

## 0. THE TASK (what we need you to do next)

**Find the *perfect* (optimal) settings for the LETRA profile and the SYMPHONY profile.**
The machine and the tuning levers are built. What's missing is the empirical work:
run each profile, read the trade journal, and converge on the best parameter set per
engine — using the data, not intuition. The base strategy is **unvalidated**; treat
this as a research problem (find edge, or prove there isn't one), not a polish job.

Deliverable: recommended values (and *why*, from the journal) for each engine's
`MinRR`, `CycleRawStopATR`, `CycleRawTgtATR`, `TalonBeATR`, `TalonGiveback`,
`MaxStacks`, plus whether Free-Run all-phases beats return/breakout-only.

> ⚠️ The agent **cannot run MetaTrader** (sandbox is Linux; MetaEditor/Tester is
> Windows). The USER runs the backtests/optimizations and pastes back the journal
> CSV or the analyzer output. Your job is to direct the experiment and interpret it.

---

## 1. WHAT FALCON OS IS

A single MQL5 EA merging three originals into one modular OS sharing ONE market
state + ONE event pipeline:
- **LETRA** (market physics / structure / wave lifecycle)
- **F16 / Senseei** (invisible network, recursive curve tree, campaign ownership, TIE)
- **Symphony** (execution, risk, ARC exits, money management)

Layers: Kernel (config/state/eventbus/log/persistence) → Market → Memory →
Intelligence → Decision → Execution → Visualization. Deterministic per-bar pipeline,
every calc once, all modules read `g_state`.

### Recently completed (this is the new core)
**Comparative multi-engine wave-cycle framework** — DON'T pick one "truth": run
**three phase cycles simultaneously** on the same observations and let the market
decide which predicts best.
- `g_state.cycles[3]` = LETRA / F16 / SYMPHONY, each emits a normalized `WaveCycle`
  (dir · stage · phase · maturity · objective · invalidation · confidence · entry edge).
- **Wave Intelligence referee** (S12J) scores each engine's *demonstrated* directional
  & objective accuracy (EWMA shadow-prediction book), consensus, deviation, best/leader.
- `InpEntryEngine` selects which engine DRIVES entries + the canonical phase
  (LETRA / F16 / SYMPHONY / CONSENSUS / BEST). Default authority bridges to `g_state.wave`.
- The chosen engine can run **FREE** (all phases) or classic (return/breakout only).

---

## 2. ENTRY / EXIT OWNERSHIP (critical — recently fixed)

**Entries (raw/free mode):** the authority engine fires on its own phase edges,
bypassing the Symphony fact-gate (which is tuned to Symphony's "price-at-zone"
phase-3 and would veto LETRA/F16). Free-Run = enter on every fresh in-direction
phase transition (expansion/return/breakout); **liquidation/reversal phases are
skipped** to cut bad counter-trend entries. `InpMinRR` is enforced even on raw
entries. `InpMaxOpenPositions` caps total concurrent trades. `InpNoHedge` = never
hold both directions.

**Exits — ONLY these manage trades now (everything else is block-only):**
1. **TALON** grip — breakeven + curve-convergent structural trail + **peak-profit
   give-back lock** (`InpTalonGiveback`, e.g. 0.35 keeps 65% of peak).
2. **Position SL / TP** — the ATR stop and the R-multiple target on the order.
3. **Money-manager ladder** — only if `InpUseProfitLadder` is on.

Suppressed so they can't kill trades early:
- Symphony's ARC/phase exit + ARC partial → **off in raw/free mode** (were keyed to
  `sym_mode/sym_phase` and closed the authority engine's trades).
- EE ATR trail + partial → off under Symphony host; also yields to TALON/MM.
- DD-flatten + PYRO catastrophe flatten → **`InpRiskAutoClose=false`** makes them
  *block new entries only*, never close open trades.

**IMPORTANT GOTCHA:** TALON needs the campaign baskets, which PYRO builds. When PYRO
is off TALON builds them itself (fixed). Keep `InpUseSymphony=true` always — Symphony
is the **execution host** (owns order placement); `InpEntryEngine` only selects whose
*signals* it acts on.

---

## 3. THE PROFILES (presets) — your starting points

Two ways to load, both produce the same config:
- **In-EA dropdown:** `InpPreset` = `LETRA` / `SYMPHONY` / `CUSTOM` (GENERAL section).
  It's a **modifiable BASE**: it fills inputs you left at default; **any input you
  change wins**. (Limitation: 4 flip-bools — `useTalon`, `useThermalRisk`, `noHedge`,
  `trailEnable` — can't be reverted to their default while a preset is selected; use
  CUSTOM for that. MT5 also can't repaint the inputs grid from code — confirm the live
  config on the **Experts log line** at init and the **Overview "Active cfg"** line.)
- **`.set` files:** `presets/FALCON_LETRA.set`, `presets/FALCON_SYMPHONY.set`
  (Tester → Load — these DO populate + let you edit the grid).

### Shared frame (both profiles)
`minRR=4` · `maxOpenPositions=2` · `noHedge=true` · TALON on (BE 0.9 / giveback 0.35) ·
PYRO on (maxStacks 2, anti-martingale 1, throttle 0.5/freeze 0.8/critical 1.0,
adverseSpan 3.5) · profit ladder OFF · counter-dir OFF · `riskAutoClose=false` ·
operatingTF M5 · COMMAND tab (14).

### Per-engine differences (the bits most worth tuning)
| Param | LETRA | SYMPHONY | Notes |
|---|---|---|---|
| `InpEntryEngine` | LETRA(0) | SYMPHONY(2) | identity (forced) |
| `InpCycleRawStopATR` | 1.2 | 1.0 | LETRA needs more room |
| `InpCycleRawTgtATR` | 5.0 | 4.2 | LETRA overshoots targets |
| `InpTalonBaseATR` | 2.8 | 2.5 | |

**Why these:** the referee showed LETRA ~83% *directional* accuracy but only ~29%
*objective* accuracy (it overshoots) → wider stop + bigger target. Symphony tighter.

---

## 4. HOW TO FIND THE PERFECT SETTINGS (the method)

### A. Per-engine journal analysis (primary)
1. User runs each profile with `InpJournal=true` over a full period → CSV in
   `<MT5>/MQL5/Files/FALCON_Journal_<sym>_<tf>.csv`.
2. `python3 analyze_journal.py <csv>` — now prints **per engine** (parsed from the
   trade tag, e.g. `LETRA P3 Long`): win% · expectancy(R) · profit factor, threshold
   sweeps (`conf`, `execProb`, `ownerCtrl`, `htfAlign`, `completion`), P3-vs-P4 /
   dir / phase breakdown, and a **STOP/TARGET FIT** from MFE/MAE percentiles
   (→ ideal `CycleRawTgtATR` ≈ MFE p75; flags if the stop is clipping winners).
3. For each engine pick the lowest threshold where expectancy(R) stays solidly
   positive with meaningful trade count → set the matching input.

### B. MT5 Strategy Tester optimization (confirmatory)
`InpPreset=CUSTOM`, fix the engine, optimize a few high-leverage params:
`CycleRawTgtATR` (2.5–6.0/0.5) · `CycleRawStopATR` (0.8–1.8/0.2) · `MinRR` (2–5/0.5) ·
`TalonGiveback` (0.2–0.6/0.05) · `TalonBeATR` (0.6–1.6/0.2) · `MaxStacks` (1–3).
Run once per engine. Criterion: **Profit Factor** (not raw net). Use **forward
optimization** (e.g. 75/25) to avoid curve-fit.

### C. Live read
COMMAND tab (14) shows execution + self-learning + the 3-engine `dir acc%(N)` live.
Trust accuracy only once N ≥ ~20.

### Expectations / honesty
With `minRR=4`, both engines are **low win-rate / high-payoff** (~25–40% win, big
winners) — judge on **expectancy(R)**, not win%. Flag clearly if a profile has no
edge out-of-sample rather than over-fitting.

---

## 5. WORKING MECHANICS (how this repo operates)

- **Cannot compile here.** After every change do a static brace/paren balance check
  with awk (strip `//`): `awk '{l=$0;sub(/\/\/.*/,"",l);b+=gsub(/{/,"{",l)-gsub(/}/,"}",l);p+=gsub(/\(/,"(",l)-gsub(/\)/,")",l)} END{print b,p}' file`. Must be 0/0.
- **Rebuild the single file after EVERY change:** `./build_allinone.sh <version>`
  (bumps `#property version`; concatenates `FALCON_OS/**` per the ORDER list, strips
  per-file `#include`/`#property`). NOTE: `FalconState.mqh` must precede
  `FalconConfig.mqh` in the order (Config uses the `FALCON_ENGINE` enum).
- **Push** via the `kiro_powers` github power: action=use, serverName=github,
  toolName=push_to_remote, owner=`snxperfx1-dev`, repository_name=`combo`,
  path=`/projects/sandbox/combo`, remote_branch_name=`falcon-os-platform`. Run twice
  (commit races the push). Always give the user the raw link after.
- Default test: XAUUSD, M5, Visual mode (keyboard tab-switch doesn't work in tester →
  set `InpDashboardTab`).

### File map
- `FALCON_OS/Kernel/FalconConfig.mqh` — every input + `g_cfg` + `FalconApplyPreset`.
- `FALCON_OS/Kernel/FalconState.mqh` — all structs, enums (`FALCON_ENGINE`,
  `WaveCycle`, `WaveReferee`, `PH_*`, `CYC_*`), master `g_state`.
- `FALCON_OS/Engines/WaveCycleIntel.mqh` — LETRA & F16 cycle computes + referee.
- `FALCON_OS/Engines/SymphonyEngine.mqh` — Symphony cycle, entry resolver
  (`Sym_RawEntryEdges`), `PhaseAuthorityApply`, `Sym_PlaceEntry`, TALON (`TalonGrip`),
  ARC partial, `SymphonyManageExits`, `SymRawActive`.
- `FALCON_OS/Engines/ExecutionEngine.mqh` — orders, DD protection, EE trail (legacy).
- `FALCON_OS/Engines/ThermalRiskEngine.mqh` — PYRO.
- `FALCON_OS/Engines/Visualization.mqh` — tabs incl. ENGINES(13) + COMMAND(14).
- `analyze_journal.py` — per-engine journal analyzer (the tuning tool).
- `presets/FALCON_LETRA.set`, `presets/FALCON_SYMPHONY.set`.
- `docs/PORT_AUDIT.md` — what's ported (TIE + recursive curve tree now done).

---

## 6. DESIGN LAWS (do not violate)

- **Phases are OUTPUTS, never inputs to decisions.** Reasoning = concrete engines
  (phases, curve tree, ownership, curve locator, structure, true multi-TF). The old
  belief/hypothesis/prediction/threat/opportunity/story layer was REMOVED — don't
  reintroduce score-voting.
- Direction emerges from ownership, not voting. Per-campaign risk, never netted.
- Learning ranks/avoids/sizes but **cannot create edge**. Hard filters never overridable.
- Circuit breakers must be **timed**, never permanent deadlock. Keep "emotion"
  (recency/tilt) OUT of hard risk; self-awareness is off by default.
- Bounded learning: min samples, EWMA, clamps.
- Keep `InpUseSymphony=true` (execution host). Symphony being multi-campaign
  (long+short) is by design — `InpNoHedge` is the opt-in override.

---

## 7. QUICK STATE SNAPSHOT (v5.16)
Defaults ON: useSymphony, runAllCycles, refereeLearn, cycleFreeRun, cycleRawEntries,
useCurveTree, useTimeIntel, useCurveLocator, useTradePlan, fractalZones, useAdaptive,
useMissLearn, ddProtect, riskAutoClose, targetTP, journal.
Defaults OFF: useThermalRisk(PYRO), useTalon, useProfitLadder, counterDirBlock,
noHedge, requireConfluence, useSelfAware, timeGateEntries.
**Presets flip:** PYRO on, TALON on, noHedge on, riskAutoClose off, ladder off,
minRR 4, maxOpenPositions 2.
