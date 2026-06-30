# FALCON Intelligence Layers — Portable Spec (v1.0)

A reusable specification for the four intelligence layers built in FALCON OS,
written so they can be bolted onto **any** trading EA — not just FALCON.

They are deliberately **bounded, interpretable, online** systems (no black-box
ML). Each is independent; add only the ones you want. Order of value for a
typical algo: **Adaptive → Curve Locator → Regret → Self-Awareness (optional)**.

> **The one law that governs all of them:** learning can only *rank and avoid*
> outcomes — it cannot *create* an edge. If the host strategy has no edge, these
> layers make it lose more slowly; they do not make it win. Validate the base
> first.

---

## 0. The host contract (what your EA must provide)

Each layer needs only a small, generic interface from the host. If your EA can
do these five things, it can host all four layers:

| # | Host must provide | Used by |
|---|---|---|
| C1 | **Context key** at entry: a small set of *discrete* features → an integer bucket | Adaptive, Self-Awareness |
| C2 | **Entry event**: `(ticket, contextBucket, riskAtEntry$, predictedProb?)` on every fill | Adaptive, Self-Awareness |
| C3 | **Close detection + realised P&L**: detect a position left the book and read its profit (e.g. `HistorySelectByPosition`) | Adaptive, Self-Awareness |
| C4 | **Blocked-signal event**: when a valid signal is vetoed → `(dir, entry, stop, target, reasonCode)` | Regret |
| C5 | **Per-bar tick** + **file read/write** (persistence) | all |

**R-multiple convention** (used everywhere): `R = realisedProfit / riskAtEntry$`,
where `riskAtEntry$ = lots × |entry − stop| × contractValue`. A stop-out ≈ `−1R`.

**Persistence key convention** (so learning survives renames / restarts and
never collides between instances):
`FALCON_<layer>_<magic>_<symbol>_<timeframe>.csv` in the **Common** files folder.

---

## 1. Adaptive Edge Learning

**Purpose:** learn per-context expectancy from the EA's own closed trades; size
up contexts that pay, throttle/veto contexts that persistently lose.

### Context buckets
Keep them **low-dimensional** — over-bucketing = sample starvation = noise.
Recommended: 2 dimensions, ≤ ~10–12 buckets total. FALCON uses
`direction (L/S) × structural-band (5)` = 10. Any host substitutes its own
second dimension (regime, session, setup-type…).

### State (per bucket)
```
int    n;        // resolved trades
int    wins;
double ewmaR;    // recency-weighted expectancy (R/trade)
```

### Update on close
```
R = profit / riskAtEntry
ewmaR = (n==0) ? R : ewmaR + alpha*(R - ewmaR)     // alpha ~0.10
n++; if(R>0) wins++
```

### Outputs (consumed by the host's entry path)
```
SizeMult(bucket):
   if n < minN: return 1.0                         // not enough evidence
   return clamp(1 + K*ewmaR, floor, ceil)          // K~0.4, floor 0.3, ceil 1.6

Veto(bucket):
   if n < 2*minN: return false                     // veto needs a robust sample
   return ewmaR <= vetoR                           // vetoR ~ -0.30
```
Host: `lots *= SizeMult(bucket)`; block entry if `Veto(bucket)`.

### Also expose (feeds Self-Awareness)
`globalR` = EWMA of **every** closed trade's R (overall realised edge),
`winStreak`, `lossStreak`, and calibration sums (`Σ predictedProb`, `Σ wins`, `count`).

### Defaults
`minN=8, alpha=0.10, K=0.40, floor=0.30, ceil=1.60, vetoR=-0.30`.

---

## 2. Regret / Missed-Trade Learning (counterfactual)

**Purpose:** measure the *opportunity cost* of each filter. If a filter keeps
blocking trades that **would have won**, learn it's too strict and start taking
them. Keep filters that genuinely avoided losses.

### Mechanism — shadow (paper) book
When a valid signal is blocked by a **soft** filter, open a shadow trade with the
same composed stop/target, tagged with the **reason code**. Each bar, advance all
open shadows against price:
```
LONG : low<=stop  -> resolve -1R (filter saved a loser)
       high>=target-> resolve +(target-entry)/(entry-stop) R (filter cost a winner)
SHORT: mirror
age >= maxBars    -> expire (neutral, no learning)
```
Attribute the resolved R per reason (EWMA, same as Adaptive).

### State (per veto reason)
```
int n; int wins; double ewmaR;
```

### Output
```
Override(reasonCode):
   if reason is NOT soft-eligible: return false        // see safety
   if n < minN: return false
   if globalN >= minN AND globalR < 0: return false     // *** critical gate ***
   return ewmaR >= overrideR                            // overrideR ~ +0.30..0.60
```
Host: in the gate, for a soft filter, `if(!Override(code)) { recordMiss(); veto(); }`.

### Soft vs hard reasons (host classifies)
- **Override-eligible (soft / quality-timing):** "not at a zone", "no room",
  "too late in move", "minor opposing pressure".
- **Never overridable (hard / integrity):** "wrong side vs owner/HTF",
  "structure reversed", "already learned-avoided", "health stand-down",
  "risk-limit breach".

### Defaults
`minN=8, overrideR=+0.30, maxBars=120, alpha=0.10`.

> ⚠ **Hard-won bug (must implement the gate):** shadow fills assume perfect
> stop/target with no spread/slippage → they are **optimistic**. Without the
> `globalR < 0` gate, regret will override filters and pull losing trades back
> in *while the system is already losing*, fighting the adaptive vetoes. Only
> relax filters when the **real** edge is non-negative.

---

## 3. Self-Awareness / Metacognition  (OPTIONAL — read the caveat)

**Purpose:** model the EA's own form/calibration/health → one `selfConfidence`
and a global risk **throttle**, plus a circuit-breaker.

### Signals
```
calibration = 100 - |avgPredictedProb - actualWinRate|*100   (needs >=5 closes)
form        = f(winStreak, lossStreak, equitySlope, drawdownFromPeak)
regimeFit   = blend(best learned bucket edge here, higher-TF agreement)
health      = data sane AND not in drawdown halt AND not in loss-cluster cooldown
selfConfidence = 0.30*calibration + 0.35*form + 0.20*regimeFit + 0.15*health
```

### Throttle (size multiplier)
```
if !health:                       throttle = 0          (stand down)
else if conf >= fullConf:         throttle = 1.0         (FULL size in normal conditions)
else throttle = clamp(minThrottle + (1-minThrottle)*conf/fullConf, minThrottle, 1)
```
Host: `lots *= throttle`; block entry while `!health`.

### Circuit breaker — MUST be timed
```
on lossStreak >= lossHalt: start cooldown = haltBars
while cooldown>0: health=false; cooldown--
   on cooldown==0: reset lossStreak=0   // resume, fresh start
```

> ⚠ **Two hard-won bugs:**
> 1. **Deadlock** — a *permanent* loss-cluster stand-down blocks all trades, so it
>    can never win to reset the streak → frozen forever. Breakers **must be timed
>    and auto-recover.**
> 2. **Linear throttle haircut** — mapping `conf/100` straight to size shrinks
>    every trade even at normal confidence. Use the `fullConf` plateau above.
>
> ⚠ **Philosophical caveat:** this layer encodes *path-dependence on recent P&L*
> — i.e. **emotion** (cut size after losses, press after wins). For a
> positive-expectancy system that's often *harmful* (smallest right before the
> mean-reversion winner). Keep it **optional and default-off**, and keep your
> **hard risk limits separate from it** (limits are math, not mood).

### Defaults
`minThrottle=0.25, fullConf=50, lossHalt=6, haltBars=24`.

---

## 4. Curve Locator  ("you are here")

**Purpose:** an always-on, continuous coordinate of where price sits between a
curve's origin and destination — never undefined. Gives a clean "how much move
is left" gate and a "late in move" veto. Portable to any algo that can define a
**target/destination** and an **invalidation/origin** for the move it's trading
(ideally per timeframe).

### Per-TF position
```
pos(tf) = clamp( (price - origin(tf)) / (destination(tf) - origin(tf)), 0, 1.2 )
          // self-normalises for long & short; -1 if origin==destination (undefined)
```

### Master location — cascade + graceful degradation
```
ownerTF = highest TF currently "in control" (host provides, or use highest valid)
pos = pos(ownerTF); cascade UP then DOWN the TF ladder for the first defined leg
if none defined: keep last-good pos, DECAY confidence  (never snap to zero)
vel = EWMA(pos - prevPos)            // advancing toward destination if >0
conf = f(ownerTF validity, TF agreement)
```

### Output
- `pos` (0..1), `dir`, `vel`, `conf`, label (Early/Dev/Mid/Late/Terminal).
- Gate: **block entry when `pos >= maxOwnerLegPos`** (≈0.80) — no move left.

> Key property: anchored to the *owner* timeframe and degrades gracefully, so the
> system **never loses its place** between impulses.

---

## 5. Integration order (per bar)

```
1. host updates market/structure (+ per-TF curves if using the Locator)
2. CurveLocator.update()            // where are we
3. host forms signal / decision
4. ENTRY gate, in this order:
      direction & hard filters (host)         -> veto (never overridable)
      soft filters: if !Regret.override(code) -> recordMiss + veto
      CurveLocator late-gate                  -> veto
      Adaptive.veto(bucket)                   -> veto
      SelfAware.standDown()                   -> veto (if enabled)
   on pass: lots = baseLots
            * Adaptive.sizeMult(bucket)
            * SelfAware.throttle()            // 1.0 if disabled
   on fill: Adaptive.recordEntry(...);  (Regret/Self read the same close stream)
5. host manages/Exits
6. on close (detected via history): Adaptive.learn(); feed Self-Aware + globalR;
   Regret.onBar() resolves shadows
7. persist every N bars + on deinit
```

---

## 6. Safety laws (non-negotiable — these are why it doesn't blow up)

1. **Min sample before acting** (veto/override need 2× the sizing sample).
2. **Clamp every multiplier** — learning can tune size, never explode it.
3. **EWMA, not raw mean** — tracks regime change; one old streak can't poison it.
4. **Hard filters are never overridable** — direction integrity, structure,
   risk limits, health. Learning sits *on top of* safety, never replaces it.
5. **Regret override gated by real edge** — never relax filters while `globalR<0`.
6. **Circuit breakers are timed, never permanent** — they must auto-recover.
7. **Self-awareness is optional and separate from risk limits** — it's emotion;
   limits are math.
8. **Persist by instance identity** (`magic_symbol_tf`), not by EA name.
9. **Everything is visible** — expose every learned number on a dashboard/log;
   if you can't audit it, don't trust it.

---

## 7. Reference implementation

See the FALCON OS modules (drop-in MQL5, each ~one file):
`Engines/Adaptive.mqh`, `Engines/MissTrade.mqh`, `Engines/SelfAwareness.mqh`,
`Engines/CurveLocator.mqh`. Each reads `g_state`/`g_cfg` and the shared series
helpers; to port, replace those reads with your host's equivalents per the
contract in §0.
