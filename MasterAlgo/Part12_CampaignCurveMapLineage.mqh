//+------------------------------------------------------------------+
//| Part12_CampaignCurveMapLineage.mqh                                |
//| MASTER ALGO - Campaign Ownership + Participant Engine +           |
//| MTF Curve Map + Narrative Lineage + Curve Budget Target           |
//| From F16: Campaign, Participants (Fib interference), MTF Map,     |
//| retrace-depth lineage voting, ODDE-driven budget target           |
//+------------------------------------------------------------------+
#property strict

//==================================================================
// CAMPAIGN OWNERSHIP ENGINE (from F16)
// Determines whether we are in EXPANSION or TERMINAL campaign,
// who owns price, location relative to HTF structure, compression
// regime, and the participant interference zones
//
// PARTICIPANT ENGINE: 0.618/0.70/0.786 retracement + flip level
// Shows where early traders get trapped (interference zones)
//
// MTF CURVE MAP: 7 fixed rungs (M1-H4) with direction/origin/
// extreme/progress/retrace per rung, alignment count
//
// NARRATIVE LINEAGE: retrace-depth sequence voting (SUPPORT/DEGRADE),
// convergence/divergence detection, chain vitality scoring
//
// CURVE BUDGET TARGET: ODDE-driven destination (origin if leaking,
// parent HTF zone if persisting)
//==================================================================


//--- Campaign state
struct CampaignState
{
   string campaign;       // "EXPANSION" or "TERMINAL"
   string location;       // "BUILDING" / "TRANSITIONING" / "APPROACHING" / "INSIDE HTF ZONE"
   int    ownerDir;       // who owns price (1=bull, -1=bear)
   string compRegime;     // "WIDE" / "MEDIUM" / "COMPRESSED" / "FAILURE SWING"
   int    expDepth;       // expected recursion depth based on compression
   double curveBudget;    // % of curve budget remaining to HTF target (0-100)
};

CampaignState g_campaign;

//--- Participant Engine (Fib interference zones)
struct ParticipantZones
{
   double fib618;         // 0.618 retracement of owner curve
   double fib70;          // 0.70 retracement
   double fib786;         // 0.786 retracement
   double flipLevel;      // true induction (flip zone)
   double retrAbs;        // current retrace fraction (0-1)
   string zone;           // "pre-0.618" / "0.618" / "0.70" / "0.786" / "FLIP"
   string interference;   // "absorbed" / "active" / "DOMINANT"
   bool   displacing;     // impulse inside participant band
};

ParticipantZones g_participants;

//--- MTF Curve Map (7 fixed rungs)
struct CurveMapRung
{
   int    direction;      // origin-based wave direction
   double origin;         // wave birth price
   double extreme;        // peak/trough price
   double progress;       // wave progress 0-100
   double retrace;        // retrace % from extreme
   string phase;          // simple phase family
   string relation;       // "align" / "counter" / "-"
};

CurveMapRung g_curveMap[7]; // M1, M3, M5, M15, M30(unused), H1, H4
int    g_mapAlignCount = 0;
string g_mapStory = "";
string g_mapOwnerTF = "";

//--- Narrative Lineage
struct NarrativeLineage
{
   int    ownerDir;         // current lineage direction
   double legExtreme;       // current leg's extreme
   double legPBDepth;       // deepest pullback in current leg (%)
   double narrative;        // 0-100 narrative strength
   string state;            // "STRENGTHENING" / "HOLDING" / "WEAKENING"
   string lastVote;         // "SUPPORT" / "DEGRADE" / "NEUTRAL"
   int    supportVotes;
   int    degradeVotes;
   bool   converging;       // retraces getting shallower
   double chainVitality;    // 0-100 (life across successive curves)
   double wholeChainLife;   // persistent across resets
};

NarrativeLineage g_lineage;

// Retrace sequence (last 5 pullback depths)
#define LINEAGE_SEQ_MAX 5
double g_retraceSeq[LINEAGE_SEQ_MAX];
int    g_retraceSeqCount = 0;
double g_lifeSeq[LINEAGE_SEQ_MAX];
int    g_lifeSeqCount = 0;

//--- Curve Budget Target
double g_curveBudgetTarget = 0;
string g_curveBudgetSource = "-";
double g_curveBudgetATR = 0;     // distance in ATR


//==================================================================
// 1. CAMPAIGN OWNERSHIP ENGINE
//==================================================================
void UpdateCampaignOwnership()
{
   double atr = g_physics.atr;
   if(atr <= 0) return;
   
   // Who owns price = curve direction (from Part 6 g_curve)
   g_campaign.ownerDir = (g_curve.direction != 0) ? g_curve.direction : g_senseei.masterBias;
   
   // Compression regime (from curve compression)
   double comp = g_curve.compression;
   if(comp >= 75)      g_campaign.compRegime = "FAILURE SWING";
   else if(comp >= 50) g_campaign.compRegime = "COMPRESSED";
   else if(comp >= 25) g_campaign.compRegime = "MEDIUM";
   else                g_campaign.compRegime = "WIDE";
   
   // Expected recursion depth from compression
   g_campaign.expDepth = MathMax(1, MathMin(4, 1 + (int)MathRound(comp / 33.0)));
   
   // Nearest forward node from network = HTF target zone
   double htfZone = (g_attrIdx >= 0) ? g_nodes[g_attrIdx].price : 0;
   double distHTF = (htfZone > 0 && ArraySize(Close) > 0) ? 
                    MathAbs(htfZone - Close[0]) : 0;
   
   // Curve budget = how much room remains to HTF zone
   g_campaign.curveBudget = (distHTF > 0) ? 
      MathMin(100.0, distHTF / MathMax(atr * 8.0, 1e-10) * 100.0) : 0;
   
   // Is the wave in terminal phases?
   bool atHTF = (distHTF > 0 && distHTF < atr * 1.5);
   bool termPhase = (g_currentPhase == PHASE_EXP_INDUCTION || 
                     g_currentPhase == PHASE_EXP_LIQUIDITY ||
                     g_currentPhase == PHASE_RETR_INDUCTION ||
                     g_currentPhase == PHASE_RETR_LIQUIDITY ||
                     g_currentPhase == PHASE_DEMAND_RETURN ||
                     g_currentPhase == PHASE_SUPPLY_RETURN);
   
   // Campaign type
   g_campaign.campaign = (atHTF || termPhase) ? "TERMINAL" : "EXPANSION";
   
   // Location
   if(atHTF || termPhase)
      g_campaign.location = "INSIDE HTF ZONE";
   else if(g_campaign.curveBudget < 25)
      g_campaign.location = "APPROACHING HTF ZONE";
   else if(g_currentPhase == PHASE_RETRACEMENT || g_currentPhase == PHASE_RETR_PRECONVEXITY)
      g_campaign.location = "TRANSITIONING";
   else
      g_campaign.location = "BUILDING";
}

//==================================================================
// 2. PARTICIPANT ENGINE (Fib interference zones)
// 0.618/0.70/0.786 = manipulation/displacement; FLIP = true induction
//==================================================================
void UpdateParticipantEngine()
{
   double atr = g_physics.atr;
   if(atr <= 0) return;
   if(g_curve.extreme == 0 || g_curve.origin == 0) return;
   
   double pcHi = g_curve.extreme;
   double pcLo = g_curve.origin;
   // Ensure Hi > Lo for retracement calculation
   if(pcHi < pcLo) { double tmp = pcHi; pcHi = pcLo; pcLo = tmp; }
   double pcRng = pcHi - pcLo;
   if(pcRng < 1e-10) return;
   
   double closeNow = (ArraySize(Close) > 1) ? Close[1] : 0;
   if(closeNow == 0) return;
   
   // Fib levels (measured from extreme toward origin)
   g_participants.fib618 = pcHi - 0.618 * pcRng;
   g_participants.fib70 = pcHi - 0.70 * pcRng;
   g_participants.fib786 = pcHi - 0.786 * pcRng;
   g_participants.flipLevel = (g_curve.direction == 1) ? g_flipBot : g_flipTop;
   
   // Current retrace fraction
   g_participants.retrAbs = MathAbs(pcHi - closeNow) / pcRng;
   
   // Zone classification
   if(g_participants.retrAbs < 0.55)
      g_participants.zone = "pre-0.618 clean";
   else if(g_participants.retrAbs < 0.66)
      g_participants.zone = "0.618 participants in";
   else if(g_participants.retrAbs < 0.74)
      g_participants.zone = "0.70 interference";
   else if(g_participants.retrAbs < 0.82)
      g_participants.zone = "0.786 heavy";
   else
      g_participants.zone = "FLIP true induction";
   
   // Displacement check (impulse inside participant band)
   bool inBand = (g_participants.retrAbs >= 0.55);
   g_participants.displacing = (inBand && (g_physics.bullImpulse || g_physics.bearImpulse));
   
   // Interference level
   bool interfDom = (g_currentPhase == PHASE_RETRACEMENT || 
                     g_currentPhase == PHASE_RETR_PRECONVEXITY ||
                     g_currentPhase == PHASE_RETR_INDUCTION ||
                     g_currentPhase == PHASE_DEMAND_RETURN ||
                     g_currentPhase == PHASE_SUPPLY_RETURN);
   
   if(interfDom)
      g_participants.interference = "DOMINANT recursive owns";
   else if(g_participants.displacing)
      g_participants.interference = "active displacement";
   else
      g_participants.interference = "absorbed parent continues";
}


//==================================================================
// 3. MTF CURVE MAP (7 fixed rungs: M1/M3/M5/M15/M30/H1/H4)
// Each rung shows direction/origin/extreme/progress/retrace
//==================================================================
void UpdateMTFCurveMap()
{
   double closeNow = (ArraySize(Close) > 1) ? Close[1] : 0;
   if(closeNow == 0) return;
   
   // Map index: 0=M1, 1=M3, 2=M5, 3=M15, 4=M30(approximated), 5=H1, 6=H4
   // Use existing structure engine outputs for M1/M3/M5/M15/H1/H4
   // M30 is approximated from M15 (no dedicated engine)
   
   int mapLayers[] = {TF_M1, TF_M3, TF_M5, TF_M15, TF_M15, TF_H1, TF_H4};
   string mapNames[] = {"M1", "M3", "M5", "M15", "M30", "H1", "H4"};
   
   int ownerDir = g_curve.direction;
   g_mapAlignCount = 0;
   
   for(int i = 0; i < 7; i++)
   {
      int layerIdx = mapLayers[i];
      CurveMapRung *r = GetPointer(g_curveMap[i]);
      
      r.direction = g_structure[layerIdx].direction;
      r.origin = g_structure[layerIdx].invalidation;
      r.extreme = (r.direction == 1) ? g_structure[layerIdx].swingHigh : g_structure[layerIdx].swingLow;
      r.progress = g_structure[layerIdx].waveProgress;
      
      // Retrace from extreme
      double span = (r.origin > 0 && r.extreme > 0) ? MathAbs(r.extreme - r.origin) : 0;
      r.retrace = (span > 1e-10) ? MathAbs(r.extreme - closeNow) / span * 100.0 : 0;
      
      // Simple phase family
      if(r.retrace < 12) r.phase = (r.direction == 1) ? "New High" : "New Low";
      else if(r.retrace < 35) r.phase = "Expansion";
      else if(r.retrace < 55) r.phase = "Pre-Conv";
      else if(r.retrace < 78) r.phase = "Retracement";
      else r.phase = "Deep/Flip";
      
      // Relation to owner
      if(ownerDir == 0 || r.direction == 0)
         r.relation = "-";
      else if(r.direction == ownerDir)
         r.relation = "align";
      else
         r.relation = "counter";
      
      // Count aligned
      if(r.direction == ownerDir && ownerDir != 0)
         g_mapAlignCount++;
   }
   
   // Cross-TF story
   if(ownerDir == 0)
      g_mapStory = "no dominant owner";
   else if(g_mapAlignCount >= 7)
      g_mapStory = "all TFs aligned - strong continuation";
   else if(g_mapAlignCount >= 5)
      g_mapStory = "HTFs lead - LTFs following";
   else if(g_mapAlignCount <= 3)
      g_mapStory = "LTFs counter HTF - pullback/transition";
   else
      g_mapStory = "mixed - rotation";
   
   // Owner TF (which TF is driving the move = mid-progress)
   if(g_curveMap[6].progress > 10 && g_curveMap[6].progress < 90) g_mapOwnerTF = "H4";
   else if(g_curveMap[5].progress > 10 && g_curveMap[5].progress < 90) g_mapOwnerTF = "H1";
   else if(g_curveMap[3].progress > 10 && g_curveMap[3].progress < 90) g_mapOwnerTF = "M15";
   else if(g_curveMap[2].progress > 10 && g_curveMap[2].progress < 90) g_mapOwnerTF = "M5";
   else if(g_curveMap[1].progress > 10 && g_curveMap[1].progress < 90) g_mapOwnerTF = "M3";
   else g_mapOwnerTF = "M1";
}


//==================================================================
// 4. NARRATIVE LINEAGE ENGINE
// Per-entry retrace-depth sequence voting: SUPPORT/DEGRADE
// Converging sequence = story strengthening
// Diverging sequence = story fading → ownership transferring
//==================================================================
void UpdateNarrativeLineage()
{
   double atr = g_physics.atr;
   if(atr <= 0) return;
   if(ArraySize(Close) < 2) return;
   double closeNow = Close[1];
   
   int ownerDir = g_curve.direction;
   double ownerOrig = g_curve.origin;
   
   // Reset lineage on direction change
   if(ownerDir != g_lineage.ownerDir)
   {
      g_lineage.ownerDir = ownerDir;
      g_lineage.legExtreme = (ownerDir == 1) ? High[1] : (ownerDir == -1) ? Low[1] : 0;
      g_lineage.legPBDepth = 0;
      g_lineage.narrative = 50.0;
      g_lineage.supportVotes = 0;
      g_lineage.degradeVotes = 0;
      g_lineage.lastVote = "-";
      g_lineage.converging = false;
      g_retraceSeqCount = 0;
      g_lifeSeqCount = 0;
   }
   
   if(ownerDir == 0 || ownerOrig == 0) return;
   
   // Track new leg extreme
   bool newLegX = false;
   if(ownerDir == 1 && High[1] > g_lineage.legExtreme)
      newLegX = true;
   if(ownerDir == -1 && Low[1] < g_lineage.legExtreme)
      newLegX = true;
   
   if(newLegX)
   {
      // If we had a meaningful pullback before this new extreme, VOTE
      if(g_lineage.legPBDepth > 6.0)
      {
         // Compute compression trend
         double cmpNow = g_curve.compression;
         double cmpTighten = cmpNow - (g_retraceSeqCount > 0 ? cmpNow : cmpNow); // simplified
         
         bool sup = (g_lineage.legPBDepth <= 50.0);  // shallow retrace = SUPPORT
         bool deg = (g_lineage.legPBDepth >= 62.0);  // deep retrace = DEGRADE
         int vote = sup ? 1 : deg ? -1 : 0;
         
         g_lineage.lastVote = (vote == 1) ? "SUPPORT" : (vote == -1) ? "DEGRADE" : "NEUTRAL";
         g_lineage.supportVotes += (vote == 1 ? 1 : 0);
         g_lineage.degradeVotes += (vote == -1 ? 1 : 0);
         g_lineage.narrative = Clamp(g_lineage.narrative + vote * 12.0, 0, 100);
         
         // Store in retrace sequence
         if(g_retraceSeqCount < LINEAGE_SEQ_MAX)
         {
            g_retraceSeq[g_retraceSeqCount] = g_lineage.legPBDepth;
            g_retraceSeqCount++;
         }
         else
         {
            // Shift left
            for(int j = 0; j < LINEAGE_SEQ_MAX - 1; j++)
               g_retraceSeq[j] = g_retraceSeq[j+1];
            g_retraceSeq[LINEAGE_SEQ_MAX-1] = g_lineage.legPBDepth;
         }
         
         // Store life in life sequence
         if(g_lifeSeqCount < LINEAGE_SEQ_MAX)
         {
            g_lifeSeq[g_lifeSeqCount] = g_curveLife;
            g_lifeSeqCount++;
         }
         else
         {
            for(int j = 0; j < LINEAGE_SEQ_MAX - 1; j++)
               g_lifeSeq[j] = g_lifeSeq[j+1];
            g_lifeSeq[LINEAGE_SEQ_MAX-1] = g_curveLife;
         }
      }
      
      // Reset for new leg
      g_lineage.legExtreme = (ownerDir == 1) ? High[1] : Low[1];
      g_lineage.legPBDepth = 0;
   }
   else
   {
      // Track deepest pullback in this leg
      double legSpan = MathAbs(g_lineage.legExtreme - ownerOrig);
      if(legSpan > 1e-10)
      {
         double pbd = MathAbs(g_lineage.legExtreme - closeNow) / legSpan * 100.0;
         g_lineage.legPBDepth = MathMax(g_lineage.legPBDepth, pbd);
      }
   }
   
   // Narrative state
   g_lineage.state = (g_lineage.narrative >= 65) ? "STRENGTHENING" :
                     (g_lineage.narrative <= 35) ? "WEAKENING" : "HOLDING";
   
   // Convergence detection (retraces getting shallower)
   g_lineage.converging = false;
   if(g_retraceSeqCount >= 2)
      g_lineage.converging = (g_retraceSeq[g_retraceSeqCount-1] < g_retraceSeq[g_retraceSeqCount-2]);
   
   // Chain vitality (is life decaying across successive curves?)
   if(g_lifeSeqCount >= 2)
      g_lineage.chainVitality = Clamp(50.0 + (g_lifeSeq[g_lifeSeqCount-1] - g_lifeSeq[0]), 0, 100);
   else
      g_lineage.chainVitality = g_curveLife;
   
   // Whole chain life (persistent EMA across resets)
   g_lineage.wholeChainLife = g_lineage.wholeChainLife + 0.02 * (g_curveLife - g_lineage.wholeChainLife);
}


//==================================================================
// 5. CURVE BUDGET TARGET (ODDE-driven destination)
// Where price is most likely aimed based on curve force state:
//   LEAKING force → origin (returns to where curve was born)
//   PERSISTING force → HTF parent zone (bigger level to reach)
//   Fallback → wave objective
//==================================================================
void UpdateCurveBudgetTarget()
{
   double atr = g_physics.atr;
   if(atr <= 0) return;
   double closeNow = (ArraySize(Close) > 1) ? Close[1] : 0;
   if(closeNow == 0) return;
   
   double ownerOrig = g_curve.origin;
   double m5Target = g_structure[TF_M5].target;
   
   // HTF parent threat = H4 structure's flip or swing
   double parentThreat = 0;
   int ownerDir = g_curve.direction;
   if(ownerDir == 1)
   {
      parentThreat = (g_structure[TF_H4].flipTop > 0 && g_structure[TF_H4].flipTop > closeNow) ?
                      g_structure[TF_H4].flipTop : g_structure[TF_H4].swingHigh;
   }
   else if(ownerDir == -1)
   {
      parentThreat = (g_structure[TF_H4].flipBot > 0 && g_structure[TF_H4].flipBot < closeNow) ?
                      g_structure[TF_H4].flipBot : g_structure[TF_H4].swingLow;
   }
   
   // Select target based on curve force state
   if(g_curveForceState == "LEAKING" && ownerOrig > 0)
   {
      g_curveBudgetTarget = ownerOrig;
      g_curveBudgetSource = "ORIGIN (force leaking)";
   }
   else if(parentThreat > 0)
   {
      g_curveBudgetTarget = parentThreat;
      g_curveBudgetSource = "H4 PARENT";
   }
   else if(m5Target > 0)
   {
      g_curveBudgetTarget = m5Target;
      g_curveBudgetSource = "WAVE OBJ";
   }
   else
   {
      g_curveBudgetTarget = 0;
      g_curveBudgetSource = "-";
   }
   
   // Distance in ATR
   g_curveBudgetATR = (g_curveBudgetTarget > 0) ?
      MathAbs(closeNow - g_curveBudgetTarget) / MathMax(atr, 1e-10) : 0;
}

//==================================================================
// 6. OWNERSHIP MERGE DETECTION (Principle 9)
// Does the child curve respect the parent FU and merge back,
// or did it break the parent (genuine handoff)?
//==================================================================
struct OwnershipMerge
{
   bool   counterChild;   // LTF going against HTF
   bool   atParentFU;     // price at the parent's flip zone
   bool   reactingParent; // impulse in parent direction
   bool   brokeParent;    // broke through parent flip
   bool   merged;         // child collapsed back into parent (B→A)
   bool   transferred;    // genuine ownership transfer (new campaign)
   string state;          // text description
};

OwnershipMerge g_ownerMerge;

void UpdateOwnershipMerge()
{
   int childDir = g_structure[TF_M5].direction;
   int parentDir = 0;
   int l2Dir = g_structure[TF_H1].direction;
   int l4Dir = g_structure[TF_H4].direction;
   int sumHTF = l2Dir + l4Dir;
   if(sumHTF != 0) parentDir = (sumHTF > 0) ? 1 : -1;
   else parentDir = g_structure[TF_M15].direction;
   
   g_ownerMerge.counterChild = (childDir != 0 && parentDir != 0 && childDir != parentDir);
   
   // At parent FU = price inside H1's flip zone
   double pFlipTop = g_structure[TF_H1].flipTop;
   double pFlipBot = g_structure[TF_H1].flipBot;
   double closeNow = (ArraySize(Close) > 1) ? Close[1] : 0;
   
   g_ownerMerge.atParentFU = (pFlipTop > 0 && pFlipBot > 0 && 
                               closeNow >= pFlipBot && closeNow <= pFlipTop);
   
   // Reacting in parent direction
   g_ownerMerge.reactingParent = (parentDir == 1 && (g_physics.bullImpulse || Close[1] > Open[1])) ||
                                  (parentDir == -1 && (g_physics.bearImpulse || Close[1] < Open[1]));
   
   // Broke parent flip
   g_ownerMerge.brokeParent = (pFlipBot > 0 && pFlipTop > 0 &&
      ((parentDir == 1 && closeNow < pFlipBot) || (parentDir == -1 && closeNow > pFlipTop)));
   
   // Merge = counter child at parent FU reacting without breaking
   g_ownerMerge.merged = (g_ownerMerge.counterChild && g_ownerMerge.atParentFU && 
                           g_ownerMerge.reactingParent && !g_ownerMerge.brokeParent);
   
   // Transfer = counter child broke through parent
   g_ownerMerge.transferred = (g_ownerMerge.counterChild && g_ownerMerge.brokeParent);
   
   // State text
   if(g_ownerMerge.transferred)
      g_ownerMerge.state = "TRANSFERRED - new campaign";
   else if(g_ownerMerge.merged)
      g_ownerMerge.state = "MERGED (B->A) parent holds";
   else if(g_ownerMerge.counterChild)
      g_ownerMerge.state = "child recursion active";
   else
      g_ownerMerge.state = "aligned with parent";
}


//==================================================================
// EXECUTION INTEGRATION HELPERS
//==================================================================

// Is the narrative still supporting the current trade direction?
bool NarrativeSupportsDirection(int tradeDir)
{
   if(g_lineage.ownerDir == 0) return(false);
   if(g_lineage.ownerDir != tradeDir) return(false);
   return(g_lineage.state != "WEAKENING");
}

// Should we consider flipping? (narrative degrading + chain dying)
bool NarrativeSuggestsFlip()
{
   return(g_lineage.state == "WEAKENING" && g_lineage.chainVitality < 40);
}

// Get the participant zone price level (where interference is expected)
double GetParticipantLevel()
{
   if(g_participants.retrAbs < 0.55) return(g_participants.fib618);
   if(g_participants.retrAbs < 0.66) return(g_participants.fib618);
   if(g_participants.retrAbs < 0.74) return(g_participants.fib70);
   if(g_participants.retrAbs < 0.82) return(g_participants.fib786);
   return(g_participants.flipLevel);
}

// Is price at a participant interference zone?
bool IsAtParticipantZone()
{
   return(g_participants.retrAbs >= 0.55);
}

// Get the campaign's recommended TP (curve budget target)
double GetCampaignTP()
{
   return(g_curveBudgetTarget);
}

//==================================================================
// MASTER CAMPAIGN/MAP/LINEAGE UPDATE
//==================================================================
void UpdateCampaignMapLineage()
{
   // 1. Campaign Ownership
   UpdateCampaignOwnership();
   
   // 2. Participant Engine (Fib interference)
   UpdateParticipantEngine();
   
   // 3. MTF Curve Map
   UpdateMTFCurveMap();
   
   // 4. Narrative Lineage (retrace-depth voting)
   UpdateNarrativeLineage();
   
   // 5. Curve Budget Target (ODDE-driven)
   UpdateCurveBudgetTarget();
   
   // 6. Ownership Merge Detection
   UpdateOwnershipMerge();
}

//+------------------------------------------------------------------+
