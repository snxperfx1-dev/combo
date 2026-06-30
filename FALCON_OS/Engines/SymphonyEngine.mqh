//+------------------------------------------------------------------+
//|  FALCON OS — Execution Layer : SymphonyEngine.mqh               |
//|  Source: Symphony (Phase Engine + Phase 3/4 Entries + ARC/Inst) |
//|                                                                  |
//|  This is the PRECISION ENTRY/EXIT AUTHORITY.                     |
//|                                                                  |
//|  The user's Symphony EA had the most precise entries and stop    |
//|  placement, so its proven curvature/retracement Phase Engine is  |
//|  ported here verbatim (adapted to FALCON's shared series + ATR + |
//|  pivot helpers) and made the primary order logic when            |
//|  g_cfg.useSymphony is true.                                      |
//|                                                                  |
//|    • Impulse + Phases 1..4 (retracement-fraction model)          |
//|    • Entries: Phase 3 + Phase 4 only (long & short)              |
//|    • Stops:  anchorLow/High ± atr*0.25  (Symphony placement)     |
//|    • Lots:   riskCash / (dist * contractValue), capped maxLots   |
//|    • Exits:  ARC exhaust + institutional outer-band sweep +      |
//|              phase-change composite                              |
//|                                                                  |
//|  This module REUSES the Execution Engine order helpers           |
//|  (EE_SendMarketOrder / EE_CloseFull / EE_IsTradeTime) so it must |
//|  be included AFTER ExecutionEngine.mqh. It does NOT port         |
//|  Symphony's DRDWCT risk engine (removed at user request).        |
//+------------------------------------------------------------------+
#ifndef FALCON_SYMPHONY_ENGINE_MQH
#define FALCON_SYMPHONY_ENGINE_MQH

#include "../Kernel/FalconState.mqh"
#include "../Kernel/FalconConfig.mqh"
#include "../Kernel/FalconSeries.mqh"
#include "../Kernel/FalconEventBus.mqh"
#include "../Kernel/FalconLog.mqh"

//==================================================================
// MODULE STATE — Symphony phase engine (one instance, shared)
//==================================================================
// Pivot history
double   sym_lastPivotPrice = 0.0;
int      sym_lastPivotShift = -1;
int      sym_lastPivotDir   = 0;   // 1 = high, -1 = low, 0 = none
double   sym_prevPivotPrice = 0.0;
int      sym_prevPivotShift = -1;
int      sym_prevPivotDir   = 0;

// Impulse / mode
int      sym_mode           = 0;   // -1 short, 1 long, 0 none
double   sym_anchorHigh      = 0.0;
double   sym_anchorLow       = 0.0;
int      sym_anchorHighShift = -1;
int      sym_anchorLowShift  = -1;

// Phases
int      sym_phaseShort      = 0;
int      sym_phaseLong       = 0;
int      sym_prevPhaseShort  = 0;
int      sym_prevPhaseLong   = 0;

// Flipzone / inducement
double   sym_shortInducPrice = 0.0;
double   sym_shortInducLow   = 0.0;
double   sym_shortInducHigh  = 0.0;
double   sym_longInducPrice  = 0.0;
double   sym_longInducLow    = 0.0;
double   sym_longInducHigh   = 0.0;

// Pre-Conv seen flags (per impulse)
bool     sym_shortPreConvSeen = false;
bool     sym_longPreConvSeen  = false;

// ARC v2 state
double   sym_arcLong  = 0.0;
double   sym_arcShort = 0.0;

// Institutional outer-band sweep flags
bool     sym_longOuterBreachSeen  = false;
bool     sym_shortOuterBreachSeen = false;

// One trade per direction per bar
datetime sym_lastLongTradeTime  = 0;
datetime sym_lastShortTradeTime = 0;

// Bridge: previous canonical phase published into g_state.wave (for prevPhase)
int      sym_bridgePrevPhase    = PH_TRANSITION;

// TALON grip — campaign-level structural trailing anchors + breakeven flags
double   talon_anchorLong  = 0.0;   // ratcheting higher-low the long grip rides
double   talon_anchorShort = 0.0;   // ratcheting lower-high the short grip rides
bool     talon_beLong  = false;     // long campaign breakeven earned
bool     talon_beShort = false;     // short campaign breakeven earned
double   talon_peakLong  = 0.0;     // peak favorable excursion (ATR) — long campaign
double   talon_peakShort = 0.0;     // peak favorable excursion (ATR) — short campaign

// Re-entry lockout — once a campaign for the CURRENT impulse has been closed
// (by trail-stop or composite exit), block re-entry in that direction until a
// FRESH impulse forms. Stops the "exit then immediately re-enter the same leg"
// churn. Reset to 0 whenever a new impulse is created (new anchor = new campaign).
double   sym_exitedLongAnchor  = 0.0;   // nonzero => long re-entry locked for this impulse
double   sym_exitedShortAnchor = 0.0;   // nonzero => short re-entry locked for this impulse
bool     sym_longCampaignOpen  = false; // a long  campaign is currently open
bool     sym_shortCampaignOpen = false; // a short campaign is currently open

//==================================================================
// INIT — reset all Symphony phase state
//==================================================================
void SymphonyInit()
{
   sym_lastPivotPrice = 0.0; sym_lastPivotShift = -1; sym_lastPivotDir = 0;
   sym_prevPivotPrice = 0.0; sym_prevPivotShift = -1; sym_prevPivotDir = 0;

   sym_mode = 0;
   sym_anchorHigh = 0.0; sym_anchorLow = 0.0;
   sym_anchorHighShift = -1; sym_anchorLowShift = -1;

   sym_phaseShort = 0; sym_phaseLong = 0;
   sym_prevPhaseShort = 0; sym_prevPhaseLong = 0;

   sym_shortInducPrice = 0.0; sym_shortInducLow = 0.0; sym_shortInducHigh = 0.0;
   sym_longInducPrice  = 0.0; sym_longInducLow  = 0.0; sym_longInducHigh  = 0.0;

   sym_shortPreConvSeen = false; sym_longPreConvSeen = false;

   sym_arcLong = 0.0; sym_arcShort = 0.0;
   sym_longOuterBreachSeen = false; sym_shortOuterBreachSeen = false;

   sym_lastLongTradeTime = 0; sym_lastShortTradeTime = 0;
   sym_bridgePrevPhase   = PH_TRANSITION;
   talon_anchorLong = 0.0; talon_anchorShort = 0.0;
   talon_beLong = false;   talon_beShort = false;
   sym_exitedLongAnchor = 0.0; sym_exitedShortAnchor = 0.0;
   sym_longCampaignOpen = false; sym_shortCampaignOpen = false;
}

//==================================================================
// LOT ENGINE — Symphony contract-value model
//   riskPerLot = dist * contractValue   (XAUUSD: dist*100 == $1850 for 18.5)
//   capped by broker limits + g_cfg.maxLots safety cap.
//==================================================================
double Sym_ComputeLots(const double riskCash,const double entry,const double sl)
{
   double dist = MathAbs(entry - sl);
   if(dist <= 0.0) return(0.0);

   double riskPerLot = dist * g_cfg.contractValue;
   if(riskPerLot <= 0.0) return(0.0);

   double lots = riskCash / riskPerLot;

   double minLot  = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(lotStep<=0) lotStep=0.01;
   if(minLot<=0)  minLot=0.01;

   lots = MathFloor(lots/lotStep)*lotStep;
   if(lots < minLot) lots = minLot;
   if(maxLot>0 && lots>maxLot) lots = maxLot;
   if(g_cfg.maxLots>0 && lots>g_cfg.maxLots) lots = g_cfg.maxLots;   // hard safety cap

   int volDigits=(lotStep>=1.0?0:lotStep>=0.1?1:2);
   return(NormalizeDouble(lots,volDigits));
}

//==================================================================
// LOT SIZING PIPELINE — base risk%% size, optional PYRO thermal admission,
// then the v3.0 pre-entry basket ceiling (hard per-direction risk cap).
//==================================================================
double Sym_SizeLots(const int dir,const double riskCash,const double entry,const double sl)
{
   double lots = Sym_ComputeLots(riskCash,entry,sl);
   if(g_cfg.useThermalRisk) lots = TR_AdmitLots(dir, lots);
   lots = MM_AdjustLotsForBasketCeiling(dir, entry, sl, lots);
   return(lots);
}

//==================================================================
// BRIDGE — SYMPHONY IS THE SINGLE PHASE/DIRECTION SOURCE OF TRUTH
//------------------------------------------------------------------
// The Market Engine still OBSERVES geometry/physics (sub-scores, energy,
// recursion, cycle extremes) — those are descriptors, not a phase engine.
// But the PHASE ENGINE itself must exist exactly once. This bridge maps
// Symphony's impulse + Phase 1..4 model onto the canonical FalconWave schema
// (phase / direction / flip zone / origin / extreme / objective / completion /
// dominanceTransfer) so EVERY downstream subsystem reasons on the SAME engine
// Symphony trades:
//   • Memory     — campaign OWNERSHIP flips with Symphony (phase 3 = return).
//   • Intelligence — energy/belief/forecast/entry-cycle read Symphony phases.
//   • Decision   — master DIRECTION = Symphony mode (via campaign owner).
//   • Execution  — stops/targets/exit phase-logic read Symphony flip/origin.
//   • Visualization — every tab shows Symphony's phase truth.
// No second phase truth survives downstream.
//
// PHASE MAP (direction-aware):
//   mode 0 / phase 0 -> PH_TRANSITION
//   phase 1 (early impulse)        -> PH_EXPANSION
//   phase 2 (retracing)            -> PH_RETRACEMENT
//   phase 3 (return into zone)     -> PH_DEMAND_RETURN (long) / PH_SUPPLY_RETURN (short)
//   phase 4 (breakout/new extreme) -> PH_NEW_HIGH (long) / PH_NEW_LOW (short)
//==================================================================
void SymphonyBridgeToWave()
{
   FalconWave w = g_state.wave;   // preserve Market-Engine geometry descriptors

   int dir = (sym_mode==1 ? DIR_LONG : sym_mode==-1 ? DIR_SHORT : DIR_NONE);
   int p   = (dir==DIR_LONG ? sym_phaseLong : dir==DIR_SHORT ? sym_phaseShort : 0);

   int ph;
   if(dir==DIR_NONE || p<=0) ph = PH_TRANSITION;
   else if(p==1)             ph = PH_EXPANSION;
   else if(p==2)             ph = PH_RETRACEMENT;
   else if(p==3)             ph = (dir==DIR_LONG ? PH_DEMAND_RETURN : PH_SUPPLY_RETURN);
   else /* p==4 */           ph = (dir==DIR_LONG ? PH_NEW_HIGH      : PH_NEW_LOW);

   // completion derived from the phase ladder (single, consistent mapping)
   double comp = (p<=0?5.0 : p==1?25.0 : p==2?45.0 : p==3?70.0 : 92.0);

   // flip zone / anchors — inducement zone tightens the band when present
   double aHi = sym_anchorHigh, aLo = sym_anchorLow;
   double flipTop = (aHi!=0.0 ? aHi : w.flipTop);
   double flipBot = (aLo!=0.0 ? aLo : w.flipBot);
   if(dir==DIR_LONG && (sym_longInducLow!=0.0 || sym_longInducHigh!=0.0))
   { flipBot = sym_longInducLow; flipTop = sym_longInducHigh; }
   if(dir==DIR_SHORT && (sym_shortInducLow!=0.0 || sym_shortInducHigh!=0.0))
   { flipBot = sym_shortInducLow; flipTop = sym_shortInducHigh; }

   double origin   = (dir==DIR_LONG ? aLo : dir==DIR_SHORT ? aHi : w.origin);
   double extreme  = (dir==DIR_LONG ? aHi : dir==DIR_SHORT ? aLo : w.extreme);
   double objective= (dir==DIR_LONG  && sym_arcLong >0.0 ? sym_arcLong
                     : dir==DIR_SHORT && sym_arcShort>0.0 ? sym_arcShort : w.objective);

   // dominanceTransfer drives the campaign OWNERSHIP flip — keyed to Symphony so
   // ownership/direction flips exactly when Symphony enters the return (phase 3).
   double dom = (p>=3 ? 60.0 : p==2 ? 30.0 : 0.0);

   // ---- commit the canonical phase-engine fields (override ME FSM result) ----
   w.prevPhase         = sym_bridgePrevPhase;
   w.phase             = ph;
   w.direction         = dir;
   w.flipTop           = flipTop;
   w.flipBot           = flipBot;
   w.origin            = origin;
   w.extreme           = extreme;
   w.objective         = objective;
   w.completion        = comp;
   w.dominanceTransfer = dom;

   // display mirror
   w.symMode       = sym_mode;
   w.symPhaseLong  = sym_phaseLong;
   w.symPhaseShort = sym_phaseShort;

   g_state.wave = w;

   if(ph != sym_bridgePrevPhase) FalconPublish(EVT_PHASE_CHANGE, ph, FalconPhaseStr(ph));
   sym_bridgePrevPhase = ph;
}

//==================================================================
// PHASE ENGINE — IMPULSE + PHASES (1..4)   [ported from Symphony]
//   Uses FALCON shared series (gClose/gHigh/gLow, shift 1 = last
//   closed bar), FalconATR and FalconIsPivotHigh/Low. Config from
//   g_cfg (pivotLen / impulseAtrMult / retrMin / retrMax /
//   inducLookback / inducZoneWidth).
//==================================================================
void SymphonyComputePhases()
{
   int barsAvail = FalconBars();
   int pivotLen  = g_cfg.pivotLen;
   if(barsAvail <= (2*pivotLen + 5)) return;

   int    shiftNow = 1;
   double closeNow = gClose[shiftNow];
   double atrRef   = FalconATR(shiftNow);
   if(atrRef<=0.0) atrRef = FalconATR(0);

   int    centerShift = pivotLen + 1;
   int    pivotDir    = 0;
   double pivotPrice  = 0.0;
   int    pivotShift  = -1;

   if(centerShift < barsAvail - pivotLen)
   {
      if(FalconIsPivotHigh(centerShift,pivotLen))
      {
         pivotDir   = 1;
         pivotPrice = gHigh[centerShift];
         pivotShift = centerShift;
      }
      else if(FalconIsPivotLow(centerShift,pivotLen))
      {
         pivotDir   = -1;
         pivotPrice = gLow[centerShift];
         pivotShift = centerShift;
      }
   }

   // SHORT impulse: last high -> new low
   if(pivotDir == -1 && sym_lastPivotDir == 1)
   {
      double r = sym_lastPivotPrice - pivotPrice;
      if(r > atrRef * g_cfg.impulseAtrMult)
      {
         sym_mode            = -1;
         sym_anchorHigh      = sym_lastPivotPrice;
         sym_anchorHighShift = sym_lastPivotShift;
         sym_anchorLow       = pivotPrice;
         sym_anchorLowShift  = pivotShift;

         sym_phaseShort      = 1;
         sym_phaseLong       = 0;
         // fresh short impulse => new campaign allowed (clear short re-entry lock)
         sym_exitedShortAnchor = 0.0; sym_shortCampaignOpen = false;

         sym_shortPreConvSeen = false;
         sym_longPreConvSeen  = false;

         sym_shortInducPrice = 0.0; sym_shortInducLow = 0.0; sym_shortInducHigh = 0.0;
         sym_longInducPrice  = 0.0; sym_longInducLow  = 0.0; sym_longInducHigh  = 0.0;

         sym_longOuterBreachSeen  = false;
         sym_shortOuterBreachSeen = false;

         double lvlS = 0.0;
         int    bestDistS = -1;
         if(sym_anchorHighShift > 0)
         {
            for(int s = sym_anchorHighShift - 1;
                s >= 0 && s >= sym_anchorHighShift - g_cfg.inducLookback;
                s--)
            {
               bool inside = (gHigh[s] < sym_anchorHigh && gLow[s] > sym_anchorLow);
               if(inside)
               {
                  int dist = (int)MathAbs(sym_anchorHighShift - s);
                  if(bestDistS < 0 || dist < bestDistS)
                  {
                     bestDistS = dist;
                     lvlS      = (gHigh[s] + gLow[s]) * 0.5;
                  }
               }
            }
         }
         if(bestDistS >= 0)
         {
            sym_shortInducPrice = lvlS;
            sym_shortInducLow   = lvlS - atrRef * g_cfg.inducZoneWidth;
            sym_shortInducHigh  = lvlS + atrRef * g_cfg.inducZoneWidth;
         }
      }
   }
   // LONG impulse: last low -> new high
   else if(pivotDir == 1 && sym_lastPivotDir == -1)
   {
      double r = pivotPrice - sym_lastPivotPrice;
      if(r > atrRef * g_cfg.impulseAtrMult)
      {
         sym_mode            = 1;
         sym_anchorLow       = sym_lastPivotPrice;
         sym_anchorLowShift  = sym_lastPivotShift;
         sym_anchorHigh      = pivotPrice;
         sym_anchorHighShift = pivotShift;

         sym_phaseLong       = 1;
         sym_phaseShort      = 0;
         // fresh long impulse => new campaign allowed (clear long re-entry lock)
         sym_exitedLongAnchor = 0.0; sym_longCampaignOpen = false;

         sym_shortPreConvSeen = false;
         sym_longPreConvSeen  = false;

         sym_shortInducPrice = 0.0; sym_shortInducLow = 0.0; sym_shortInducHigh = 0.0;
         sym_longInducPrice  = 0.0; sym_longInducLow  = 0.0; sym_longInducHigh  = 0.0;

         sym_longOuterBreachSeen  = false;
         sym_shortOuterBreachSeen = false;

         double lvlL = 0.0;
         int    bestDistL = -1;
         if(sym_anchorLowShift > 0)
         {
            for(int s = sym_anchorLowShift - 1;
                s >= 0 && s >= sym_anchorLowShift - g_cfg.inducLookback;
                s--)
            {
               bool inside = (gHigh[s] < sym_anchorHigh && gLow[s] > sym_anchorLow);
               if(inside)
               {
                  int dist = (int)MathAbs(sym_anchorLowShift - s);
                  if(bestDistL < 0 || dist < bestDistL)
                  {
                     bestDistL = dist;
                     lvlL      = (gHigh[s] + gLow[s]) * 0.5;
                  }
               }
            }
         }
         if(bestDistL >= 0)
         {
            sym_longInducPrice = lvlL;
            sym_longInducLow   = lvlL - atrRef * g_cfg.inducZoneWidth;
            sym_longInducHigh  = lvlL + atrRef * g_cfg.inducZoneWidth;
         }
      }
   }

   // Persist pivot history
   if(pivotDir != 0)
   {
      sym_prevPivotPrice = sym_lastPivotPrice;
      sym_prevPivotShift = sym_lastPivotShift;
      sym_prevPivotDir   = sym_lastPivotDir;

      sym_lastPivotPrice = pivotPrice;
      sym_lastPivotShift = pivotShift;
      sym_lastPivotDir   = pivotDir;
   }

   // Impulse invalidation
   if(sym_mode == -1 && closeNow > sym_anchorHigh)
   {
      sym_mode = 0; sym_phaseShort = 0;
      sym_shortInducPrice = 0.0; sym_shortInducLow = 0.0; sym_shortInducHigh = 0.0;
      sym_shortPreConvSeen = false; sym_longPreConvSeen = false;
      sym_longOuterBreachSeen = false; sym_shortOuterBreachSeen = false;
   }
   if(sym_mode == 1 && closeNow < sym_anchorLow)
   {
      sym_mode = 0; sym_phaseLong = 0;
      sym_longInducPrice = 0.0; sym_longInducLow = 0.0; sym_longInducHigh = 0.0;
      sym_shortPreConvSeen = false; sym_longPreConvSeen = false;
      sym_longOuterBreachSeen = false; sym_shortOuterBreachSeen = false;
   }

   int oldPhaseShort = sym_phaseShort;
   int oldPhaseLong  = sym_phaseLong;

   // SHORT side
   if(sym_mode != -1) sym_phaseShort = 0;
   if(sym_mode == -1 && sym_anchorHighShift >= 0 && sym_anchorLowShift >= 0)
   {
      double impS  = sym_anchorHigh - sym_anchorLow;
      double retrS = (impS > 0.0) ? (closeNow - sym_anchorLow) / impS : 0.0;
      double dS    = gClose[shiftNow] - gClose[shiftNow+1];

      int phaseTmpS;
      // BREAKOUT FIRST: a close at/below the impulse low is a new low (phase 4),
      // NOT an invalidation. (Previously retrS<0 pre-empted this, so P4 never fired.)
      if(closeNow <= sym_anchorLow)
         phaseTmpS = 4;
      else if(retrS > g_cfg.retrMax)   // retraced too far back UP toward the high = failed short
         phaseTmpS = 0;
      else if(retrS >= g_cfg.retrMin)
         phaseTmpS = (dS > 0.0 ? 2 : 3);
      else
         phaseTmpS = 1;

      bool hasShortZone = (sym_shortInducLow != 0.0 || sym_shortInducHigh != 0.0);
      if(phaseTmpS == 3 && hasShortZone && closeNow <= sym_shortInducHigh)
         phaseTmpS = 2;
      else if(phaseTmpS == 3)
         sym_shortPreConvSeen = true;

      if(phaseTmpS == 4 && !sym_shortPreConvSeen)
         phaseTmpS = 2;

      sym_phaseShort = phaseTmpS;
   }

   // LONG side
   if(sym_mode != 1) sym_phaseLong = 0;
   if(sym_mode == 1 && sym_anchorHighShift >= 0 && sym_anchorLowShift >= 0)
   {
      double impL  = sym_anchorHigh - sym_anchorLow;
      double retrL = (impL > 0.0) ? (sym_anchorHigh - closeNow) / impL : 0.0;
      double dL    = gClose[shiftNow] - gClose[shiftNow+1];

      int phaseTmpL;
      // BREAKOUT FIRST: a close at/above the impulse high is a new high (phase 4),
      // NOT an invalidation. (Previously retrL<0 pre-empted this, so P4 never fired.)
      if(closeNow >= sym_anchorHigh)
         phaseTmpL = 4;
      else if(retrL > g_cfg.retrMax)   // retraced too far back DOWN toward the low = failed long
         phaseTmpL = 0;
      else if(retrL >= g_cfg.retrMin)
         phaseTmpL = (dL < 0.0 ? 2 : 3);
      else
         phaseTmpL = 1;

      bool hasLongZone = (sym_longInducLow != 0.0 || sym_longInducHigh != 0.0);
      if(phaseTmpL == 3 && hasLongZone && closeNow >= sym_longInducLow)
         phaseTmpL = 2;
      else if(phaseTmpL == 3)
         sym_longPreConvSeen = true;

      if(phaseTmpL == 4 && !sym_longPreConvSeen)
         phaseTmpL = 2;

      sym_phaseLong = phaseTmpL;
   }

   sym_prevPhaseShort = oldPhaseShort;
   sym_prevPhaseLong  = oldPhaseLong;

   // ---- ARC v2 (convexity arc) ----
   sym_arcLong  = 0.0;
   sym_arcShort = 0.0;
   if(barsAvail >= 10)
   {
      int shift = 1; // last closed bar
      // LONG ARC: from anchorLow -> projected high target
      if(sym_mode == 1 && sym_anchorLowShift >= 0 && sym_anchorHighShift >= 0)
      {
         double impL = sym_anchorHigh - sym_anchorLow;
         if(impL > 0)
         {
            double targetL = sym_anchorLow + impL * g_cfg.arcExtMult;
            double tL = (double)(sym_anchorLowShift - shift) / (double)g_cfg.arcHorizonBars;
            if(tL < 0.0) tL = 0.0; if(tL > 1.0) tL = 1.0;
            sym_arcLong = sym_anchorLow + (targetL - sym_anchorLow) * MathPow(tL, g_cfg.convPower);
         }
      }
      // SHORT ARC: from anchorHigh -> projected low target
      if(sym_mode == -1 && sym_anchorLowShift >= 0 && sym_anchorHighShift >= 0)
      {
         double impS = sym_anchorHigh - sym_anchorLow;
         if(impS > 0)
         {
            double targetS = sym_anchorHigh - impS * g_cfg.arcExtMult;
            double tS = (double)(sym_anchorHighShift - shift) / (double)g_cfg.arcHorizonBars;
            if(tS < 0.0) tS = 0.0; if(tS > 1.0) tS = 1.0;
            sym_arcShort = sym_anchorHigh + (targetS - sym_anchorHigh) * MathPow(tS, g_cfg.convPower);
         }
      }
   }
}

//==================================================================
// ENGINE 3 — SYMPHONY wave cycle (the impulse + retracement-fraction
//   phase model). Normalizes sym_* into the shared WaveCycle so the
//   referee can score it against LETRA and F16 on the same yardstick.
//   Lives here because it reads the sym_* phase state. Reuses the
//   normalization helpers from WaveCycleIntel.mqh (included earlier).
//==================================================================
void CycleSymphony_Compute()
{
   WaveCycle cy; ZeroMemory(cy);
   Cycle_CarryPerf(cy, g_state.cycles[ENG_SYMPHONY]);
   int prevStage = g_state.cycles[ENG_SYMPHONY].stage;

   int dir = (sym_mode==1 ? DIR_LONG : sym_mode==-1 ? DIR_SHORT : DIR_NONE);
   int p   = (dir==DIR_LONG ? sym_phaseLong : dir==DIR_SHORT ? sym_phaseShort : 0);

   cy.engineId  = ENG_SYMPHONY;
   cy.direction = dir;
   cy.maturity  = (p<=0?5.0 : p==1?25.0 : p==2?45.0 : p==3?70.0 : 92.0);
   cy.objective = (dir==DIR_LONG  && sym_arcLong >0.0 ? sym_arcLong
                  : dir==DIR_SHORT && sym_arcShort>0.0 ? sym_arcShort
                  : dir==DIR_LONG ? Sym_DestLong() : dir==DIR_SHORT ? Sym_DestShort() : 0.0);
   cy.invalidation = (dir==DIR_LONG ? sym_anchorLow : dir==DIR_SHORT ? sym_anchorHigh : 0.0);
   bool hasZone = (dir==DIR_LONG ? (sym_longInducLow!=0.0||sym_longInducHigh!=0.0)
                                 : (sym_shortInducLow!=0.0||sym_shortInducHigh!=0.0));
   cy.confidence = FalconClamp(50.0 + (hasZone?15.0:0.0) + (p==4?15.0:p==3?10.0:0.0), 0, 100);

   int stage, ph; string nxt;
   if(dir==DIR_NONE || p<=0){ stage=CYC_NONE; ph=PH_TRANSITION; nxt="awaiting impulse"; }
   else if(p==1){ stage=CYC_EXPANSION; ph=PH_EXPANSION;   nxt="retrace into zone"; }
   else if(p==2){ stage=CYC_RETRACE;   ph=PH_RETRACEMENT; nxt="return to flip / inducement"; }
   else if(p==3){ stage=CYC_RETURN;    ph=(dir==DIR_LONG?PH_DEMAND_RETURN:PH_SUPPLY_RETURN); nxt="breakout to new extreme"; }
   else        { stage=CYC_BREAKOUT;   ph=(dir==DIR_LONG?PH_NEW_HIGH:PH_NEW_LOW); nxt="extend to ARC target"; }

   cy.stage      = stage;
   cy.phase      = ph;
   cy.phaseLabel = FalconPhaseStr(ph);
   cy.nextEvent  = nxt;
   Cycle_FillEntry(cy, prevStage);

   g_state.cycles[ENG_SYMPHONY] = cy;
}

//==================================================================
// GENERIC CYCLE → WAVE BRIDGE — write any engine's normalized cycle
//   into the canonical g_state.wave (the phase the rest of the OS
//   reads). Preserves the Market Engine geometry sub-scores; overrides
//   only the phase-engine fields. Used for the F16 / consensus / best
//   authority paths (the Symphony path keeps its richer dedicated bridge).
//==================================================================
void Cycle_BridgeToWave(const WaveCycle &cy)
{
   FalconWave w = g_state.wave;   // keep geometry descriptors
   w.prevPhase = w.phase;
   w.phase     = cy.phase;
   w.direction = cy.direction;
   if(cy.objective!=0.0)    w.objective  = cy.objective;
   if(cy.invalidation!=0.0) w.origin     = cy.invalidation;
   w.completion= cy.maturity;
   w.confidence= cy.confidence;
   // ownership transfer proxy keyed to the engine's lifecycle stage
   w.dominanceTransfer = (cy.stage>=CYC_RETURN ? 60.0 : cy.stage==CYC_RETRACE ? 30.0 : 0.0);
   g_state.wave = w;
   if(w.phase != w.prevPhase) FalconPublish(EVT_PHASE_CHANGE, w.phase, FalconPhaseStr(w.phase));
}

//==================================================================
// PHASE AUTHORITY — write the SELECTED engine's interpretation into the
//   canonical wave. This is the configurable replacement for the old
//   "Symphony is always the truth" bridge. Don't replace the phase
//   engine — pick which one DRIVES, and let the referee compare them.
//     • ENG_SYMPHONY : the dedicated Symphony bridge (default, unchanged)
//     • ENG_LETRA    : keep the native LETRA wave (no-op)
//     • ENG_F16      : bridge the F16 curve-tree cycle
//     • ENG_CONSENSUS: bridge the consensus (engine matching consensusDir)
//     • ENG_BEST     : bridge whichever engine the referee ranks best
//==================================================================
void PhaseAuthorityApply()
{
   int eng = g_cfg.entryEngine;

   // safety: if the comparative cycles are not being computed, the only valid
   // authority is Symphony's dedicated bridge (its phases are still computed).
   if(!g_cfg.runAllCycles){ if(g_cfg.useSymphony) SymphonyBridgeToWave(); return; }

   if(eng==ENG_SYMPHONY){ if(g_cfg.useSymphony) SymphonyBridgeToWave(); return; }
   if(eng==ENG_LETRA)   { return; }   // native LETRA wave already in g_state.wave
   if(eng==ENG_F16)     { Cycle_BridgeToWave(g_state.cycles[ENG_F16]); return; }

   if(eng==ENG_BEST)
   {
      int b = g_state.referee.bestEngine;
      if(b==ENG_SYMPHONY){ if(g_cfg.useSymphony) SymphonyBridgeToWave(); }
      else if(b>=0 && b<FALCON_NCYCLES) Cycle_BridgeToWave(g_state.cycles[b]);
      return;
   }

   if(eng==ENG_CONSENSUS)
   {
      int cd = g_state.referee.consensusDir;
      if(cd==DIR_NONE) return;   // no agreement -> leave native LETRA wave
      // bridge the consensus-aligned engine with the highest demonstrated edge
      int pick=-1; double best=-1.0;
      for(int e=0;e<FALCON_NCYCLES;e++)
         if(g_state.cycles[e].direction==cd && g_state.cycles[e].accuracy>best)
         { best=g_state.cycles[e].accuracy; pick=e; }
      if(pick==ENG_SYMPHONY){ if(g_cfg.useSymphony) SymphonyBridgeToWave(); }
      else if(pick>=0) Cycle_BridgeToWave(g_state.cycles[pick]);
      return;
   }
}

//==================================================================
// EFFECTIVE ENTRY ENGINE — resolve the engine that drives ENTRIES this
// bar (BEST -> referee.bestEngine). CONSENSUS is handled separately.
//==================================================================
int Sym_EffectiveEngine()
{
   if(g_cfg.entryEngine==ENG_BEST) return(g_state.referee.bestEngine);
   return(g_cfg.entryEngine);
}

//==================================================================
// Is the EA in RAW/FREE entry mode? (non-Symphony engine, or Symphony in
// FREE RUN). In this mode trades are owned by TALON + the position TP/SL +
// PYRO catastrophe stop — Symphony's discretionary ARC/phase exits and the
// ARC partial are SUPPRESSED, because they are keyed to sym_mode/sym_phase
// and would close trades the authority engine (e.g. LETRA) wants to hold
// (and Symphony's phase rotates constantly in free-run -> premature kills).
//==================================================================
bool SymRawActive()
{
   bool symAuth  = (g_cfg.entryEngine!=ENG_CONSENSUS && Sym_EffectiveEngine()==ENG_SYMPHONY);
   bool freeMode = (g_cfg.cycleFreeRun && g_cfg.runAllCycles);
   bool rawLike  = (!symAuth || freeMode);
   return(g_cfg.cycleRawEntries && rawLike);
}

//==================================================================
// RAW ENTRY EDGES — the SELECTED engine's P3 (return) / P4 (breakout)
// edges this bar, BEFORE the shared gates. Lets the entry engine run
// off LETRA, F16, Symphony, CONSENSUS or BEST identically.
//==================================================================
void Sym_RawEntryEdges(bool &eL3,bool &eL4,bool &eS3,bool &eS4)
{
   eL3=false; eL4=false; eS3=false; eS4=false;

   // CONSENSUS — any consensus-aligned engine casting an entry edge.
   if(g_cfg.entryEngine==ENG_CONSENSUS)
   {
      int cd=g_state.referee.consensusDir;
      if(cd==DIR_NONE) return;
      for(int e=0;e<FALCON_NCYCLES;e++)
      {
         if(!g_state.cycles[e].entryEdge || g_state.cycles[e].entryDir!=cd) continue;
         int k=g_state.cycles[e].entryKind;
         if(cd==DIR_LONG){ if(k==3) eL3=true; else if(k==4) eL4=true; }
         else            { if(k==3) eS3=true; else if(k==4) eS4=true; }
      }
      return;
   }

   int eff=Sym_EffectiveEngine();
   WaveCycle cy=g_state.cycles[eff];

   // FREE RUN — let the AUTHORITY engine (LETRA, F16, OR Symphony) trade on
   // EVERY fresh in-direction phase transition, not just its return/breakout
   // analogs. Edge-triggered (one shot per transition). Uses the engine's own
   // normalized cycle, so it works identically for Symphony as for LETRA.
   if(g_cfg.cycleFreeRun && g_cfg.runAllCycles)
   {
      // don't enter on reversal/sweep phases (liquidation) — those are
      // "reversal risk", a common source of incorrect counter-trend entries.
      bool freshEdge = (cy.stage!=cy.prevStage) && cy.stage>=CYC_EXPANSION
                       && cy.direction!=DIR_NONE && cy.phase!=PH_LIQUIDATION;
      if(freshEdge && cy.direction==DIR_LONG)       { if(cy.stage==CYC_BREAKOUT) eL4=true; else eL3=true; }
      else if(freshEdge && cy.direction==DIR_SHORT) { if(cy.stage==CYC_BREAKOUT) eS4=true; else eS3=true; }
      return;
   }

   // SYMPHONY authority (non-free) — native impulse phase 3/4 edges.
   if(eff==ENG_SYMPHONY)
   {
      eL3=(sym_mode==1  && sym_phaseLong ==3 && sym_prevPhaseLong !=3);
      eL4=(sym_mode==1  && sym_phaseLong ==4 && sym_prevPhaseLong !=4);
      eS3=(sym_mode==-1 && sym_phaseShort==3 && sym_prevPhaseShort!=3);
      eS4=(sym_mode==-1 && sym_phaseShort==4 && sym_prevPhaseShort!=4);
      return;
   }

   // LETRA / F16 (non-free) — normalized return/breakout edges only.
   if(cy.entryEdge)
   {
      if(cy.entryDir==DIR_LONG)      { if(cy.entryKind==3) eL3=true; else if(cy.entryKind==4) eL4=true; }
      else if(cy.entryDir==DIR_SHORT){ if(cy.entryKind==3) eS3=true; else if(cy.entryKind==4) eS4=true; }
   }
}

//==================================================================
// FACT-BASED DECISION CONTRACT — subsystems DO THEIR JOBS.
//   Each subsystem owns a concrete VETO in its own domain — no scores,
//   no weighted averages. An entry in `dir` survives only if EVERY
//   subsystem clears it. The first failing subsystem records WHY (so the
//   block is explainable / journalable), and direction is INHERITED from
//   ownership, never voted.
//
//   1. HTF        — PERMISSION: the higher-TF stack must not oppose dir.
//   2. CURVE/CAMP — OWNERSHIP : the owner of price must be dir (authority).
//   3. ZONES      — LOCATION  : price must be AT a real engagement zone
//                   (wave flip / supply-demand / order block / FU /
//                   swept inducement) — never fire in no-man's-land.
//   4. STRUCTURE  — CONFIRM   : no change-of-character against dir.
//   5. CONVEXITY  — ROOM      : curve capacity left + wave not exhausted
//                   (don't buy tops / sell bottoms).
//   6. NETWORK/PART — THREAT  : no dominant opposing authority/participant.
//==================================================================
string sym_factVeto = "";   // last veto reason (diagnostics)

bool Sym_PriceInBand(const double px,const double a,const double b)
{
   if(a==0.0 && b==0.0) return(false);
   double lo=MathMin(a,b), hi=MathMax(a,b);
   return(px>=lo && px<=hi);
}

// LOCATION fact — is price AT a real subsystem zone supporting `dir`?
bool Sym_AtRealZone(const int dir,const double px)
{
   FalconWave        w  = g_state.wave;
   FalconSupplyDemand sd= g_state.supplyDemand;
   FalconOrderBlocks  ob= g_state.orderBlocks;
   FalconFU           fu= g_state.fu;
   FalconLiquidity    lq= g_state.liquidity;

   bool flip   = Sym_PriceInBand(px, w.flipBot, w.flipTop);             // wave flip zone
   bool sweptL = lq.induceSwept;                                        // liquidity grabbed
   // owner-TF zone (fractal): price reacting at the controlling higher-TF zone
   int oiZ=g_state.htf.ownerTF;
   bool ownerZone=false;
   if(g_cfg.fractalZones && oiZ>=0 && oiZ<7 && g_tfZones[oiZ].valid)
      ownerZone = (dir==DIR_LONG ? (g_tfZones[oiZ].inDemand || (g_tfZones[oiZ].obDir==DIR_LONG && Sym_PriceInBand(px,g_tfZones[oiZ].obBot,g_tfZones[oiZ].obTop)))
                                 : (g_tfZones[oiZ].inSupply || (g_tfZones[oiZ].obDir==DIR_SHORT && Sym_PriceInBand(px,g_tfZones[oiZ].obBot,g_tfZones[oiZ].obTop))));
   if(dir==DIR_LONG)
   {
      bool dz  = sd.inDemand;                                           // supply/demand engine
      bool obz = (ob.activeDir==DIR_LONG && Sym_PriceInBand(px,ob.activeBot,ob.activeTop));
      bool fuz = (fu.active && fu.dir==DIR_LONG && Sym_PriceInBand(px,fu.zoneBot,fu.zoneTop));
      return(flip || dz || obz || fuz || sweptL || ownerZone);
   }
   else
   {
      bool sz  = sd.inSupply;
      bool obz = (ob.activeDir==DIR_SHORT && Sym_PriceInBand(px,ob.activeBot,ob.activeTop));
      bool fuz = (fu.active && fu.dir==DIR_SHORT && Sym_PriceInBand(px,fu.zoneBot,fu.zoneTop));
      return(flip || sz || obz || fuz || sweptL || ownerZone);
   }
}

// Soft-filter veto with regret learning: if the OS has LEARNED (from shadow
// trades) that this filter keeps missing winners, OVERRIDE it and take the
// trade; otherwise record the miss (keep learning) and veto.
bool SymVeto(const int code,const string reason,const int dir,const double px)
{
   if(MT_Override(code)) return(false);   // learned to take it -> allow
   MT_RecordMiss(dir, px, code);          // count the miss (keeps learning)
   sym_factVeto = reason;
   return(true);
}

bool SymphonyFactsConfirm(const int dir)
{
   sym_factVeto = "";
   if(!g_cfg.useFactGate) return(true);

   double px = gClose[1];

   // 1) HTF PERMISSION — higher-TF stack must not oppose.  [HARD]
   int htfDir = g_state.htf.stackDir;
   if(htfDir!=DIR_NONE && htfDir!=dir){ sym_factVeto="HTF opposes"; return(false); }

   // 2) OWNERSHIP — the owner of price must be this direction.  [HARD]
   int owner = g_state.campaign.owner;
   if(owner==DIR_NONE) owner = g_state.curve.ownerDir;
   if(owner!=DIR_NONE && owner!=dir){ sym_factVeto="owner opposes"; return(false); }

   // 3) LOCATION — price must be AT a real zone.  [SOFT: regret-learnable]
   if(g_cfg.factNeedZone && !Sym_AtRealZone(dir,px)){ if(SymVeto(VR_NOZONE,"no zone",dir,px)) return(false); }

   // 4) STRUCTURE — no change-of-character against the trade.  [HARD]
   if(g_state.structure.choch == -dir){ sym_factVeto="CHoCH against"; return(false); }

   // 5) CONVEXITY ROOM — capacity left + wave not exhausted.  [SOFT]
   if(g_state.convexity.geometryCapacity < g_cfg.minEntryRoomPct){ if(SymVeto(VR_NOROOM,"no room",dir,px)) return(false); }
   if(g_state.wave.completion >= g_cfg.maxEntryComplete){ if(SymVeto(VR_EXHAUST,"wave exhausted",dir,px)) return(false); }

   // 5b) CURVE LOCATOR — never enter LATE on the OWNER leg.  [SOFT]
   if(g_cfg.useCurveLocator && g_state.curveLocator.pos >= g_cfg.maxOwnerLegPos)
   { if(SymVeto(VR_LATE,"late on curve",dir,px)) return(false); }

   // 6) THREAT — dominant opposing network authority OR participant.  [SOFT]
   if(g_state.network.pressureDir == -dir
      && MathAbs(g_state.network.pressure) >= g_cfg.factNetPressure){ if(SymVeto(VR_NETWORK,"network counter",dir,px)) return(false); }
   double oppPart = (dir==DIR_LONG ? g_state.participants.seller : g_state.participants.buyer);
   double ownPart = (dir==DIR_LONG ? g_state.participants.buyer  : g_state.participants.seller);
   if(oppPart>=g_cfg.factPartThreat && oppPart>ownPart){ if(SymVeto(VR_PARTICIPANT,"participant counter",dir,px)) return(false); }

   // 7) LEARNED AVOIDANCE — refuse to repeat its own losing context.  [HARD]
   if(AD_Veto(AD_Bucket(dir))){ sym_factVeto="learned avoid"; return(false); }

   // 7b) TIME INTELLIGENCE (TIE) — optional soft temporal permit. Off by
   //     default (informational). When enabled, a DEAD-hour timeQuality
   //     vetoes new entries (the hard session window stays separate).
   if(g_cfg.useTimeIntel && g_cfg.timeGateEntries && !g_state.timeIntel.permit)
   { sym_factVeto="time dead"; return(false); }

   // 8) SELF-AWARENESS — stood itself down (health / loss cluster / DD).  [HARD]
   if(SA_StandDown()){ sym_factVeto="self standdown"; return(false); }

   return(true);
}

//==================================================================
// CONFLUENCE GATE — Symphony provides precise TIMING; the Decision layer
// owns the GO / NO-GO. An entry only fires when the brain has not stood the
// shot down and conviction clears the SAME thresholds the Decision layer uses:
//   • direction agrees with the established owner/master (no shorting a long book)
//   • the verdict is not a stand-down action (WAIT / NO_TRADE / EXIT / DEFEND)
//   • executionProbability >= execProbArm
//   • confidence       >= minConf
// (This is what would have vetoed the low-conviction short: WAIT, exec 29%,
//  confidence 36, threat 64.) Toggle off with InpRequireConfluence=false to run
// Symphony stand-alone.
//==================================================================
bool SymphonyBrainConfirms(const int dir)
{
   if(!g_cfg.requireConfluence) return(true);
   FalconIntelligence x = g_state.intel;

   // wrong side relative to the owner/master direction
   if(g_state.exec.master!=DIR_NONE && g_state.exec.master!=dir) return(false);

   // brain is actively telling us to stand down / protect / bank
   int a = g_state.exec.action;
   if(a==ACT_WAIT || a==ACT_NO_TRADE || a==ACT_EXIT || a==ACT_DEFEND) return(false);

   // continuous-probability conviction gates (phases are outputs, these decide)
   if(x.executionProbability < g_cfg.execProbArm) return(false);
   if(x.confidence           < g_cfg.minConf)     return(false);

   return(true);
}

//==================================================================
// PLACE ENTRY — compose the subsystem trade plan, then execute it.
//   When useTradePlan: stop = subsystem zone-invalidation, target =
//   owner-driven destination, lots scaled by participant/campaign
//   conviction, and the entry must clear the subsystem reward:risk gate.
//   Otherwise falls back to Symphony's anchor ± 0.25 ATR stop.
//==================================================================
//==================================================================
// TRADE COMPOSITION / RANGE BANDS — model & categorize every entry by
// its geometry (entry · stop · stop-distance · target · target-distance
// · R · range band), then MANAGE each band appropriately. Two trades at
// the same R behave differently by absolute range: a 40->120pt trade is
// a wide swing that must be de-risked into the move; a 20->60pt trade is
// a tight intraday push that can ride to target. WIDE trades bank a
// partial + move to BE at BandPartialR; tighter trades ride to capture.
//==================================================================
#define TG_SCALP  0
#define TG_NORMAL 1
#define TG_WIDE   2

struct TradeGeom
{
   ulong  ticket;
   int    dir;
   double entry;
   double sl;
   double stopDist;     // |entry-sl| in price
   double target;
   double tgtDist;      // |target-entry| in price
   double rr;           // tgtDist / stopDist
   double stopATR;      // stopDist / ATR  (the range scale)
   int    band;         // TG_SCALP / TG_NORMAL / TG_WIDE
   bool   partialDone;
};
TradeGeom tg_book[128];
int       tg_count = 0;

string TG_BandStr(const int b){ return(b==TG_WIDE?"WIDE":b==TG_NORMAL?"NORMAL":"SCALP"); }

int TG_Band(const double stopATR)
{
   if(stopATR < g_cfg.bandWideATR*0.5) return(TG_SCALP);
   if(stopATR < g_cfg.bandWideATR)     return(TG_NORMAL);
   return(TG_WIDE);
}

int TG_Find(const ulong ticket)
{
   for(int i=0;i<tg_count;i++) if(tg_book[i].ticket==ticket) return(i);
   return(-1);
}

void TG_Record(const ulong ticket,const int dir,const double entry,const double sl,const double target,const double atr)
{
   if(ticket==0 || atr<=0.0) return;
   int idx=TG_Find(ticket);
   if(idx<0)
   {
      if(tg_count>=128){ for(int i=1;i<tg_count;i++) tg_book[i-1]=tg_book[i]; tg_count--; }
      idx=tg_count++;
   }
   double stopDist=MathAbs(entry-sl);
   double tgtDist =MathAbs(target-entry);
   tg_book[idx].ticket=ticket; tg_book[idx].dir=dir; tg_book[idx].entry=entry; tg_book[idx].sl=sl;
   tg_book[idx].stopDist=stopDist; tg_book[idx].target=target; tg_book[idx].tgtDist=tgtDist;
   tg_book[idx].rr=(stopDist>0.0?tgtDist/stopDist:0.0);
   tg_book[idx].stopATR=(atr>0.0?stopDist/atr:0.0);
   tg_book[idx].band=TG_Band(tg_book[idx].stopATR);
   tg_book[idx].partialDone=false;

   // surface the live trade composition for the dashboard
   g_state.exec.tradeBand   = tg_book[idx].band;
   g_state.exec.stopDistPts = stopDist;
   g_state.exec.tgtDistPts  = tgtDist;
}

//------------------------------------------------------------------
// BAND MANAGER — WIDE-range trades get de-risked into the move:
// bank a partial + move stop to BE once they reach BandPartialR.
// (Tight/normal trades are left to the capture-at-done / TP exit.)
//------------------------------------------------------------------
void TG_Manage()
{
   double atr=g_state.physics.atr; if(atr<=0.0) atr=FalconATR(1); if(atr<=0.0) return;
   double step =SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double minLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);

   int total=PositionsTotal();
   for(int i=total-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=g_cfg.magic) continue;

      int idx=TG_Find(ticket);
      if(idx<0) continue;
      if(tg_book[idx].band!=TG_WIDE || tg_book[idx].partialDone) continue;

      double entry=tg_book[idx].entry, risk=tg_book[idx].stopDist;
      if(risk<=0.0) continue;
      long type=PositionGetInteger(POSITION_TYPE);
      double px=(type==POSITION_TYPE_BUY?SymbolInfoDouble(_Symbol,SYMBOL_BID):SymbolInfoDouble(_Symbol,SYMBOL_ASK));
      double rNow=(type==POSITION_TYPE_BUY?(px-entry):(entry-px))/risk;
      if(rNow < g_cfg.bandPartialR) continue;

      // bank a partial (de-risk the wide swing)
      if(g_cfg.bandPartialFrac>0.0)
      {
         double lots=PositionGetDouble(POSITION_VOLUME);
         double cut =MathFloor((lots*g_cfg.bandPartialFrac)/step)*step;
         if(cut>=minLot && cut<lots) EE_ClosePartial(ticket,cut);
      }
      // move the remainder to breakeven (+small buffer)
      double be=(type==POSITION_TYPE_BUY?entry+atr*0.05:entry-atr*0.05);
      EE_ModifySL(ticket,be);
      tg_book[idx].partialDone=true;
      FalconPublish(EVT_EXIT_FIRED,(type==POSITION_TYPE_BUY?1:-1),"WIDE band partial+BE");
   }
}


// structure (impulse anchor / swing), not a fixed ATR off entry.
//   LONG  : structural swing LOW  - 0.25 ATR
//   SHORT : structural swing HIGH + 0.25 ATR
// Priority: the current Symphony impulse anchor (its structural origin),
// else the nearest recent pivot on the correct side, else ATR fallback.
//==================================================================
double Sym_StructuralStop(const int dir,const double entry,const double atr)
{
   double buf = atr*0.25;
   int len  = g_cfg.stopPivotLen;     // SMALL pivot -> recent MINOR structure (tight stop)
   int look = g_cfg.stopLookback;     // SHORT window -> don't reach far back for a wide swing

   // nearest recent minor swing on the correct side (closest c = most recent)
   if(dir==DIR_LONG)
   {
      for(int c=len+1;c<look;c++)
         if(FalconIsPivotLow(c,len) && gLow[c]<entry) return(gLow[c]-buf);
   }
   else
   {
      for(int c=len+1;c<look;c++)
         if(FalconIsPivotHigh(c,len) && gHigh[c]>entry) return(gHigh[c]+buf);
   }

   // No recent minor swing -> fall back to the Symphony impulse anchor IF it is
   // on the correct side (classic behaviour), else skip the trade.
   if(dir==DIR_LONG  && sym_anchorLow >0.0 && sym_anchorLow <entry) return(sym_anchorLow  - buf);
   if(dir==DIR_SHORT && sym_anchorHigh>0.0 && sym_anchorHigh>entry) return(sym_anchorHigh + buf);
   return(0.0);   // no structure within reach -> skip (no wide/ATR fallback)
}

void Sym_PlaceEntry(const int dir,const string tag,const double riskCash,const double atrNow,const bool raw=false)
{
   double entry = (dir==DIR_LONG ? SymbolInfoDouble(_Symbol,SYMBOL_ASK)
                                 : SymbolInfoDouble(_Symbol,SYMBOL_BID));
   double sl, target=0.0, t2=0.0, rr=0.0;
   double lots;
   int    adBucket = AD_Bucket(dir);            // self-learning context
   double adMult   = AD_SizeMult(adBucket);     // size by learned edge
   double saMult   = SA_Throttle();             // global self-awareness throttle

   if(raw)
   {
      // RAW / FREE mode: STRUCTURAL stop (Symphony-style — just beyond the
      // swing/anchor), with the target placed at minRR x the structural risk so
      // every entry is a real structural setup at the required R:R. (The
      // capture-at-done exit banks profit at the curve destination; this TP is
      // the backstop.)
      sl = Sym_StructuralStop(dir, entry, atrNow);
      if(sl<=0.0) return;                              // no structure -> skip the trade (no ATR fallback)
      double stopDist = MathAbs(entry - sl);
      if(stopDist <= 0.0) return;
      if(g_cfg.maxStructStopATR>0.0 && stopDist > g_cfg.maxStructStopATR*atrNow) return;  // structural stop too WIDE -> skip (unmanageable range)
      if(g_cfg.maxStopATR>0.0 && stopDist > g_cfg.maxStopATR*atrNow) return;  // structure too far -> skip
      double t = stopDist * g_cfg.minRR;
      target = (dir==DIR_LONG ? entry + t : entry - t);
      t2     = target;
      rr     = g_cfg.minRR;
      lots   = Sym_SizeLots(dir, riskCash*adMult*saMult, entry, sl);
   }
   else if(g_cfg.useTradePlan)
   {
      FalconTradePlan pl = ComposeTradePlan(dir, entry, atrNow);
      if(!pl.valid)          return;
      if(pl.rr < g_cfg.minRR) return;                 // subsystem-derived R:R gate
      sl     = pl.stop; target = pl.target; t2 = pl.target2; rr = pl.rr;
      lots   = Sym_SizeLots(dir, riskCash*pl.convictionMult*adMult*saMult, entry, sl);  // conviction x learned edge x self-throttle
   }
   else
   {
      sl   = (dir==DIR_LONG ? sym_anchorLow - atrNow*0.25 : sym_anchorHigh + atrNow*0.25);
      lots = Sym_SizeLots(dir, riskCash*adMult*saMult, entry, sl);
   }

   bool slOk = (dir==DIR_LONG ? (sl>0 && entry>sl) : (sl>0 && sl>entry));
   if(!slOk || lots<=0.0) return;

   // UNIVERSAL wide-stop filter (applies to ALL entry modes: raw / tradeplan /
   // classic). If the stop sits more than InpMaxStructStopATR ATR from entry,
   // the range is unmanageably wide -> skip the trade.
   if(g_cfg.maxStructStopATR>0.0 && atrNow>0.0 &&
      MathAbs(entry-sl) > g_cfg.maxStructStopATR*atrNow)
      return;

   // bank the runner at the destination: composed (or raw) target -> position TP
   double tpOrder = (target>0.0 && (raw || (g_cfg.useTradePlan && g_cfg.targetTP))) ? target : 0.0;
   if(EE_SendMarketOrder(dir>0?+1:-1, lots, sl, "SYM "+tag, tpOrder))
   {
      if(dir==DIR_LONG){ sym_lastLongTradeTime=gTime[0]; sym_longCampaignOpen=true; }
      else             { sym_lastShortTradeTime=gTime[0]; sym_shortCampaignOpen=true; }
      TJ_RecordEntry(ee_lastTicket,dir,tag,entry,sl,lots);
      TG_Record(ee_lastTicket,dir,entry,sl,target,atrNow);   // model + categorize this entry's geometry/range band
      AD_RecordEntry(ee_lastTicket, adBucket, lots*MathAbs(entry-sl)*g_cfg.contractValue, g_state.intel.executionProbability);
      g_state.exec.entry=entry; g_state.exec.stop=sl; g_state.exec.lots=lots; g_state.exec.riskCash=riskCash;
      g_state.exec.target=target; g_state.exec.target2=t2; g_state.exec.reward=rr;
   }
}

//==================================================================
// ENTRIES — Phase 3 + Phase 4 only (long & short)   [Symphony]
//   Trigger/timing = Symphony phase edge; stop/target/size = composed
//   from the subsystems (TradePlan). Reuses EE_IsTradeTime.
//==================================================================
// FREE-RUN ENTRY QUALITY — the location discipline that stops "random"
// entries when the heavy fact gate is bypassed (raw/free mode). Keeps only
// the checks that decide WHERE you enter: at a real zone (demand=buys /
// supply=sells) and with room left on the curve. HTF/ownership/network
// vetoes stay off in free-run; this just blocks random-location entries.
bool Sym_EntryQuality(const int dir,const double px)
{
   if(g_cfg.entryAtZone && !Sym_AtRealZone(dir,px)){ sym_factVeto="not at zone"; return(false); }
   if(g_cfg.entryNeedRoom)
   {
      if(g_state.convexity.geometryCapacity < g_cfg.minEntryRoomPct){ sym_factVeto="no room"; return(false); }
      if(g_state.wave.completion >= g_cfg.maxEntryComplete){ sym_factVeto="exhausted"; return(false); }
      if(g_cfg.useCurveLocator && g_state.curveLocator.pos >= g_cfg.maxOwnerLegPos){ sym_factVeto="late on curve"; return(false); }
   }
   return(true);
}

void SymphonyExecuteTrading()
{
   int barsAvail = FalconBars();
   if(barsAvail < 3) return;

   int      shiftNow = 1;
   double   closeNow = gClose[shiftNow];
   double   atrNow   = FalconATR(shiftNow);
   if(atrNow<=0.0) atrNow=FalconATR(0);
   datetime barTime  = gTime[0];

   double equity   = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskCash = equity * g_cfg.riskPercent * 0.01;

   // session + drawdown gating (FALCON-managed)
   if(!EE_IsTradeTime()) return;
   if(g_cfg.blockIfBreach && !ee_lastRiskOk) return;
   if(ee_riskCooldown>0) return;

   // Re-entry lockout: a campaign for THIS impulse was already closed -> wait for
   // a fresh impulse before re-engaging this direction (kills exit/re-enter churn).
   bool longLocked  = (sym_exitedLongAnchor  != 0.0);
   bool shortLocked = (sym_exitedShortAnchor != 0.0);

   // The Symphony per-impulse lockout only makes sense under Symphony authority
   // (it is keyed to sym anchors). Other engines — and Symphony itself in FREE
   // RUN — rely on edge-triggering + per-bar dedupe to avoid churn.
   bool symAuth  = (g_cfg.entryEngine!=ENG_CONSENSUS && Sym_EffectiveEngine()==ENG_SYMPHONY);
   bool freeMode = (g_cfg.cycleFreeRun && g_cfg.runAllCycles);   // any authority engine trades ALL phases
   bool rawLike  = (!symAuth || freeMode);                       // free/raw entry behaviour (no lockout / no anchor confirm)
   if(rawLike){ longLocked=false; shortLocked=false; }

   // EDGE-TRIGGERED entries from the SELECTED engine's wave cycle (LETRA / F16 /
   // Symphony / Consensus / Best). Each fires only on the bar the engine
   // TRANSITIONS into a return (P3) or breakout (P4), then clears the SAME
   // subsystem gates (facts / brain / counter-dir).
   bool eL3,eL4,eS3,eS4;
   Sym_RawEntryEdges(eL3,eL4,eS3,eS4);

   // RAW mode: an engine entering on its own edge (non-Symphony, or Symphony in
   // FREE RUN) bypasses the Symphony fact/brain gate (which is tuned to
   // Symphony's "price-back-at-zone" phase-3 and would veto raw phase edges)
   // and uses a clean ATR stop/target. This is what makes the A/B/C test fair
   // and lets any engine "trade freely like LETRA".
   bool rawMode = (g_cfg.cycleRawEntries && rawLike);
   bool gateL = (rawMode ? Sym_EntryQuality(DIR_LONG, closeNow)  : (SymphonyFactsConfirm(DIR_LONG)  && SymphonyBrainConfirms(DIR_LONG)));
   bool gateS = (rawMode ? Sym_EntryQuality(DIR_SHORT,closeNow)  : (SymphonyFactsConfirm(DIR_SHORT) && SymphonyBrainConfirms(DIR_SHORT)));

   bool L3 = (eL3 && !longLocked  && !MM_CounterDirBlocked(DIR_LONG)  && gateL);
   bool L4 = (eL4 && !longLocked  && !MM_CounterDirBlocked(DIR_LONG)  && gateL);
   bool S3 = (eS3 && !shortLocked && !MM_CounterDirBlocked(DIR_SHORT) && gateS);
   bool S4 = (eS4 && !shortLocked && !MM_CounterDirBlocked(DIR_SHORT) && gateS);

   string engTag = FalconEngineStr(g_cfg.entryEngine==ENG_BEST?g_state.referee.bestEngine:g_cfg.entryEngine);

   // NO HEDGE — never hold both directions. Block a new entry while ANY
   // opposite-direction position is open (regardless of its PnL). This is the
   // hard "one direction at a time" rule, distinct from the counter-dir lock
   // (which only blocks against a *net-profitable* opposite book).
   if(g_cfg.noHedge)
   {
      if(g_state.exec.openShortCount>0){ L3=false; L4=false; }
      if(g_state.exec.openLongCount >0){ S3=false; S4=false; }
   }

   // MAX CONCURRENT POSITIONS — hard cap across all directions. Once the cap is
   // reached, no new entries fire (existing positions still manage their exits).
   if(g_cfg.maxOpenPositions>0 &&
      (g_state.exec.openLongCount+g_state.exec.openShortCount) >= g_cfg.maxOpenPositions)
   { L3=false; L4=false; S3=false; S4=false; }

   double impL = sym_anchorHigh - sym_anchorLow;
   double impS = sym_anchorHigh - sym_anchorLow;

   // LONG P3
   if(L3 && sym_lastLongTradeTime!=barTime)
      Sym_PlaceEntry(DIR_LONG,engTag+" P3 Long",riskCash,atrNow,rawMode);

   // LONG P4
   if(L4 && sym_lastLongTradeTime!=barTime && (rawLike || impL>0))
   {
      bool breakout = rawLike || (closeNow>sym_anchorHigh || closeNow>gHigh[shiftNow+1] + 0.20*atrNow);
      if(breakout) Sym_PlaceEntry(DIR_LONG,engTag+" P4 Long",riskCash,atrNow,rawMode);
   }

   // SHORT P3
   if(S3 && sym_lastShortTradeTime!=barTime)
      Sym_PlaceEntry(DIR_SHORT,engTag+" P3 Short",riskCash,atrNow,rawMode);

   // SHORT P4
   if(S4 && sym_lastShortTradeTime!=barTime && (rawLike || impS>0))
   {
      bool breakout = rawLike || (closeNow<sym_anchorLow || closeNow<gLow[shiftNow+1] - 0.20*atrNow);
      if(breakout) Sym_PlaceEntry(DIR_SHORT,engTag+" P4 Short",riskCash,atrNow,rawMode);
   }
}

//==================================================================
// EXITS — ARC + institutional outer-band sweep + phase composite
//   [ported from Symphony ManageArcInstitutionalExits]
//   Reuses EE_CloseFull from ExecutionEngine.
//==================================================================
void SymphonyManageExits()
{
   int barsAvail = FalconBars();
   if(barsAvail <= (2*g_cfg.pivotLen + 5)) return;

   // RAW/FREE mode: TALON + position TP/SL + PYRO own the exit. Symphony's
   // ARC/phase exit is keyed to sym_mode/sym_phase and would kill the authority
   // engine's trades early (and fire constantly in free-run). Skip it.
   if(SymRawActive()) return;

   int    shiftNow = 1;
   double closeNow = gClose[shiftNow];
   double atrNow   = FalconATR(shiftNow);
   if(atrNow<=0.0) atrNow=FalconATR(0);

   // --- 1) ARC exhaustion flags (measured against the genuine curve DESTINATION,
   //         not the time-evolving arc that sits near the origin early) ---
   double destL = Sym_DestLong();
   double destS = Sym_DestShort();
   bool arcExhaustLong  = (sym_mode == 1  && destL > 0.0 && closeNow >= (destL - g_cfg.arcToleranceAtr * atrNow));
   bool arcExhaustShort = (sym_mode == -1 && destS > 0.0 && closeNow <= (destS + g_cfg.arcToleranceAtr * atrNow));

   // --- 2) INSTITUTIONAL BANDS ---
   double instLevelL = (sym_longInducPrice != 0.0 ? sym_longInducPrice : (sym_anchorHigh > 0.0 ? sym_anchorHigh : 0.0));
   double innerTopL  = (sym_longInducHigh > 0.0 ? sym_longInducHigh : instLevelL);
   double outerTopL  = innerTopL + g_cfg.outerBandAtrMult * atrNow;

   double instLevelS = (sym_shortInducPrice != 0.0 ? sym_shortInducPrice : (sym_anchorLow > 0.0 ? sym_anchorLow : 0.0));
   double innerBotS  = (sym_shortInducLow != 0.0 ? sym_shortInducLow : instLevelS);
   double outerBotS  = innerBotS - g_cfg.outerBandAtrMult * atrNow;

   // --- 3) TRACK OUTER-BAND SWEEPS PER IMPULSE ---
   if(sym_mode == 1 && instLevelL > 0.0 && closeNow > outerTopL)
      sym_longOuterBreachSeen = true;
   if(sym_mode == -1 && instLevelS > 0.0 && closeNow < outerBotS)
      sym_shortOuterBreachSeen = true;

   // --- 4) PHASE-CHANGE AT EXTREME ---
   bool phaseTrendEndLong =
      (sym_mode == 1 && (sym_prevPhaseLong == 3 || sym_prevPhaseLong == 4) && (sym_phaseLong <= 1));
   bool phaseTrendEndShort =
      (sym_mode == -1 && (sym_prevPhaseShort == 3 || sym_prevPhaseShort == 4) && (sym_phaseShort <= 1));

   // --- 5) FULL EXIT CONDITIONS ---
   bool exitLong = false;
   bool exitShort = false;

   if(sym_mode == 1 && arcExhaustLong && phaseTrendEndLong)
   {
      bool hasInstL = (instLevelL > 0.0);
      bool instPatternOK = !hasInstL || (sym_longOuterBreachSeen && closeNow < innerTopL);
      if(instPatternOK) exitLong = true;
   }
   if(sym_mode == -1 && arcExhaustShort && phaseTrendEndShort)
   {
      bool hasInstS = (instLevelS > 0.0);
      bool instPatternOK = !hasInstS || (sym_shortOuterBreachSeen && closeNow > innerBotS);
      if(instPatternOK) exitShort = true;
   }

   if(!exitLong && !exitShort) return;

   // --- 6) EXECUTE EXITS ON MATCHING POSITIONS ---
   int total = PositionsTotal();
   for(int i=total-1;i>=0;i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != g_cfg.magic) continue;
      long type = PositionGetInteger(POSITION_TYPE);

      if(exitLong && type == POSITION_TYPE_BUY)
      {
         if(EE_CloseFull(ticket)) FalconPublish(EVT_EXIT_FIRED,1,"SYM ARC/INST exit");
      }
      if(exitShort && type == POSITION_TYPE_SELL)
      {
         if(EE_CloseFull(ticket)) FalconPublish(EVT_EXIT_FIRED,-1,"SYM ARC/INST exit");
      }
   }

   // Lock re-entry for THIS impulse so we don't immediately re-open the same leg.
   if(exitLong)  { sym_exitedLongAnchor  = (sym_anchorLow >0.0?sym_anchorLow :1.0); sym_longCampaignOpen=false;  }
   if(exitShort) { sym_exitedShortAnchor = (sym_anchorHigh>0.0?sym_anchorHigh:1.0); sym_shortCampaignOpen=false; }
}

//==================================================================
// CURVE DESTINATION — the genuine FIXED projected target of the impulse.
//   destLong  = anchorLow  + impulse * arcExtMult   (the curve's high target)
//   destShort = anchorHigh - impulse * arcExtMult   (the curve's low target)
//
//   NOTE: this is NOT sym_arcLong/sym_arcShort. Those are the TIME-EVOLVING
//   arc curve, which sits near the impulse ORIGIN early in a move (t→0) and
//   would sit BELOW price — using it as a harvest/convergence trigger banks
//   winners the instant they open. The grip and the partial must converge on
//   the real destination, so winners are allowed to travel to the target.
//==================================================================
double Sym_DestLong()
{
   double imp = sym_anchorHigh - sym_anchorLow;
   if(sym_mode!=1 || imp<=0.0) return(0.0);
   return(sym_anchorLow + imp*g_cfg.arcExtMult);
}
double Sym_DestShort()
{
   double imp = sym_anchorHigh - sym_anchorLow;
   if(sym_mode!=-1 || imp<=0.0) return(0.0);
   return(sym_anchorHigh - imp*g_cfg.arcExtMult);
}

//==================================================================
// TALON GRIP — curve-convergent STRUCTURAL trailing + earned breakeven
//   Replaces basic ATR trailing. Operates at the CAMPAIGN (basket) level:
//   one grip for the whole directional fleet, off blended cost. The stop is
//   driven by the same intelligence that drives entries:
//     1) STRUCTURE  — rides behind confirmed swing pivots (higher-lows for
//        longs / lower-highs for shorts), ratcheting only.
//     2) BREAKEVEN  — EARNED, not arbitrary: locks once a BOS confirms in the
//        campaign direction OR the fleet is TalonBeATR in favor. (No more
//        getting tagged on a healthy phase-2 retrace.)
//     3) CONVERGENCE — the trail distance CONTRACTS as price nears the curve
//        destination (ARC target / wave objective) and as geometryCapacity
//        drains. Far = wide (let it run); near = tight (bank before reversal).
//     4) PHASE/THERMAL — hard-tightens at terminal phase (NEW_HIGH/NEW_LOW) or
//        when the campaign's profit velocity (coolingRate) rolls over.
//   Reuses EE_ModifySL. Applies one ratcheting stop to every leg of the side.
//==================================================================
void TalonManageSide(const int dir,const FalconThermalCampaign &c,
                     const double atr,const double bid,const double ask,
                     const double pivot)
{
   double E = c.blendedEntry;
   if(E<=0.0) return;
   double price = (dir==DIR_LONG ? bid : ask);
   double buf   = atr*g_cfg.talonBufATR;

   // 1) STRUCTURAL ANCHOR — ratchet to confirmed swings in the trade direction
   if(dir==DIR_LONG)
   {
      if(talon_anchorLong<=0.0)
         talon_anchorLong = MathMax(g_state.structure.swingLow, E - atr*g_cfg.talonBaseATR);
      if(pivot>0.0 && pivot>talon_anchorLong && pivot<price) talon_anchorLong = pivot;
   }
   else
   {
      if(talon_anchorShort<=0.0)
         talon_anchorShort = (g_state.structure.swingHigh>0.0 ? g_state.structure.swingHigh
                                                              : E + atr*g_cfg.talonBaseATR);
      if(pivot>0.0 && pivot<talon_anchorShort && pivot>price) talon_anchorShort = pivot;
   }
   double anchor = (dir==DIR_LONG ? talon_anchorLong : talon_anchorShort);
   double structuralSL = (dir==DIR_LONG ? anchor-buf : anchor+buf);

   // 2) EARNED BREAKEVEN — structural confirm (BOS in dir) OR favor >= TalonBeATR
   bool earned = (g_state.structure.bos==dir) || (c.favorableATR>=g_cfg.talonBeATR);
   if(earned){ if(dir==DIR_LONG) talon_beLong=true; else talon_beShort=true; }
   bool   beLocked = (dir==DIR_LONG ? talon_beLong : talon_beShort);
   double beFloor  = (dir==DIR_LONG ? E+atr*0.05 : E-atr*0.05);

   // 3) CURVE CONVERGENCE — wide far from the destination (let winners run),
   //    contracts ONLY on the final approach. The destination is the FIXED
   //    curve target (Sym_Dest*), never the time-evolving arc that sits near
   //    the origin early in the move.
   double target = (dir==DIR_LONG ? Sym_DestLong() : Sym_DestShort());
   if(target<=0.0) target = g_state.wave.objective;
   double distATR = (target>0.0 ? MathAbs(target-price)/atr : 999.0);
   double geom    = FalconClamp(g_state.convexity.geometryCapacity/100.0,0.0,1.0);

   // base: far => convFrac→1 (full base trail); near => convFrac→minTighten.
   double convFrac = FalconClamp(distATR/MathMax(g_cfg.talonConvSpanATR,1e-6),
                                 g_cfg.talonMinTighten, 1.0);
   bool approaching = (distATR < g_cfg.talonConvSpanATR);
   // geometry can ONLY tighten further once we are genuinely approaching the
   // destination — never strangle a young winner that is still far from target.
   if(approaching)
      convFrac = FalconClamp(MathMin(convFrac, MathMax(geom, g_cfg.talonMinTighten)),
                             g_cfg.talonMinTighten, 1.0);

   // 4) TERMINAL hard-tighten — only at the true terminal phase AND in the final
   //    approach. (Removed the single-bar coolingRate<0 trigger: one pullback bar
   //    was slamming the trail and stopping out healthy winners on noise.)
   bool terminal = ((dir==DIR_LONG  && g_state.wave.phase==PH_NEW_HIGH)
                  || (dir==DIR_SHORT && g_state.wave.phase==PH_NEW_LOW))
                  && distATR < g_cfg.talonConvSpanATR*0.5;
   if(terminal) convFrac = g_cfg.talonMinTighten;
   double trailDist = atr*g_cfg.talonBaseATR*convFrac;
   double convSL    = (dir==DIR_LONG ? price-trailDist : price+trailDist);

   // 4b) PROFIT GIVE-BACK LOCK — the give-back killer. The structural/convergence
   //    trail only tightens NEAR the target; a stacked campaign can run deep in
   //    profit while the destination is still far, and hand a chunk back before
   //    the wide trail catches. So track PEAK favorable excursion (ATR, ratchet
   //    only) and, once it clears talonLockArmATR, never give back more than
   //    talonGiveback of that peak. This caps "up heavy then gives it back"
   //    regardless of distance to target. talonGiveback=1 disables it.
   double favATR = (dir==DIR_LONG ? (price-E) : (E-price))/atr;
   if(dir==DIR_LONG){ if(favATR>talon_peakLong)  talon_peakLong =favATR; }
   else             { if(favATR>talon_peakShort) talon_peakShort=favATR; }
   double peakATR = (dir==DIR_LONG ? talon_peakLong : talon_peakShort);
   bool   lockOn  = false; double lockSL = 0.0;
   if(g_cfg.talonGiveback < 1.0 && peakATR >= g_cfg.talonLockArmATR)
   {
      double keep = (1.0 - g_cfg.talonGiveback) * peakATR * atr;   // profit (price) to protect
      lockSL = (dir==DIR_LONG ? E + keep : E - keep);
      lockOn = true;
   }

   // 5) COMPOSE — RIDE vs BANK.
   //    Far from the destination: use the LOOSER of (structural ratchet, ATR
   //    trail) so a healthy winner is given full room and is NOT noise-stopped
   //    on a normal pullback to the prior swing. On the final approach / terminal:
   //    use the TIGHTER of the two to bank before the reversal. Floor at earned
   //    breakeven; ratchet only (handled by the apply step).
   double cand;
   if(approaching || terminal)
      cand = (dir==DIR_LONG ? MathMax(structuralSL,convSL) : MathMin(structuralSL,convSL)); // tighter => bank
   else
      cand = (dir==DIR_LONG ? MathMin(structuralSL,convSL) : MathMax(structuralSL,convSL)); // looser => ride
   if(beLocked)
      cand = (dir==DIR_LONG ? MathMax(cand,beFloor) : MathMin(cand,beFloor));
   // profit give-back lock ratchets the stop up to protect banked peak profit
   if(lockOn)
      cand = (dir==DIR_LONG ? MathMax(cand,lockSL) : MathMin(cand,lockSL));

   // stage (display)
   int stage;
   if(!beLocked)        stage=TG_FORMING;
   else if(terminal)    stage=TG_TERMINAL;
   else if(lockOn && ((dir==DIR_LONG && lockSL>=convSL) || (dir==DIR_SHORT && lockSL<=convSL))) stage=TG_CONVERGING;
   else if(approaching) stage=TG_CONVERGING;
   else if(g_state.structure.bos==dir) stage=TG_RIDING;
   else                 stage=TG_BREAKEVEN;

   if(dir==DIR_LONG){ g_state.exec.gripLong=cand;  g_state.exec.talonStageLong=stage; }
   else             { g_state.exec.gripShort=cand; g_state.exec.talonStageShort=stage; }

   // 6) APPLY one ratcheting grip to every leg of this campaign
   int total=PositionsTotal();
   for(int i=0;i<total;i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=g_cfg.magic) continue;
      long type=PositionGetInteger(POSITION_TYPE);
      double sl=PositionGetDouble(POSITION_SL);
      if(dir==DIR_LONG && type==POSITION_TYPE_BUY && cand<bid && (sl==0.0||cand>sl))
      { if(EE_ModifySL(ticket,cand)) g_state.exec.exitState=XS_TRAIL_STOP; }
      if(dir==DIR_SHORT&& type==POSITION_TYPE_SELL&& cand>ask && (sl==0.0||cand<sl))
      { if(EE_ModifySL(ticket,cand)) g_state.exec.exitState=XS_TRAIL_STOP; }
   }
}

void TalonGrip()
{
   if(!g_cfg.useTalon) return;
   double atr=FalconATR(1); if(atr<=0.0) atr=FalconATR(0);
   if(atr<=0.0) return;
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);

   // TALON needs the campaign baskets (blended entry / stack count / favorable
   // excursion). PYRO builds them when it runs — but if PYRO is OFF, TALON must
   // build them itself, otherwise the grip is inert (stackCount stays 0) and
   // trades give profit back with no trailing at all.
   if(!g_cfg.useThermalRisk)
   {
      TR_BuildCampaign(DIR_LONG,  g_state.risk.campaign[0]);
      TR_BuildCampaign(DIR_SHORT, g_state.risk.campaign[1]);
   }

   // confirmed structural pivots for the grip anchor
   int cl = g_cfg.talonStructLen+1;
   double pLow  = FalconIsPivotLow (cl,g_cfg.talonStructLen) ? gLow[cl]  : 0.0;
   double pHigh = FalconIsPivotHigh(cl,g_cfg.talonStructLen) ? gHigh[cl] : 0.0;

   FalconThermalCampaign cL = g_state.risk.campaign[0];
   FalconThermalCampaign cS = g_state.risk.campaign[1];

   if(cL.stackCount>0) TalonManageSide(DIR_LONG, cL, atr, bid, ask, pLow);
   else { talon_anchorLong=0.0;  talon_beLong=false;  talon_peakLong=0.0;  g_state.exec.gripLong=0.0;  g_state.exec.talonStageLong=TG_FORMING; }

   if(cS.stackCount>0) TalonManageSide(DIR_SHORT, cS, atr, bid, ask, pHigh);
   else { talon_anchorShort=0.0; talon_beShort=false; talon_peakShort=0.0; g_state.exec.gripShort=0.0; g_state.exec.talonStageShort=TG_FORMING; }
}

//==================================================================
// ARC PARTIAL — bank a fraction of each leg ONLY when price actually REACHES
// the genuine curve destination (Sym_Dest*), and only after a minimum
// favorable excursion. This no longer fires off the time-evolving arc (which
// sits near the origin early and used to half-close every winner instantly).
// Set InpArcPartialFrac=0 to let the whole position run to the trail.
//==================================================================
void SymphonyArcPartial()
{
   double frac = g_cfg.arcPartialFrac;
   if(frac<=0.0) return;                       // disabled => let it all run

   // RAW/FREE mode: the ARC destination (Sym_DestLong/Short) is Symphony's
   // impulse target, not the authority engine's — banking against it would
   // clip a LETRA/free trade at the wrong level. The raw position TP banks at
   // target instead, and TALON trails the rest. Skip the ARC partial here.
   if(SymRawActive()) return;

   double atr = FalconATR(1); if(atr<=0.0) atr=FalconATR(0);
   if(atr<=0.0) return;
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double destL = Sym_DestLong();
   double destS = Sym_DestShort();
   double minMove = atr*g_cfg.arcPartialMinATR;

   int total=PositionsTotal();
   for(int i=0;i<total;i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=g_cfg.magic) continue;
      long   type=PositionGetInteger(POSITION_TYPE);
      double vol =PositionGetDouble(POSITION_VOLUME);
      double open=PositionGetDouble(POSITION_PRICE_OPEN);
      int    slot=EE_TPSlot((long)ticket);
      if(ee_tpStage[slot]>=1) continue;        // already banked this leg
      if(type==POSITION_TYPE_BUY  && destL>0.0 && bid>=destL && (bid-open)>=minMove)
      { if(EE_ClosePartial(ticket,vol*frac)) ee_tpStage[slot]=1; }
      if(type==POSITION_TYPE_SELL && destS>0.0 && ask<=destS && (open-ask)>=minMove)
      { if(EE_ClosePartial(ticket,vol*frac)) ee_tpStage[slot]=1; }
   }
}

//==================================================================
// CAMPAIGN LOCKOUT DETECTOR — if a campaign was open and now has zero open
// legs, it was closed by the trail-stop / SL (server-side) or the composite
// exit. Engage the re-entry lock for the CURRENT impulse so we don't churn
// straight back into the same leg. Cleared when a fresh impulse forms.
//==================================================================
void SymphonyUpdateCampaignLockout()
{
   int openL=0, openS=0;
   int total=PositionsTotal();
   for(int i=0;i<total;i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=g_cfg.magic) continue;
      if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY) openL++; else openS++;
   }
   if(sym_longCampaignOpen && openL==0)
   { sym_exitedLongAnchor  = (sym_anchorLow >0.0?sym_anchorLow :1.0); sym_longCampaignOpen=false;  }
   if(sym_shortCampaignOpen && openS==0)
   { sym_exitedShortAnchor = (sym_anchorHigh>0.0?sym_anchorHigh:1.0); sym_shortCampaignOpen=false; }
}

//==================================================================
// CAPTURE-AT-DONE — the "no trail, just bank it when the move is finished"
// exit. When the OWNER curve has travelled to its destination (curve
// locator pos >= captureCurvePos) and a position in that direction is in
// profit, close it. No trailing, no breakeven scratch — the trade rides
// the full squeeze and the profit is taken when the curve completes.
// (Losers are still cut by the position SL; runaway TP still backstops.)
//==================================================================
void SymphonyCaptureExit()
{
   if(!g_cfg.captureAtDone) return;
   if(g_state.curveLocator.pos < g_cfg.captureCurvePos) return;   // move not done yet
   int odir = g_state.curveLocator.dir;
   if(odir==DIR_NONE) return;

   int total=PositionsTotal();
   for(int i=total-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=g_cfg.magic) continue;
      double pnl=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
      if(pnl<=0.0) continue;                                       // only CAPTURE profit
      long type=PositionGetInteger(POSITION_TYPE);
      if(type==POSITION_TYPE_BUY  && odir==DIR_LONG)  { if(EE_CloseFull(ticket)) FalconPublish(EVT_EXIT_FIRED, 1); }
      if(type==POSITION_TYPE_SELL && odir==DIR_SHORT) { if(EE_CloseFull(ticket)) FalconPublish(EVT_EXIT_FIRED,-1); }
   }
}

//==================================================================
// MASTER — Symphony manage step (manage open trades, then exits, then entries)
//   Called from the pipeline's execution stage when g_cfg.useSymphony.
//==================================================================
void SymphonyTradeManage()
{
   SymphonyUpdateCampaignLockout(); // detect closed campaigns -> lock the impulse (no churn)
   if(g_cfg.useProfitLadder)        // v3.0 default: live-PnL ladder + BE/trail protection
   {
      MM_RunStopProtection();
      MM_RunProfitLadder();
   }
   if(g_cfg.useTalon)               // optional: TALON curve-convergent grip + ARC partial
   {
      TalonGrip();
      SymphonyArcPartial();
   }
   SymphonyCaptureExit();   // bank profit when the curve reaches its destination (no trailing)
   TG_Manage();             // WIDE-range trades: bank partial + move to BE once well in profit
   SymphonyManageExits();   // composite ARC + institutional + phase reversal exit (suppressed in raw/free)
   SymphonyExecuteTrading();// Phase 3/4 entries
}

#endif // FALCON_SYMPHONY_ENGINE_MQH
//+------------------------------------------------------------------+
