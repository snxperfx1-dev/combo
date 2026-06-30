//+------------------------------------------------------------------+
//|  FALCON OS — Intelligence : WaveCycleIntel.mqh                  |
//|                                                                  |
//|  THE COMPARATIVE WAVE FRAMEWORK (S12 Wave Intelligence becomes   |
//|  the REFEREE). Don't replace the phase engine — run THREE wave-  |
//|  cycle engines on the SAME shared observations and let the market |
//|  decide which has the highest predictive power:                  |
//|                                                                  |
//|        MARKET ENGINE  (shared observations once / bar)           |
//|              │                                                   |
//|     ┌────────┼────────┐                                          |
//|   LETRA    F16      SYMPHONY                                     |
//|   Eng 1A   Eng 8/F72 Phase Engine                               |
//|     └────────┼────────┘                                          |
//|        Wave Intelligence (referee: compare / validate / score)   |
//|              │                                                   |
//|        Decision & Execution                                      |
//|                                                                  |
//|  Each engine emits a NORMALIZED forecast (phase · stage · dir ·  |
//|  maturity · objective · invalidation · confidence · next event)  |
//|  into g_state.cycles[]. The referee (Part C, below) tracks each   |
//|  engine's demonstrated accuracy and forms a consensus / best.    |
//|                                                                  |
//|  THIS FILE reads g_state only (LETRA + F16 lenses + referee).    |
//|  The Symphony cycle is computed inside SymphonyEngine.mqh where   |
//|  the sym_* phase state lives. Include AFTER CurveLocator.mqh.     |
//+------------------------------------------------------------------+
#ifndef FALCON_WAVE_CYCLE_INTEL_MQH
#define FALCON_WAVE_CYCLE_INTEL_MQH

#include "../Kernel/FalconState.mqh"
#include "../Kernel/FalconConfig.mqh"
#include "../Kernel/FalconSeries.mqh"
#include "../Kernel/FalconEventBus.mqh"

//==================================================================
// NORMALIZATION HELPERS — shared across all three engines so they are
// judged on the SAME yardstick.
//==================================================================
// Fill the entry-trigger fields from the just-computed stage + the
// previous bar's stage (edge detection). A return (CYC_RETURN) is the
// P3 analog; a breakout (CYC_BREAKOUT) is the P4 analog.
void Cycle_FillEntry(WaveCycle &cy,const int prevStage)
{
   cy.prevStage  = prevStage;
   cy.entryArmed = (cy.stage==CYC_RETURN || cy.stage==CYC_BREAKOUT) && cy.direction!=DIR_NONE;
   cy.entryEdge  = cy.entryArmed && (prevStage != cy.stage);
   cy.entryKind  = (cy.stage==CYC_BREAKOUT ? 4 : cy.stage==CYC_RETURN ? 3 : 0);
   cy.entryDir   = cy.entryArmed ? cy.direction : DIR_NONE;
}

// carry referee-learned performance forward (compute steps rebuild the
// descriptive fields each bar but must NOT wipe accumulated accuracy)
void Cycle_CarryPerf(WaveCycle &cy,const WaveCycle &prev)
{
   cy.accuracy    = prev.accuracy;
   cy.objAccuracy = prev.objAccuracy;
   cy.avgLeadBars = prev.avgLeadBars;
   cy.samples     = prev.samples;
   cy.wins        = prev.wins;
}

//==================================================================
// ENGINE 1 — LETRA wave cycle (the per-TF fixed-structure lifecycle).
//   Reads the NATIVE LETRA wave FSM (g_state.wave) BEFORE any phase
//   authority overwrites it. me_pst lifecycle 0..14 -> normalized
//   stage + canonical phase.
//==================================================================
void CycleLetra_Compute()
{
   WaveCycle cy; ZeroMemory(cy);
   Cycle_CarryPerf(cy, g_state.cycles[ENG_LETRA]);
   int prevStage = g_state.cycles[ENG_LETRA].stage;

   FalconWave w = g_state.wave;   // native LETRA at this point in the pipeline
   int pst = w.phase;             // 0..14 lifecycle
   int dir = w.direction;

   cy.engineId  = ENG_LETRA;
   cy.direction = dir;
   cy.maturity  = w.completion;
   cy.objective = w.objective;
   cy.invalidation = w.origin;
   cy.confidence = FalconClamp(w.confidence*0.6 + w.strength*0.4, 0, 100);

   int stage, ph; string nxt;
   switch(pst)
   {
      case 1:  stage=CYC_EXPANSION; ph=PH_EXPANSION;    nxt="decay -> retrace"; break;
      case 2:  stage=CYC_RETRACE;   ph=PH_RETRACEMENT;  nxt="counter-impulse / transfer"; break;
      case 3:  stage=CYC_RETURN;    ph=(dir==DIR_LONG?PH_DEMAND_RETURN:PH_SUPPLY_RETURN); nxt="confirm BOS continuation"; break;
      case 4:  stage=CYC_BREAKOUT;  ph=(dir==DIR_LONG?PH_NEW_HIGH:PH_NEW_LOW);  nxt="extend to objective"; break;
      case 5:  case 6: stage=CYC_BREAKOUT; ph=(dir==DIR_LONG?PH_NEW_HIGH:PH_NEW_LOW); nxt="post-extreme recursion"; break;
      case 7:  stage=CYC_RETRACE;   ph=PH_RETRACEMENT;  nxt="transfer of ownership"; break;
      case 8:  stage=CYC_RETRACE;   ph=PH_TRANSITION;   nxt="return to flip zone"; break;
      case 9:  stage=CYC_RETURN;    ph=(dir==DIR_LONG?PH_DEMAND_RETURN:PH_SUPPLY_RETURN); nxt="impulse from flip"; break;
      case 10: stage=CYC_BREAKOUT;  ph=(dir==DIR_LONG?PH_NEW_HIGH:PH_NEW_LOW);  nxt="continuation to target"; break;
      case 11: stage=CYC_RETRACE;   ph=PH_LIQUIDATION;  nxt="opposing BOS / reversal risk"; break;
      case 12: stage=CYC_RETRACE;   ph=PH_LIQUIDATION;  nxt="liquidity sweep"; break;
      case 13: case 14: stage=CYC_RETURN; ph=(dir==DIR_LONG?PH_DEMAND_RETURN:PH_SUPPLY_RETURN); nxt="terminal reversal confirm"; break;
      default: stage=CYC_NONE;      ph=PH_TRANSITION;   nxt="awaiting impulse"; break;
   }
   cy.stage      = stage;
   cy.phase      = ph;
   cy.phaseLabel = FalconPhaseStr(ph);
   cy.nextEvent  = nxt;
   Cycle_FillEntry(cy, prevStage);

   g_state.cycles[ENG_LETRA] = cy;
}

//==================================================================
// ENGINE 2 — F16 wave cycle (the recursive curve-tree node lens).
//   Phases EMERGE from the owning node (Principle 1). Reads the F72
//   tree summary in g_state.curve (populated by CurveTree.mqh).
//==================================================================
bool CY_Contains(const string s,const string sub){ return(StringFind(s,sub)>=0); }

void CycleF16_Compute()
{
   WaveCycle cy; ZeroMemory(cy);
   Cycle_CarryPerf(cy, g_state.cycles[ENG_F16]);
   int prevStage = g_state.cycles[ENG_F16].stage;

   FalconCurve cu = g_state.curve;
   int dir   = cu.ownerNodeDir!=DIR_NONE ? cu.ownerNodeDir : cu.ownerDir;
   string st = cu.ownerNodeState;
   double org= cu.ownerNodeOrigin;
   double ext= cu.ownerNodeExtreme;

   cy.engineId  = ENG_F16;
   cy.direction = dir;
   cy.maturity  = FalconClamp(cu.ownerNodeEnergy, 0, 100);
   cy.invalidation = org;
   // owner-curve destination: project the leg beyond its extreme
   double leg = (org!=0.0 && ext!=0.0) ? MathAbs(ext-org) : 0.0;
   cy.objective = (ext!=0.0 && leg>0.0) ? (dir==DIR_LONG ? ext+leg*0.5 : ext-leg*0.5)
                                        : g_state.wave.objective;
   cy.confidence= FalconClamp(cu.ownerNodeEnergy*0.55 + cu.narrative*0.30 + (cu.recursionComplete?0:15.0), 0, 100);

   int stage, ph; string nxt;
   if(CY_Contains(st,"New High"))      { stage=CYC_BREAKOUT; ph=PH_NEW_HIGH;  nxt="extend / recursion budget"; }
   else if(CY_Contains(st,"New Low"))  { stage=CYC_BREAKOUT; ph=PH_NEW_LOW;   nxt="extend / recursion budget"; }
   else if(CY_Contains(st,"Climax"))   { stage=CYC_BREAKOUT; ph=(dir==DIR_LONG?PH_NEW_HIGH:PH_NEW_LOW); nxt="exhaustion / transfer"; }
   else if(CY_Contains(st,"Origin"))   { stage=CYC_RETURN;   ph=(dir==DIR_LONG?PH_DEMAND_RETURN:PH_SUPPLY_RETURN); nxt="impulse off node origin"; }
   else if(CY_Contains(st,"recursive")){ stage=CYC_RETURN;   ph=(dir==DIR_LONG?PH_DEMAND_RETURN:PH_SUPPLY_RETURN); nxt="child curve resolves"; }
   else if(CY_Contains(st,"Retracement")){ stage=CYC_RETRACE; ph=PH_RETRACEMENT; nxt="return to demand/supply"; }
   else if(CY_Contains(st,"Induction")){ stage=CYC_EXPANSION; ph=PH_EXP_INDUCTION; nxt="liquidity engineered"; }
   else if(CY_Contains(st,"Liquidity")){ stage=CYC_EXPANSION; ph=PH_EXP_LIQUIDITY; nxt="sweep then continue"; }
   else if(CY_Contains(st,"Expansion")){ stage=CYC_EXPANSION; ph=PH_EXPANSION;  nxt="convexity develops"; }
   else                                { stage=CYC_NONE;     ph=PH_TRANSITION;  nxt="awaiting owner node"; }

   cy.stage      = stage;
   cy.phase      = ph;
   cy.phaseLabel = (st!="" && st!="—") ? st : FalconPhaseStr(ph);
   cy.nextEvent  = nxt;
   Cycle_FillEntry(cy, prevStage);

   g_state.cycles[ENG_F16] = cy;
}

#endif // FALCON_WAVE_CYCLE_INTEL_MQH
//+------------------------------------------------------------------+
