//+------------------------------------------------------------------+
//| Part7_DashboardPanel.mqh                                          |
//| MASTER ALGO - Dashboard & Panel System                            |
//| On-chart Comment-based HUD showing all intelligence readouts      |
//| Panels: Command Center, Fractal Stack, Beliefs, ERF, Curve,       |
//|         Execution Probability, Time Intel, Senseei Verdict        |
//+------------------------------------------------------------------+
#property strict

//==================================================================
// DASHBOARD PANEL SYSTEM
//
// Uses Comment() for on-chart display (MT5 native, no objects needed)
// Organized into logical sections matching the source indicators:
//
//   SECTION 1 - COMMAND CENTER (Senseei verdict + action)
//   SECTION 2 - FRACTAL STACK (per-TF direction + alignment)
//   SECTION 3 - WAVE STATE (phase + progress + targets)
//   SECTION 4 - BELIEFS (6 simultaneous belief scores)
//   SECTION 5 - ERF (energy + resolution + attractor)
//   SECTION 6 - CURVE (F72 life + force + compression)
//   SECTION 7 - EXECUTION (probabilities + directive)
//   SECTION 8 - POSITIONS (open trades + P&L)
//==================================================================

//--- Dashboard update throttle
datetime g_lastDashUpdate = 0;

//--- Bar helper for gauge display
string GaugeBar(double pct, int width = 10)
{
   int filled = (int)MathRound(Clamp(pct, 0, 100) / (100.0 / width));
   string bar = "";
   for(int i = 0; i < width; i++)
      bar += (i < filled) ? "|" : ".";
   return(bar);
}

//--- Direction arrow
string DirArrow(int dir)
{
   if(dir == 1) return("^ BULL");
   if(dir == -1) return("v BEAR");
   return("- FLAT");
}

//--- Short direction symbol
string DirSym(int dir)
{
   if(dir == 1) return("^");
   if(dir == -1) return("v");
   return("-");
}

//--- Action color word (for comment display)
string ActionWord(ENUM_SENSEEI_ACTION action)
{
   switch(action)
   {
      case ACTION_ATTACK: return(">>> ATTACK <<<");
      case ACTION_PREPARE: return(">> PREPARE <<");
      case ACTION_MANAGE_EXIT: return("> MANAGE/EXIT <");
      default: return("-- WAIT --");
   }
}

//--- Resolution state string
string ResolutionStr(ENUM_RESOLUTION res)
{
   switch(res)
   {
      case RES_RESOLVED: return("RESOLVED");
      case RES_PARTIALLY_RESOLVED: return("PARTIAL");
      default: return("UNRESOLVED");
   }
}

//--- EDE state string
string EDEStateStr(ENUM_EDE_STATE s)
{
   switch(s)
   {
      case EDE_ACCUMULATING: return("Accumulating");
      case EDE_RELEASE_INITIAL: return("Release 1");
      case EDE_RELEASE_SECONDARY: return("Release 2");
      case EDE_PURGE: return("Purge");
      case EDE_DELIVERING: return("Delivering");
      case EDE_RESOLVING: return("Resolving");
      default: return("Unknown");
   }
}

//==================================================================
// MAIN DASHBOARD RENDER
//==================================================================
void RenderDashboard()
{
   // Throttle: update once per second max
   datetime now = TimeCurrent();
   if(now == g_lastDashUpdate) return;
   g_lastDashUpdate = now;
   
   string nl = "\n";
   string sep = "----------------------------------------------" + nl;
   string dash = "";
   
   //=== SECTION 1: COMMAND CENTER (Senseei) ===
   dash += "============ MASTER ALGO v1.0 ============" + nl;
   dash += "  " + ActionWord(g_senseei.action) + nl;
   dash += sep;
   dash += "  BIAS: " + DirArrow(g_senseei.masterBias);
   dash += "  |  CONF: " + IntegerToString((int)g_senseei.confidence) + "%";
   dash += "  |  OPP: " + g_senseei.opportunity + nl;
   dash += "  Intent: " + g_senseei.intent;
   dash += "  |  Timing: " + g_senseei.timing + nl;
   dash += "  Align: " + IntegerToString((int)g_senseei.alignment) + "%";
   dash += "  Conflict: " + IntegerToString((int)g_senseei.conflict) + "%";
   dash += "  Threat: " + IntegerToString((int)g_senseei.threat) + "%" + nl;
   dash += sep;
   
   //=== SECTION 2: FRACTAL STACK ===
   dash += "  FRACTAL STACK  [" + GaugeBar(g_fractalStack.score) + "] ";
   dash += IntegerToString((int)g_fractalStack.score) + "%" + nl;
   dash += "  M1:" + DirSym(g_structure[TF_M1].direction);
   dash += "  M3:" + DirSym(g_structure[TF_M3].direction);
   dash += "  M5:" + DirSym(g_structure[TF_M5].direction);
   dash += "  M15:" + DirSym(g_structure[TF_M15].direction);
   dash += "  H1:" + DirSym(g_structure[TF_H1].direction);
   dash += "  H4:" + DirSym(g_structure[TF_H4].direction) + nl;
   dash += "  Context: " + IntegerToString((int)g_fractalStack.contextScore) + "%";
   dash += "  |  Dir: " + DirArrow(g_fractalStack.direction) + nl;
   dash += sep;
   
   //=== SECTION 3: WAVE STATE ===
   dash += "  WAVE: " + g_currentDisplayPhase + nl;
   dash += "  Progress: [" + GaugeBar(g_waveProgress) + "] " + IntegerToString((int)g_waveProgress) + "%" + nl;
   dash += "  Direction: " + DirArrow(g_direction);
   dash += "  |  Mode: " + IntegerToString(g_mode) + nl;
   
   if(g_flipTop > 0 && g_flipBot > 0)
   {
      dash += "  FlipZone: " + DoubleToString(g_flipBot, 2) + " - " + DoubleToString(g_flipTop, 2) + nl;
   }
   if(g_structure[TF_M5].target > 0)
   {
      dash += "  Target: " + DoubleToString(g_structure[TF_M5].target, 2);
      dash += "  |  Invalid: " + DoubleToString(g_structure[TF_M5].invalidation, 2) + nl;
   }
   dash += "  Cycle: " + IntegerToString(g_entryCycle);
   dash += "  |  Depth: " + IntegerToString(g_waveDepth);
   dash += "  |  Recursive: " + (g_isRecursive ? "Yes" : "No") + nl;
   dash += "  PhaseConf: " + IntegerToString((int)g_phaseConfidence) + "%";
   dash += "  |  Integrity: " + IntegerToString((int)g_phaseIntegrity) + "%" + nl;
   dash += sep;
   
   //=== SECTION 4: BELIEFS ===
   dash += "  BELIEFS (simultaneous)" + nl;
   dash += "  Expansion:  [" + GaugeBar(g_beliefs.expansion, 8) + "] " + IntegerToString((int)g_beliefs.expansion) + nl;
   dash += "  Convexity:  [" + GaugeBar(g_beliefs.convexity, 8) + "] " + IntegerToString((int)g_beliefs.convexity) + nl;
   dash += "  Creation:   [" + GaugeBar(g_beliefs.creation, 8) + "] " + IntegerToString((int)g_beliefs.creation) + nl;
   dash += "  Absorption: [" + GaugeBar(g_beliefs.absorption, 8) + "] " + IntegerToString((int)g_beliefs.absorption) + nl;
   dash += "  Retrace:    [" + GaugeBar(g_beliefs.retracement, 8) + "] " + IntegerToString((int)g_beliefs.retracement) + nl;
   dash += "  DemReturn:  [" + GaugeBar(g_beliefs.demandReturn, 8) + "] " + IntegerToString((int)g_beliefs.demandReturn) + nl;
   dash += "  Hypothesis: " + g_primaryHypothesis + nl;
   dash += "  Predict: " + g_expectedNextPhase + " (" + IntegerToString((int)g_expectedNextProb) + "%)" + nl;
   dash += "  ModelConf: " + IntegerToString((int)g_modelConfidence) + "%";
   dash += "  |  Reliability: " + IntegerToString((int)g_predReliability) + "%" + nl;
   dash += sep;
   
   //=== SECTION 5: ENERGY RESOLUTION FRAMEWORK ===
   dash += "  ERF - ENERGY FRAMEWORK" + nl;
   dash += "  State: " + EDEStateStr(g_erf.edeState) + nl;
   dash += "  Energy In:   [" + GaugeBar(g_erf.expansionEnergy, 8) + "] " + IntegerToString((int)g_erf.expansionEnergy) + nl;
   dash += "  Dissipated:  [" + GaugeBar(g_erf.dissipatedEnergy, 8) + "] " + IntegerToString((int)g_erf.dissipatedEnergy) + nl;
   dash += "  Residual:    [" + GaugeBar(g_erfResidualEnergy, 8) + "] " + IntegerToString((int)g_erfResidualEnergy) + nl;
   dash += "  DissipProg:  [" + GaugeBar(g_erf.dissipationProgress, 8) + "] " + IntegerToString((int)g_erf.dissipationProgress) + "%" + nl;
   dash += "  Resolution: " + ResolutionStr(g_erf.resolutionState);
   dash += "  |  RecCompl: " + IntegerToString((int)g_erf.recursiveCompletion) + "%" + nl;
   dash += "  Attractor: " + g_erfAttractorLabel;
   if(g_erfPrimaryAttractorPrice > 0)
      dash += " @ " + DoubleToString(g_erfPrimaryAttractorPrice, 2);
   dash += nl;
   dash += "  AttractorScore: " + IntegerToString((int)g_erfPrimaryAttractorScore) + "%";
   dash += "  |  TradeReady: " + IntegerToString((int)g_erfTradeReadiness) + "%" + nl;
   dash += "  ERF Gate: " + (g_erf.entryGateOpen ? "OPEN" : "CLOSED") + nl;
   dash += sep;
   
   //=== SECTION 6: CURVE (F72) ===
   dash += "  F72 CURVE  |  " + g_curveAliveStatus + nl;
   dash += "  Life:  [" + GaugeBar(g_curveLife, 8) + "] " + IntegerToString((int)g_curveLife) + nl;
   dash += "  Force: [" + GaugeBar(g_curveForce, 8) + "] " + IntegerToString((int)g_curveForce);
   dash += "  " + g_curveForceState + nl;
   dash += "  Compress: [" + GaugeBar(g_curve.compression, 8) + "] " + IntegerToString((int)g_curve.compression) + nl;
   dash += "  Maturity: [" + GaugeBar(g_curve.maturity, 8) + "] " + IntegerToString((int)g_curve.maturity) + nl;
   if(g_curve.origin > 0)
      dash += "  Origin: " + DoubleToString(g_curve.origin, 2) + "  Extreme: " + DoubleToString(g_curve.extreme, 2) + nl;
   dash += "  DispATR: " + DoubleToString(g_curve.dispATR, 1) + nl;
   dash += sep;
   
   //=== SECTION 7: EXECUTION PROBABILITY ===
   dash += "  EXECUTION PROB V2" + nl;
   dash += "  Directive: " + g_execProb.directive + nl;
   dash += "  Continue:  " + IntegerToString((int)g_execProb.continuation) + "%";
   dash += "  |  Reversal: " + IntegerToString((int)g_execProb.reversal) + "%" + nl;
   dash += "  Expansion: " + IntegerToString((int)g_execProb.expansion) + "%";
   dash += "  |  Creation: " + IntegerToString((int)g_execProb.creation) + "%" + nl;
   dash += "  Absorb:    " + IntegerToString((int)g_execProb.absorption) + "%";
   dash += "  |  StandDwn: " + IntegerToString((int)g_execProb.standDown) + "%" + nl;
   dash += nl;
   dash += "  DIRECTION: " + g_liveDirective + nl;
   dash += "  BuyProb: " + IntegerToString((int)g_buyProb) + "%";
   dash += "  |  SellProb: " + IntegerToString((int)g_sellProb) + "%";
   dash += "  |  Edge: " + DoubleToString(g_netEdge, 1) + nl;
   dash += sep;
   
   //=== SECTION 8: TIME INTELLIGENCE ===
   dash += "  TIME INTEL" + nl;
   dash += "  Direction: " + DirArrow(g_timeIntel.timeDirection);
   dash += "  |  Align: " + IntegerToString((int)g_timeIntel.timeAlignment) + "%" + nl;
   dash += "  H1 Timing: " + g_timeIntel.h1Timing;
   dash += "  |  H1 Hi:" + (g_timeIntel.h1HighTaken ? "DONE" : "open");
   dash += "  Lo:" + (g_timeIntel.h1LowTaken ? "DONE" : "open") + nl;
   dash += sep;
   
   //=== SECTION 9: MULTI-TF WAVE PROGRESS ===
   dash += "  MTF WAVE PROGRESS" + nl;
   dash += "  M1:  " + PhaseToString(g_structure[TF_M1].phase) + "  [" + GaugeBar(g_structure[TF_M1].waveProgress, 6) + "]" + nl;
   dash += "  M3:  " + PhaseToString(g_structure[TF_M3].phase) + "  [" + GaugeBar(g_structure[TF_M3].waveProgress, 6) + "]" + nl;
   dash += "  M5:  " + PhaseToString(g_structure[TF_M5].phase) + "  [" + GaugeBar(g_structure[TF_M5].waveProgress, 6) + "]" + nl;
   dash += "  M15: " + PhaseToString(g_structure[TF_M15].phase) + "  [" + GaugeBar(g_structure[TF_M15].waveProgress, 6) + "]" + nl;
   dash += "  H1:  " + PhaseToString(g_structure[TF_H1].phase) + "  [" + GaugeBar(g_structure[TF_H1].waveProgress, 6) + "]" + nl;
   dash += "  H4:  " + PhaseToString(g_structure[TF_H4].phase) + "  [" + GaugeBar(g_structure[TF_H4].waveProgress, 6) + "]" + nl;
   dash += sep;
   
   //=== SECTION 10: OPEN POSITIONS ===
   dash += "  POSITIONS" + nl;
   int posCount = CountOurPositions();
   int longs = CountOurPositions(1);
   int shorts = CountOurPositions(-1);
   dash += "  Total: " + IntegerToString(posCount);
   dash += "  |  Longs: " + IntegerToString(longs);
   dash += "  |  Shorts: " + IntegerToString(shorts) + nl;
   
   // Total P&L
   double totalPnl = 0;
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      totalPnl += PositionGetDouble(POSITION_PROFIT) + 
                  PositionGetDouble(POSITION_SWAP) + 
                  PositionGetDouble(POSITION_COMMISSION);
   }
   dash += "  Floating P&L: " + DoubleToString(totalPnl, 2) + nl;
   dash += "  Armed: " + (g_engineArmed ? "YES" : "NO (locked)") + nl;
   dash += sep;
   
   //=== SECTION 11: NARRATIVE ===
   dash += "  NARRATIVE" + nl;
   dash += "  " + g_marketNarrative + nl;
   dash += "  " + g_actionNarrative + nl;
   dash += "==========================================" + nl;
   
   // Render
   Comment(dash);
}

//==================================================================
// CHART OBJECTS: Key price levels (optional visual overlay)
//==================================================================
void UpdateChartLevels()
{
   // Primary Attractor line
   if(g_erfPrimaryAttractorPrice > 0)
   {
      string name = "MASTER_ATTRACTOR";
      if(ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_HLINE, 0, 0, g_erfPrimaryAttractorPrice);
      else
         ObjectSetDouble(0, name, OBJPROP_PRICE, g_erfPrimaryAttractorPrice);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrGold);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetString(0, name, OBJPROP_TEXT, "Attractor " + IntegerToString((int)g_erfPrimaryAttractorScore) + "%");
   }
   
   // M5 Target line
   double m5Target = g_structure[TF_M5].target;
   if(m5Target > 0)
   {
      string name = "MASTER_TARGET";
      if(ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_HLINE, 0, 0, m5Target);
      else
         ObjectSetDouble(0, name, OBJPROP_PRICE, m5Target);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrDodgerBlue);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetString(0, name, OBJPROP_TEXT, "M5 Target");
   }
   
   // M5 Invalidation line
   double m5Inv = g_structure[TF_M5].invalidation;
   if(m5Inv > 0)
   {
      string name = "MASTER_INVALID";
      if(ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_HLINE, 0, 0, m5Inv);
      else
         ObjectSetDouble(0, name, OBJPROP_PRICE, m5Inv);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetString(0, name, OBJPROP_TEXT, "M5 Origin/Invalid");
   }
   
   // Flip Zone box (top/bot)
   if(g_flipTop > 0 && g_flipBot > 0)
   {
      string nameT = "MASTER_FLIP_TOP";
      string nameB = "MASTER_FLIP_BOT";
      
      if(ObjectFind(0, nameT) < 0)
         ObjectCreate(0, nameT, OBJ_HLINE, 0, 0, g_flipTop);
      else
         ObjectSetDouble(0, nameT, OBJPROP_PRICE, g_flipTop);
      ObjectSetInteger(0, nameT, OBJPROP_COLOR, clrMediumPurple);
      ObjectSetInteger(0, nameT, OBJPROP_STYLE, STYLE_DASHDOT);
      ObjectSetInteger(0, nameT, OBJPROP_WIDTH, 1);
      
      if(ObjectFind(0, nameB) < 0)
         ObjectCreate(0, nameB, OBJ_HLINE, 0, 0, g_flipBot);
      else
         ObjectSetDouble(0, nameB, OBJPROP_PRICE, g_flipBot);
      ObjectSetInteger(0, nameB, OBJPROP_COLOR, clrMediumPurple);
      ObjectSetInteger(0, nameB, OBJPROP_STYLE, STYLE_DASHDOT);
      ObjectSetInteger(0, nameB, OBJPROP_WIDTH, 1);
   }
}

//==================================================================
// CLEANUP CHART OBJECTS
//==================================================================
void CleanupChartObjects()
{
   ObjectDelete(0, "MASTER_ATTRACTOR");
   ObjectDelete(0, "MASTER_TARGET");
   ObjectDelete(0, "MASTER_INVALID");
   ObjectDelete(0, "MASTER_FLIP_TOP");
   ObjectDelete(0, "MASTER_FLIP_BOT");
}

//==================================================================
// MASTER DASHBOARD UPDATE
//==================================================================
void UpdateDashboard()
{
   RenderDashboard();
   UpdateChartLevels();
}

//+------------------------------------------------------------------+
