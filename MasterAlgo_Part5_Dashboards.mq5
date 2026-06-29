//+------------------------------------------------------------------+
//| MasterAlgo_Part5_Dashboards.mq5                                  |
//| Part 5: Dashboard Panels and Comment Display                     |
//| Contains: UpdateDashboards() called once per new bar,            |
//|           Comment()-based text HUD (13 sections),                |
//|           On-chart horizontal line markers for key levels,       |
//|           f_gauge() helper for text progress bars                |
//| This file is #included after Parts 1, 2, 3, and 4               |
//+------------------------------------------------------------------+
#property strict

//==================================================================
// DASHBOARD CONFIGURATION
//==================================================================
input color   InpDash_TargetColor   = clrGold;       // Target line color
input color   InpDash_EntryColor    = clrLime;       // Entry zone color
input color   InpDash_StopColor     = clrRed;        // Stop level color
input color   InpDash_SwingColor    = clrDodgerBlue; // Swing level color
input color   InpDash_HTFColor      = clrMagenta;    // HTF level color

//==================================================================
// HELPER: f_gauge - Text gauge bar for 0-100% display
// Returns string like "[========  ]" proportional to pct
//==================================================================
string f_gauge(double pct)
{
   if(pct < 0.0) pct = 0.0;
   if(pct > 100.0) pct = 100.0;
   int filled = (int)MathRound(pct / 10.0);
   int empty  = 10 - filled;
   string bar = "[";
   for(int i = 0; i < filled; i++) bar += "=";
   for(int i = 0; i < empty; i++)  bar += " ";
   bar += "]";
   return(bar);
}

//==================================================================
// HELPER: Direction arrow string
//==================================================================
string f_dirArrow(int dir)
{
   if(dir == 1)  return("BULL ^");
   if(dir == -1) return("BEAR v");
   return("FLAT -");
}

//==================================================================
// HELPER: Short direction string
//==================================================================
string f_dirStr(int dir)
{
   if(dir == 1)  return("BULL");
   if(dir == -1) return("BEAR");
   return("FLAT");
}

//==================================================================
// HELPER: Timeframe name string
//==================================================================
string f_tfName(int idx)
{
   switch(idx)
   {
      case 0: return("M1");
      case 1: return("M3");
      case 2: return("M5");
      case 3: return("M15");
      case 4: return("H1");
      case 5: return("H4");
   }
   return("??");
}

//==================================================================
// HELPER: Control state from fractal stack score
//==================================================================
string f_controlState(double score)
{
   if(score >= 83.0) return("DOMINANT");
   if(score >= 66.0) return("STABLE");
   if(score >= 50.0) return("CONTESTED");
   return("FRAGMENTED");
}

//==================================================================
// HELPER: Transfer state from fractal directions
//==================================================================
string f_transferState()
{
   // Check if all TFs cascade same direction
   int same = 0;
   int refDir = g_se[TF_H4].dir;
   for(int i = 0; i < SE_TF_COUNT; i++)
      if(g_se[i].dir == refDir && refDir != 0) same++;

   if(same >= 5) return("FULL CASCADE");
   if(same >= 3) return("ROTATING");
   return("FORMING");
}

//==================================================================
// HELPER: Curve energy state string
//==================================================================
string f_curveEnergyState()
{
   double eIn  = g_curve.eIn;
   double eRes = g_curve.eRes;
   double conv = g_curve.convex;
   double mat  = g_curve.maturity;

   if(mat >= 85.0 || eRes < 10.0) return("TERMINAL");
   if(conv >= 60.0 && eRes < 30.0) return("TRANSFERRING");
   if(eRes < eIn * 0.4) return("DISSIPATING");
   if(eIn > 50.0 && eRes > 50.0) return("EXPANDING");
   return("CHARGING");
}

//==================================================================
// HELPER: Opportunity grade string
//==================================================================
string f_opportunityGrade(double opp)
{
   if(opp >= 82.0) return("EXCEPTIONAL");
   if(opp >= 62.0) return("STRONG");
   if(opp >= 40.0) return("GOOD");
   if(opp >= 20.0) return("DEVELOPING");
   return("NONE");
}

//==================================================================
// HELPER: Threat state string
//==================================================================
string f_threatState(double threat)
{
   if(threat >= 70.0) return("DANGER");
   if(threat >= 50.0) return("ELEVATED");
   if(threat >= 30.0) return("CAUTION");
   return("CLEAR");
}

//==================================================================
// HELPER: Destination war analysis
//==================================================================
string f_destWarState()
{
   double att = g_eae_primaryAttractorScore;
   if(att >= 70.0) return("MAGNET");
   if(att >= 45.0) return("COMPETING");
   if(att >= 20.0) return("UNSTABLE");
   return("NONE");
}

//==================================================================
// ON-CHART LEVEL MANAGEMENT
// Creates/updates horizontal lines for key price levels
//==================================================================
void Dash_SetHLine(string name, double price, color clr, int style, int width)
{
   if(price <= 0.0)
   {
      ObjectDelete(0, name);
      return;
   }

   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   }
   else
   {
      ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   }

   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, name + ": " + DoubleToString(price, _Digits));
}

//==================================================================
// ON-CHART LABEL MANAGEMENT
//==================================================================
void Dash_SetLabel(string name, int x, int y, string text, color clr, int fontSize)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   }

   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

//==================================================================
// CLEAN UP CHART OBJECTS ON DEINIT
//==================================================================
void Dash_Cleanup()
{
   ObjectDelete(0, "DASH_PrimaryTarget");
   ObjectDelete(0, "DASH_SecondaryTarget");
   ObjectDelete(0, "DASH_M5SwingHigh");
   ObjectDelete(0, "DASH_M5SwingLow");
   ObjectDelete(0, "DASH_EntryZone");
   ObjectDelete(0, "DASH_StopLevel");
   ObjectDelete(0, "DASH_DailyHigh");
   ObjectDelete(0, "DASH_DailyLow");
   ObjectDelete(0, "DASH_H1High");
   ObjectDelete(0, "DASH_H1Low");
   ObjectDelete(0, "DASH_Invalidation");
   ObjectDelete(0, "DASH_ARC");
}

//==================================================================
// UPDATE ON-CHART LEVELS
//==================================================================
void Dash_UpdateLevels()
{
   double atr = GetATR(1);

   // Primary target (from M5 SE target)
   Dash_SetHLine("DASH_PrimaryTarget", g_se[TF_M5].target,
                 InpDash_TargetColor, STYLE_DASH, 1);

   // Secondary target (H4 target as secondary destination)
   Dash_SetHLine("DASH_SecondaryTarget", g_se[TF_H4].target,
                 InpDash_HTFColor, STYLE_DOT, 1);

   // M5 swing levels
   Dash_SetHLine("DASH_M5SwingHigh", g_se[TF_M5].swingHigh,
                 InpDash_SwingColor, STYLE_DOT, 1);
   Dash_SetHLine("DASH_M5SwingLow", g_se[TF_M5].swingLow,
                 InpDash_SwingColor, STYLE_DOT, 1);

   // Entry zone (P4 level based on mode direction)
   double entryZone = 0.0;
   if(g_mode == 1 && g_longInducPrice > 0.0)
      entryZone = g_longInducPrice;
   else if(g_mode == -1 && g_shortInducPrice > 0.0)
      entryZone = g_shortInducPrice;
   Dash_SetHLine("DASH_EntryZone", entryZone,
                 InpDash_EntryColor, STYLE_DASHDOTDOT, 1);

   // Stop loss level
   double stopLevel = 0.0;
   if(g_mode == 1 && g_anchorLow > 0.0)
      stopLevel = g_anchorLow - atr * 0.25;
   else if(g_mode == -1 && g_anchorHigh > 0.0)
      stopLevel = g_anchorHigh + atr * 0.25;
   Dash_SetHLine("DASH_StopLevel", stopLevel,
                 InpDash_StopColor, STYLE_SOLID, 2);

   // Daily high/low
   Dash_SetHLine("DASH_DailyHigh", g_timeD.prevHigh,
                 InpDash_HTFColor, STYLE_DOT, 1);
   Dash_SetHLine("DASH_DailyLow", g_timeD.prevLow,
                 InpDash_HTFColor, STYLE_DOT, 1);

   // H1 high/low (current cycle)
   Dash_SetHLine("DASH_H1High", g_timeH1.high,
                 InpDash_SwingColor, STYLE_DOT, 1);
   Dash_SetHLine("DASH_H1Low", g_timeH1.low,
                 InpDash_SwingColor, STYLE_DOT, 1);

   // Invalidation level
   Dash_SetHLine("DASH_Invalidation", g_se[TF_M5].invalidation,
                 InpDash_StopColor, STYLE_DASHDOT, 1);

   // ARC level (long or short depending on mode)
   double arcLvl = (g_mode == 1) ? g_arcLong : (g_mode == -1) ? g_arcShort : 0.0;
   Dash_SetHLine("DASH_ARC", arcLvl,
                 InpDash_TargetColor, STYLE_DASHDOT, 1);
}

//==================================================================
// MAIN DASHBOARD UPDATE FUNCTION
// Called once per new bar from Part 6 (OnTick)
// Builds a comprehensive Comment() string with 13 sections
// and updates on-chart horizontal line markers
//==================================================================
void UpdateDashboards()
{
   // Update chart object levels
   Dash_UpdateLevels();

   // Gather current state for display
   double closeNow = Close[1];
   double atr = GetATR(1);
   double spread = SymbolInfoDouble(_Symbol, SYMBOL_SPREAD) * _Point;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   string nl = "\n";
   string sep = "--------------------------------------------";
   string out = "";

   //==========================================================
   // SECTION 1: HEADER
   //==========================================================
   out += "=== MASTER ALGO v1.0 ===" + nl;
   out += _Symbol + " | " + EnumToString((ENUM_TIMEFRAMES)_Period);
   out += " | Spread: " + DoubleToString(spread, _Digits);
   out += " | Equity: $" + DoubleToString(equity, 2) + nl;
   out += "Time: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES) + nl;
   out += sep + nl;

   //==========================================================
   // SECTION 2: SENSEEI HUD (Chief Strategist)
   //==========================================================
   out += "[SENSEEI - Chief Strategist]" + nl;
   out += "  Master: " + f_dirStr(g_senseei_master);
   out += " | Phase: " + f_phaseStr(g_se[TF_M5].phase) + nl;
   out += "  Progress: " + f_gauge(g_waveProgress) + " " + DoubleToString(g_waveProgress, 0) + "%" + nl;
   out += "  Intent: " + g_senseei_intent;
   out += " | Timing: " + g_senseei_timing + nl;
   out += "  Alignment: " + DoubleToString(g_senseei_alignment, 0) + "%";
   out += " | Conflict: " + DoubleToString(g_senseei_conflict, 0) + "%" + nl;
   out += "  Confidence: " + DoubleToString(g_senseei_confidence, 0) + "%";
   out += " | Threat: " + DoubleToString(g_senseei_threat, 0) + "%" + nl;
   out += "  Opportunity: " + f_opportunityGrade(g_senseei_opportunity);
   out += " (" + DoubleToString(g_senseei_opportunity, 0) + "%)" + nl;
   out += "  ACTION: " + g_senseei_action + nl;
   out += sep + nl;

   //==========================================================
   // SECTION 3: ENGINE READOUT
   //==========================================================
   out += "[ENGINE READOUT]" + nl;
   out += "  Wave: " + f_dirStr(g_se[TF_M5].dir) + " | Phase " + IntegerToString(g_se[TF_M5].phase);
   out += " (" + f_phaseStr(g_se[TF_M5].phase) + ")" + nl;
   out += "  Progress: " + f_gauge(g_waveProgress) + " " + DoubleToString(g_waveProgress, 0) + "%";
   out += " -> Target: " + DoubleToString(g_se[TF_M5].target, _Digits) + nl;
   out += "  Fractal Stack: " + f_dirStr(g_fractalStackDir);
   out += " | Score: " + DoubleToString(g_fractalStackScore, 0) + "%" + nl;
   out += "  Resolution: " + Intel_ResolutionStr();
   out += " | Residual: " + f_gauge(g_re_residualEnergyScore) + " " + DoubleToString(g_re_residualEnergyScore, 0) + "%" + nl;
   out += "  Attractor: " + DoubleToString(g_eae_primaryAttractorPrice, _Digits);
   out += " (" + DoubleToString(g_eae_primaryAttractorScore, 0) + "%) " + g_eae_primaryAttractorLabel + nl;
   out += "  Net Bias: " + f_dirStr(g_fractalStackDir);
   out += " | Invalidation: " + DoubleToString(g_se[TF_M5].invalidation, _Digits) + nl;
   out += "  Mode: " + (g_mode == 1 ? "LONG" : g_mode == -1 ? "SHORT" : "NONE");
   out += " | ERF Suppress: " + (g_erf_suppressRotation ? "YES" : "NO") + nl;
   out += sep + nl;

   //==========================================================
   // SECTION 4: WAVE MATRIX (per-TF narrative)
   //==========================================================
   out += "[WAVE MATRIX - MTF Narrative]" + nl;
   for(int i = 0; i < SE_TF_COUNT; i++)
   {
      out += "  " + f_tfName(i) + ": " + f_dirArrow(g_se[i].dir);
      out += " P" + IntegerToString(g_se[i].phase);
      out += " (" + f_phaseStr(g_se[i].phase) + ")";
      out += " Prog:" + DoubleToString(g_se[i].waveProgress, 0) + "%" + nl;
   }
   out += "  --- Execution Probability ---" + nl;
   out += "  Continuation: " + DoubleToString(g_predScore_Expansion, 0) + "%";
   out += " | Reversal: " + DoubleToString(g_predScore_Retracement, 0) + "%" + nl;
   out += "  Expansion: " + DoubleToString(g_predScore_Expansion, 0) + "%";
   out += " | NewHigh/Low: " + DoubleToString(g_predScore_Creation, 0) + "%" + nl;
   out += "  Absorption: " + DoubleToString(g_predScore_Absorption, 0) + "%";
   out += " | StandDown: " + DoubleToString(g_predScore_DemandReturn, 0) + "%" + nl;
   out += "  Next Phase: " + g_expectedNextPhase;
   out += " (" + DoubleToString(g_expectedNextProb, 0) + "% prob)" + nl;
   out += sep + nl;

   //==========================================================
   // SECTION 5: CONTROL PANEL
   //==========================================================
   out += "[CONTROL PANEL]" + nl;
   out += "  TF Dirs: ";
   for(int i = 0; i < SE_TF_COUNT; i++)
   {
      out += f_tfName(i) + ":" + (g_se[i].dir == 1 ? "^" : g_se[i].dir == -1 ? "v" : "-") + " ";
   }
   out += nl;
   out += "  Authority: " + f_gauge(g_fractalStackScore) + " " + DoubleToString(g_fractalStackScore, 0) + "%" + nl;
   out += "  Control: " + f_controlState(g_fractalStackScore);
   out += " | Transfer: " + f_transferState() + nl;
   out += sep + nl;

   //==========================================================
   // SECTION 6: CURVE ENERGY
   //==========================================================
   out += "[CURVE ENERGY]" + nl;
   out += "  Direction: " + f_dirStr(g_curve.dir);
   out += " | State: " + f_curveEnergyState() + nl;
   out += "  Energy In:    " + f_gauge(g_curve.eIn) + " " + DoubleToString(g_curve.eIn, 0) + "%" + nl;
   out += "  Dissipated:   " + f_gauge(g_curve.eDiss) + " " + DoubleToString(g_curve.eDiss, 0) + "%" + nl;
   out += "  Residual:     " + f_gauge(g_curve.eRes) + " " + DoubleToString(g_curve.eRes, 0) + "%" + nl;
   out += "  Displacement: " + DoubleToString(g_curve.dispATR, 2) + " ATR" + nl;
   out += "  Convexity: " + DoubleToString(g_curve.convex, 0) + "%";
   out += " | Compression: " + DoubleToString(g_curve.compress, 0) + "%";
   out += " | Maturity: " + DoubleToString(g_curve.maturity, 0) + "%" + nl;
   out += sep + nl;

   //==========================================================
   // SECTION 7: CURVE TREE
   //==========================================================
   out += "[CURVE TREE]" + nl;
   out += "  Trade Dir: " + f_dirStr(g_ownerDir);
   out += " | Owner Energy: " + DoubleToString(g_ownerEnergy, 0) + "%" + nl;
   out += "  Depth: " + IntegerToString(g_ownerDepth);
   out += "/" + IntegerToString(g_treeMaxDepth);
   out += " | Live Nodes: " + IntegerToString(g_treeAlive) + nl;

   // Curve coordinates
   double origP = (g_ownerIdx >= 0) ? g_tree[g_ownerIdx].origin : g_curve.origin;
   double extP  = (g_ownerIdx >= 0) ? g_tree[g_ownerIdx].extreme : g_curve.extreme;
   out += "  Coords: " + DoubleToString(origP, _Digits) + " -> ";
   out += DoubleToString(extP, _Digits) + " -> ";
   out += DoubleToString(closeNow, _Digits) + nl;
   out += "  Phase: " + g_ownerState + nl;
   out += "  Force: " + DoubleToString(g_cpForce, 0) + "%";
   out += " | CP: " + g_cpState;
   out += " | Tighten: " + DoubleToString(g_cpTighten, 1) + nl;
   out += "  Trade Alive: " + g_curveLifeState;
   out += " (" + DoubleToString(g_curveLifeScore, 0) + "%)" + nl;
   out += "  Narrative: " + g_narrState;
   out += " (" + DoubleToString(g_narrScore, 0) + "%)";
   out += " | Chain Vitality: " + DoubleToString(g_chainVitality, 0) + "%" + nl;
   out += sep + nl;

   //==========================================================
   // SECTION 8: CAMPAIGN
   //==========================================================
   out += "[CAMPAIGN]" + nl;
   out += "  State: " + g_campaignState;
   out += " | Owner: " + f_dirStr(g_campaignOwnerDir) + nl;
   out += "  Location: " + g_campaignLocation;
   out += " | Budget: " + f_gauge(g_curveBudget) + " " + DoubleToString(g_curveBudget, 0) + "%" + nl;
   out += "  Compression: " + g_cpState;
   out += " | Recursive Depth: " + IntegerToString(g_treeMaxDepth) + nl;
   out += "  Participant Zone: " + g_partZone + nl;
   if(g_part_618 > 0.0)
   {
      out += "  Levels: 0.618=" + DoubleToString(g_part_618, _Digits);
      out += " 0.70=" + DoubleToString(g_part_70, _Digits);
      out += " 0.786=" + DoubleToString(g_part_786, _Digits) + nl;
   }
   out += sep + nl;

   //==========================================================
   // SECTION 9: TIME INTELLIGENCE
   //==========================================================
   out += "[TIME INTELLIGENCE]" + nl;
   // Per-cycle display
   out += "  MN: " + (g_timeMN.bias == 1 ? "^" : g_timeMN.bias == -1 ? "v" : "-");
   out += " Comp:" + DoubleToString(g_timeMN.completion, 0) + "%";
   out += " " + g_timeMN.state + nl;
   out += "  W:  " + (g_timeW.bias == 1 ? "^" : g_timeW.bias == -1 ? "v" : "-");
   out += " Comp:" + DoubleToString(g_timeW.completion, 0) + "%";
   out += " " + g_timeW.state + nl;
   out += "  D:  " + (g_timeD.bias == 1 ? "^" : g_timeD.bias == -1 ? "v" : "-");
   out += " Comp:" + DoubleToString(g_timeD.completion, 0) + "%";
   out += " " + g_timeD.state + nl;
   out += "  H4: " + (g_timeH4.bias == 1 ? "^" : g_timeH4.bias == -1 ? "v" : "-");
   out += " Comp:" + DoubleToString(g_timeH4.completion, 0) + "%";
   out += " " + g_timeH4.state + nl;
   out += "  H1: " + (g_timeH1.bias == 1 ? "^" : g_timeH1.bias == -1 ? "v" : "-");
   out += " Comp:" + DoubleToString(g_timeH1.completion, 0) + "%";
   out += " " + g_timeH1.state + nl;
   out += "  Time Align: " + DoubleToString(g_timeAlign, 0) + "%";
   out += " | Conflict: " + DoubleToString(g_timeConflict, 0) + "%" + nl;
   out += "  H1 Timing: " + g_h1Timing;
   out += " | Overall: " + f_dirStr(g_timeDir) + nl;
   out += sep + nl;

   //==========================================================
   // SECTION 10: EXECUTION COPILOT
   //==========================================================
   out += "[EXECUTION COPILOT]" + nl;
   // Commander verdict from Senseei
   out += "  Verdict: " + g_senseei_action + nl;

   // Trigger type
   string trigType = "NONE";
   if(g_mode == 1 && (g_phaseLong == 3 || g_phaseLong == 4))
      trigType = "Phase " + IntegerToString(g_phaseLong) + " LONG";
   else if(g_mode == -1 && (g_phaseShort == 3 || g_phaseShort == 4))
      trigType = "Phase " + IntegerToString(g_phaseShort) + " SHORT";
   out += "  Trigger: " + trigType + nl;

   // Entry/Stop/Target
   double entryPrice = closeNow;
   double stopPrice = 0.0;
   double targetPrice = g_se[TF_M5].target;
   if(g_mode == 1)
      stopPrice = g_anchorLow - atr * 0.25;
   else if(g_mode == -1)
      stopPrice = g_anchorHigh + atr * 0.25;

   out += "  Entry: " + DoubleToString(entryPrice, _Digits);
   out += " | Stop: " + DoubleToString(stopPrice, _Digits);
   out += " | Target: " + DoubleToString(targetPrice, _Digits) + nl;

   // Risk grade
   string riskGrade = "LOW";
   if(g_senseei_threat >= 60.0) riskGrade = "HIGH";
   else if(g_senseei_threat >= 35.0) riskGrade = "MEDIUM";
   out += "  Risk: " + riskGrade;

   // Current blocker
   string blocker = "NONE";
   if(!IsTradeTime())
      blocker = "OUT OF SESSION";
   else if(StringCompare(g_curveLifeState, "DEAD") == 0)
      blocker = "CURVE DEAD";
   else if(g_liqg_active && !g_liqg_objArrival)
      blocker = "LIQ WAVE ACTIVE";
   else if(g_erf_confidence < InpERF_ReadyThresh)
      blocker = "ERF LOW (" + DoubleToString(g_erf_confidence, 0) + "%)";
   else if(StringCompare(g_senseei_action, "WAIT") == 0)
      blocker = "SENSEEI WAIT";
   out += " | Blocker: " + blocker + nl;
   out += "  Last Entry: " + g_lastEntryReason + nl;
   out += "  Last Exit:  " + g_lastExitReason + nl;
   out += sep + nl;

   //==========================================================
   // SECTION 11: DESTINATION WAR
   //==========================================================
   out += "[DESTINATION WAR]" + nl;
   out += "  Winner: " + DoubleToString(g_eae_primaryAttractorPrice, _Digits);
   out += " | Type: " + g_eae_primaryAttractorLabel + nl;
   out += "  Quality: " + f_opportunityGrade(g_eae_primaryAttractorScore);
   out += " (" + DoubleToString(g_eae_primaryAttractorScore, 0) + "%)" + nl;
   out += "  War State: " + f_destWarState() + nl;

   // Scoreboard of candidates
   out += "  Candidates:" + nl;
   out += "    M5 Target: " + DoubleToString(g_se[TF_M5].target, _Digits) + nl;
   out += "    H1 Target: " + DoubleToString(g_se[TF_H1].target, _Digits) + nl;
   out += "    H4 Target: " + DoubleToString(g_se[TF_H4].target, _Digits) + nl;
   if(g_liqg_active)
      out += "    Liq Target: " + DoubleToString(g_liqg_target, _Digits) + nl;
   out += "  Revisit Prob: " + DoubleToString(g_re_revisitProbability, 0) + "%" + nl;
   out += sep + nl;

   //==========================================================
   // SECTION 12: THREAT MATRIX
   //==========================================================
   out += "[THREAT MATRIX]" + nl;
   out += "  State: " + f_threatState(g_senseei_threat);
   out += " (" + DoubleToString(g_senseei_threat, 0) + "%)" + nl;
   out += "  Active Threats:" + nl;

   // Enumerate active threats
   if(g_senseei_conflict > 50.0)
      out += "    - Voter conflict: " + DoubleToString(g_senseei_conflict, 0) + "%" + nl;
   if(g_re_residualEnergyScore > 50.0)
      out += "    - Residual energy unresolved: " + DoubleToString(g_re_residualEnergyScore, 0) + "%" + nl;
   if(g_timeConflict > 60.0)
      out += "    - Time cycle conflict: " + DoubleToString(g_timeConflict, 0) + "%" + nl;
   if(g_liqg_active)
      out += "    - Liquidation wave: " + g_liqg_subPhase + " (dist " + DoubleToString(g_liqg_distPct, 0) + "%)" + nl;
   if(StringCompare(g_narrState, "WEAKENING") == 0)
      out += "    - Narrative weakening: " + DoubleToString(g_narrScore, 0) + "%" + nl;
   if(g_fractalStackDir != 0 && g_fractalStackDir != g_se[TF_M5].dir)
      out += "    - Stack vs M5 divergence" + nl;
   if(g_senseei_conflict <= 50.0 && g_re_residualEnergyScore <= 50.0 &&
      g_timeConflict <= 60.0 && !g_liqg_active)
      out += "    (none)" + nl;
   out += sep + nl;

   //==========================================================
   // SECTION 13: MARKET STORY (MOS)
   //==========================================================
   out += "[MARKET STORY]" + nl;

   // Build natural language narrative
   string story = "  ";

   // What is happening
   story += "Market is in " + f_phaseStr(g_se[TF_M5].phase) + " phase";
   if(g_se[TF_M5].dir == 1)
      story += " (bullish wave)";
   else if(g_se[TF_M5].dir == -1)
      story += " (bearish wave)";
   story += ". ";

   // Why (energy state)
   story += "Energy: " + g_eae_energyState + ". ";

   // Dominant belief
   story += "Dominant belief: " + Intel_DominantBelief() + ". ";

   // Where heading
   if(g_eae_primaryAttractorPrice > 0.0)
   {
      story += "Primary destination: " + DoubleToString(g_eae_primaryAttractorPrice, _Digits);
      story += " (" + g_eae_primaryAttractorLabel + "). ";
   }

   // Threats
   if(g_senseei_threat >= 50.0)
      story += "WARNING: Elevated threat level. ";
   else if(g_senseei_threat >= 30.0)
      story += "Caution: moderate threat. ";

   // Outlook
   story += "Next: " + g_expectedNextPhase;
   story += " (" + DoubleToString(g_expectedNextProb, 0) + "% prob). ";

   // Liquidation wave
   if(g_liqg_active)
   {
      story += "Liquidation wave active: " + Intel_LiqWaveTitle() + ". ";
   }

   out += story + nl;
   out += "============================================" + nl;

   //==========================================================
   // OUTPUT via Comment()
   //==========================================================
   Comment(out);
}
//+------------------------------------------------------------------+
