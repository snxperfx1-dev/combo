# FALCON OS — Port Audit (originals vs current build, v4.57)

Audit of the three source systems against what is now in `FALCON_OS/`.

**Important:** the originals are different languages/types —
- **LETRA 37** (`LETRA 37.txt`) — *Pine Script v6 indicator* (~6,200 lines)
- **F16 V70** (`F16 V70.txt`) — *Pine Script v6 indicator* (~2,670 lines) = LETRA + network/Senseei
- **Symphony** (`symphony.txt`) — *MQL5 EA* v1.6 (DRDWCT) (~1,755 lines)

So LETRA/F16 were **logic ports** (Pine → MQL5); Symphony was a **direct port**.

Legend: ✅ ported · 🟡 partial/simplified · ❌ missing · ⛔ removed by design (your decision)

---

## A. SYMPHONY (MQL5 EA → SymphonyEngine + Execution + MoneyManager)

| Original | Status | Where in FALCON |
|---|---|---|
| Series / ATR / pivots (`RefreshSeries`,`GetATR`,`IsPivotHigh/Low`) | ✅ | `FalconSeries.mqh` |
| `UpdatePhaseEngine` (impulse + Phase 1–4) | ✅ | `SymphonyEngine.SymphonyUpdatePhases` |
| `UpdateARC` (convexity arc target) | ✅ | `sym_arc*` + `Sym_DestLong/Short` |
| `ComputeLots` (XAUUSD contract model) | ✅ | `Sym_ComputeLots` |
| `IsTradeTime` (session windows) | ✅ | `EE_IsTradeTime` |
| `SendMarketOrder` / `ClosePartial` / `CloseFull` | ✅ | `EE_SendMarketOrder` / `EE_ClosePartial` / `EE_CloseFull` |
| `ExecuteTrading` (P3/P4 entries, anchor±0.25ATR stop) | ✅ | `SymphonyExecuteTrading` (+ edge-trigger, lockout) |
| `ManageArcInstitutionalExits` | ✅ | `SymphonyManageExits` |
| **DRDWCT / VaR / Gamma / SAG / RD / micro-bomb / trim cascade** (`RE_*`, ~600 lines) | ⛔ | **Removed at your request.** Replaced by PYRO thermal (optional, off) + the v3.0 money manager (counter-dir lock / basket ceiling / profit ladder). |

> Note: `symphony.txt` here is the **v1.6 DRDWCT** build. The **v3.0** money
> management (counter-direction lock, basket ceiling, live-PnL ladder) that is
> now FALCON's default came from a later Symphony and is fully ported in
> `MoneyManager.mqh`.

**Symphony verdict:** core engine 100% ported; the old DRDWCT risk stack removed by design.

---

## B. LETRA 37 (Pine indicator → Market / Intelligence / Visualization)

| Original section / engine | Status | Where / note |
|---|---|---|
| S2 Core Physics Engine | ✅ | `MarketEngine` physics |
| S3 HTF Belief Engine | 🟡 | HTF stack ported; the "belief" scoring ⛔ removed |
| S4 Market Structure | ✅ | `MarketEngine` structure (BOS/CHoCH/swings) |
| **Fixed-Timeframe Structure Engine** (per-TF `request.security`) | ✅ | **This is now "true multi-TF":** per-TF curve engine `ME_TFCurve` + per-TF zones `ME_TFZones` on W1→M1 |
| S5 Max Pivot Memory · S6 Impulse · S7 Inducement/Flipzone | ✅ | pivots + impulse in phase engine; inducement in `ME_UpdateInducement` + Symphony zone |
| S8 Wave Context · ENGINE 1A (wave lifecycle/phase) | ✅ | Symphony phase → `g_state.wave` bridge (single phase authority) |
| **ERF — Energy Resolution Framework (EDE / RE / EAE)** | ⛔ | **Removed at your request** |
| S10 Liquidity Heatmap Engine | ✅ | `MarketEngine` liquidity (+ per-TF pools/sweeps) |
| S11 Geometry Engine | ✅ | `Convexity` (geometryCapacity / convexityWidth / curvatureRadius) |
| 12-POS Geometric Wave Position | ✅ → upgraded | replaced by the **Curve Locator** (continuous, multi-TF, persistent) |
| 12-CM Convexity Maturity | ✅ | `convexity.maturity` |
| 12A Belief · 12D Hypothesis · 12E Prediction · 12F Validation | ⛔ | **Removed at your request** |
| 12G Adaptive Confidence · 12H Wave Deviation · 12I M1 Early Warning | ❌ | not ported (M1 context now exists via the M1 ladder rung, but no dedicated early-warning) |
| S13 Wave Spawn Engine | ✅ | per-TF curve spawn inside `ME_TFCurve` |
| S14 Induction Zone Classification | 🟡 | inducement zones ported; fine-grained induction *classification* simplified |
| S15 Scoring Engine · S16 Bayesian Probabilistic Model | ⛔ / ❌ | scoring removed with beliefs; Bayesian model not ported |
| S17/18 Future Return Zone Engine (FRZ) | ✅ | `MemoryEngine.MEM_ComputeFRZ` (owner-driven destination) |
| S18 Slippage & Trade Opportunity Engine | 🟡 | opportunity ⛔ removed; **slippage not modeled** |
| S19 HTF Alignment Gate | ✅ | fact-gate HTF permission |
| S20 Adaptive Execution Lock · S21 Entry Signals | ✅ | re-entry lockout + Symphony entries + fact gate |
| S24 Trade State Engine | ✅ | `exec.tradeState` |
| Structural Destination Engine V2 (ODDE) | ✅ | `TradePlan` owner-driven escalating target |
| S25 Dashboards A/B/C/P3/FU · S26 Display Intelligence Engine | ✅ replaced | unified 13-tab `Visualization` |

---

## C. F16 V70 (Pine indicator = LETRA + network/Senseei)

| Original engine | Status | Where / note |
|---|---|---|
| PART A — **Invisible Network Engine** (nodes/authority/dormancy/revisits) | ✅ | `MemoryEngine` network |
| Conversation Web / graph (edges, conversation weight) | ✅ | `network.edge*` / `conversationWeight` |
| Network bias · pressure · path · magnet · **next authoritative node** | ✅ | `network.bias/pressureDir/nextNodePrice` (feeds TradePlan target) |
| PART B — LETRA engine exact port | ✅ | (see section B) |
| Per-rung **Curve family** `c_r1..c_r6` (curves inside curves) | ✅ | per-TF `g_tfCurve[7]` (W1→M1) |
| **F72 Recursive Curve Tree** (event-generated `CurveNode` array, budget depth, parent/child) | 🟡 | simplified: `curve.root/parent/emergentNodes/childCount` derived from the per-TF rungs — **not** the full event-driven recursive node array with compression-budget depth |
| Engine 1A.7 — Pre-Objective **Liquidation Wave** | ✅ | `IE_LiquidationWave` (kept) |
| **ENGINE 8.0 — Time Intelligence Engine (TIE)** (5-cycle temporal stack, path/time probabilities) | ❌ | **NOT ported** — FALCON has only a basic session window (`EE_IsTradeTime`). Biggest genuine gap. |
| Senseei / Chief Strategist (meta verdict) | 🟡 | `DecisionEngine` (Senseei/Chief/CampaignAI/MasterChief) — simplified, now **concrete-reasoning** (beliefs removed) |
| Opportunity Engine / dual co-pilot | ⛔ | opportunity removed with the belief layer |
| Verdict Engine (8 actions) | ✅ | `DecisionEngine` → BUY/SELL/WAIT/ATTACK/DEFEND/EXIT/SCALE/NO-TRADE |
| F72 **Campaign Ownership + Participant Engine** | ✅ | `MemoryEngine` campaign + participants |
| FEZ corridor / Future Engagement Zone | ✅ | `state.fez` |
| Flight HUD | ✅ replaced | `Visualization` HUD overlay |

---

## D. What's genuinely MISSING (not by-design removals)

These were in the originals, are **not** deliberate removals, and could be ported:

1. **Time Intelligence Engine (TIE)** — F16 ENGINE 8.0. The 5-cycle temporal / session-probability stack. FALCON only has a binary session filter. *(biggest gap)*
2. **Full recursive Curve Tree** — F16 F72 event-driven `CurveNode` array with compression-budget depth. FALCON has a simplified per-rung tree. *(the spec's "curve tree" is only partially realised)*
3. **M1 Early-Warning Engine** — LETRA 12I. (Mitigated: M1 now exists as a ladder rung, but no dedicated early-warning trigger.)
4. **Induction-zone fine classification** — LETRA S14 (zones ported, sub-types simplified).
5. **Slippage / trade-opportunity modelling** — LETRA S18 (not modelled).

## E. Removed BY DESIGN (your decisions — listed for completeness)

- **DRDWCT / VaR / Gamma / SAG trim cascade** (Symphony) → replaced by PYRO + money manager.
- **Energy Resolution Framework (EDE/RE/EAE)** (LETRA/F16).
- **Belief · Hypothesis · Prediction · Validation · Threat · Opportunity · Intent · Story** (LETRA/F16) → reasoning is now the concrete engines.
- **Bayesian probabilistic model / scoring engine** (LETRA).

## F. NEW in FALCON (not in any original)

- Single shared state + event bus + deterministic kernel pipeline.
- **Curve Locator** (continuous, persistent, multi-TF "you are here").
- **Per-TF zones** on all 7 absolute timeframes.
- **Subsystem-composed Trade Plan** (each engine owns a field).
- **Learning stack** — Adaptive edge, Regret/missed-trade, Self-Awareness (optional).
- **Trade journal CSV + analyzer**, unified diagnostics, persistence.

---

## Summary

- **Symphony:** fully ported (minus DRDWCT, removed by design).
- **LETRA:** market/structure/liquidity/geometry/wave/FRZ/inducement **ported**; the
  per-TF structure engine became *true multi-TF*; belief/energy/scoring **removed by design**.
- **F16:** invisible network / campaign / participants / curve family / verdict **ported**;
  **TIE** and the **full recursive curve tree** are the two real gaps; Senseei simplified to concrete reasoning.

**Net real gaps to consider:** (1) Time Intelligence Engine, (2) full recursive curve-tree node engine. Everything else is either ported or removed by deliberate decision.
