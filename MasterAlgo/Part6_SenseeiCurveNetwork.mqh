//+------------------------------------------------------------------+
//| Part6_SenseeiCurveNetwork.mqh                                     |
//| MASTER ALGO - Senseei Meta-Intelligence + F72 Curve + Network     |
//| F16's strategic intelligence layer:                               |
//|   - Senseei (Alignment/Contradiction/Threat/Confidence/Action)    |
//|   - F72 Curve Object (energy/displacement/maturity/compression)   |
//|   - Curve Tree (recursive ownership + life score)                 |
//|   - Time Intelligence Engine (cycle completion tracking)          |
//|   - Compression Persistence (hold vs abandon)                     |
//+------------------------------------------------------------------+
#property strict

//==================================================================
// SENSEEI META-INTELLIGENCE (from F16)
//
// The Senseei is the "chief strategist" - it reads ALL sub-engines
// (wave, network, ERF, beliefs, time) and produces a single
// actionable verdict: WAIT / PREPARE / ATTACK / MANAGE-EXIT
//
// Dimensions:
//   Alignment   - How many voters agree on direction
//   Conflict    - How many voters disagree
//   Threat      - Risk level from conflict + residual + time
//   Confidence  - Strength of the edge
//   Opportunity - Is there a tradeable setup right now?
//   Action      - What to do
//==================================================================

//--- Curve Tree persistent state
struct CurveNode
{
   int    id;
   int    parentId;
   int    direction;    // 1=bull, -1=bear
   double origin;
   double extreme;
   double energy;       // 0-100
   bool   alive;
   int    depth;
   int    birthBar;
   double compression;
   double maturity;
   string state;       // emergent phase label
};

#define MAX_CURVE_NODES 30
CurveNode g_curveTree[MAX_CURVE_NODES];
int       g_curveNodeCount = 0;
int       g_curveNodeSeq = 0;

// Curve life/force scores
double g_curveLife = 50.0;
double g_curveForce = 50.0;
string g_curveAliveStatus = "HOLD";
string g_curveForceState = "NEUTRAL";

// Time Intelligence
double g_timeAlignment = 50.0;
double g_timeConflict = 50.0;
int    g_timeDirection = 0;

//==================================================================
// 1. F72 CURVE OBJECT (from F16 - energy state of the active wave)
//==================================================================
void UpdateCurveObject()
{
   if(ArraySize(Close) < 2) return;
   double atr = g_physics.atr;
   if(atr <= 0) return;
   
   int dir = g_structure[TF_M5].direction;
   double origin = g_structure[TF_M5].invalidation;
   double extreme = (dir == 1) ? g_cycleHigh : (dir == -1) ? g_cycleLow : Close[1];
   
   // Displacement in ATR units
   double dispATR = (origin > 0) ? MathAbs(extreme - origin) / MathMax(atr, 1e-10) : 0;
   
   // Compression (from Part 2 structure engine)
   double comp = g_structure[TF_M5].compression;
   
   // Build curve object
   g_curve.direction = dir;
   g_curve.origin = origin;
   g_curve.extreme = extreme;
   g_curve.dispATR = dispATR;
   g_curve.energyIn = g_erf.expansionEnergy;
   g_curve.energyDissipated = g_erf.dissipatedEnergy;
   g_curve.energyResidual = g_erfResidualEnergy;
   g_curve.convexity = g_obsCurvature;
   g_curve.compression = comp;
   g_curve.maturity = g_waveProgress;
}

//==================================================================
// 2. CURVE TREE ENGINE (recursive ownership from F16)
// Event-generated curves: CHoCH against owner spawns child curve
//==================================================================
void UpdateCurveTree()
{
   if(ArraySize(Close) < 2) return;
   double atr = g_physics.atr;
   if(atr <= 0) return;
   double closeNow = Close[1];
   
   // Find current owner (shallowest alive node with energy >= 12)
   int ownerIdx = -1;
   double ownerEnergy = -1;
   int ownerDepth = 999;
   
   for(int i = 0; i < g_curveNodeCount; i++)
   {
      if(g_curveTree[i].alive && g_curveTree[i].energy >= 12.0)
      {
         if(g_curveTree[i].depth < ownerDepth || 
            (g_curveTree[i].depth == ownerDepth && g_curveTree[i].energy > ownerEnergy))
         {
            ownerDepth = g_curveTree[i].depth;
            ownerEnergy = g_curveTree[i].energy;
            ownerIdx = i;
         }
      }
   }
   
   // If no owner, seed root from M5 structure
   int m5Dir = g_structure[TF_M5].direction;
   double m5Inv = g_structure[TF_M5].invalidation;
   
   if(ownerIdx < 0 && m5Dir != 0 && m5Inv > 0)
   {
      if(g_curveNodeCount < MAX_CURVE_NODES)
      {
         g_curveNodeSeq++;
         CurveNode node;
         node.id = g_curveNodeSeq;
         node.parentId = -1;
         node.direction = m5Dir;
         node.origin = m5Inv;
         node.extreme = (m5Dir == 1) ? g_cycleHigh : g_cycleLow;
         node.energy = MathMax(40.0, g_erf.expansionEnergy);
         node.alive = true;
         node.depth = 0;
         node.birthBar = ArraySize(Close);
         node.compression = g_curve.compression;
         node.maturity = g_waveProgress;
         node.state = "Expansion";
         g_curveTree[g_curveNodeCount] = node;
         g_curveNodeCount++;
         ownerIdx = g_curveNodeCount - 1;
      }
   }
   
   // Spawn child on CHoCH against owner
   if(ownerIdx >= 0)
   {
      CurveNode *owner = GetPointer(g_curveTree[ownerIdx]);
      int curveBudget = MathMax(1, MathMin(4, 1 + (int)MathRound(g_curve.compression / 33.0)));
      
      bool bearCH = (g_structure[TF_M5].chochSignal == -1);
      bool bullCH = (g_structure[TF_M5].chochSignal == 1);
      
      bool spawnChild = ((owner.direction == 1 && bearCH) || 
                         (owner.direction == -1 && bullCH)) &&
                        (owner.depth + 1 <= curveBudget);
      
      if(spawnChild && g_curveNodeCount < MAX_CURVE_NODES)
      {
         g_curveNodeSeq++;
         CurveNode child;
         child.id = g_curveNodeSeq;
         child.parentId = owner.id;
         child.direction = -owner.direction;
         child.origin = closeNow;
         child.extreme = closeNow;
         child.energy = MathMax(25.0, g_erf.expansionEnergy * 0.85);
         child.alive = true;
         child.depth = owner.depth + 1;
         child.birthBar = ArraySize(Close);
         child.compression = g_curve.compression;
         child.maturity = 0;
         child.state = "Transition";
         g_curveTree[g_curveNodeCount] = child;
         g_curveNodeCount++;
      }
   }
   
   // Update all living nodes
   int treeAlive = 0;
   int treeMaxDepth = 0;
   
   for(int i = 0; i < g_curveNodeCount; i++)
   {
      if(!g_curveTree[i].alive) continue;
      
      CurveNode *n = GetPointer(g_curveTree[i]);
      
      // Progress check
      bool prog = (n.direction == 1) ? (High[1] > n.extreme) : (Low[1] < n.extreme);
      
      // Update extreme
      if(n.depth == 0)
      {
         n.origin = g_structure[TF_M5].invalidation;
         n.extreme = (n.direction == 1) ? g_structure[TF_M5].swingHigh : g_structure[TF_M5].swingLow;
         n.direction = g_structure[TF_M5].direction;
      }
      else
      {
         if(n.direction == 1)
            n.extreme = MathMax(n.extreme, High[1]);
         else
            n.extreme = (n.extreme == 0) ? Low[1] : MathMin(n.extreme, Low[1]);
      }
      
      // Energy: rises on progress, decays when stalled
      n.energy = prog ? MathMin(100.0, n.energy + 7.0) : MathMax(0.0, n.energy - 2.0);
      n.maturity = g_structure[TF_M5].waveProgress;
      n.compression = g_structure[TF_M5].compression;
      
      // Emergent state from energy/depth/maturity
      if(n.depth > 0)
         n.state = (n.energy >= 70) ? "Recursive Expansion" : 
                   (n.energy >= 40) ? "Recursive Induction" : "Recursive Liquidation";
      else if(n.maturity < 12)
         n.state = "Point 4 Origin";
      else if(n.energy >= 78 && n.maturity >= 70)
         n.state = (n.direction == 1) ? "New High" : "New Low";
      else if(n.maturity < 35)
         n.state = "Expansion";
      else if(n.maturity < 55)
         n.state = "Expansion Pre-Convexity";
      else if(n.energy >= 55)
         n.state = "Expansion Induction";
      else if(n.energy >= 35)
         n.state = "Expansion Liquidity";
      else
         n.state = "Retracement";
      
      // Kill dead nodes
      if(n.energy <= 2.0)
         n.alive = false;
      else
      {
         treeAlive++;
         treeMaxDepth = MathMax(treeMaxDepth, n.depth);
      }
   }
   
   // Trim old dead nodes if too many
   while(g_curveNodeCount > MAX_CURVE_NODES - 5)
   {
      // Remove oldest dead node
      bool removed = false;
      for(int i = 0; i < g_curveNodeCount; i++)
      {
         if(!g_curveTree[i].alive)
         {
            for(int j = i; j < g_curveNodeCount - 1; j++)
               g_curveTree[j] = g_curveTree[j+1];
            g_curveNodeCount--;
            removed = true;
            break;
         }
      }
      if(!removed) break;
   }
   
   //--- Compute Curve Life Score (hold vs abandon)
   // Re-find owner after updates
   ownerIdx = -1;
   ownerEnergy = -1;
   ownerDepth = 999;
   for(int i = 0; i < g_curveNodeCount; i++)
   {
      if(g_curveTree[i].alive && g_curveTree[i].energy >= 12.0)
      {
         if(g_curveTree[i].depth < ownerDepth ||
            (g_curveTree[i].depth == ownerDepth && g_curveTree[i].energy > ownerEnergy))
         {
            ownerDepth = g_curveTree[i].depth;
            ownerEnergy = g_curveTree[i].energy;
            ownerIdx = i;
         }
      }
   }
   
   int ownerDir = (ownerIdx >= 0) ? g_curveTree[ownerIdx].direction : 0;
   double ownerOrig = (ownerIdx >= 0) ? g_curveTree[ownerIdx].origin : 0;
   double ownerExt = (ownerIdx >= 0) ? g_curveTree[ownerIdx].extreme : 0;
   
   // Compression persistence force
   double cmpNow = g_curve.compression;
   g_curveForce = Clamp(
      cmpNow * 0.50 + g_erfResidualEnergy * 0.20 - treeMaxDepth * 12.0 + 8.0,
      0.0, 100.0);
   g_curveForceState = (g_curveForce >= 60) ? "PERSISTING" : (g_curveForce <= 35) ? "LEAKING" : "NEUTRAL";
   
   // Retrace depth from extreme
   double retrX = 50.0;
   if(ownerOrig > 0 && ownerExt > 0 && ownerExt != ownerOrig)
      retrX = MathMin(100.0, MathAbs(ownerExt - closeNow) / MathAbs(ownerExt - ownerOrig) * 100.0);
   
   // Is the trade attacking (progressing)?
   bool attacking = (ownerDir == 1 && High[1] >= ownerExt) || 
                    (ownerDir == -1 && Low[1] <= ownerExt);
   bool trendImp = (ownerDir == 1 && g_physics.bullImpulse) || 
                   (ownerDir == -1 && g_physics.bearImpulse);
   bool progressing = attacking || trendImp;
   
   // Recursion complete?
   int curveBudget = MathMax(1, MathMin(4, 1 + (int)MathRound(g_curve.compression / 33.0)));
   bool recursionComplete = (curveBudget > 0 && treeMaxDepth >= curveBudget);
   
   // LIFE SCORE (the single hold-vs-abandon judgement)
   g_curveLife = Clamp(
      g_curveForce * 0.45 +
      g_erfResidualEnergy * 0.30 +
      (progressing ? 28.0 : 0.0) +
      (retrX < 25.0 ? 16.0 : retrX < 45.0 ? 6.0 : retrX > 75.0 ? -12.0 : 0.0) -
      (recursionComplete && !progressing ? 25.0 : 0.0) -
      (g_curveForceState == "LEAKING" && !progressing ? 20.0 : 0.0) +
      10.0,
      0.0, 100.0);
   
   // Alive status
   if(progressing && g_curveLife >= 45)
      g_curveAliveStatus = "ALIVE - ATTACKING";
   else if(g_curveLife >= 60)
      g_curveAliveStatus = "ALIVE - HOLD";
   else if(g_curveLife <= 32)
      g_curveAliveStatus = "DEAD - FLIP";
   else
      g_curveAliveStatus = "WEAKENING - MANAGE";
}

//==================================================================
// 3. TIME INTELLIGENCE ENGINE (from F16 Engine 8.0)
// Tracks cycle completion across MN/W/D/H4/H1
//==================================================================
void UpdateTimeIntelligence()
{
   // Simplified: use H4 and H1 cycle data
   // H1 bias from open vs current
   double h1Open = 0, h1High = 0, h1Low = 0;
   double h4Open = 0, h4High = 0, h4Low = 0;
   double dOpen = 0, dHigh = 0, dLow = 0;
   
   // Get H1 current bar OHLC
   double h1O[], h1H[], h1L[];
   ArraySetAsSeries(h1O, true); ArraySetAsSeries(h1H, true); ArraySetAsSeries(h1L, true);
   if(CopyOpen(_Symbol, PERIOD_H1, 0, 1, h1O) > 0) h1Open = h1O[0];
   if(CopyHigh(_Symbol, PERIOD_H1, 0, 1, h1H) > 0) h1High = h1H[0];
   if(CopyLow(_Symbol, PERIOD_H1, 0, 1, h1L) > 0) h1Low = h1L[0];
   
   // Get H4 current bar OHLC
   double h4O[], h4H[], h4L[];
   ArraySetAsSeries(h4O, true); ArraySetAsSeries(h4H, true); ArraySetAsSeries(h4L, true);
   if(CopyOpen(_Symbol, PERIOD_H4, 0, 1, h4O) > 0) h4Open = h4O[0];
   if(CopyHigh(_Symbol, PERIOD_H4, 0, 1, h4H) > 0) h4High = h4H[0];
   if(CopyLow(_Symbol, PERIOD_H4, 0, 1, h4L) > 0) h4Low = h4L[0];
   
   // Get Daily current bar OHLC
   double dO[], dH[], dL[];
   ArraySetAsSeries(dO, true); ArraySetAsSeries(dH, true); ArraySetAsSeries(dL, true);
   if(CopyOpen(_Symbol, PERIOD_D1, 0, 1, dO) > 0) dOpen = dO[0];
   if(CopyHigh(_Symbol, PERIOD_D1, 0, 1, dH) > 0) dHigh = dH[0];
   if(CopyLow(_Symbol, PERIOD_D1, 0, 1, dL) > 0) dLow = dL[0];
   
   double closeNow = (ArraySize(Close) > 0) ? Close[0] : 0;
   
   // Bias per timeframe (close vs open)
   int h1Bias = (closeNow > h1Open) ? 1 : (closeNow < h1Open) ? -1 : 0;
   int h4Bias = (closeNow > h4Open) ? 1 : (closeNow < h4Open) ? -1 : 0;
   int dBias = (closeNow > dOpen) ? 1 : (closeNow < dOpen) ? -1 : 0;
   
   // Previous highs/lows taken
   double h1PrevH[], h1PrevL[];
   ArraySetAsSeries(h1PrevH, true); ArraySetAsSeries(h1PrevL, true);
   bool h1HighTaken = false, h1LowTaken = false;
   if(CopyHigh(_Symbol, PERIOD_H1, 1, 1, h1PrevH) > 0 && h1High > h1PrevH[0])
      h1HighTaken = true;
   if(CopyLow(_Symbol, PERIOD_H1, 1, 1, h1PrevL) > 0 && h1Low < h1PrevL[0])
      h1LowTaken = true;
   
   g_timeIntel.h1HighTaken = h1HighTaken;
   g_timeIntel.h1LowTaken = h1LowTaken;
   
   // Time direction consensus
   int bullVotes = (h1Bias == 1 ? 1 : 0) + (h4Bias == 1 ? 1 : 0) + (dBias == 1 ? 1 : 0);
   int bearVotes = (h1Bias == -1 ? 1 : 0) + (h4Bias == -1 ? 1 : 0) + (dBias == -1 ? 1 : 0);
   
   g_timeDirection = (bullVotes > bearVotes) ? 1 : (bearVotes > bullVotes) ? -1 : 0;
   g_timeIntel.timeDirection = g_timeDirection;
   g_timeAlignment = (bullVotes + bearVotes > 0) ? 
      MathMax(bullVotes, bearVotes) / 3.0 * 100.0 : 50.0;
   g_timeIntel.timeAlignment = g_timeAlignment;
   g_timeConflict = 100.0 - g_timeAlignment;
   g_timeIntel.timeConflict = g_timeConflict;
   
   // H1 timing
   if(h1HighTaken && h1LowTaken)
      g_timeIntel.h1Timing = "COMPLETION";
   else if(!h1LowTaken)
      g_timeIntel.h1Timing = "LOW FIRST";
   else if(!h1HighTaken)
      g_timeIntel.h1Timing = "HIGH FIRST";
   else
      g_timeIntel.h1Timing = "BALANCED";
}

//==================================================================
// 4. SENSEEI META-INTELLIGENCE (from F16 Part D)
// Reads ALL sub-engines and produces the strategic verdict
//==================================================================
void ComputeSenseei()
{
   // Four directional voters
   int vt1 = g_structure[TF_M5].direction;  // Wave direction
   int vt2 = g_fractalStack.direction;      // Fractal stack
   int vt3 = g_timeDirection;               // Time intelligence
   int vt4 = (g_netEdge > 12) ? 1 : (g_netEdge < -12) ? -1 : 0; // Network pressure
   
   int sum = vt1 + vt2 + vt3 + vt4;
   int master = (sum > 0) ? 1 : (sum < 0) ? -1 : 0;
   
   // Count cast votes and agreement
   int cast = (vt1 != 0 ? 1 : 0) + (vt2 != 0 ? 1 : 0) + (vt3 != 0 ? 1 : 0) + (vt4 != 0 ? 1 : 0);
   int forV = 0;
   if(master != 0)
   {
      forV = (vt1 == master ? 1 : 0) + (vt2 == master ? 1 : 0) + 
             (vt3 == master ? 1 : 0) + (vt4 == master ? 1 : 0);
   }
   
   // Alignment & Conflict
   double alignment = (cast > 0) ? (double)forV / (double)cast * 100.0 : 50.0;
   double conflict = (cast > 0) ? (double)(cast - forV) / (double)cast * 100.0 : 0.0;
   
   // Threat
   double threat = Clamp(
      conflict * 0.40 +
      g_erfResidualEnergy * 0.28 +
      g_timeConflict * 0.12 +
      (vt4 != 0 && vt4 != master ? 18.0 : 0.0) +
      (g_erf.resolutionState == RES_PARTIALLY_RESOLVED ? 10.0 : 0.0),
      0.0, 100.0);
   
   // Confidence
   double confidence = Clamp(
      alignment * 0.40 +
      g_timeAlignment * 0.12 +
      g_fractalStack.score * 0.18 +
      g_erfPrimaryAttractorScore * 0.15 +
      MathMin(15.0, g_liqHeat * 0.12) -
      threat * 0.20,
      0.0, 100.0);
   
   // Opportunity scoring
   double oppScore = Clamp(
      alignment * 0.40 +
      g_erfPrimaryAttractorScore * 0.30 +
      g_fractalStack.score * 0.30 -
      threat * 0.35,
      0.0, 100.0);
   
   // Timing assessment
   string timing = "";
   if(g_currentPhase == PHASE_ABSORPTION || g_erf.resolutionState == RES_RESOLVED)
      timing = "RESOLVED";
   else if(g_waveProgress < 15) timing = "VERY EARLY";
   else if(g_waveProgress < 35) timing = "EARLY";
   else if(g_waveProgress < 55) timing = "DEVELOPING";
   else if(g_waveProgress < 80) timing = "MID CYCLE";
   else if(g_waveProgress < 96) timing = "LATE";
   else timing = "TERMINAL";
   
   // Opportunity grade
   string opportunity = "";
   if(master == 0) opportunity = "NONE";
   else if(conflict > 60) opportunity = "DEVELOPING";
   else if(oppScore < 20) opportunity = "NONE";
   else if(oppScore < 40) opportunity = "DEVELOPING";
   else if(oppScore < 62) opportunity = "GOOD";
   else if(oppScore < 82) opportunity = "STRONG";
   else opportunity = "EXCEPTIONAL";
   
   // Intent
   string intent = "";
   if(conflict > 55) intent = "ABSORPTION";
   else if(g_currentPhase == PHASE_EXPANSION) intent = "EXPANSION";
   else if(g_currentPhase == PHASE_EXP_PRECONVEXITY) intent = "CONTINUATION";
   else if(g_currentPhase == PHASE_EXP_INDUCTION || g_currentPhase == PHASE_RETR_INDUCTION) intent = "RESOLUTION";
   else if(g_currentPhase == PHASE_EXP_LIQUIDITY || g_currentPhase == PHASE_NEW_HIGH || g_currentPhase == PHASE_NEW_LOW) intent = "DELIVERY";
   else if(g_currentPhase == PHASE_ABSORPTION) intent = "ABSORPTION";
   else if(master == 0) intent = "BALANCE";
   else intent = "CONTINUATION";
   
   // ACTION verdict
   ENUM_SENSEEI_ACTION action;
   if(master == 0 || conflict > 60)
      action = ACTION_WAIT;
   else if(g_erf.resolutionState == RES_RESOLVED)
      action = ACTION_MANAGE_EXIT;
   else if((opportunity == "STRONG" || opportunity == "EXCEPTIONAL") && 
           confidence >= InpMinConfAttack && threat < 45)
      action = ACTION_ATTACK;
   else if(opportunity == "GOOD" || opportunity == "STRONG")
      action = ACTION_PREPARE;
   else
      action = ACTION_WAIT;
   
   // Store outputs
   g_senseei.masterBias = master;
   g_senseei.alignment = alignment;
   g_senseei.conflict = conflict;
   g_senseei.confidence = confidence;
   g_senseei.threat = threat;
   g_senseei.opportunityScore = oppScore;
   g_senseei.action = action;
   g_senseei.intent = intent;
   g_senseei.timing = timing;
   g_senseei.opportunity = opportunity;
}

//==================================================================
// 5. NARRATIVE ENGINE (single-sentence market story)
//==================================================================
string g_marketNarrative = "";
string g_actionNarrative = "";

void ComputeNarrative()
{
   string dirWord = (g_senseei.masterBias == 1) ? "Bullish" : 
                    (g_senseei.masterBias == -1) ? "Bearish" : "Neutral";
   
   // What's happening
   g_marketNarrative = dirWord + " " + g_currentDisplayPhase + 
      " | Progress " + IntegerToString((int)g_waveProgress) + "%" +
      " | Stack " + IntegerToString((int)g_fractalStack.score) + "%" +
      " | Life " + IntegerToString((int)g_curveLife);
   
   // What to do
   switch(g_senseei.action)
   {
      case ACTION_ATTACK:
         g_actionNarrative = "ATTACK - entry conditions aligned";
         break;
      case ACTION_PREPARE:
         g_actionNarrative = "PREPARE - wait for trigger";
         break;
      case ACTION_MANAGE_EXIT:
         g_actionNarrative = "MANAGE/EXIT - energy resolved";
         break;
      default:
         g_actionNarrative = "WAIT - no edge";
         break;
   }
}

//==================================================================
// MASTER SENSEEI/CURVE UPDATE
//==================================================================
void UpdateSenseeiCurveNetwork()
{
   // 1. F72 Curve Object
   UpdateCurveObject();
   
   // 2. Curve Tree (recursive ownership)
   UpdateCurveTree();
   
   // 3. Time Intelligence
   UpdateTimeIntelligence();
   
   // 4. Senseei Meta-Intelligence (reads all engines)
   ComputeSenseei();
   
   // 5. Narrative
   ComputeNarrative();
}

//+------------------------------------------------------------------+
