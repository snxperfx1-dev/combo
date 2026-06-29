//+------------------------------------------------------------------+
//| MasterAlgo_Part4_ExecutionEngine.mq5                             |
//| Part 4: Execution Engine                                          |
//| Contains: Curve Object, Curve Tree, Compression Persistence,     |
//|           Is Trade Alive, Narrative Lineage, Campaign Ownership,  |
//|           Time Intelligence Engine, Master Execution Logic,       |
//|           Lot Sizing, Order Execution, Composite Exit System      |
//| This file is #included after Parts 1, 2, and 3                   |
//+------------------------------------------------------------------+
#property strict

//==================================================================
// INPUT PARAMETERS - EXECUTION ENGINE
//==================================================================
input double InpCurve_OwnMinEnergy  = 12.0;   // Min energy for tree ownership
input int    InpCurve_MaxNodes      = 60;      // Max tree nodes before pruning
input double InpLife_AliveThresh    = 60.0;    // Life score >= ALIVE
input double InpLife_DeadThresh     = 32.0;    // Life score <= DEAD
input double InpERF_ReadyThresh     = 35.0;    // ERF confidence for entry gate
input double InpEntry_BreakoutMult  = 0.20;    // P4 breakout ATR multiple

//==================================================================
// 1. CURVE OBJECT STRUCT (F72 Foundation)
//==================================================================
struct CurveObject
{
   int    dir;         // direction: 1=bull, -1=bear, 0=none
   double origin;      // structural origin (invalidation level)
   double extreme;     // structural extreme (cycle high/low)
   double dispATR;     // displacement in ATR units
   double eIn;         // expansion energy injected (0-100)
   double eDiss;       // energy dissipated (0-100)
   double eRes;        // energy remaining (0-100)
   double convex;      // curvature (0-100)
   double compress;    // compression (0-100, high = tight)
   double maturity;    // lifecycle progress (0-100)
};

//==================================================================
// 2. CURVENODE STRUCT (F72 Recursive Tree)
//==================================================================
struct CurveNode
{
   int    id;          // unique node ID
   int    parent;      // parent node ID (-1 = root)
   int    dir;         // direction
   double origin;      // node origin price
   double extreme;     // node extreme price
   double energy;      // energy level (0-100)
   bool   alive;       // whether node is still active
   int    depth;       // recursion depth (0 = root)
   string state;       // phase label from f_nodeState
   int    bar;         // bar_index at birth
   double comp;        // this node's compression
   double mat;         // this node's maturity
   int    srcTf;       // source timeframe index (TF_M5=2, TF_H1=4, TF_H4=5)
};

//==================================================================
// 3. TIME CYCLE STRUCT (Time Intelligence Engine)
//==================================================================
struct TimeCycle
{
   double open;        // cycle open price
   double high;        // running cycle high
   double low;         // running cycle low
   double prevHigh;    // prior cycle high
   double prevLow;     // prior cycle low
   int    bias;        // 1=bull, -1=bear, 0=flat
   double elapsed;     // 0-1 progress through cycle
   string state;       // OPENING/EXPANDING/MID CYCLE/TERMINAL/HIGH DONE/LOW DONE/DUAL DONE
   double completion;  // 0-100 completion score
   bool   highTaken;   // prior high exceeded
   bool   lowTaken;    // prior low exceeded
};

//==================================================================
// 4. GLOBAL STATE - CURVE OBJECT
//==================================================================
CurveObject g_curve;

//==================================================================
// 5. GLOBAL STATE - CURVE TREE
//==================================================================
CurveNode g_tree[];
int       g_treeCount    = 0;
int       g_nodeSeq      = 0;
int       g_treeAlive    = 0;
int       g_treeMaxDepth = 0;
int       g_ownerIdx     = -1;       // index of owning node
int       g_ownerDir     = 0;        // owner direction
int       g_ownerDepth   = 0;        // owner depth
double    g_ownerEnergy  = 0.0;      // owner energy
string    g_ownerState   = "";       // owner phase state

//==================================================================
// 6. GLOBAL STATE - COMPRESSION PERSISTENCE
//==================================================================
double g_cpForce       = 0.0;        // compression persistence force (0-100)
string g_cpState       = "NEUTRAL";  // PERSISTING / NEUTRAL / LEAKING
double g_cpTighten     = 0.0;        // compression delta (pos=tightening)

//==================================================================
// 7. GLOBAL STATE - IS TRADE ALIVE
//==================================================================
double g_curveLifeScore = 50.0;      // life score (0-100)
string g_curveLifeState = "ALIVE";   // ALIVE / WEAKENING / DEAD
bool   g_recursionComplete = false;
bool   g_progressing    = false;

//==================================================================
// 8. GLOBAL STATE - NARRATIVE LINEAGE
//==================================================================
int    g_narrDir         = 0;
double g_narrScore       = 50.0;     // narrative health (0-100)
string g_narrState       = "HOLDING"; // STRENGTHENING / HOLDING / WEAKENING
int    g_narrSupVotes    = 0;
int    g_narrDegVotes    = 0;
double g_narrLegExtreme  = 0.0;
double g_narrLegPBDepth  = 0.0;
double g_chainVitality   = 50.0;
double g_wholeChainLife  = 50.0;

// Sequence arrays (max 5 entries for retrace depth tracking)
double g_seqRetr[];
double g_lifeSeq[];

//==================================================================
// 9. GLOBAL STATE - CAMPAIGN OWNERSHIP
//==================================================================
string g_campaignState    = "EXPANSION";  // TERMINAL / EXPANSION
string g_campaignLocation = "BUILDING";   // BUILDING / APPROACHING / INSIDE / TRANSITIONING
int    g_campaignOwnerDir = 0;
double g_curveBudget      = 100.0;        // budget to HTF zone (0-100)

//==================================================================
// 10. GLOBAL STATE - PARTICIPANT INTERFERENCE ZONES
//==================================================================
double g_part_618    = 0.0;
double g_part_70     = 0.0;
double g_part_786    = 0.0;
double g_part_flip   = 0.0;
string g_partZone    = "";       // pre-0.618/0.618/0.70/0.786/FLIP
double g_partRetrAbs = 0.0;

//==================================================================
// 11. GLOBAL STATE - TIME INTELLIGENCE ENGINE
//==================================================================
TimeCycle g_timeMN;
TimeCycle g_timeW;
TimeCycle g_timeD;
TimeCycle g_timeH4;
TimeCycle g_timeH1;

int    g_timeDir      = 0;       // overall time bias direction
double g_timeAlign    = 50.0;    // alignment score (0-100)
double g_timeConflict = 50.0;    // conflict score (0-100)
string g_h1Timing     = "BALANCED";  // LOW FIRST / HIGH FIRST / BALANCED / COMPLETION
string g_timeStack    = "";      // display string

//==================================================================
// 12. GLOBAL STATE - EXECUTION TRACKING
//==================================================================
bool   g_entryGateOpen   = false;  // combined intelligence entry gate
string g_lastEntryReason = "";     // reason for last entry
string g_lastExitReason  = "";     // reason for last exit


//==================================================================
// 13. CURVE OBJECT COMPUTATION
// Populates gCurve from M5 engine outputs
//==================================================================
void Exec_UpdateCurveObject()
{
   int tfIdx = TF_M5;
   SE_Result &se5 = g_se[tfIdx];

   // Direction from M5 structure engine
   g_curve.dir = se5.dir;

   // Origin = M5 invalidation level (structural origin)
   g_curve.origin = se5.invalidation;

   // Extreme = swing high (bull) or swing low (bear)
   if(g_curve.dir == 1)
      g_curve.extreme = se5.swingHigh;
   else if(g_curve.dir == -1)
      g_curve.extreme = se5.swingLow;
   else
      g_curve.extreme = Close[1];

   // Displacement in ATR units
   double atr = GetATR(1);
   if(atr <= 0.0) atr = 1e-10;
   if(g_curve.origin != 0.0)
      g_curve.dispATR = MathAbs(g_curve.extreme - g_curve.origin) / atr;
   else
      g_curve.dispATR = 0.0;

   // Energy from EDE (Part 3)
   g_curve.eIn   = g_ede_expansionEnergy;
   g_curve.eDiss = g_ede_dissipatedEnergy;
   g_curve.eRes  = g_re_residualEnergyScore;

   // Convexity from Part 3
   g_curve.convex = g_convexityMaturity;

   // Compression: inverse of efficiency + displacement tightness
   double eff = se5.compression;
   double disp = g_curve.dispATR;
   double compFromEff  = (1.0 - MathMin(eff / MathMax(InpSE_EffThresh, 1e-10), 1.0)) * 60.0;
   double compFromDisp = (1.0 - MathMin(disp / MathMax(InpSE_DispThresh, 1e-10), 1.0)) * 40.0;
   g_curve.compress = MathMin(100.0, MathMax(0.0, compFromEff + compFromDisp));

   // Maturity = wave progress from Part 3
   g_curve.maturity = g_waveProgress;
}

//==================================================================
// 14. CURVE TREE - NODE STATE DETERMINATION
// Maps energy/lifecycle/depth to Principle-14 phase labels
//==================================================================
string Exec_NodeState(int dir, double energy, int depth, double comp, double mat)
{
   // Recursive child nodes (depth > 0) live in Transition family
   if(depth > 0)
   {
      if(energy >= 70.0) return("Transition recursive expansion");
      if(energy >= 40.0) return("Transition recursive induction");
      return("Transition recursive liquidation");
   }

   // Root nodes: phase emerges from energy/maturity/compression
   if(mat < 12.0)  return("Point 4 Origin");

   if(energy >= 78.0 && mat >= 70.0)
   {
      if(dir == 1)  return("New High");
      if(dir == -1) return("New Low");
      return("Climax");
   }

   if(mat < 35.0)  return("Expansion");
   if(mat < 55.0)  return("Expansion Pre-Convexity");
   if(energy >= 55.0) return("Expansion Induction");
   if(energy >= 35.0) return("Expansion Liquidity");
   if(comp >= 60.0)   return("Retracement Pre-Convexity");
   if(energy >= 18.0) return("Retracement Induction");
   return("Retracement");
}

//==================================================================
// 15. CURVE TREE UPDATE
// Event-generated recursive nodes, energy dynamics, ownership
//==================================================================
void Exec_UpdateCurveTree()
{
   // Ensure array is allocated
   if(ArraySize(g_tree) < InpCurve_MaxNodes + 10)
      ArrayResize(g_tree, InpCurve_MaxNodes + 10);

   int barsAvail = ArraySize(Close);
   if(barsAvail < 5) return;

   double closeNow = Close[1];
   double highNow  = High[1];
   double lowNow   = Low[1];

   //-- Find current owner (Principle 8: shallowest with energy) --
   g_ownerIdx   = -1;
   g_ownerDir   = 0;
   g_ownerDepth = 999;
   g_ownerEnergy = -1.0;

   for(int i = 0; i < g_treeCount; i++)
   {
      if(!g_tree[i].alive) continue;
      if(g_tree[i].energy >= InpCurve_OwnMinEnergy)
      {
         if(g_tree[i].depth < g_ownerDepth ||
            (g_tree[i].depth == g_ownerDepth && g_tree[i].energy > g_ownerEnergy))
         {
            g_ownerDepth  = g_tree[i].depth;
            g_ownerEnergy = g_tree[i].energy;
            g_ownerIdx    = i;
         }
      }
   }

   // Fallback: any alive node with highest energy
   if(g_ownerIdx < 0)
   {
      double bestE = -1.0;
      for(int i = 0; i < g_treeCount; i++)
      {
         if(g_tree[i].alive && g_tree[i].energy > bestE)
         {
            bestE = g_tree[i].energy;
            g_ownerIdx = i;
         }
      }
   }

   if(g_ownerIdx >= 0)
   {
      g_ownerDir    = g_tree[g_ownerIdx].dir;
      g_ownerDepth  = g_tree[g_ownerIdx].depth;
      g_ownerEnergy = g_tree[g_ownerIdx].energy;
   }

   //-- Seed/re-seed root when no owner exists --
   SE_Result &se5 = g_se[TF_M5];
   SE_Result &seH1 = g_se[TF_H1];
   SE_Result &seH4 = g_se[TF_H4];

   if(g_ownerIdx < 0 && se5.dir != 0 && se5.invalidation != 0.0)
   {
      g_nodeSeq++;
      int idx = g_treeCount;
      if(idx >= ArraySize(g_tree))
         ArrayResize(g_tree, idx + 20);

      g_tree[idx].id      = g_nodeSeq;
      g_tree[idx].parent  = -1;
      g_tree[idx].dir     = se5.dir;
      g_tree[idx].origin  = se5.invalidation;
      g_tree[idx].extreme = (se5.dir == 1) ? se5.swingHigh : se5.swingLow;
      g_tree[idx].energy  = MathMax(40.0, g_ede_expansionEnergy);
      g_tree[idx].alive   = true;
      g_tree[idx].depth   = 0;
      g_tree[idx].bar     = 0;
      g_tree[idx].comp    = g_curve.compress;
      g_tree[idx].mat     = g_curve.maturity;
      g_tree[idx].srcTf   = TF_M5;
      g_tree[idx].state   = Exec_NodeState(g_tree[idx].dir, g_tree[idx].energy,
                                           0, g_tree[idx].comp, g_tree[idx].mat);
      g_treeCount++;
      g_ownerIdx = idx;
      g_ownerDir = g_tree[idx].dir;
      g_ownerDepth = 0;
      g_ownerEnergy = g_tree[idx].energy;
   }

   //-- Compression-based recursion budget (Principle 3/4) --
   int curveBudgetDepth = MathMax(1, MathMin(4, 1 + (int)MathRound(g_curve.compress / 33.0)));

   //-- Event-generated CHILD: Phase-2 CHoCH against owner spawns inverse --
   if(g_ownerIdx >= 0)
   {
      bool bullCHoCH = (se5.chochDir == 1);
      bool bearCHoCH = (se5.chochDir == -1);

      CurveNode &owner = g_tree[g_ownerIdx];
      bool spawnChild = false;

      if(owner.dir == 1 && bearCHoCH && (owner.depth + 1 <= curveBudgetDepth))
         spawnChild = true;
      if(owner.dir == -1 && bullCHoCH && (owner.depth + 1 <= curveBudgetDepth))
         spawnChild = true;

      if(spawnChild && g_treeCount < ArraySize(g_tree))
      {
         g_nodeSeq++;
         int idx = g_treeCount;
         g_tree[idx].id      = g_nodeSeq;
         g_tree[idx].parent  = owner.id;
         g_tree[idx].dir     = -owner.dir;
         g_tree[idx].origin  = closeNow;
         g_tree[idx].extreme = closeNow;
         g_tree[idx].energy  = MathMax(25.0, g_ede_expansionEnergy * 0.85);
         g_tree[idx].alive   = true;
         g_tree[idx].depth   = owner.depth + 1;
         g_tree[idx].bar     = 0;
         g_tree[idx].comp    = g_curve.compress;
         g_tree[idx].mat     = 0.0;
         g_tree[idx].srcTf   = TF_M5;
         g_tree[idx].state   = Exec_NodeState(g_tree[idx].dir, g_tree[idx].energy,
                                              g_tree[idx].depth, g_tree[idx].comp, 0.0);
         g_treeCount++;
      }
   }

   //-- Update living nodes: energy dynamics --
   g_treeAlive    = 0;
   g_treeMaxDepth = 0;

   for(int i = 0; i < g_treeCount; i++)
   {
      if(!g_tree[i].alive) continue;

      // Root nodes mirror their TF direction
      if(g_tree[i].depth == 0)
      {
         if(g_tree[i].srcTf == TF_H4)
            g_tree[i].dir = g_se[TF_H4].dir;
         else if(g_tree[i].srcTf == TF_H1)
            g_tree[i].dir = g_se[TF_H1].dir;
         else
            g_tree[i].dir = g_se[TF_M5].dir;
      }

      // Progress detection
      bool prog = false;
      if(g_tree[i].dir == 1 && highNow > g_tree[i].extreme)
         prog = true;
      if(g_tree[i].dir == -1 && lowNow < g_tree[i].extreme)
         prog = true;

      // Update coordinates
      if(g_tree[i].depth == 0)
      {
         // Root mirrors source TF
         int src = g_tree[i].srcTf;
         if(src >= 0 && src < SE_TF_COUNT)
         {
            g_tree[i].origin  = g_se[src].invalidation;
            g_tree[i].extreme = (g_tree[i].dir == 1) ? g_se[src].swingHigh : g_se[src].swingLow;
         }
      }
      else
      {
         // Children track their own counter-move extreme
         if(g_tree[i].dir == 1)
            g_tree[i].extreme = MathMax(g_tree[i].extreme, highNow);
         else
            g_tree[i].extreme = MathMin(g_tree[i].extreme, lowNow);
      }

      // Energy: rises on progress, decays when stalled
      if(prog)
         g_tree[i].energy = MathMin(100.0, g_tree[i].energy + 7.0);
      else
         g_tree[i].energy = MathMax(0.0, g_tree[i].energy - 2.0);

      // Refresh maturity/compression from source TF
      int src2 = g_tree[i].srcTf;
      if(src2 >= 0 && src2 < SE_TF_COUNT)
      {
         g_tree[i].mat  = g_se[src2].waveProgress;
         g_tree[i].comp = g_se[src2].compression;
      }

      // Update state label
      g_tree[i].state = Exec_NodeState(g_tree[i].dir, g_tree[i].energy,
                                       g_tree[i].depth, g_tree[i].comp, g_tree[i].mat);

      // Kill nodes with no energy
      if(g_tree[i].energy <= 2.0)
         g_tree[i].alive = false;

      if(g_tree[i].alive)
      {
         g_treeAlive++;
         if(g_tree[i].depth > g_treeMaxDepth)
            g_treeMaxDepth = g_tree[i].depth;
      }
   }

   // Prune if too many nodes
   while(g_treeCount > InpCurve_MaxNodes)
   {
      // Remove oldest dead nodes from the front
      bool removed = false;
      for(int i = 0; i < g_treeCount; i++)
      {
         if(!g_tree[i].alive)
         {
            // Shift array
            for(int j = i; j < g_treeCount - 1; j++)
               g_tree[j] = g_tree[j + 1];
            g_treeCount--;
            if(g_ownerIdx > i) g_ownerIdx--;
            else if(g_ownerIdx == i) g_ownerIdx = -1;
            removed = true;
            break;
         }
      }
      if(!removed) break;
   }

   // Re-find owner after update
   g_ownerIdx   = -1;
   g_ownerDepth = 999;
   g_ownerEnergy = -1.0;
   for(int i = 0; i < g_treeCount; i++)
   {
      if(!g_tree[i].alive) continue;
      if(g_tree[i].energy >= InpCurve_OwnMinEnergy)
      {
         if(g_tree[i].depth < g_ownerDepth ||
            (g_tree[i].depth == g_ownerDepth && g_tree[i].energy > g_ownerEnergy))
         {
            g_ownerDepth  = g_tree[i].depth;
            g_ownerEnergy = g_tree[i].energy;
            g_ownerIdx    = i;
         }
      }
   }
   if(g_ownerIdx < 0)
   {
      double bestE2 = -1.0;
      for(int i = 0; i < g_treeCount; i++)
      {
         if(g_tree[i].alive && g_tree[i].energy > bestE2)
         {
            bestE2 = g_tree[i].energy;
            g_ownerIdx = i;
         }
      }
   }

   if(g_ownerIdx >= 0)
   {
      g_ownerDir    = g_tree[g_ownerIdx].dir;
      g_ownerDepth  = g_tree[g_ownerIdx].depth;
      g_ownerEnergy = g_tree[g_ownerIdx].energy;
      g_ownerState  = g_tree[g_ownerIdx].state;
   }
   else
   {
      g_ownerDir    = 0;
      g_ownerDepth  = 0;
      g_ownerEnergy = 0.0;
      g_ownerState  = "";
   }
}


//==================================================================
// 16. COMPRESSION PERSISTENCE (F72 Principle 10)
// After break + pullback: can the counter side generate room?
//==================================================================
void Exec_UpdateCompressionPersistence()
{
   // Compression force combines: compression, residual energy, tree depth
   // Positive tightening boosts force; deep recursion leaks it
   static double prevCompress = 0.0;
   g_cpTighten = g_curve.compress - prevCompress;
   prevCompress = g_curve.compress;

   g_cpForce = MathMax(0.0, MathMin(100.0,
      g_curve.compress * 0.50 +
      g_curve.eRes * 0.20 -
      g_treeMaxDepth * 12.0 +
      MathMax(0.0, g_cpTighten) * 0.8 +
      8.0));

   // State classification
   if(g_cpForce >= 60.0)
      g_cpState = "PERSISTING";
   else if(g_cpForce <= 35.0)
      g_cpState = "LEAKING";
   else
      g_cpState = "NEUTRAL";
}

//==================================================================
// 17. IS TRADE ALIVE? (F72 single judgment)
// Combines compression force + energy + retrace + recursion
//==================================================================
void Exec_UpdateTradeAlive()
{
   // Recursion budget check
   int curveBudgetDepth = MathMax(1, MathMin(4, 1 + (int)MathRound(g_curve.compress / 33.0)));
   g_recursionComplete = (curveBudgetDepth > 0 && g_treeMaxDepth >= curveBudgetDepth);

   // Progress detection: price attacking/breaking the curve extreme
   double closeNow = Close[1];
   double highNow  = High[1];
   double lowNow   = Low[1];
   bool attacking = false;
   if(g_ownerIdx >= 0)
   {
      if(g_ownerDir == 1 && highNow >= g_tree[g_ownerIdx].extreme)
         attacking = true;
      if(g_ownerDir == -1 && lowNow <= g_tree[g_ownerIdx].extreme)
         attacking = true;
   }

   // Impulse detection (mode active in same direction)
   bool trendImp = (g_ownerDir == 1 && g_mode == 1) || (g_ownerDir == -1 && g_mode == -1);
   g_progressing = attacking || trendImp;

   // Retrace depth from curve extreme to origin
   double ownOrig = (g_ownerIdx >= 0) ? g_tree[g_ownerIdx].origin : g_curve.origin;
   double ownExt  = (g_ownerIdx >= 0) ? g_tree[g_ownerIdx].extreme : g_curve.extreme;
   double retrX = 50.0;
   if(ownExt != ownOrig && ownExt != 0.0 && ownOrig != 0.0)
      retrX = MathMin(100.0, MathAbs(ownExt - closeNow) / MathAbs(ownExt - ownOrig) * 100.0);

   // HTF parent threat (from H4 structure)
   SE_Result &seH4 = g_se[TF_H4];
   double parentThreat = 0.0;
   double atr = GetATR(1);
   if(atr <= 0.0) atr = 1e-10;
   if(g_ownerDir == 1 && seH4.swingHigh > closeNow)
      parentThreat = MathAbs(seH4.swingHigh - closeNow) / atr;
   else if(g_ownerDir == -1 && seH4.swingLow < closeNow && seH4.swingLow > 0)
      parentThreat = MathAbs(seH4.swingLow - closeNow) / atr;

   // Life score computation (matches F16 formula)
   double life = g_cpForce * 0.45 +
                 g_curve.eRes * 0.30 +
                 (g_cpTighten > 0.0 ? 12.0 : 0.0) -
                 (g_recursionComplete && !g_progressing ? 25.0 : 0.0) -
                 (StringCompare(g_cpState, "LEAKING") == 0 && !g_progressing ? 20.0 : 0.0) +
                 (g_progressing ? 28.0 : 0.0) +
                 (retrX < 25.0 ? 16.0 : retrX < 45.0 ? 6.0 : retrX > 75.0 ? -12.0 : 0.0) +
                 10.0;

   g_curveLifeScore = MathMax(0.0, MathMin(100.0, life));

   // State classification
   if(g_curveLifeScore >= InpLife_AliveThresh)
      g_curveLifeState = "ALIVE";
   else if(g_curveLifeScore <= InpLife_DeadThresh)
      g_curveLifeState = "DEAD";
   else
      g_curveLifeState = "WEAKENING";
}

//==================================================================
// 18. NARRATIVE LINEAGE
// Track sequence of entry curves, SUPPORT/DEGRADE voting
//==================================================================
void Exec_UpdateNarrativeLineage()
{
   double closeNow = Close[1];
   double highNow  = High[1];
   double lowNow   = Low[1];

   // Detect owner direction change (new lineage)
   if(g_ownerDir != g_narrDir)
   {
      g_narrDir       = g_ownerDir;
      g_narrLegExtreme = (g_ownerDir == 1) ? highNow : lowNow;
      g_narrLegPBDepth = 0.0;
      g_narrScore      = 50.0;
      g_narrSupVotes   = 0;
      g_narrDegVotes   = 0;
      ArrayResize(g_seqRetr, 0);
      ArrayResize(g_lifeSeq, 0);
   }

   if(g_ownerDir == 0) return;

   double ownOrig = (g_ownerIdx >= 0) ? g_tree[g_ownerIdx].origin : g_curve.origin;
   if(ownOrig == 0.0) return;

   // Check for new leg extreme
   bool newLegX = false;
   if(g_ownerDir == 1 && highNow > g_narrLegExtreme)
      newLegX = true;
   if(g_ownerDir == -1 && lowNow < g_narrLegExtreme)
      newLegX = true;

   if(newLegX)
   {
      // Score the completed pullback
      if(g_narrLegPBDepth > 6.0)
      {
         bool sup = (g_narrLegPBDepth <= 50.0 && g_cpTighten >= -1.0);
         bool deg = (g_narrLegPBDepth >= 62.0 || g_cpTighten < -3.0);
         int vote = sup ? 1 : deg ? -1 : 0;

         if(vote == 1)  g_narrSupVotes++;
         if(vote == -1) g_narrDegVotes++;

         g_narrScore += vote * 12.0 + (g_cpTighten > 0.0 ? 3.0 : -3.0);
         g_narrScore = MathMax(0.0, MathMin(100.0, g_narrScore));

         // Push to retrace sequence (max 5)
         int sz = ArraySize(g_seqRetr);
         ArrayResize(g_seqRetr, sz + 1);
         g_seqRetr[sz] = g_narrLegPBDepth;
         if(ArraySize(g_seqRetr) > 5)
         {
            // Shift left
            for(int i = 0; i < ArraySize(g_seqRetr) - 1; i++)
               g_seqRetr[i] = g_seqRetr[i + 1];
            ArrayResize(g_seqRetr, ArraySize(g_seqRetr) - 1);
         }

         // Push life to sequence
         int szL = ArraySize(g_lifeSeq);
         ArrayResize(g_lifeSeq, szL + 1);
         g_lifeSeq[szL] = g_curveLifeScore;
         if(ArraySize(g_lifeSeq) > 5)
         {
            for(int i = 0; i < ArraySize(g_lifeSeq) - 1; i++)
               g_lifeSeq[i] = g_lifeSeq[i + 1];
            ArrayResize(g_lifeSeq, ArraySize(g_lifeSeq) - 1);
         }
      }

      // Reset for new leg
      g_narrLegExtreme = (g_ownerDir == 1) ? highNow : lowNow;
      g_narrLegPBDepth = 0.0;
   }
   else
   {
      // Track pullback depth
      double legRange = MathAbs(g_narrLegExtreme - ownOrig);
      if(legRange > 1e-9)
      {
         double pbd = MathAbs(g_narrLegExtreme - closeNow) / legRange * 100.0;
         if(pbd > g_narrLegPBDepth)
            g_narrLegPBDepth = pbd;
      }
   }

   // Narrative state
   if(g_narrScore >= 65.0)
      g_narrState = "STRENGTHENING";
   else if(g_narrScore <= 35.0)
      g_narrState = "WEAKENING";
   else
      g_narrState = "HOLDING";

   // Chain vitality: life trending across curves
   int lsz = ArraySize(g_lifeSeq);
   if(lsz >= 2)
      g_chainVitality = MathMax(0.0, MathMin(100.0, 50.0 + (g_lifeSeq[lsz - 1] - g_lifeSeq[0])));
   else
      g_chainVitality = g_wholeChainLife;

   // Whole chain life: slow EMA of current life
   g_wholeChainLife += 0.02 * (g_curveLifeScore - g_wholeChainLife);
}


//==================================================================
// 19. CAMPAIGN OWNERSHIP (F72)
// TERMINAL vs EXPANSION state machine with location tracking
//==================================================================
void Exec_UpdateCampaign()
{
   SE_Result &seH4 = g_se[TF_H4];
   double atr = GetATR(1);
   if(atr <= 0.0) atr = 1e-10;
   double closeNow = Close[1];

   // HTF zone detection (H4 as primary HTF reference)
   double htfZone = 0.0;
   if(g_curve.dir == 1 && seH4.target > closeNow)
      htfZone = seH4.target;
   else if(g_curve.dir == -1 && seH4.target < closeNow && seH4.target > 0)
      htfZone = seH4.target;
   else if(g_curve.dir == 1 && seH4.swingHigh > closeNow)
      htfZone = seH4.swingHigh;
   else if(g_curve.dir == -1 && seH4.swingLow > 0 && seH4.swingLow < closeNow)
      htfZone = seH4.swingLow;

   double distHTF = (htfZone > 0) ? MathAbs(htfZone - closeNow) : 0.0;
   g_curveBudget = (distHTF > 0) ? MathMin(100.0, distHTF / (atr * 8.0) * 100.0) : 100.0;

   bool atHTF = (distHTF > 0 && distHTF < atr * 1.5);
   bool nearHTF = (g_curveBudget < 25.0);

   // Terminal phase detection from Part 3 wave progress + EDE state
   bool termPhase = (g_ede_state >= 4) || (g_waveProgress >= 75.0) || g_liqg_active;

   // Campaign state
   if(atHTF || termPhase)
      g_campaignState = "TERMINAL";
   else
      g_campaignState = "EXPANSION";

   // Location
   if(atHTF || termPhase)
      g_campaignLocation = "INSIDE HTF ZONE";
   else if(nearHTF)
      g_campaignLocation = "APPROACHING HTF ZONE";
   else if(g_ede_state >= 3)
      g_campaignLocation = "TRANSITIONING";
   else
      g_campaignLocation = "BUILDING";

   // Owner direction (from curve object, fallback to phase engine)
   g_campaignOwnerDir = (g_curve.dir != 0) ? g_curve.dir : g_mode;
}

//==================================================================
// 20. PARTICIPANT INTERFERENCE ZONES (0.618/0.70/0.786/Flip)
//==================================================================
void Exec_UpdateParticipantZones()
{
   double pcHi  = g_curve.extreme;
   double pcLo  = g_curve.origin;
   double pcRng = pcHi - pcLo;
   double closeNow = Close[1];

   // Compute Fibonacci retracement levels
   if(MathAbs(pcRng) > 1e-10)
   {
      g_part_618 = pcHi - 0.618 * pcRng;
      g_part_70  = pcHi - 0.70  * pcRng;
      g_part_786 = pcHi - 0.786 * pcRng;

      // Flip level from Part 1 flipzones
      if(g_curve.dir == 1)
         g_part_flip = g_longInducPrice;
      else if(g_curve.dir == -1)
         g_part_flip = g_shortInducPrice;
      else
         g_part_flip = 0.0;

      // Current retrace depth (absolute)
      g_partRetrAbs = MathAbs(pcHi - closeNow) / MathAbs(pcRng);

      // Zone classification
      if(g_partRetrAbs < 0.55)
         g_partZone = "pre-0.618 clean";
      else if(g_partRetrAbs < 0.66)
         g_partZone = "0.618 participants in";
      else if(g_partRetrAbs < 0.74)
         g_partZone = "0.70 interference";
      else if(g_partRetrAbs < 0.82)
         g_partZone = "0.786 heavy";
      else
         g_partZone = "FLIP true induction";
   }
   else
   {
      g_part_618    = 0.0;
      g_part_70     = 0.0;
      g_part_786    = 0.0;
      g_part_flip   = 0.0;
      g_partRetrAbs = 0.0;
      g_partZone    = "";
   }
}

//==================================================================
// 21. TIME INTELLIGENCE ENGINE (5-cycle stack: MN/W/D/H4/H1)
// Fetches OHLC from higher timeframes via iClose/iHigh/iLow/iOpen
//==================================================================
void Exec_UpdateTimeIntelligence()
{
   double closeNow = Close[1];

   //-- Monthly cycle --
   g_timeMN.open     = iOpen(_Symbol, PERIOD_MN1, 0);
   g_timeMN.high     = iHigh(_Symbol, PERIOD_MN1, 0);
   g_timeMN.low      = iLow(_Symbol, PERIOD_MN1, 0);
   g_timeMN.prevHigh = iHigh(_Symbol, PERIOD_MN1, 1);
   g_timeMN.prevLow  = iLow(_Symbol, PERIOD_MN1, 1);
   g_timeMN.bias     = (closeNow > g_timeMN.open) ? 1 : (closeNow < g_timeMN.open) ? -1 : 0;
   g_timeMN.highTaken = (g_timeMN.high > g_timeMN.prevHigh);
   g_timeMN.lowTaken  = (g_timeMN.low < g_timeMN.prevLow);
   Exec_ComputeCycleState(g_timeMN, PERIOD_MN1);

   //-- Weekly cycle --
   g_timeW.open     = iOpen(_Symbol, PERIOD_W1, 0);
   g_timeW.high     = iHigh(_Symbol, PERIOD_W1, 0);
   g_timeW.low      = iLow(_Symbol, PERIOD_W1, 0);
   g_timeW.prevHigh = iHigh(_Symbol, PERIOD_W1, 1);
   g_timeW.prevLow  = iLow(_Symbol, PERIOD_W1, 1);
   g_timeW.bias     = (closeNow > g_timeW.open) ? 1 : (closeNow < g_timeW.open) ? -1 : 0;
   g_timeW.highTaken = (g_timeW.high > g_timeW.prevHigh);
   g_timeW.lowTaken  = (g_timeW.low < g_timeW.prevLow);
   Exec_ComputeCycleState(g_timeW, PERIOD_W1);

   //-- Daily cycle --
   g_timeD.open     = iOpen(_Symbol, PERIOD_D1, 0);
   g_timeD.high     = iHigh(_Symbol, PERIOD_D1, 0);
   g_timeD.low      = iLow(_Symbol, PERIOD_D1, 0);
   g_timeD.prevHigh = iHigh(_Symbol, PERIOD_D1, 1);
   g_timeD.prevLow  = iLow(_Symbol, PERIOD_D1, 1);
   g_timeD.bias     = (closeNow > g_timeD.open) ? 1 : (closeNow < g_timeD.open) ? -1 : 0;
   g_timeD.highTaken = (g_timeD.high > g_timeD.prevHigh);
   g_timeD.lowTaken  = (g_timeD.low < g_timeD.prevLow);
   Exec_ComputeCycleState(g_timeD, PERIOD_D1);

   //-- H4 cycle --
   g_timeH4.open     = iOpen(_Symbol, PERIOD_H4, 0);
   g_timeH4.high     = iHigh(_Symbol, PERIOD_H4, 0);
   g_timeH4.low      = iLow(_Symbol, PERIOD_H4, 0);
   g_timeH4.prevHigh = iHigh(_Symbol, PERIOD_H4, 1);
   g_timeH4.prevLow  = iLow(_Symbol, PERIOD_H4, 1);
   g_timeH4.bias     = (closeNow > g_timeH4.open) ? 1 : (closeNow < g_timeH4.open) ? -1 : 0;
   g_timeH4.highTaken = (g_timeH4.high > g_timeH4.prevHigh);
   g_timeH4.lowTaken  = (g_timeH4.low < g_timeH4.prevLow);
   Exec_ComputeCycleState(g_timeH4, PERIOD_H4);

   //-- H1 cycle --
   g_timeH1.open     = iOpen(_Symbol, PERIOD_H1, 0);
   g_timeH1.high     = iHigh(_Symbol, PERIOD_H1, 0);
   g_timeH1.low      = iLow(_Symbol, PERIOD_H1, 0);
   g_timeH1.prevHigh = iHigh(_Symbol, PERIOD_H1, 1);
   g_timeH1.prevLow  = iLow(_Symbol, PERIOD_H1, 1);
   g_timeH1.bias     = (closeNow > g_timeH1.open) ? 1 : (closeNow < g_timeH1.open) ? -1 : 0;
   g_timeH1.highTaken = (g_timeH1.high > g_timeH1.prevHigh);
   g_timeH1.lowTaken  = (g_timeH1.low < g_timeH1.prevLow);
   Exec_ComputeCycleState(g_timeH1, PERIOD_H1);

   //-- Aggregate: time direction, alignment, conflict --
   int tBull = (g_timeMN.bias == 1 ? 1 : 0) +
               (g_timeW.bias == 1 ? 1 : 0) +
               (g_timeD.bias == 1 ? 1 : 0) +
               (g_timeH4.bias == 1 ? 1 : 0) +
               (g_timeH1.bias == 1 ? 1 : 0);
   int tBear = (g_timeMN.bias == -1 ? 1 : 0) +
               (g_timeW.bias == -1 ? 1 : 0) +
               (g_timeD.bias == -1 ? 1 : 0) +
               (g_timeH4.bias == -1 ? 1 : 0) +
               (g_timeH1.bias == -1 ? 1 : 0);

   g_timeDir = (tBull > tBear) ? 1 : (tBear > tBull) ? -1 : 0;

   int totalVotes = tBull + tBear;
   g_timeAlign   = (totalVotes > 0) ? (double)MathMax(tBull, tBear) / totalVotes * 100.0 : 50.0;
   g_timeConflict = 100.0 - g_timeAlign;

   //-- H1 timing sequence --
   double h1Pos = 50.0;
   double h1Rng = g_timeH1.high - g_timeH1.low;
   if(h1Rng > 0)
      h1Pos = (closeNow - g_timeH1.low) / h1Rng * 100.0;

   if(g_timeH1.highTaken && g_timeH1.lowTaken)
      g_h1Timing = "COMPLETION";
   else if(h1Pos >= 55.0)
      g_h1Timing = "LOW FIRST";
   else if(h1Pos <= 45.0)
      g_h1Timing = "HIGH FIRST";
   else
      g_h1Timing = "BALANCED";
}

//==================================================================
// 21A. TIME CYCLE STATE HELPER
//==================================================================
void Exec_ComputeCycleState(TimeCycle &cycle, ENUM_TIMEFRAMES tf)
{
   // Elapsed: approximate based on period seconds vs time since open
   int periodSec = PeriodSeconds(tf);
   if(periodSec <= 0) periodSec = 3600;
   datetime cycleOpenTime = iTime(_Symbol, tf, 0);
   datetime now = TimeCurrent();
   double elapsed = (double)(now - cycleOpenTime) / (double)periodSec;
   cycle.elapsed = MathMax(0.0, MathMin(1.0, elapsed));

   // State
   if(cycle.highTaken && cycle.lowTaken)
   {
      cycle.state = "DUAL DONE";
      cycle.completion = 95.0;
   }
   else if(cycle.highTaken)
   {
      cycle.state = "HIGH DONE";
      cycle.completion = 45.0;
   }
   else if(cycle.lowTaken)
   {
      cycle.state = "LOW DONE";
      cycle.completion = 45.0;
   }
   else if(cycle.elapsed < 0.15)
   {
      cycle.state = "OPENING";
      cycle.completion = cycle.elapsed * 15.0;
   }
   else if(cycle.elapsed < 0.6)
   {
      cycle.state = "EXPANDING";
      cycle.completion = cycle.elapsed * 15.0;
   }
   else if(cycle.elapsed < 0.9)
   {
      cycle.state = "MID CYCLE";
      cycle.completion = cycle.elapsed * 15.0;
   }
   else
   {
      cycle.state = "TERMINAL";
      cycle.completion = cycle.elapsed * 15.0;
   }
}


//==================================================================
// 22. LOT SIZING ENGINE (from Symphony - unchanged)
// Distance-based for XAUUSD model
//==================================================================
double ComputeLots(double riskCash, double entry, double sl)
{
   // Absolute distance in price
   double dist = MathAbs(entry - sl);
   if(dist <= 0.0) return(0.0);

   // Distance in "gold pips": $0.10 = 1 pip -> dist * 10
   double distancePips = dist * 10.0;

   // Pip value per 1.00 lot: $10 per pip
   double pipValuePerLot = 10.0;

   // Total risk per full lot at this SL distance
   double riskPerLot = distancePips * pipValuePerLot;

   if(riskPerLot <= 0.0) return(0.0);

   // Raw lots from risk
   double lots = riskCash / riskPerLot;

   // Broker constraints
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   // Normalise to broker increment, floor
   lots = MathFloor(lots / lotStep) * lotStep;
   if(lots < minLot) lots = minLot;

   return(NormalizeDouble(lots, 2));
}

//==================================================================
// 23. RAW ORDER EXECUTION (from Symphony - IOC filling)
//==================================================================
bool SendMarketOrder(int direction, double lots, double sl, const string comment)
{
   if(lots <= 0.0) return(false);

   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   req.action       = TRADE_ACTION_DEAL;
   req.symbol       = _Symbol;
   req.magic        = InpMagic;
   req.volume       = lots;
   req.sl           = sl;
   req.tp           = 0.0;
   req.deviation    = 20;
   req.type_filling = ORDER_FILLING_IOC;
   req.type_time    = ORDER_TIME_GTC;
   req.comment      = comment;

   if(direction > 0)
   {
      req.type  = ORDER_TYPE_BUY;
      req.price = ask;
   }
   else
   {
      req.type  = ORDER_TYPE_SELL;
      req.price = bid;
   }

   if(!OrderSend(req, res))
   {
      Print("OrderSend failed dir=", direction, " lots=", lots, " retcode=", res.retcode);
      return(false);
   }

   if(res.retcode != TRADE_RETCODE_DONE && res.retcode != TRADE_RETCODE_DONE_PARTIAL)
   {
      Print("OrderSend not DONE, retcode=", res.retcode);
      return(false);
   }

   return(true);
}

//==================================================================
// 24. CLOSE POSITION PARTIAL (from Symphony)
//==================================================================
bool ClosePositionPartial(ulong ticket, double lotsToClose)
{
   if(lotsToClose <= 0.0) return(false);
   if(!PositionSelectByTicket(ticket)) return(false);

   string sym  = PositionGetString(POSITION_SYMBOL);
   long   mgc  = PositionGetInteger(POSITION_MAGIC);
   long   type = PositionGetInteger(POSITION_TYPE);
   double posLots = PositionGetDouble(POSITION_VOLUME);

   if(sym != _Symbol) return(false);
   if(mgc != InpMagic) return(false);

   lotsToClose = NormalizeDouble(lotsToClose, 2);
   if(lotsToClose > posLots) lotsToClose = posLots;
   if(lotsToClose <= 0) return(false);

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);

   req.action       = TRADE_ACTION_DEAL;
   req.symbol       = _Symbol;
   req.magic        = InpMagic;
   req.position     = ticket;
   req.volume       = lotsToClose;
   req.deviation    = 20;
   req.type_filling = ORDER_FILLING_IOC;
   req.type_time    = ORDER_TIME_GTC;
   req.comment      = "MASTER TRIM";

   if(type == POSITION_TYPE_BUY)
   {
      req.type  = ORDER_TYPE_SELL;
      req.price = bid;
   }
   else
   {
      req.type  = ORDER_TYPE_BUY;
      req.price = ask;
   }

   if(!OrderSend(req, res))
   {
      Print("ClosePartial failed ticket=", ticket, " lots=", lotsToClose, " retcode=", res.retcode);
      return(false);
   }

   if(res.retcode != TRADE_RETCODE_DONE && res.retcode != TRADE_RETCODE_DONE_PARTIAL)
   {
      Print("ClosePartial not DONE ticket=", ticket, " retcode=", res.retcode);
      return(false);
   }

   return(true);
}

//==================================================================
// 25. CLOSE POSITION FULL (from Symphony)
//==================================================================
bool ClosePositionFull(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return(false);
   double lots = PositionGetDouble(POSITION_VOLUME);
   return(ClosePositionPartial(ticket, lots));
}


//==================================================================
// 26. INTELLIGENCE ENTRY GATE
// Combines all intelligence conditions for trade readiness
//==================================================================
bool Exec_CheckEntryGate(int tradeDir)
{
   // (a) Senseei must be ATTACK or PREPARE
   bool senseeiOK = (StringCompare(g_senseei_action, "ATTACK") == 0 ||
                     StringCompare(g_senseei_action, "PREPARE") == 0);
   if(!senseeiOK) return(false);

   // (b) Fractal stack direction must agree with trade direction
   if(g_fractalStackDir != 0 && g_fractalStackDir != tradeDir)
      return(false);

   // (c) ERF confidence must meet threshold (trade readiness)
   if(g_erf_confidence < InpERF_ReadyThresh)
      return(false);

   // (d) Liquidation wave must NOT be active blocking
   //     (exception: objective has arrived = safe to trade)
   if(g_liqg_active && !g_liqg_objArrival)
      return(false);

   // (e) Time filter must pass
   if(!IsTradeTime())
      return(false);

   // (f) Curve life must not be DEAD
   if(StringCompare(g_curveLifeState, "DEAD") == 0)
      return(false);

   // (g) Time Intelligence alignment: time direction should not conflict with trade
   if(g_timeDir != 0 && g_timeDir != tradeDir && g_timeConflict > 70.0)
      return(false);

   return(true);
}

//==================================================================
// 27. MASTER EXECUTION LOGIC
// Symphony Phase 3+4 entries gated by intelligence
//==================================================================
void Exec_MasterEntry()
{
   int barsAvail = (int)ArraySize(Close);
   if(barsAvail < 3) return;

   int    shiftNow = 1;
   double closeNow = Close[shiftNow];
   double atrNow   = GetATR(shiftNow);
   datetime barTime = Time[0];

   double equity   = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskCash = equity * InpRiskPercent * 0.01;

   // Time filter (primary - redundant with gate but early exit)
   if(!IsTradeTime())
      return;

   // Phase conditions from Part 1
   bool L3 = (g_mode == 1  && g_phaseLong == 3);
   bool L4 = (g_mode == 1  && g_phaseLong == 4);
   bool S3 = (g_mode == -1 && g_phaseShort == 3);
   bool S4 = (g_mode == -1 && g_phaseShort == 4);

   //-- LONG Phase 3 Entry --
   if(L3 && g_lastLongTradeTime != barTime)
   {
      if(Exec_CheckEntryGate(+1))
      {
         double entry = closeNow;
         double sl    = g_anchorLow - atrNow * 0.25;
         double lots  = ComputeLots(riskCash, entry, sl);
         if(sl > 0 && entry > sl && lots > 0)
         {
            if(SendMarketOrder(+1, lots, sl, "MASTER P3 Long"))
            {
               g_lastLongTradeTime = barTime;
               g_lastEntryReason   = "P3L gate=" + g_senseei_action +
                                     " erf=" + DoubleToString(g_erf_confidence, 0) +
                                     " life=" + g_curveLifeState;
            }
         }
      }
   }

   //-- LONG Phase 4 Entry (breakout) --
   if(L4 && g_lastLongTradeTime != barTime)
   {
      bool breakout = (closeNow > g_anchorHigh ||
                       closeNow > High[shiftNow + 1] + InpEntry_BreakoutMult * atrNow);
      if(breakout && Exec_CheckEntryGate(+1))
      {
         double entry = closeNow;
         double sl    = g_anchorLow - atrNow * 0.25;
         double lots  = ComputeLots(riskCash, entry, sl);
         if(sl > 0 && entry > sl && lots > 0)
         {
            if(SendMarketOrder(+1, lots, sl, "MASTER P4 Long"))
            {
               g_lastLongTradeTime = barTime;
               g_lastEntryReason   = "P4L breakout gate=" + g_senseei_action;
            }
         }
      }
   }

   //-- SHORT Phase 3 Entry --
   if(S3 && g_lastShortTradeTime != barTime)
   {
      if(Exec_CheckEntryGate(-1))
      {
         double entry = closeNow;
         double sl    = g_anchorHigh + atrNow * 0.25;
         double lots  = ComputeLots(riskCash, entry, sl);
         if(sl > 0 && sl > entry && lots > 0)
         {
            if(SendMarketOrder(-1, lots, sl, "MASTER P3 Short"))
            {
               g_lastShortTradeTime = barTime;
               g_lastEntryReason    = "P3S gate=" + g_senseei_action +
                                      " erf=" + DoubleToString(g_erf_confidence, 0) +
                                      " life=" + g_curveLifeState;
            }
         }
      }
   }

   //-- SHORT Phase 4 Entry (breakout) --
   if(S4 && g_lastShortTradeTime != barTime)
   {
      bool breakout = (closeNow < g_anchorLow ||
                       closeNow < Low[shiftNow + 1] - InpEntry_BreakoutMult * atrNow);
      if(breakout && Exec_CheckEntryGate(-1))
      {
         double entry = closeNow;
         double sl    = g_anchorHigh + atrNow * 0.25;
         double lots  = ComputeLots(riskCash, entry, sl);
         if(sl > 0 && sl > entry && lots > 0)
         {
            if(SendMarketOrder(-1, lots, sl, "MASTER P4 Short"))
            {
               g_lastShortTradeTime = barTime;
               g_lastEntryReason    = "P4S breakout gate=" + g_senseei_action;
            }
         }
      }
   }
}


//==================================================================
// 28. COMPOSITE EXIT SYSTEM
// ARC + Institutional + Phase-Change + Intelligence Exits
//==================================================================
void Exec_ManageExits()
{
   int barsAvail = (int)ArraySize(Close);
   if(barsAvail <= (2 * InpPivotLen + 5)) return;

   int    shiftNow = 1;
   double closeNow = Close[shiftNow];
   double atrNow   = GetATR(shiftNow);

   //==================================================
   // SECTION A: ARC EXHAUSTION (from Symphony)
   //==================================================
   bool arcExhaustLong  = (g_mode == 1  && g_arcLong  > 0.0 &&
                           closeNow >= (g_arcLong - InpArcToleranceAtr * atrNow));
   bool arcExhaustShort = (g_mode == -1 && g_arcShort > 0.0 &&
                           closeNow <= (g_arcShort + InpArcToleranceAtr * atrNow));

   //==================================================
   // SECTION B: INSTITUTIONAL OUTER-BAND SWEEP (from Symphony)
   //==================================================
   // Long side institutional levels
   double instLevelL = (g_longInducPrice != 0.0) ? g_longInducPrice :
                       (g_anchorHigh > 0.0 ? g_anchorHigh : 0.0);
   double innerTopL  = (g_longInducHigh > 0.0) ? g_longInducHigh : instLevelL;
   double outerTopL  = innerTopL + InpOuterBandAtrMult * atrNow;

   // Short side institutional levels
   double instLevelS = (g_shortInducPrice != 0.0) ? g_shortInducPrice :
                       (g_anchorLow > 0.0 ? g_anchorLow : 0.0);
   double innerBotS  = (g_shortInducLow != 0.0) ? g_shortInducLow : instLevelS;
   double outerBotS  = innerBotS - InpOuterBandAtrMult * atrNow;

   // Track outer-band sweeps
   if(g_mode == 1 && instLevelL > 0.0 && closeNow > outerTopL)
      g_longOuterBreachSeen = true;
   if(g_mode == -1 && instLevelS > 0.0 && closeNow < outerBotS)
      g_shortOuterBreachSeen = true;

   //==================================================
   // SECTION C: PHASE-CHANGE AT EXTREME (from Symphony)
   //==================================================
   bool phaseTrendEndLong = (g_mode == 1 &&
      (g_prevPhaseLong == 3 || g_prevPhaseLong == 4) &&
      (g_phaseLong <= 1));

   bool phaseTrendEndShort = (g_mode == -1 &&
      (g_prevPhaseShort == 3 || g_prevPhaseShort == 4) &&
      (g_phaseShort <= 1));

   //==================================================
   // SECTION D: SYMPHONY COMPOSITE EXIT CONDITION
   //==================================================
   bool symExitLong = false;
   bool symExitShort = false;

   // LONG: ARC exhaust + outer sweep + inner-band re-entry + phase-end
   if(g_mode == 1 && arcExhaustLong && phaseTrendEndLong)
   {
      bool hasInstL = (instLevelL > 0.0);
      bool instPatternOK = !hasInstL ||
         (g_longOuterBreachSeen && closeNow < innerTopL);
      if(instPatternOK)
         symExitLong = true;
   }

   // SHORT: ARC exhaust + outer sweep + inner-band re-entry + phase-end
   if(g_mode == -1 && arcExhaustShort && phaseTrendEndShort)
   {
      bool hasInstS = (instLevelS > 0.0);
      bool instPatternOK = !hasInstS ||
         (g_shortOuterBreachSeen && closeNow > innerBotS);
      if(instPatternOK)
         symExitShort = true;
   }

   //==================================================
   // SECTION E: INTELLIGENCE-BASED EXIT CONDITIONS
   //==================================================
   // (a) Senseei flips to MANAGE or WAIT (no longer attacking)
   bool senseeiExit = (StringCompare(g_senseei_action, "MANAGE") == 0 ||
                       StringCompare(g_senseei_action, "WAIT") == 0);

   // (b) Curve life drops to DEAD
   bool curveDeadExit = (StringCompare(g_curveLifeState, "DEAD") == 0);

   // (c) ERF resolution state becomes RESOLVED
   bool erfResolvedExit = (g_re_resolutionState == 2);  // 2 = RESOLVED

   // Intelligence exit fires only if at least 2 of 3 conditions met
   int intelExitCount = (senseeiExit ? 1 : 0) +
                        (curveDeadExit ? 1 : 0) +
                        (erfResolvedExit ? 1 : 0);
   bool intelExitLong  = (g_mode == 1  && intelExitCount >= 2);
   bool intelExitShort = (g_mode == -1 && intelExitCount >= 2);

   //==================================================
   // SECTION F: COMBINED EXIT DECISION
   //==================================================
   bool exitLong  = symExitLong  || intelExitLong;
   bool exitShort = symExitShort || intelExitShort;

   if(!exitLong && !exitShort)
      return;

   // Record exit reason
   if(exitLong)
   {
      if(symExitLong)
         g_lastExitReason = "ARC+INST+PHASE long exit";
      else
         g_lastExitReason = "INTEL exit: senseei=" + g_senseei_action +
                            " life=" + g_curveLifeState +
                            " erf=" + IntegerToString(g_re_resolutionState);
   }
   if(exitShort)
   {
      if(symExitShort)
         g_lastExitReason = "ARC+INST+PHASE short exit";
      else
         g_lastExitReason = "INTEL exit: senseei=" + g_senseei_action +
                            " life=" + g_curveLifeState +
                            " erf=" + IntegerToString(g_re_resolutionState);
   }

   //==================================================
   // SECTION G: EXECUTE EXITS ON MATCHING POSITIONS
   //==================================================
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;

      string sym  = PositionGetString(POSITION_SYMBOL);
      long   mgc  = PositionGetInteger(POSITION_MAGIC);
      long   type = PositionGetInteger(POSITION_TYPE);

      if(sym != _Symbol) continue;
      if(mgc != InpMagic) continue;

      // LONG positions
      if(exitLong && type == POSITION_TYPE_BUY)
      {
         if(!ClosePositionFull(ticket))
            Print("EXIT LONG failed ticket=", ticket, " err=", GetLastError());
      }

      // SHORT positions
      if(exitShort && type == POSITION_TYPE_SELL)
      {
         if(!ClosePositionFull(ticket))
            Print("EXIT SHORT failed ticket=", ticket, " err=", GetLastError());
      }
   }
}


//==================================================================
// 29. MASTER UPDATE FUNCTION - EXECUTION ENGINE
// Calls all sub-engines in correct dependency order, then executes
//==================================================================
void Exec_UpdateAll()
{
   // 1. Curve Object (needs Part 2 SE + Part 3 EDE/RE)
   Exec_UpdateCurveObject();

   // 2. Curve Tree (needs curve object + SE CHoCH)
   Exec_UpdateCurveTree();

   // 3. Compression Persistence (needs curve object + tree)
   Exec_UpdateCompressionPersistence();

   // 4. Is Trade Alive? (needs compression + tree + curve)
   Exec_UpdateTradeAlive();

   // 5. Narrative Lineage (needs trade alive + owner + compression)
   Exec_UpdateNarrativeLineage();

   // 6. Campaign Ownership (needs curve + EDE + liqg)
   Exec_UpdateCampaign();

   // 7. Participant Interference Zones (needs curve object)
   Exec_UpdateParticipantZones();

   // 8. Time Intelligence (independent HTF data)
   Exec_UpdateTimeIntelligence();

   // 9. Composite Exit System (needs ARC + intelligence states)
   Exec_ManageExits();

   // 10. Master Entry Logic (needs phase engine + intelligence gate)
   Exec_MasterEntry();
}

//==================================================================
// 30. INITIALIZATION
//==================================================================
void Exec_Init()
{
   // Curve Object
   g_curve.dir      = 0;
   g_curve.origin   = 0.0;
   g_curve.extreme  = 0.0;
   g_curve.dispATR  = 0.0;
   g_curve.eIn      = 0.0;
   g_curve.eDiss    = 0.0;
   g_curve.eRes     = 0.0;
   g_curve.convex   = 0.0;
   g_curve.compress = 0.0;
   g_curve.maturity = 0.0;

   // Curve Tree
   ArrayResize(g_tree, InpCurve_MaxNodes + 10);
   g_treeCount    = 0;
   g_nodeSeq      = 0;
   g_treeAlive    = 0;
   g_treeMaxDepth = 0;
   g_ownerIdx     = -1;
   g_ownerDir     = 0;
   g_ownerDepth   = 0;
   g_ownerEnergy  = 0.0;
   g_ownerState   = "";

   // Compression Persistence
   g_cpForce   = 0.0;
   g_cpState   = "NEUTRAL";
   g_cpTighten = 0.0;

   // Is Trade Alive
   g_curveLifeScore    = 50.0;
   g_curveLifeState    = "ALIVE";
   g_recursionComplete = false;
   g_progressing       = false;

   // Narrative Lineage
   g_narrDir        = 0;
   g_narrScore      = 50.0;
   g_narrState      = "HOLDING";
   g_narrSupVotes   = 0;
   g_narrDegVotes   = 0;
   g_narrLegExtreme = 0.0;
   g_narrLegPBDepth = 0.0;
   g_chainVitality  = 50.0;
   g_wholeChainLife = 50.0;
   ArrayResize(g_seqRetr, 0);
   ArrayResize(g_lifeSeq, 0);

   // Campaign
   g_campaignState    = "EXPANSION";
   g_campaignLocation = "BUILDING";
   g_campaignOwnerDir = 0;
   g_curveBudget      = 100.0;

   // Participant Zones
   g_part_618    = 0.0;
   g_part_70     = 0.0;
   g_part_786    = 0.0;
   g_part_flip   = 0.0;
   g_partZone    = "";
   g_partRetrAbs = 0.0;

   // Time Intelligence
   ZeroMemory(g_timeMN);
   ZeroMemory(g_timeW);
   ZeroMemory(g_timeD);
   ZeroMemory(g_timeH4);
   ZeroMemory(g_timeH1);
   g_timeDir      = 0;
   g_timeAlign    = 50.0;
   g_timeConflict = 50.0;
   g_h1Timing     = "BALANCED";
   g_timeStack    = "";

   // Execution tracking
   g_entryGateOpen   = false;
   g_lastEntryReason = "";
   g_lastExitReason  = "";
}
//+------------------------------------------------------------------+
