//+------------------------------------------------------------------+
//| Part9_Panels.mqh - Dashboard Panels: Engine Readout, Senseei HUD,|
//|                    Co-Pilot, Wave Matrix, Campaign, Curve Energy,|
//|                    Curve Tree - All rendered via OBJ_LABEL +     |
//|                    Comment() summary                             |
//| Master MT5 EA: Symphony + Letra + F16 Combined System           |
//+------------------------------------------------------------------+
#property strict

//==================================================================
// PANEL OBJECT NAME PREFIXES
//==================================================================
#define PNL_PREFIX      "MasterAlgo_Panel_"
#define PNL_READOUT     PNL_PREFIX "Readout"
#define PNL_SENSEEI     PNL_PREFIX "Senseei"
#define PNL_COPILOT     PNL_PREFIX "CoPilot"
#define PNL_WAVEMATRIX  PNL_PREFIX "WaveMatrix"
#define PNL_CAMPAIGN    PNL_PREFIX "Campaign"
#define PNL_CURVE       PNL_PREFIX "Curve"
#define PNL_CURVETREE   PNL_PREFIX "CurveTree"

//==================================================================
// PANEL POSITIONING CONSTANTS (pixel coordinates)
//==================================================================
#define PNL_FONT_SIZE   8
#define PNL_FONT_NAME   "Consolas"

// Top-right: Engine Readout
#define PNL_READOUT_X   820
#define PNL_READOUT_Y   20

// Top-left: Senseei HUD
#define PNL_SENSEEI_X   20
#define PNL_SENSEEI_Y   20

// Bottom-right: Co-Pilot
#define PNL_COPILOT_X   820
#define PNL_COPILOT_Y   320

// Bottom-center: Wave Matrix
#define PNL_WAVEMATRIX_X 380
#define PNL_WAVEMATRIX_Y 420

// Middle-left: Campaign
#define PNL_CAMPAIGN_X  20
#define PNL_CAMPAIGN_Y  260

// Middle-right: Curve Energy
#define PNL_CURVE_X     820
#define PNL_CURVE_Y     180

// Curve Tree (below Campaign)
#define PNL_CURVETREE_X 20
#define PNL_CURVETREE_Y 420

//==================================================================
// HELPER: Create a label object on the chart
//==================================================================
void CreatePanelLabel(const string name, int x, int y, color clr,
                      int fontSize = PNL_FONT_SIZE,
                      ENUM_BASE_CORNER corner = CORNER_LEFT_UPPER)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   }
   ObjectSetInteger(0, name, OBJPROP_CORNER, corner);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, PNL_FONT_NAME);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//==================================================================
// HELPER: Set label text
//==================================================================
void SetPanelText(const string name, const string text)
{
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

//==================================================================
// HELPER: Set label color
//==================================================================
void SetPanelColor(const string name, color clr)
{
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

//==================================================================
// HELPER: Direction string
//==================================================================
string DirStr(int dir)
{
   if(dir > 0) return("BULL");
   if(dir < 0) return("BEAR");
   return("-");
}

//==================================================================
// HELPER: Resolution state string
//==================================================================
string ResolutionStr(int state)
{
   switch(state)
   {
      case 0:  return("UNRESOLVED");
      case 1:  return("PARTIAL");
      case 2:  return("RESOLVED");
      default: return("UNKNOWN");
   }
}

//==================================================================
// HELPER: Char array to string
//==================================================================
string CharToStr(const char &arr[], int maxLen = 32)
{
   string result = "";
   for(int i = 0; i < maxLen; i++)
   {
      if(arr[i] == 0) break;
      result += CharToString((uchar)arr[i]);
   }
   return(result);
}

//==================================================================
// HELPER: Color based on direction
//==================================================================
color DirColor(int dir)
{
   if(dir > 0) return(clrLime);
   if(dir < 0) return(clrRed);
   return(clrGray);
}

//==================================================================
// HELPER: Color based on score (0-100, red->yellow->green)
//==================================================================
color ScoreColor(double score)
{
   if(score >= 70.0) return(clrLime);
   if(score >= 45.0) return(clrYellow);
   return(clrOrangeRed);
}

//==================================================================
// HELPER: TF name string from index
//==================================================================
string TFName(int idx)
{
   switch(idx)
   {
      case 0: return("M1");
      case 1: return("M3");
      case 2: return("M5");
      case 3: return("M15");
      case 4: return("H1");
      case 5: return("H4");
      default: return("??");
   }
}

//==================================================================
// HELPER: Time cycle TF name from index (0=MN,1=W,2=D,3=H4,4=H1)
//==================================================================
string TimeCycleTFName(int idx)
{
   switch(idx)
   {
      case 0: return("MN");
      case 1: return("W");
      case 2: return("D");
      case 3: return("H4");
      case 4: return("H1");
      default: return("??");
   }
}

//==================================================================
// 1. InitPanels() - Create all label objects
//==================================================================
void InitPanels()
{
   // Engine Readout (top-right corner)
   CreatePanelLabel(PNL_READOUT, PNL_READOUT_X, PNL_READOUT_Y, clrWhite,
                    PNL_FONT_SIZE, CORNER_RIGHT_UPPER);

   // Senseei HUD (top-left)
   CreatePanelLabel(PNL_SENSEEI, PNL_SENSEEI_X, PNL_SENSEEI_Y, clrCyan,
                    PNL_FONT_SIZE, CORNER_LEFT_UPPER);

   // Co-Pilot (bottom-right)
   CreatePanelLabel(PNL_COPILOT, PNL_COPILOT_X, PNL_COPILOT_Y, clrWhite,
                    PNL_FONT_SIZE, CORNER_RIGHT_UPPER);

   // Wave Matrix (bottom-center)
   CreatePanelLabel(PNL_WAVEMATRIX, PNL_WAVEMATRIX_X, PNL_WAVEMATRIX_Y, clrAqua,
                    PNL_FONT_SIZE, CORNER_LEFT_UPPER);

   // Campaign (middle-left)
   CreatePanelLabel(PNL_CAMPAIGN, PNL_CAMPAIGN_X, PNL_CAMPAIGN_Y, clrGold,
                    PNL_FONT_SIZE, CORNER_LEFT_UPPER);

   // Curve Energy (middle-right)
   CreatePanelLabel(PNL_CURVE, PNL_CURVE_X, PNL_CURVE_Y, clrMagenta,
                    PNL_FONT_SIZE, CORNER_RIGHT_UPPER);

   // Curve Tree (below campaign, left)
   CreatePanelLabel(PNL_CURVETREE, PNL_CURVETREE_X, PNL_CURVETREE_Y, clrWhite,
                    PNL_FONT_SIZE, CORNER_LEFT_UPPER);
}

//==================================================================
// 2. UpdatePanels() - Refresh all panel data + Comment() summary
//==================================================================
void UpdatePanels()
{
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   //--------------------------------------------------------------
   // (a) ENGINE READOUT (top-right)
   //--------------------------------------------------------------
   string phaseStr = PhaseToString(g_letra[2].phase);
   string rotationStr = (g_timeConflict >= 50.0) ? "ROTATING" : "ALIGNED";

   string readout = "";
   readout += "=== ENGINE READOUT ===\n";
   readout += "Wave: " + DirStr(g_letra[2].dir) + " | " + phaseStr + "\n";
   readout += "Progress: " + DoubleToString(g_energy.waveProgress, 1) + "% -> "
            + DoubleToString(g_letra[2].tgt, digits) + "\n";
   readout += "Stack: " + DirStr(g_fractalStackDir) + " "
            + DoubleToString(g_fractalStackScore, 1) + "%\n";
   readout += "Resolution: " + ResolutionStr(g_energy.re_resolutionState) + "\n";
   readout += "Residual: " + DoubleToString(g_energy.re_residualEnergyScore, 1) + "%\n";
   readout += "Attractor: " + DoubleToString(g_energy.eae_primaryAttractorScore, 1) + " @ "
            + DoubleToString(g_energy.eae_primaryAttractorPrice, digits) + "\n";
   readout += "Network: " + DirStr(g_netBias) + " | Nodes:" + IntegerToString(g_eligibleNodes)
            + " | Prs:" + DoubleToString(g_pressure, 1) + "\n";
   readout += "Invalidation: " + DoubleToString(g_letra[2].inv, digits) + "\n";
   readout += "Rotation: " + rotationStr;

   SetPanelText(PNL_READOUT, readout);
   SetPanelColor(PNL_READOUT, DirColor(g_letra[2].dir));

   //--------------------------------------------------------------
   // (b) SENSEEI HUD (top-left)
   //--------------------------------------------------------------
   string actionStr = CharToStr(g_senseei.action);
   string intentStr = CharToStr(g_senseei.intent);
   string timingStr = CharToStr(g_senseei.timing);
   string oppStr    = CharToStr(g_senseei.opportunity);

   string senseei = "";
   senseei += "=== SENSEEI HUD ===\n";
   senseei += "Master: " + DirStr(g_senseei.master) + "\n";
   senseei += "Phase: " + phaseStr + "\n";
   senseei += "Progress: " + DoubleToString(g_energy.waveProgress, 1) + "%\n";
   senseei += "Intent: " + intentStr + "\n";
   senseei += "Align: " + IntegerToString(g_senseei.alignment) + " | Conflict: "
            + IntegerToString(g_senseei.conflict) + "\n";
   senseei += "Conf: " + IntegerToString(g_senseei.confidence) + " | Threat: "
            + IntegerToString(g_senseei.threat) + "\n";
   senseei += "Opportunity: " + oppStr + " | " + timingStr + "\n";
   senseei += "Resolution: " + ResolutionStr(g_energy.re_resolutionState) + "\n";
   senseei += "Cycle: " + IntegerToString(g_spawn.entryCycle) + " | Depth: "
            + IntegerToString(g_spawn.waveDepth) + "\n";
   senseei += "ACTION: " + actionStr + "\n";
   senseei += "Entry Prob: " + DoubleToString(g_senseei.entryProb, 1) + "%";

   SetPanelText(PNL_SENSEEI, senseei);

   // Color action label
   color actClr = clrGray;
   if(actionStr == "ATTACK")       actClr = clrLime;
   else if(actionStr == "PREPARE") actClr = clrYellow;
   else if(actionStr == "MANAGE")  actClr = clrOrange;
   else if(actionStr == "WAIT")    actClr = clrGray;
   SetPanelColor(PNL_SENSEEI, actClr);

   //--------------------------------------------------------------
   // (c) DUAL CO-PILOT (bottom-right)
   //--------------------------------------------------------------
   // Firing solution grade
   string firingGrade = "NO TRADE";
   if(g_senseei.entryProb >= 92.0 && g_senseei.confidence >= 70)
      firingGrade = "A+";
   else if(g_senseei.entryProb >= 88.0 && g_senseei.confidence >= 60)
      firingGrade = "A";
   else if(g_senseei.entryProb >= 78.0 && g_senseei.confidence >= 50)
      firingGrade = "B";
   else if(g_senseei.entryProb >= 65.0)
      firingGrade = "C";

   string copilot = "";
   copilot += "=== DUAL CO-PILOT ===\n";
   // Opportunity section
   copilot += "[Opportunity]\n";
   copilot += " Sitrep: " + DirStr(g_senseei.master) + " " + oppStr + " " + phaseStr + "\n";
   copilot += " Vector: " + DirStr(g_letra[2].dir) + " wave "
            + DoubleToString(g_energy.waveProgress, 0) + "% maturity\n";
   copilot += " Flight: sweep->" + DoubleToString(g_spawn.flipzoneInducPrice, digits)
            + "->FU->" + DoubleToString(g_letra[2].tgt, digits) + "\n";
   copilot += " AltPath: " + DoubleToString(g_letra[2].inv, digits) + " inv flip\n";
   // Cycle radar
   copilot += "[Cycle Radar]\n";
   for(int c = 0; c < 5; c++)
   {
      string biasIcon = (g_timeCycles[c].bias > 0) ? "+" : (g_timeCycles[c].bias < 0) ? "-" : "o";
      string takenStr = "";
      if(g_timeCycles[c].highTaken) takenStr += "H";
      if(g_timeCycles[c].lowTaken) takenStr += "L";
      copilot += " " + TimeCycleTFName(c) + ": " + biasIcon + " " + takenStr + "\n";
   }
   // Target locks
   copilot += "[Targets] P:" + DoubleToString(g_letra[2].tgt, digits)
            + " S:" + DoubleToString(g_phase.arcLong != 0.0 ? g_phase.arcLong : g_phase.arcShort, digits)
            + " E:" + DoubleToString(g_energy.eae_primaryAttractorPrice, digits) + "\n";
   // Firing solution
   copilot += "Firing: " + firingGrade + "\n";
   // Master Chief section
   copilot += "[Master Chief]\n";
   copilot += " Bias: " + DirStr(g_netBias) + " " + g_campaign.compRegime + "\n";
   copilot += " Happening: " + g_campaign.campaign + " " + g_campaign.location + "\n";
   copilot += " Levels: inv=" + DoubleToString(g_letra[2].inv, digits)
            + " tgt=" + DoubleToString(g_letra[2].tgt, digits) + "\n";
   copilot += " Headed: " + DirStr(g_curveOwnerDir) + " next@"
            + DoubleToString(g_energy.eae_primaryAttractorPrice, digits) + "\n";
   copilot += " NetMagnet: " + DoubleToString(
              g_attractorIdx >= 0 ? g_nodes[g_attractorIdx].px : 0.0, digits) + "\n";
   copilot += " Risk: threat=" + IntegerToString(g_senseei.threat)
            + " residual=" + DoubleToString(g_energy.re_residualEnergyScore, 0) + "%\n";
   copilot += " Blockers: " + (g_senseei.conflict > 50 ?
              "conflict>" + IntegerToString(g_senseei.conflict) : "none") + "\n";
   copilot += " BottomLine: " + actionStr + " prob=" + DoubleToString(g_senseei.entryProb, 1) + "%";

   SetPanelText(PNL_COPILOT, copilot);
   SetPanelColor(PNL_COPILOT, (firingGrade == "A+" || firingGrade == "A") ? clrLime :
                 (firingGrade == "B") ? clrYellow : clrGray);

   //--------------------------------------------------------------
   // (d) WAVE MATRIX (bottom-center)
   //--------------------------------------------------------------
   string wmatrix = "";
   wmatrix += "=== WAVE MATRIX ===\n";
   // Per-TF wave narrative
   for(int t = 0; t < 6; t++)
   {
      wmatrix += TFName(t) + ": " + DirStr(g_letra[t].dir) + " "
               + PhaseToString(g_letra[t].phase) + " "
               + DoubleToString(g_letra[t].waveProgress, 0) + "%\n";
   }
   // Execution probability (derived from beliefs and hypotheses)
   double contProb = MathMax(0.0, g_energy.beliefs[2] * 100.0);
   double revProb  = MathMax(0.0, (1.0 - g_energy.beliefs[2]) * 50.0);
   double expProb  = MathMax(0.0, g_energy.hypotheses[2] * 80.0);
   double newProb  = MathMax(0.0, g_energy.predictionProb);
   double absProb  = MathMax(0.0, 100.0 - contProb - revProb);

   wmatrix += "[Exec Prob]\n";
   wmatrix += " Cont:" + DoubleToString(contProb, 0) + " Rev:" + DoubleToString(revProb, 0)
            + " Exp:" + DoubleToString(expProb, 0) + " New:" + DoubleToString(newProb, 0)
            + " Abs:" + DoubleToString(absProb, 0) + "\n";
   // Fractal confidence
   wmatrix += "FractalConf: " + DoubleToString(g_fractalStackScore, 1) + "% "
            + DirStr(g_fractalStackDir) + "\n";
   // Model confidence
   wmatrix += "ModelConf: " + DoubleToString(g_energy.modelConfidence, 1) + "%";

   SetPanelText(PNL_WAVEMATRIX, wmatrix);
   SetPanelColor(PNL_WAVEMATRIX, ScoreColor(g_fractalStackScore));

   //--------------------------------------------------------------
   // (e) CAMPAIGN OWNERSHIP (middle-left)
   //--------------------------------------------------------------
   int curveBudgetDepth = (int)MathMax(1, MathMin(4, 1 + MathRound(g_curve.compress / 33.0)));

   string campaign = "";
   campaign += "=== CAMPAIGN ===\n";
   campaign += "State: " + g_campaign.campaign + "\n";
   campaign += "Owner: " + DirStr(g_campaign.ownerDir) + " | Next HTF node\n";
   campaign += "Location: " + g_campaign.location + "\n";
   campaign += "Compression: " + g_campaign.compRegime + "\n";
   campaign += "Budget: " + DoubleToString(g_campaign.curveBudget, 1) + "% to HTF\n";
   campaign += "RecDepth: " + IntegerToString(curveBudgetDepth) + "\n";
   campaign += "Participant: " + g_participant.zone + "\n";
   campaign += "Interference: " + g_participant.interference + "\n";
   campaign += "Maturity: " + DoubleToString(g_curve.maturity, 1) + "%\n";
   campaign += "Coords: orig=" + DoubleToString(g_curve.origin, digits)
             + " ext=" + DoubleToString(g_curve.extreme, digits);

   SetPanelText(PNL_CAMPAIGN, campaign);
   SetPanelColor(PNL_CAMPAIGN, (g_campaign.campaign == "EXPANSION") ? clrGold : clrOrangeRed);

   //--------------------------------------------------------------
   // (f) CURVE ENERGY (middle-right)
   //--------------------------------------------------------------
   string curveState = "";
   if(g_curve.maturity >= 90.0)
      curveState = "TERMINAL";
   else if(g_curve.eRes < 15.0)
      curveState = "DISSIPATING";
   else if(g_curve.eIn > 60.0 && g_curve.maturity < 40.0)
      curveState = "CHARGING";
   else if(g_curve.dispATR > 2.0)
      curveState = "EXPANDING";
   else
      curveState = "TRANSFERRING";

   string curvePanel = "";
   curvePanel += "=== CURVE ENERGY ===\n";
   curvePanel += "Dir: " + DirStr(g_curve.dir) + " | " + curveState + "\n";
   curvePanel += "Energy In: " + DoubleToString(g_curve.eIn, 1) + "\n";
   curvePanel += "Dissipated: " + DoubleToString(g_curve.eDiss, 1) + "\n";
   curvePanel += "Residual: " + DoubleToString(g_curve.eRes, 1) + "\n";
   curvePanel += "DispATR: " + DoubleToString(g_curve.dispATR, 2) + "\n";
   curvePanel += "Convexity: " + DoubleToString(g_curve.convex, 1) + "\n";
   curvePanel += "Compression: " + DoubleToString(g_curve.compress, 1) + "\n";
   curvePanel += "Maturity: " + DoubleToString(g_curve.maturity, 1) + "%";

   SetPanelText(PNL_CURVE, curvePanel);
   SetPanelColor(PNL_CURVE, ScoreColor(g_curve.eRes));

   //--------------------------------------------------------------
   // (g) CURVE TREE (below campaign, left)
   //--------------------------------------------------------------
   // Count alive nodes and find deepest
   int treeAlive = 0;
   int treeMaxDepth = 0;
   for(int i = 0; i < g_curveTreeCount; i++)
   {
      if(g_curveTree[i].alive)
      {
         treeAlive++;
         if(g_curveTree[i].depth > treeMaxDepth)
            treeMaxDepth = g_curveTree[i].depth;
      }
   }

   string ownerPhase = NodeStateToString(g_curveOwnerState);

   string ctree = "";
   ctree += "=== CURVE TREE ===\n";
   ctree += "Trade: " + DirStr(g_curveOwnerDir) + "\n";
   ctree += "Recursion: depth=" + IntegerToString(treeMaxDepth)
          + " budget=" + IntegerToString(curveBudgetDepth) + "\n";
   ctree += "Live Nodes: " + IntegerToString(treeAlive) + "\n";
   ctree += "OwnerEnergy: " + DoubleToString(g_curveOwnerEnergy, 1) + "\n";
   ctree += "Coords: " + DoubleToString(g_curve.origin, digits) + " -> "
          + DoubleToString(g_curve.extreme, digits) + " -> "
          + DoubleToString(Close[0], digits) + "\n";
   ctree += "Phase: " + ownerPhase + "\n";
   ctree += "Compression: force=" + DoubleToString(g_compression.force, 1)
          + " " + g_compression.state + " " + g_compression.trend + "\n";
   ctree += "Alive: " + g_tradeAlive.verdict + " life="
          + DoubleToString(g_tradeAlive.life, 1) + "\n";
   ctree += "Narrative: " + g_narrative.state + " sup="
          + IntegerToString(g_narrative.supVotes)
          + " deg=" + IntegerToString(g_narrative.degVotes) + "\n";
   ctree += "Chain: " + g_narrative.chainScope + " vitality="
          + DoubleToString(g_narrative.chainVitality, 1);

   SetPanelText(PNL_CURVETREE, ctree);
   SetPanelColor(PNL_CURVETREE, ScoreColor(g_tradeAlive.life));

   //--------------------------------------------------------------
   // COMMENT() SUMMARY - Most critical info at a glance
   //--------------------------------------------------------------
   string cmt = "";
   cmt += "--- MASTER ALGO DASHBOARD ---\n";
   cmt += "ACTION: " + actionStr + " | Prob: "
        + DoubleToString(g_senseei.entryProb, 1) + "%\n";
   cmt += "Master: " + DirStr(g_senseei.master) + " | Phase: " + phaseStr + "\n";
   cmt += "Wave: " + DirStr(g_letra[2].dir) + " "
        + DoubleToString(g_energy.waveProgress, 1) + "%\n";
   cmt += "Stack: " + DirStr(g_fractalStackDir) + " "
        + DoubleToString(g_fractalStackScore, 0) + "%\n";
   cmt += "Resolution: " + ResolutionStr(g_energy.re_resolutionState) + " | Residual: "
        + DoubleToString(g_energy.re_residualEnergyScore, 0) + "%\n";
   cmt += "Conf: " + IntegerToString(g_senseei.confidence) + " | Threat: "
        + IntegerToString(g_senseei.threat) + " | Align: "
        + IntegerToString(g_senseei.alignment) + "\n";
   cmt += "Opp: " + oppStr + " | " + timingStr + "\n";
   cmt += "Curve: " + DirStr(g_curve.dir) + " " + curveState + " E:"
        + DoubleToString(g_curve.eRes, 0) + " M:"
        + DoubleToString(g_curve.maturity, 0) + "%\n";
   cmt += "Campaign: " + g_campaign.campaign + " " + g_campaign.location + "\n";
   cmt += "Alive: " + g_tradeAlive.verdict + " life="
        + DoubleToString(g_tradeAlive.life, 0) + "\n";
   cmt += "Fire: " + firingGrade + " | Net:" + DirStr(g_netBias) + " Prs:"
        + DoubleToString(g_pressure, 0);

   Comment(cmt);
}

//==================================================================
// 3. DeinitPanels() - Remove all chart objects
//==================================================================
void DeinitPanels()
{
   ObjectDelete(0, PNL_READOUT);
   ObjectDelete(0, PNL_SENSEEI);
   ObjectDelete(0, PNL_COPILOT);
   ObjectDelete(0, PNL_WAVEMATRIX);
   ObjectDelete(0, PNL_CAMPAIGN);
   ObjectDelete(0, PNL_CURVE);
   ObjectDelete(0, PNL_CURVETREE);
   Comment("");
}

//+------------------------------------------------------------------+
