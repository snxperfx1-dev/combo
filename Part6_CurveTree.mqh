//+------------------------------------------------------------------+
//| Part6_CurveTree.mqh - F72 Curve Object, Recursive Curve Tree,  |
//|                       Campaign Ownership, Participant Zones,    |
//|                       Compression Persistence, Narrative Lineage|
//|                       and Trade-Alive Judgement                 |
//| Master MT5 EA: Symphony + Letra + F16 Combined System           |
//+------------------------------------------------------------------+
#property strict

//==================================================================
// GLOBALS - CURVE TREE ENGINE
//==================================================================
int      g_curveOwnerDir    = 0;       // Owner curve direction
double   g_curveOwnerEnergy = 0.0;     // Owner curve energy
char     g_curveOwnerState[64];        // Owner curve phase state string
int      g_nodeSeq          = 0;       // Monotonic node sequence counter

//==================================================================
// STRUCTS - CAMPAIGN / PARTICIPANT / COMPRESSION / TRADE-ALIVE
//==================================================================

struct CampaignState
{
   string   campaign;       // "TERMINAL" or "EXPANSION"
   string   location;       // "INSIDE HTF ZONE" / "APPROACHING" / "TRANSITIONING" / "BUILDING"
   int      ownerDir;       // Owner direction from curve object
   double   curveBudget;    // Budget to HTF (0-100)
   string   compRegime;     // "FAILURE SWING" / "COMPRESSED" / "MEDIUM" / "WIDE"
   int      expDepth;       // Expected recursion depth
};

struct ParticipantZone
{
   double   f618;           // 0.618 retracement level
   double   f70;            // 0.70 retracement level
   double   f786;           // 0.786 retracement level
   double   flipLvl;        // Flip level (flipBot for bull, flipTop for bear)
   string   zone;           // Zone classification
   string   interference;   // Interference state
};

struct CompressionState
{
   double   force;          // Compression persistence force (0-100)
   string   state;          // "PERSISTING" / "LEAKING" / "NEUTRAL"
   string   trend;          // "tightening" / "broadening" / "stable"
};

struct TradeAliveState
{
   double   life;           // Life score (0-100)
   string   verdict;        // "ALIVE ATTACKING" / "ALIVE HOLD" / "DEAD FLIP" / "WEAKENING MANAGE"
   bool     progressing;    // Price attacking extreme or trend impulse
   double   retrFromExtreme; // Retrace depth from extreme (0-100)
};

struct NarrativeState
{
   double   score;          // Narrative score (0-100)
   string   state;          // "STRENGTHENING" / "WEAKENING" / "HOLDING"
   int      supVotes;       // Support votes count
   int      degVotes;       // Degrade votes count
   double   chainVitality;  // Chain vitality score (0-100)
   string   chainScope;     // "healthy" / "CURVE only" / "CHAIN weakening" / "WHOLE CHAIN decaying"
};

//==================================================================
// GLOBAL STATE INSTANCES - CURVE TREE SUB-ENGINES
//==================================================================
CampaignState    g_campaign;
ParticipantZone  g_participant;
CompressionState g_compression;
TradeAliveState  g_tradeAlive;
NarrativeState   g_narrative;

//==================================================================
// PER-RUNG CURVE FAMILY (c_r1 through c_r6)
//==================================================================
CurveObject      g_curveRung[6];   // One per TF: M1, M3, M5, M15, H1, H4

//==================================================================
// INTERNAL STATICS (tracked across calls)
//==================================================================
double   s_prevCompress    = 0.0;   // Previous compression value
int      s_narrDir         = 0;     // Narrative direction tracking
double   s_legExtreme      = 0.0;   // Current leg extreme price
double   s_legPBdepth      = 0.0;   // Current leg pullback depth
double   s_narrativeScore  = 50.0;  // Running narrative score
int      s_supVotes        = 0;     // Accumulated support votes
int      s_degVotes        = 0;     // Accumulated degrade votes
double   s_wholeChainLife  = 50.0;  // Whole-chain life (persistent)
double   s_lifeSeq[5];             // Recent life scores
int      s_lifeSeqCount    = 0;
double   s_retrSeq[5];             // Recent retrace depths
int      s_retrSeqCount    = 0;

//==================================================================
// 1. CURVE OBJECT COMPUTATION
//    Assembles the canonical curve from physics primitives.
//    dir/origin/extreme from M5 structure; energy from EDE/RE.
//==================================================================

void UpdateCurveObject()
{
   // Direction from M5 wave (index 2)
   g_curve.dir = g_letra[2].dir;

   // Origin = M5 invalidation level
   g_curve.origin = g_letra[2].inv;

   // Extreme = cycle high/low depending on direction
   if(g_curve.dir == 1)
      g_curve.extreme = g_spawn.cycleHigh;
   else if(g_curve.dir == -1)
      g_curve.extreme = g_spawn.cycleLow;
   else
      g_curve.extreme = Close[0];

   // Displacement in ATR units
   double atr = GetATR(0);
   if(g_curve.origin != 0.0 && atr > 0.0)
      g_curve.dispATR = MathAbs(g_curve.extreme - g_curve.origin) / atr;
   else
      g_curve.dispATR = 0.0;

   // Energy fields from framework
   g_curve.eIn      = g_energy.ede_expansionEnergy;
   g_curve.eDiss    = g_energy.ede_dissipatedEnergy;
   g_curve.eRes     = g_energy.re_residualEnergyScore;

   // Convexity from energy framework
   g_curve.convex   = g_energy.convexityMaturity * 100.0;

   // Compression from M5 structure engine
   g_curve.compress = g_letra[2].compression;

   // Maturity from wave progress
   g_curve.maturity = g_energy.waveProgress;
}

//==================================================================
// 2. PER-RUNG CURVE FAMILY
//    One Curve per fixed timeframe (M1-H4) with direction, origin,
//    convexity maturity, compression from their respective outputs.
//==================================================================

void UpdateCurveRungs()
{
   for(int i = 0; i < 6; i++)
   {
      g_curveRung[i].dir      = g_letra[i].dir;
      g_curveRung[i].origin   = g_letra[i].inv;
      g_curveRung[i].extreme  = 0.0;  // Not tracked per-rung (canonical only)
      g_curveRung[i].dispATR  = 0.0;
      g_curveRung[i].eIn      = 100.0;
      g_curveRung[i].eDiss    = g_letra[i].waveProgress;
      g_curveRung[i].eRes     = MathMax(0.0, 100.0 - g_letra[i].waveProgress);
      g_curveRung[i].convex   = g_letra[i].convexityMaturity * 100.0;
      g_curveRung[i].compress = g_letra[i].compression;
      g_curveRung[i].maturity = g_letra[i].waveProgress;
   }
}

//==================================================================
// 3. NODE PHASE STATE (f_nodeState from F16)
//    Maps energy/lifecycle/depth/compression/maturity to phase label.
//    Principle 14: phases EMERGE from the node.
//==================================================================

void NodePhaseState(int dir, double energy, int depth, double comp, double mat, char &result[])
{
   string phase = "";

   // Recursion depth > 0: this is a CHILD curve (Transition family)
   if(depth > 0)
   {
      if(energy >= 70.0)
         phase = "Transition recursive expansion";
      else if(energy >= 40.0)
         phase = "Transition recursive induction";
      else
         phase = "Transition recursive liquidation";
   }
   // Root node phases based on maturity/energy
   else if(mat < 12.0)
   {
      phase = "Point 4 Origin";
   }
   else if(energy >= 78.0 && mat >= 70.0)
   {
      if(dir == 1)
         phase = "New High";
      else if(dir == -1)
         phase = "New Low";
      else
         phase = "Climax";
   }
   else if(mat < 35.0)
   {
      phase = "Expansion";
   }
   else if(mat < 55.0)
   {
      phase = "Expansion Pre-Convexity";
   }
   else if(energy >= 55.0)
   {
      phase = "Expansion Induction";
   }
   else if(energy >= 35.0)
   {
      phase = "Expansion Liquidity";
   }
   else if(comp >= 60.0)
   {
      phase = "Retracement Pre-Convexity";
   }
   else if(energy >= 18.0)
   {
      phase = "Retracement Induction";
   }
   else
   {
      phase = "Retracement";
   }

   // Copy phase string to char array (max 63 chars + null)
   int len = StringLen(phase);
   if(len > 63) len = 63;
   for(int i = 0; i < len; i++)
      result[i] = (char)StringGetCharacter(phase, i);
   result[len] = 0;
}

//==================================================================
// Helper: Convert char[] state to string
//==================================================================
string NodeStateToString(const char &state[])
{
   string result = "";
   for(int i = 0; i < 64; i++)
   {
      if(state[i] == 0) break;
      result += CharToString((uchar)state[i]);
   }
   return(result);
}

//==================================================================
// 4. RECURSIVE CURVE TREE ENGINE
//    Event-generated CurveNodes with energy dynamics.
//    Ownership follows Principle 8 (shallowest with energy >= 12).
//    CHoCH against owner spawns inverse child curve.
//    Compression sets recursion budget (1-4 depth).
//==================================================================

void UpdateTreeEngine()
{
   double atr = GetATR(0);

   //--- STEP 1: Find current owner (Principle 8)
   //    Shallowest alive node with energy >= 12
   int    preOwn   = -1;
   double preE     = -1.0;
   int    preDepth = 999;

   for(int i = 0; i < g_curveTreeCount; i++)
   {
      if(g_curveTree[i].alive && g_curveTree[i].energy >= 12.0)
      {
         if(g_curveTree[i].depth < preDepth ||
            (g_curveTree[i].depth == preDepth && g_curveTree[i].energy > preE))
         {
            preDepth = g_curveTree[i].depth;
            preE     = g_curveTree[i].energy;
            preOwn   = i;
         }
      }
   }

   // Fallback: if no node meets threshold, pick highest energy alive
   if(preOwn < 0)
   {
      for(int i = 0; i < g_curveTreeCount; i++)
      {
         if(g_curveTree[i].alive && g_curveTree[i].energy > preE)
         {
            preE   = g_curveTree[i].energy;
            preOwn = i;
         }
      }
   }

   //--- STEP 2: Seed root curve if no owner exists
   //    Origin from M5 invalidation, direction from M5 wave
   int ctxDir  = g_letra[2].dir;
   double ctxOrig = g_letra[2].inv;

   if(preOwn < 0 && ctxDir != 0 && ctxOrig != 0.0)
   {
      g_nodeSeq++;
      if(g_curveTreeCount < 60)
      {
         CurveNode newNode;
         newNode.id      = g_nodeSeq;
         newNode.parent  = -1;
         newNode.dir     = ctxDir;
         newNode.origin  = ctxOrig;
         newNode.extreme = (ctxDir == 1) ? g_spawn.cycleHigh : g_spawn.cycleLow;
         newNode.energy  = MathMax(40.0, g_energy.ede_expansionEnergy);
         newNode.alive   = true;
         newNode.depth   = 0;
         newNode.bar     = 0;
         newNode.comp    = g_curve.compress;
         newNode.mat     = g_curve.maturity;
         newNode.srcTf   = 0;  // Chart/M5

         NodePhaseState(newNode.dir, newNode.energy, newNode.depth,
                        newNode.comp, newNode.mat, newNode.state);

         g_curveTree[g_curveTreeCount] = newNode;
         g_curveTreeCount++;
         preOwn = g_curveTreeCount - 1;
      }
   }

   //--- STEP 3: Event-generated children
   //    CHoCH against owner spawns inverse child curve.
   //    Compression sets recursion budget: 1 + round(compress/33), clamped 1-4.
   int curveBudgetDepth = (int)MathMax(1, MathMin(4, 1 + MathRound(g_curve.compress / 33.0)));

   if(preOwn >= 0)
   {
      int ownerDir = g_curveTree[preOwn].dir;
      bool chochAgainst = false;

      // Detect CHoCH against owner from M5 structure
      if(ownerDir == 1 && g_letra[2].choch && g_letra[2].dir == -1)
         chochAgainst = true;
      if(ownerDir == -1 && g_letra[2].choch && g_letra[2].dir == 1)
         chochAgainst = true;

      if(chochAgainst && (g_curveTree[preOwn].depth + 1 <= curveBudgetDepth))
      {
         if(g_curveTreeCount < 60)
         {
            g_nodeSeq++;
            CurveNode child;
            child.id      = g_nodeSeq;
            child.parent  = g_curveTree[preOwn].id;
            child.dir     = -ownerDir;
            child.origin  = Close[0];
            child.extreme = Close[0];
            child.energy  = MathMax(25.0, g_energy.ede_expansionEnergy * 0.85);
            child.alive   = true;
            child.depth   = g_curveTree[preOwn].depth + 1;
            child.bar     = 0;
            child.comp    = g_curve.compress;
            child.mat     = g_curve.maturity;
            child.srcTf   = 0;  // Chart/M5

            NodePhaseState(child.dir, child.energy, child.depth,
                           child.comp, child.mat, child.state);

            g_curveTree[g_curveTreeCount] = child;
            g_curveTreeCount++;
         }
      }
   }

   //--- STEP 4: Update all living nodes - energy dynamics
   //    Progress (new extreme) raises energy +7; stall decays -2.
   //    Kill if energy <= 2.
   int treeAlive = 0;
   int treeDepth = 0;

   for(int i = 0; i < g_curveTreeCount; i++)
   {
      if(!g_curveTree[i].alive) continue;

      // Root (depth 0) mirrors its timeframe direction
      if(g_curveTree[i].depth == 0)
      {
         if(g_curveTree[i].srcTf == 6)       // H4
            g_curveTree[i].dir = g_letra[5].dir;
         else if(g_curveTree[i].srcTf == 5)  // H1
            g_curveTree[i].dir = g_letra[4].dir;
         else                                 // Chart/M5
            g_curveTree[i].dir = g_letra[2].dir;
      }

      // Check progress: is price making new extremes in node direction?
      bool progress = false;
      if(g_curveTree[i].dir == 1 && High[0] > g_curveTree[i].extreme)
         progress = true;
      if(g_curveTree[i].dir == -1 && Low[0] < g_curveTree[i].extreme)
         progress = true;

      // Update extreme for root vs children
      if(g_curveTree[i].depth == 0)
      {
         // Root mirrors structural origin/extreme
         if(g_curveTree[i].srcTf == 6)
         {
            g_curveTree[i].origin  = g_letra[5].inv;
            g_curveTree[i].extreme = (g_curveTree[i].dir == 1) ?
               g_letra[5].swingHigh : g_letra[5].swingLow;
         }
         else if(g_curveTree[i].srcTf == 5)
         {
            g_curveTree[i].origin  = g_letra[4].inv;
            g_curveTree[i].extreme = (g_curveTree[i].dir == 1) ?
               g_letra[4].swingHigh : g_letra[4].swingLow;
         }
         else
         {
            g_curveTree[i].origin  = g_letra[2].inv;
            g_curveTree[i].extreme = (g_curveTree[i].dir == 1) ?
               g_spawn.cycleHigh : g_spawn.cycleLow;
         }
      }
      else
      {
         // Children track their own counter-move extreme
         if(g_curveTree[i].dir == 1)
            g_curveTree[i].extreme = MathMax(g_curveTree[i].extreme, High[0]);
         else
            g_curveTree[i].extreme = MathMin(g_curveTree[i].extreme, Low[0]);
      }

      // Energy dynamics: progress +7, stall -2, clamped 0-100
      if(progress)
         g_curveTree[i].energy = MathMin(100.0, g_curveTree[i].energy + 7.0);
      else
         g_curveTree[i].energy = MathMax(0.0, g_curveTree[i].energy - 2.0);

      // Refresh maturity/compression from source timeframe
      if(g_curveTree[i].srcTf == 6)
      {
         g_curveTree[i].mat  = g_letra[5].waveProgress;
         g_curveTree[i].comp = g_letra[5].compression;
      }
      else if(g_curveTree[i].srcTf == 5)
      {
         g_curveTree[i].mat  = g_letra[4].waveProgress;
         g_curveTree[i].comp = g_letra[4].compression;
      }
      else
      {
         g_curveTree[i].mat  = g_curve.maturity;
         g_curveTree[i].comp = g_curve.compress;
      }

      // Recompute phase state
      NodePhaseState(g_curveTree[i].dir, g_curveTree[i].energy,
                     g_curveTree[i].depth, g_curveTree[i].comp,
                     g_curveTree[i].mat, g_curveTree[i].state);

      // Kill if energy depleted
      if(g_curveTree[i].energy <= 2.0)
         g_curveTree[i].alive = false;

      // Track tree stats
      if(g_curveTree[i].alive)
      {
         treeAlive++;
         if(g_curveTree[i].depth > treeDepth)
            treeDepth = g_curveTree[i].depth;
      }
   }

   //--- STEP 5: Cap tree at 60 nodes (remove oldest dead ones)
   while(g_curveTreeCount > 60)
   {
      // Shift array left removing index 0 (oldest)
      for(int i = 0; i < g_curveTreeCount - 1; i++)
         g_curveTree[i] = g_curveTree[i + 1];
      g_curveTreeCount--;
      // Adjust preOwn index if needed
      if(preOwn > 0) preOwn--;
      else if(preOwn == 0) preOwn = -1;
   }

   //--- STEP 6: Final owner selection (Principle 8 - after updates)
   int ownF      = -1;
   double ownFE  = -1.0;
   int ownDepth  = 999;

   for(int i = 0; i < g_curveTreeCount; i++)
   {
      if(g_curveTree[i].alive && g_curveTree[i].energy >= 12.0)
      {
         if(g_curveTree[i].depth < ownDepth ||
            (g_curveTree[i].depth == ownDepth && g_curveTree[i].energy > ownFE))
         {
            ownDepth = g_curveTree[i].depth;
            ownFE    = g_curveTree[i].energy;
            ownF     = i;
         }
      }
   }

   // Fallback
   if(ownF < 0)
   {
      for(int i = 0; i < g_curveTreeCount; i++)
      {
         if(g_curveTree[i].alive && g_curveTree[i].energy > ownFE)
         {
            ownFE = g_curveTree[i].energy;
            ownF  = i;
         }
      }
   }

   // Publish owner globals
   if(ownF >= 0)
   {
      g_curveOwnerDir    = g_curveTree[ownF].dir;
      g_curveOwnerEnergy = g_curveTree[ownF].energy;
      ArrayCopy(g_curveOwnerState, g_curveTree[ownF].state, 0, 0, 64);
   }
   else
   {
      g_curveOwnerDir    = 0;
      g_curveOwnerEnergy = 0.0;
      g_curveOwnerState[0] = 0;
   }
}

//==================================================================
// 5. CAMPAIGN OWNERSHIP
//    Determines campaign state (TERMINAL vs EXPANSION) based on
//    proximity to HTF zone and lifecycle phase. Owner direction
//    from curve object. Compression regime classification.
//==================================================================

void ComputeCampaignOwnership(CampaignState &camp)
{
   double atr = GetATR(0);
   if(atr <= 0.0) atr = 1.0;

   //--- Find next path node (attractor from network - use g_attractorIdx)
   double htfZone   = 0.0;
   double distHTF   = 0.0;
   bool   hasHTF    = false;

   // Use the attractor from Part5 network engine
   if(g_attractorIdx >= 0 && g_attractorIdx < g_nodeCount)
   {
      htfZone = g_nodes[g_attractorIdx].px;
      distHTF = MathAbs(htfZone - Close[0]);
      hasHTF  = true;
   }

   //--- Curve budget to HTF (0-100)
   double curveBudget = 0.0;
   if(hasHTF && atr > 0.0)
      curveBudget = MathMin(100.0, distHTF / (atr * 8.0) * 100.0);

   //--- Determine if AT HTF zone (dist < 1.5 ATR) or terminal phase
   bool atHTF = hasHTF && (distHTF < atr * 1.5);
   bool nearHTF = (curveBudget < 25.0) && hasHTF;

   // Terminal phase detection from owner state
   string ownerState = NodeStateToString(g_curveOwnerState);
   bool termPhase = (StringFind(ownerState, "Induction") >= 0 ||
                     StringFind(ownerState, "Liquidation") >= 0 ||
                     StringFind(ownerState, "Retracement") >= 0);

   //--- Campaign classification
   if(atHTF || termPhase)
      camp.campaign = "TERMINAL";
   else
      camp.campaign = "EXPANSION";

   //--- Location
   if(atHTF || termPhase)
      camp.location = "INSIDE HTF ZONE";
   else if(nearHTF)
      camp.location = "APPROACHING";
   else if(StringFind(ownerState, "Transition") >= 0 ||
           StringFind(ownerState, "Retracement") >= 0)
      camp.location = "TRANSITIONING";
   else
      camp.location = "BUILDING";

   //--- Owner direction from curve object
   camp.ownerDir = (g_curve.dir != 0) ? g_curve.dir : g_netBias;

   //--- Compression regime
   double gComp = g_curve.compress;
   if(gComp >= 75.0)
      camp.compRegime = "FAILURE SWING";
   else if(gComp >= 50.0)
      camp.compRegime = "COMPRESSED";
   else if(gComp >= 25.0)
      camp.compRegime = "MEDIUM";
   else
      camp.compRegime = "WIDE";

   //--- Curve budget and expected depth
   camp.curveBudget = curveBudget;
   camp.expDepth = (int)MathMax(1, MathMin(4, 1 + MathRound(gComp / 33.0)));
}

//==================================================================
// 6. PARTICIPANT INTERFERENCE ZONES
//    0.618/0.70/0.786 retracement from curve origin to extreme.
//    Zone classification based on where price sits in the retrace.
//==================================================================

void ComputeParticipantZones(ParticipantZone &pz)
{
   double extreme = g_curve.extreme;
   double origin  = g_curve.origin;
   double range   = extreme - origin;

   // Compute Fibonacci retracement levels
   if(MathAbs(range) > 0.0)
   {
      pz.f618 = extreme - 0.618 * range;
      pz.f70  = extreme - 0.70  * range;
      pz.f786 = extreme - 0.786 * range;
   }
   else
   {
      pz.f618 = 0.0;
      pz.f70  = 0.0;
      pz.f786 = 0.0;
   }

   // Flip level based on direction
   if(g_curve.dir == 1)
      pz.flipLvl = g_spawn.flipBot;
   else if(g_curve.dir == -1)
      pz.flipLvl = g_spawn.flipTop;
   else
      pz.flipLvl = 0.0;

   // Retrace depth as fraction of range
   double retrAbs = 0.0;
   if(MathAbs(range) > 0.0)
      retrAbs = MathAbs(extreme - Close[0]) / MathAbs(range);

   // Zone classification
   if(retrAbs < 0.55)
      pz.zone = "pre-0.618 clean";
   else if(retrAbs < 0.66)
      pz.zone = "0.618 participants";
   else if(retrAbs < 0.74)
      pz.zone = "0.70 interference";
   else if(retrAbs < 0.82)
      pz.zone = "0.786 heavy";
   else
      pz.zone = "FLIP true induction";

   // Interference state
   string ownerState = NodeStateToString(g_curveOwnerState);
   bool interfDom = (StringFind(ownerState, "Transition") >= 0 ||
                     StringFind(ownerState, "Retracement") >= 0);

   if(interfDom)
      pz.interference = "DOMINANT recursive owns";
   else if(retrAbs >= 0.55)
      pz.interference = "active displacement";
   else
      pz.interference = "absorbed parent continues";
}

//==================================================================
// 7. COMPRESSION PERSISTENCE (Principle 10 from F16)
//    Tight compression + concentrated energy + few recursions means
//    counter side suffocates. Broad + growing recursion means leaking.
//==================================================================

void ComputeCompressionPersistence(CompressionState &cp)
{
   double cmpNow = g_curve.compress;

   // Tightening = current compress minus previous (positive = tightening)
   double cmpTighten = cmpNow - s_prevCompress;

   // Track previous for next call
   s_prevCompress = cmpNow;

   // Compute tree depth from alive nodes
   int treeDepth = 0;
   for(int i = 0; i < g_curveTreeCount; i++)
   {
      if(g_curveTree[i].alive && g_curveTree[i].depth > treeDepth)
         treeDepth = g_curveTree[i].depth;
   }

   // Force formula from F16:
   // cpForce = compress*0.50 + residual*0.20 - treeDepth*12 + max(0,tighten)*0.8 + 8
   double force = cmpNow * 0.50
                + g_curve.eRes * 0.20
                - treeDepth * 12.0
                + MathMax(0.0, cmpTighten) * 0.8
                + 8.0;
   force = MathMax(0.0, MathMin(100.0, force));

   cp.force = force;

   // State classification
   if(force >= 60.0)
      cp.state = "PERSISTING";
   else if(force <= 35.0)
      cp.state = "LEAKING";
   else
      cp.state = "NEUTRAL";

   // Trend from tightening
   if(cmpTighten > 3.0)
      cp.trend = "tightening";
   else if(cmpTighten < -3.0)
      cp.trend = "broadening";
   else
      cp.trend = "stable";
}

//==================================================================
// 8. TRADE ALIVE JUDGEMENT
//    The single hold-vs-abandon call, every bar.
//    ALIVE while force persists, energy remains, recursion budget
//    unspent. DEAD once recursion completes and force leaks.
//==================================================================

void ComputeTradeAlive(CompressionState &cp, TradeAliveState &ta)
{
   double atr = GetATR(0);
   if(atr <= 0.0) atr = 1.0;

   //--- Get owner curve coordinates
   double ownOrig = g_curve.origin;
   double ownExt  = g_curve.extreme;
   int    ownDir  = g_curveOwnerDir;

   //--- Progressing: price attacking extreme OR trend impulse
   bool attacking = false;
   if(ownDir == 1 && High[0] >= ownExt)
      attacking = true;
   if(ownDir == -1 && Low[0] <= ownExt)
      attacking = true;

   // Check for trend impulse (from M5 physics stored in letra)
   bool trendImp = false;
   if(ownDir == 1 && g_letra[2].bos && g_letra[2].dir == 1)
      trendImp = true;
   if(ownDir == -1 && g_letra[2].bos && g_letra[2].dir == -1)
      trendImp = true;

   bool progressing = attacking || trendImp;
   ta.progressing = progressing;

   //--- Retrace depth from extreme (0-100)
   double retrX = 50.0;
   if(ownExt != ownOrig && ownOrig != 0.0)
      retrX = MathMin(100.0, MathAbs(ownExt - Close[0]) / MathAbs(ownExt - ownOrig) * 100.0);
   ta.retrFromExtreme = retrX;

   //--- Recursion complete check
   int curveBudgetDepth = (int)MathMax(1, MathMin(4, 1 + MathRound(g_curve.compress / 33.0)));
   int treeDepth = 0;
   for(int i = 0; i < g_curveTreeCount; i++)
   {
      if(g_curveTree[i].alive && g_curveTree[i].depth > treeDepth)
         treeDepth = g_curveTree[i].depth;
   }
   bool recursionComplete = (curveBudgetDepth > 0) && (treeDepth >= curveBudgetDepth);

   //--- Compression tightening
   double cmpTighten = g_curve.compress - s_prevCompress;
   // Note: s_prevCompress already updated in ComputeCompressionPersistence
   // This uses the same delta computed there

   //--- Life score formula from F16:
   // life = cpForce*0.45 + residual*0.30 + (tighten>0 ? 12 : 0)
   //       - (recursionComplete AND !progressing ? 25 : 0)
   //       - (leaking AND !progressing ? 20 : 0)
   //       + (progressing ? 28 : 0)
   //       + retrX adjustments + 10 base
   double life = cp.force * 0.45
               + g_curve.eRes * 0.30
               + (cmpTighten > 0.0 ? 12.0 : 0.0)
               - (recursionComplete && !progressing ? 25.0 : 0.0)
               - (cp.state == "LEAKING" && !progressing ? 20.0 : 0.0)
               + (progressing ? 28.0 : 0.0)
               + (retrX < 25.0 ? 16.0 : retrX < 45.0 ? 6.0 : retrX > 75.0 ? -12.0 : 0.0)
               + 10.0;

   life = MathMax(0.0, MathMin(100.0, life));
   ta.life = life;

   //--- Verdict
   if(progressing && life >= 45.0)
      ta.verdict = "ALIVE ATTACKING";
   else if(life >= 60.0)
      ta.verdict = "ALIVE HOLD";
   else if(life <= 32.0)
      ta.verdict = "DEAD FLIP";
   else
      ta.verdict = "WEAKENING MANAGE";
}

//==================================================================
// 9. NARRATIVE LINEAGE
//    Track sequence of pullback depths per leg. Each completed
//    pullback votes SUPPORT (shallow + tightening) or DEGRADE
//    (deep + broadening). Narrative score 0-100.
//==================================================================

void ComputeNarrativeLineage(NarrativeState &narr)
{
   int ownDir = g_curveOwnerDir;
   double ownOrig = g_curve.origin;

   //--- Direction flip resets lineage
   if(ownDir != s_narrDir)
   {
      s_narrDir        = ownDir;
      s_legExtreme     = (ownDir == 1) ? High[0] : (ownDir == -1) ? Low[0] : Close[0];
      s_legPBdepth     = 0.0;
      s_narrativeScore = 50.0;
      s_supVotes       = 0;
      s_degVotes       = 0;
      s_lifeSeqCount   = 0;
      s_retrSeqCount   = 0;
   }

   //--- Track pullback depths within current direction
   if(ownDir != 0 && ownOrig != 0.0)
   {
      // Check for new leg extreme
      bool newLegX = false;
      if(ownDir == 1 && High[0] > s_legExtreme)
         newLegX = true;
      if(ownDir == -1 && Low[0] < s_legExtreme)
         newLegX = true;

      if(newLegX)
      {
         // Vote on the pullback that just completed
         if(s_legPBdepth > 6.0)
         {
            double cmpTighten = g_curve.compress - s_prevCompress;
            bool isSup  = (s_legPBdepth <= 50.0) && (cmpTighten >= -1.0);
            bool isDeg  = (s_legPBdepth >= 62.0) || (cmpTighten < -3.0);
            int  vote   = isSup ? 1 : isDeg ? -1 : 0;

            if(vote == 1)  s_supVotes++;
            if(vote == -1) s_degVotes++;

            // Update narrative score
            s_narrativeScore += vote * 12.0 + (cmpTighten > 0.0 ? 3.0 : -3.0);
            s_narrativeScore = MathMax(0.0, MathMin(100.0, s_narrativeScore));

            // Track retrace sequence (rolling window of 5)
            if(s_retrSeqCount < 5)
            {
               s_retrSeq[s_retrSeqCount] = s_legPBdepth;
               s_retrSeqCount++;
            }
            else
            {
               for(int i = 0; i < 4; i++)
                  s_retrSeq[i] = s_retrSeq[i + 1];
               s_retrSeq[4] = s_legPBdepth;
            }

            // Track life sequence
            if(s_lifeSeqCount < 5)
            {
               s_lifeSeq[s_lifeSeqCount] = g_tradeAlive.life;
               s_lifeSeqCount++;
            }
            else
            {
               for(int i = 0; i < 4; i++)
                  s_lifeSeq[i] = s_lifeSeq[i + 1];
               s_lifeSeq[4] = g_tradeAlive.life;
            }
         }

         // Reset for new leg
         s_legExtreme = (ownDir == 1) ? High[0] : Low[0];
         s_legPBdepth = 0.0;
      }
      else
      {
         // Track maximum pullback depth
         double legRange = MathAbs(s_legExtreme - ownOrig);
         if(legRange > 0.0)
         {
            double pbd = MathAbs(s_legExtreme - Close[0]) / legRange * 100.0;
            if(pbd > s_legPBdepth)
               s_legPBdepth = pbd;
         }
      }
   }

   //--- Publish narrative state
   narr.score    = s_narrativeScore;
   narr.supVotes = s_supVotes;
   narr.degVotes = s_degVotes;

   if(s_narrativeScore >= 65.0)
      narr.state = "STRENGTHENING";
   else if(s_narrativeScore <= 35.0)
      narr.state = "WEAKENING";
   else
      narr.state = "HOLDING";

   //--- Chain vitality: is LIFE decaying across successive curves?
   s_wholeChainLife += 0.02 * (g_tradeAlive.life - s_wholeChainLife);

   double chainVitality = s_wholeChainLife;
   if(s_lifeSeqCount >= 2)
   {
      chainVitality = MathMax(0.0, MathMin(100.0,
         50.0 + (s_lifeSeq[s_lifeSeqCount - 1] - s_lifeSeq[0])));
   }
   narr.chainVitality = chainVitality;

   // Chain scope classification
   if(g_tradeAlive.life >= 50.0)
      narr.chainScope = "healthy";
   else if(chainVitality >= 50.0)
      narr.chainScope = "CURVE only chain intact";
   else if(s_wholeChainLife >= 45.0)
      narr.chainScope = "CHAIN weakening";
   else
      narr.chainScope = "WHOLE CHAIN decaying";
}

//==================================================================
// 10. MASTER UPDATE - CURVE TREE
//     Called once per bar from the main OnTick flow.
//     Orchestrates all sub-engines in correct dependency order.
//==================================================================

void UpdateCurveTree()
{
   //--- 1. Assemble the canonical Curve Object from physics primitives
   UpdateCurveObject();

   //--- 2. Update per-rung curve family
   UpdateCurveRungs();

   //--- 3. Update recursive tree (seed/spawn/update living nodes)
   UpdateTreeEngine();

   //--- 4. Campaign ownership
   ComputeCampaignOwnership(g_campaign);

   //--- 5. Participant interference zones
   ComputeParticipantZones(g_participant);

   //--- 6. Compression persistence
   ComputeCompressionPersistence(g_compression);

   //--- 7. Trade alive judgement (depends on compression)
   ComputeTradeAlive(g_compression, g_tradeAlive);

   //--- 8. Narrative lineage (depends on trade alive life score)
   ComputeNarrativeLineage(g_narrative);
}
