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
void SymphonyUpdatePhases()
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
      if(retrS > g_cfg.retrMax || retrS < 0.0)
         phaseTmpS = 0;
      else if(closeNow <= sym_anchorLow)
         phaseTmpS = 4;
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
      if(retrL > g_cfg.retrMax || retrL < 0.0)
         phaseTmpL = 0;
      else if(closeNow >= sym_anchorHigh)
         phaseTmpL = 4;
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

   // ---- Symphony is the SINGLE phase/direction source of truth: map its
   //      impulse+phase model onto the canonical FalconWave so the whole OS
   //      (memory/intel/decision/execution/viz) reads the SAME phase engine. ----
   SymphonyBridgeToWave();
}

//==================================================================
// ENTRIES — Phase 3 + Phase 4 only (long & short)   [Symphony]
//   Stop placement: anchorLow/High ± atr*0.25 (Symphony precision).
//   Reuses EE_SendMarketOrder / EE_IsTradeTime from ExecutionEngine.
//==================================================================
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

   bool L3 = (sym_mode==1  && sym_phaseLong ==3);
   bool L4 = (sym_mode==1  && sym_phaseLong ==4);
   bool S3 = (sym_mode==-1 && sym_phaseShort==3);
   bool S4 = (sym_mode==-1 && sym_phaseShort==4);

   double impL = sym_anchorHigh - sym_anchorLow;
   double impS = sym_anchorHigh - sym_anchorLow;

   // LONG P3
   if(L3 && sym_lastLongTradeTime!=barTime)
   {
      double entry = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double sl    = sym_anchorLow - atrNow*0.25;
      double lots  = Sym_ComputeLots(riskCash,entry,sl);
      if(sl>0 && entry>sl && lots>0)
      {
         if(EE_SendMarketOrder(+1,lots,sl,"SYM P3 Long"))
         {
            sym_lastLongTradeTime=barTime;
            g_state.exec.entry=entry; g_state.exec.stop=sl; g_state.exec.lots=lots; g_state.exec.riskCash=riskCash;
         }
      }
   }

   // LONG P4
   if(L4 && sym_lastLongTradeTime!=barTime && impL>0)
   {
      bool breakout = (closeNow>sym_anchorHigh || closeNow>gHigh[shiftNow+1] + 0.20*atrNow);
      if(breakout)
      {
         double entry = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         double sl    = sym_anchorLow - atrNow*0.25;
         double lots  = Sym_ComputeLots(riskCash,entry,sl);
         if(sl>0 && entry>sl && lots>0)
         {
            if(EE_SendMarketOrder(+1,lots,sl,"SYM P4 Long"))
            {
               sym_lastLongTradeTime=barTime;
               g_state.exec.entry=entry; g_state.exec.stop=sl; g_state.exec.lots=lots; g_state.exec.riskCash=riskCash;
            }
         }
      }
   }

   // SHORT P3
   if(S3 && sym_lastShortTradeTime!=barTime)
   {
      double entry = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double sl    = sym_anchorHigh + atrNow*0.25;
      double lots  = Sym_ComputeLots(riskCash,entry,sl);
      if(sl>0 && sl>entry && lots>0)
      {
         if(EE_SendMarketOrder(-1,lots,sl,"SYM P3 Short"))
         {
            sym_lastShortTradeTime=barTime;
            g_state.exec.entry=entry; g_state.exec.stop=sl; g_state.exec.lots=lots; g_state.exec.riskCash=riskCash;
         }
      }
   }

   // SHORT P4
   if(S4 && sym_lastShortTradeTime!=barTime && impS>0)
   {
      bool breakout = (closeNow<sym_anchorLow || closeNow<gLow[shiftNow+1] - 0.20*atrNow);
      if(breakout)
      {
         double entry = SymbolInfoDouble(_Symbol,SYMBOL_BID);
         double sl    = sym_anchorHigh + atrNow*0.25;
         double lots  = Sym_ComputeLots(riskCash,entry,sl);
         if(sl>0 && sl>entry && lots>0)
         {
            if(EE_SendMarketOrder(-1,lots,sl,"SYM P4 Short"))
            {
               sym_lastShortTradeTime=barTime;
               g_state.exec.entry=entry; g_state.exec.stop=sl; g_state.exec.lots=lots; g_state.exec.riskCash=riskCash;
            }
         }
      }
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

   int    shiftNow = 1;
   double closeNow = gClose[shiftNow];
   double atrNow   = FalconATR(shiftNow);
   if(atrNow<=0.0) atrNow=FalconATR(0);

   // --- 1) ARC exhaustion flags ---
   bool arcExhaustLong  = (sym_mode == 1  && sym_arcLong  > 0.0 && closeNow >= (sym_arcLong  - g_cfg.arcToleranceAtr * atrNow));
   bool arcExhaustShort = (sym_mode == -1 && sym_arcShort > 0.0 && closeNow <= (sym_arcShort + g_cfg.arcToleranceAtr * atrNow));

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
}

//==================================================================
// MASTER — Symphony manage step (exits first, then entries)
//   Called from the pipeline's execution stage when g_cfg.useSymphony.
//==================================================================
void SymphonyTradeManage()
{
   SymphonyManageExits();
   SymphonyExecuteTrading();
}

#endif // FALCON_SYMPHONY_ENGINE_MQH
//+------------------------------------------------------------------+
