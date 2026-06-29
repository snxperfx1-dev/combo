//+------------------------------------------------------------------+
//| MasterAlgo_Part3_Intelligence.mq5                                |
//| Part 3: Intelligence Engines                                      |
//| Contains: Physics Observation Layer, Energy Resolution Framework  |
//|           (EDE/RE/EAE), Wave Intelligence (similarity scoring,   |
//|           convexity maturity, wave progress), Belief Engine,      |
//|           Hypothesis Engine, Prediction Engine, Liquidation Wave  |
//|           Overlay (Engine 1A.7), Senseei Meta-Intelligence        |
//| This file is #included after Parts 1 and 2                       |
//+------------------------------------------------------------------+
#property strict

//==================================================================
// INPUT PARAMETERS - INTELLIGENCE ENGINES
//==================================================================
input int    InpBelief_Smooth    = 3;      // Belief EMA smoothing period
input double InpBelief_Alpha     = 0.0;    // Belief EMA alpha (0=auto from period)
input int    InpMinConf_Attack   = 55;     // Min confidence to ATTACK

//==================================================================
// GLOBAL STATE - PHYSICS OBSERVATION
//==================================================================
double g_velocityScore      = 0.0;
double g_accelerationScore  = 0.0;
double g_convexityScore     = 0.0;
double g_obs_ExpansionScore = 0.0;
double g_obs_DecayScore     = 0.0;
double g_obs_CurvatureScore = 0.0;
double g_obs_AbsorptionScore= 0.0;
double g_obs_LiquidityScore = 0.0;
double g_physicsMax         = 0.0;
double g_physicsDiff        = 0.0;
double g_physicsConsensus   = 0.0;

//==================================================================
// GLOBAL STATE - ENERGY RESOLUTION FRAMEWORK
//==================================================================
// EDE
int    g_ede_state                = 1;
string g_ede_cleaningState        = "Accumulating";
double g_ede_expansionEnergy      = 0.0;
double g_ede_dissipatedEnergy     = 0.0;
double g_ede_dissipationProgress  = 0.0;
bool   g_ede_messyPriceIsDissipation = false;

// RE
int    g_re_expectedCycles        = 1;
int    g_re_completedCycles       = 0;
double g_re_recursiveCompletionScore = 0.0;
double g_re_residualEnergy        = 0.0;
bool   g_re_objectiveReached      = false;
bool   g_re_fullDissipation       = false;
int    g_re_resolutionState       = 0;  // 0=UNRESOLVED, 1=PARTIALLY, 2=RESOLVED
double g_re_residualEnergyScore   = 0.0;
double g_re_revisitProbability    = 0.0;

// EAE
double g_eae_primaryAttractorPrice  = 0.0;
double g_eae_primaryAttractorScore  = 0.0;
string g_eae_primaryAttractorLabel  = "No Active Attractor";
string g_eae_energyState            = "Accumulating";

// ERF Confidence
double g_erf_confidence             = 0.0;
bool   g_erf_activeDissipation      = false;
bool   g_erf_suppressRotation       = false;

//==================================================================
// GLOBAL STATE - WAVE INTELLIGENCE
//==================================================================
// Similarity scores
double g_sim_Expansion    = 0.0;
double g_sim_PreConv      = 0.0;
double g_sim_Induction    = 0.0;
double g_sim_Liquidity    = 0.0;
double g_sim_Creation     = 0.0;
double g_sim_Absorption   = 0.0;
double g_sim_Retracement  = 0.0;
double g_sim_DemandReturn = 0.0;

// Convexity Maturity
double g_expWeaknessScore     = 0.0;
double g_inductionMatScore    = 0.0;
double g_liqMatScore          = 0.0;
double g_rawConvexityMaturity = 0.0;
double g_convexityMaturity    = 0.0;  // EMA smoothed

// Wave Progress
double g_waveProgress         = 30.0; // EMA smoothed 0-100

//==================================================================
// GLOBAL STATE - BELIEF ENGINE (6 beliefs, EMA smoothed)
//==================================================================
double g_expansionBelief    = 0.0;
double g_convexityBelief    = 0.0;
double g_creationBelief     = 0.0;
double g_absorptionBelief   = 0.0;
double g_retracementBelief  = 0.0;
double g_demandReturnBelief = 0.0;

//==================================================================
// GLOBAL STATE - HYPOTHESIS ENGINE
//==================================================================
double g_hyp_LateExpansion      = 0.0;
double g_hyp_TerminalConvexity  = 0.0;
double g_hyp_CreationForming    = 0.0;
double g_hyp_AbsorptionActive   = 0.0;
double g_hyp_RetracementActive  = 0.0;
double g_hyp_DemandReturn       = 0.0;

//==================================================================
// GLOBAL STATE - PREDICTION ENGINE
//==================================================================
double g_predScore_Expansion    = 0.0;
double g_predScore_Convexity    = 0.0;
double g_predScore_Creation     = 0.0;
double g_predScore_Absorption   = 0.0;
double g_predScore_Retracement  = 0.0;
double g_predScore_DemandReturn = 0.0;
string g_expectedNextPhase      = "Expansion";
double g_expectedNextProb       = 50.0;

//==================================================================
// GLOBAL STATE - LIQUIDATION WAVE OVERLAY (Engine 1A.7)
//==================================================================
bool   g_liqg_active    = false;
bool   g_liqg_isRetr    = false;
int    g_liqg_dir       = 0;
double g_liqg_target    = 0.0;
double g_liqg_initDist  = 0.0;
double g_liqg_distPct   = 100.0;
bool   g_liqg_objArrival= false;
bool   g_liqg_trueCHoCH = false;
string g_liqg_subPhase  = "";

//==================================================================
// GLOBAL STATE - SENSEEI META-INTELLIGENCE
//==================================================================
int    g_senseei_master     = 0;   // master direction from 4 voters
double g_senseei_alignment  = 50.0;
double g_senseei_conflict   = 0.0;
double g_senseei_threat     = 0.0;
double g_senseei_confidence = 0.0;
string g_senseei_timing     = "DEVELOPING";
string g_senseei_intent     = "BALANCE";
double g_senseei_opportunity= 0.0;
string g_senseei_action     = "WAIT";  // ATTACK/PREPARE/MANAGE/WAIT

//==================================================================
// PERSISTENT STATE (wave depth, entry cycle tracking)
//==================================================================
int    g_intel_waveDepth   = 0;
int    g_intel_entryCycle  = 0;
int    g_intel_lastDir     = 0;
bool   g_intel_recursiveComplete = false;
double g_intel_waveModelFit = 50.0;


//==================================================================
// HELPER: EMA Alpha from period (or direct alpha input)
//==================================================================
double Intel_GetAlpha()
{
   if(InpBelief_Alpha > 0.0)
      return(InpBelief_Alpha);
   return(2.0 / (InpBelief_Smooth + 1.0));
}

//==================================================================
// HELPER: Ideal Similarity (4D Euclidean distance in normalized space)
// Computes similarity between observed physics vector and ideal template
//==================================================================
double f_idealSim(double eObs, double dObs, double vObs, double cObs,
                  double eIdeal, double dIdeal, double vIdeal, double cIdeal)
{
   double diff = MathPow(eObs - eIdeal, 2) +
                 MathPow(dObs - dIdeal, 2) +
                 MathPow(vObs - vIdeal, 2) +
                 MathPow(cObs - cIdeal, 2);
   return(MathMax(0.0, 100.0 * (1.0 - diff / 4.0)));
}

//==================================================================
// SECTION 9: PHYSICS OBSERVATION LAYER
// Computed from the M5 structure engine physics (g_se[TF_M5])
//==================================================================
void Intel_UpdatePhysicsObservation()
{
   // We use M5 timeframe as canonical (index TF_M5 = 2)
   int tfIdx = TF_M5;
   SE_Result &se = g_se[tfIdx];

   // Get M5 close/high/low for physics computation
   double cl[];
   double hi[];
   double lo[];
   ArraySetAsSeries(cl, true);
   ArraySetAsSeries(hi, true);
   ArraySetAsSeries(lo, true);

   int bars = CopyClose(_Symbol, PERIOD_M5, 0, 30, cl);
   CopyHigh(_Symbol, PERIOD_M5, 0, 30, hi);
   CopyLow(_Symbol, PERIOD_M5, 0, 30, lo);
   if(bars < 15) return;

   double atr = SE_ComputeATR(hi, lo, bars, InpSE_ATRLen);
   if(atr <= 0.0) atr = 1e-10;

   // Velocity (EMA3 of close deltas)
   double velocity = 0.0;
   if(bars > 3)
   {
      double d0 = cl[0] - cl[1];
      double d1 = cl[1] - cl[2];
      double d2 = cl[2] - cl[3];
      double mult = 2.0 / 4.0;
      double ema = d2;
      ema = d1 * mult + ema * (1.0 - mult);
      ema = d0 * mult + ema * (1.0 - mult);
      velocity = ema;
   }

   // Acceleration
   double velPrev = 0.0;
   if(bars > 4)
   {
      double d0p = cl[1] - cl[2];
      double d1p = cl[2] - cl[3];
      double d2p = cl[3] - cl[4];
      double mult = 2.0 / 4.0;
      double ema = d2p;
      ema = d1p * mult + ema * (1.0 - mult);
      ema = d0p * mult + ema * (1.0 - mult);
      velPrev = ema;
   }
   double acceleration = velocity - velPrev;

   // Convexity (CSM approximation)
   double accPrev = 0.0;
   if(bars > 5)
   {
      double velPrev2 = 0.0;
      double d0pp = cl[2] - cl[3];
      double d1pp = cl[3] - cl[4];
      double d2pp = cl[4] - cl[5];
      double mult = 2.0 / 4.0;
      double ema = d2pp;
      ema = d1pp * mult + ema * (1.0 - mult);
      ema = d0pp * mult + ema * (1.0 - mult);
      velPrev2 = ema;
      accPrev = velPrev - velPrev2;
   }
   double convSmooth = acceleration - accPrev;

   // Efficiency
   double eff = 0.0;
   if(bars > InpSE_EffLen)
   {
      double mv = MathAbs(cl[0] - cl[InpSE_EffLen]);
      double ps = 0.0;
      for(int i = 0; i < InpSE_EffLen; i++)
         ps += MathAbs(cl[i] - cl[i + 1]);
      eff = (ps > 0.0) ? mv / ps : 0.0;
   }

   // Displacement
   double disp = (hi[0] - lo[0]) / MathMax(atr, 1e-10);

   // Momentum decay flags
   bool bullMomDecay = MathAbs(acceleration) < MathAbs(accPrev) * 0.8 && velocity > 0;
   bool bearMomDecay = MathAbs(acceleration) < MathAbs(accPrev) * 0.8 && velocity < 0;

   // Physics scores
   g_velocityScore     = MathMin(MathAbs(velocity) / MathMax(atr * 0.1, 1e-10) * 50.0, 100.0);
   g_accelerationScore = MathMin(MathAbs(acceleration) / MathMax(atr * 0.05, 1e-10) * 50.0, 100.0);
   g_convexityScore    = MathMin(MathAbs(convSmooth) / MathMax(atr * InpSE_ConvMult, 1e-10) * 25.0, 100.0);

   // obs_ExpansionScore
   double expBase = (eff > InpSE_EffThresh) ? eff * 60.0 : eff * 30.0;
   double expDisp = (disp > InpSE_DispThresh) ? (disp / MathMax(InpSE_DispThresh, 1e-10) - 1.0) * 20.0 : 0.0;
   double expVel  = ((velocity > 0 && acceleration > 0) || (velocity < 0 && acceleration < 0))
                    ? g_velocityScore * 0.2 : 0.0;
   g_obs_ExpansionScore = MathMin(expBase + expDisp + expVel, 100.0);

   // obs_DecayScore
   double decayBase = (bullMomDecay || bearMomDecay) ? 40.0 : 0.0;
   double decayConv = (g_convexityScore > 30) ? g_convexityScore * 0.5 : 0.0;
   double decayVel  = (MathAbs(velocity) < MathAbs(velPrev) * 0.7) ? 30.0 : 0.0;
   g_obs_DecayScore = MathMin(decayBase + decayConv + decayVel, 100.0);

   // obs_CurvatureScore
   g_obs_CurvatureScore = g_convexityScore;

   // obs_AbsorptionScore
   double absEff  = (eff < InpSE_EffThresh * 0.7) ? (1.0 - eff / MathMax(InpSE_EffThresh, 1e-10)) * 50.0 : 0.0;
   double absVel  = (MathAbs(velocity) < MathAbs(velPrev) * 0.5) ? 30.0 : 0.0;
   double absDisp = (disp < InpSE_DispThresh * 0.5) ? 20.0 : 0.0;
   g_obs_AbsorptionScore = MathMin(absEff + absVel + absDisp, 100.0);

   // obs_LiquidityScore
   double liqDecay = g_obs_DecayScore * 0.4;
   double liqCurv  = g_obs_CurvatureScore * 0.4;
   double liqDisp  = (disp > InpSE_DispThresh * 1.2 && (bullMomDecay || bearMomDecay)) ? 20.0 : 0.0;
   g_obs_LiquidityScore = MathMin(liqDecay + liqCurv + liqDisp, 100.0);

   // Consensus metrics
   g_physicsMax  = MathMax(g_obs_ExpansionScore, MathMax(g_obs_DecayScore,
                   MathMax(g_obs_AbsorptionScore, g_obs_LiquidityScore)));
   double physMin = MathMin(g_obs_ExpansionScore, MathMin(g_obs_DecayScore,
                   MathMin(g_obs_AbsorptionScore, g_obs_LiquidityScore)));
   g_physicsDiff = g_physicsMax - physMin;
   g_physicsConsensus = MathMax(0.0, 100.0 - g_physicsDiff);
}


//==================================================================
// EDE - ENERGY DISSIPATION ENGINE
// Maps canonical phase -> energy state 1-6
//==================================================================
void Intel_UpdateEDE()
{
   int phase = g_se[TF_M5].phase;

   // Map canonical phase to EDE state
   // 0=Point4, 1=Expansion -> state 1 (Accumulating)
   // 2=ExpPreConv -> state 2
   // 3=ExpInduction -> state 3
   // 4=ExpLiquidity -> state 4
   // 5/6=NewHigh/NewLow -> state 5
   // 7+=Absorption onward -> state 6
   if(phase <= 1)
      g_ede_state = 1;
   else if(phase == 2)
      g_ede_state = 2;
   else if(phase == 3)
      g_ede_state = 3;
   else if(phase == 4)
      g_ede_state = 4;
   else if(phase == 5 || phase == 6)
      g_ede_state = 5;
   else
      g_ede_state = 6;

   // Cleaning state label
   switch(g_ede_state)
   {
      case 1: g_ede_cleaningState = "Accumulating"; break;
      case 2: g_ede_cleaningState = "Cleaning - Initial Release"; break;
      case 3: g_ede_cleaningState = "Cleaning - Secondary Release"; break;
      case 4: g_ede_cleaningState = "Cleaning - Purge"; break;
      case 5: g_ede_cleaningState = "Delivering"; break;
      default: g_ede_cleaningState = "Resolving"; break;
   }

   // Expansion energy: physics score during expansion
   double impBonus = (g_se[TF_M5].compression > InpSE_EffThresh) ? 30.0 : 0.0;
   g_ede_expansionEnergy = MathMin(
      g_obs_ExpansionScore * 0.50 + impBonus + g_se[TF_M5].compression * 20.0,
      100.0);

   // Dissipated energy: accumulates through pre-conv -> induction -> liquidation
   double dissDecay = (g_ede_state >= 2) ? g_obs_DecayScore * 0.40 : 0.0;
   double dissCurv  = (g_ede_state >= 3) ? g_obs_CurvatureScore * 0.30 : 0.0;
   double dissLiq   = (g_ede_state >= 4) ? g_obs_LiquidityScore * 0.30 : 0.0;
   g_ede_dissipatedEnergy = MathMin(dissDecay + dissCurv + dissLiq, 100.0);

   // Dissipation progress 0-100
   double prog = 0.0;
   if(g_ede_state >= 2) prog += 25.0;
   if(g_ede_state >= 3) prog += 25.0;
   if(g_ede_state >= 4) prog += 25.0;
   if(g_ede_state >= 5) prog += 25.0;
   g_ede_dissipationProgress = MathMin(prog, 100.0);

   // Messy price action = Energy Dissipation (not randomness)
   g_ede_messyPriceIsDissipation =
      (g_ede_state >= 2 && g_ede_state <= 4) &&
      g_obs_DecayScore > 30.0 &&
      g_se[TF_M5].compression < InpSE_EffThresh * 0.9;
}

//==================================================================
// RE - RESOLUTION ENGINE
// Answers: Did the process actually finish?
//==================================================================
void Intel_UpdateRE()
{
   // Track wave depth and entry cycles
   int curDir = g_se[TF_M5].dir;
   if(curDir != g_intel_lastDir && curDir != 0)
   {
      g_intel_lastDir = curDir;
      g_intel_waveDepth = 0;
      g_intel_entryCycle = 0;
      g_intel_recursiveComplete = false;
   }

   // Increment depth on structure breaks
   if(g_se[TF_M5].recursionBreaks > g_intel_waveDepth)
      g_intel_waveDepth = g_se[TF_M5].recursionBreaks;

   // Expected recursive cycles
   g_re_expectedCycles = MathMax(1, MathMin(g_intel_waveDepth + 2, 4));
   g_re_completedCycles = MathMax(0, MathMin(g_intel_entryCycle, g_re_expectedCycles));

   // Recursive completion score 0-100
   g_re_recursiveCompletionScore = (g_re_expectedCycles > 0)
      ? MathMin((double)g_re_completedCycles / (double)g_re_expectedCycles * 100.0, 100.0)
      : 0.0;

   // Residual energy
   g_re_residualEnergy = MathMax(0.0, g_ede_expansionEnergy - g_ede_dissipatedEnergy);

   // Resolution state
   g_re_objectiveReached = (g_ede_state >= 5);
   g_re_fullDissipation  = (g_ede_dissipationProgress >= 75.0);

   // Check if absorbed and returned (phases 12/13 = Demand/Supply Return)
   bool absorbedAndReturned = (g_se[TF_M5].phase >= 12) && g_intel_recursiveComplete;

   if(absorbedAndReturned && g_re_fullDissipation && g_re_recursiveCompletionScore >= 75.0)
      g_re_resolutionState = 2; // RESOLVED
   else if(g_re_objectiveReached && g_ede_dissipationProgress >= 50.0)
      g_re_resolutionState = 1; // PARTIALLY RESOLVED
   else
      g_re_resolutionState = 0; // UNRESOLVED

   // Residual energy score 0-100
   g_re_residualEnergyScore = MathMin(g_re_residualEnergy, 100.0);

   // Revisit probability
   if(g_re_resolutionState == 0)
      g_re_revisitProbability = MathMin(g_re_residualEnergyScore * 0.90, 95.0);
   else if(g_re_resolutionState == 1)
      g_re_revisitProbability = MathMin(g_re_residualEnergyScore * 0.60, 75.0);
   else
      g_re_revisitProbability = MathMin(g_re_residualEnergyScore * 0.20, 25.0);
}


//==================================================================
// EAE - ENERGY ATTRACTOR ENGINE
// Where is unresolved energy pulling price?
//==================================================================
void Intel_UpdateEAE()
{
   int dir = g_se[TF_M5].dir;
   double closeNow = 0.0;
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyClose(_Symbol, PERIOD_M5, 0, 1, buf) >= 1)
      closeNow = buf[0];

   double atr = GetATR(0);
   if(atr <= 0.0) atr = 1e-10;

   // Primary attractor price
   if(dir == 0)
   {
      g_eae_primaryAttractorPrice = 0.0;
   }
   else if(g_re_resolutionState == 0) // UNRESOLVED -> flip zone
   {
      g_eae_primaryAttractorPrice = (dir == 1)
         ? (g_se[TF_M5].flipBot > 0 ? g_se[TF_M5].flipBot : closeNow - atr * 2.0)
         : (g_se[TF_M5].flipTop > 0 ? g_se[TF_M5].flipTop : closeNow + atr * 2.0);
   }
   else if(g_re_resolutionState == 1) // PARTIALLY -> origin zone
   {
      g_eae_primaryAttractorPrice = (dir == 1)
         ? (g_se[TF_M5].p4Low > 0 ? g_se[TF_M5].p4Low : closeNow - atr)
         : (g_se[TF_M5].p4High > 0 ? g_se[TF_M5].p4High : closeNow + atr);
   }
   else
   {
      g_eae_primaryAttractorPrice = 0.0;
   }

   // Attractor score: weighted by residual energy + resolution state + proximity
   double resBonus = (g_re_resolutionState == 0) ? 30.0 :
                     (g_re_resolutionState == 1) ? 20.0 : 5.0;
   double proxBonus = 0.0;
   if(g_eae_primaryAttractorPrice > 0.0)
      proxBonus = MathMax(0.0, 30.0 - MathAbs(closeNow - g_eae_primaryAttractorPrice) / MathMax(atr, 1e-10) * 5.0);

   g_eae_primaryAttractorScore = MathMin(
      g_re_residualEnergyScore * 0.40 + resBonus + proxBonus, 100.0);

   // Attractor label
   if(g_re_resolutionState == 0)
      g_eae_primaryAttractorLabel = "Flip Zone (High Residual)";
   else if(g_re_resolutionState == 1)
      g_eae_primaryAttractorLabel = "Origin Zone (Partial)";
   else
      g_eae_primaryAttractorLabel = "No Active Attractor";

   // Energy state summary
   if(g_ede_state == 1)
      g_eae_energyState = "Accumulating";
   else if(g_ede_state >= 2 && g_ede_state <= 4)
      g_eae_energyState = "Cleaning";
   else if(g_ede_state == 5)
      g_eae_energyState = "Delivering";
   else if(g_re_resolutionState == 2)
      g_eae_energyState = "Exhausted";
   else
      g_eae_energyState = "Resolving";

   // ERF confidence
   double confPhase = (g_eae_energyState != "Accumulating")
      ? g_se[TF_M5].modelFit * 0.40 : 20.0;
   double confRes = (g_re_resolutionState == 2) ? 30.0 :
                    (g_re_resolutionState == 1) ? 20.0 : 10.0;
   g_erf_confidence = MathMin(confPhase + confRes + g_eae_primaryAttractorScore * 0.30, 100.0);

   // Dissipation-based rotation suppression
   g_erf_activeDissipation = g_ede_messyPriceIsDissipation;
   g_erf_suppressRotation  = g_erf_activeDissipation && g_ede_state >= 2 && g_ede_state <= 4;
}


//==================================================================
// WAVE INTELLIGENCE - SIMILARITY SCORING
// Euclidean distance in 4D normalized physics space
//==================================================================
void Intel_UpdateSimilarity()
{
   // Normalize current physics to 0-1 range
   double refEff  = MathMin(g_se[TF_M5].compression, 1.0);

   // Get displacement and velocity from M5
   double cl[];
   double hi[];
   double lo[];
   ArraySetAsSeries(cl, true);
   ArraySetAsSeries(hi, true);
   ArraySetAsSeries(lo, true);
   int bars = CopyClose(_Symbol, PERIOD_M5, 0, 15, cl);
   CopyHigh(_Symbol, PERIOD_M5, 0, 15, hi);
   CopyLow(_Symbol, PERIOD_M5, 0, 15, lo);
   if(bars < 5) return;

   double atr = SE_ComputeATR(hi, lo, bars, InpSE_ATRLen);
   if(atr <= 0.0) atr = 1e-10;

   double disp = (hi[0] - lo[0]) / MathMax(atr, 1e-10);
   double refDisp = MathMin(disp / MathMax(InpSE_DispThresh * 2.0, 1e-10), 1.0);

   // Velocity normalized
   double vel = 0.0;
   if(bars > 3)
   {
      double d0 = cl[0] - cl[1];
      double d1 = cl[1] - cl[2];
      double d2 = cl[2] - cl[3];
      double mult = 2.0 / 4.0;
      double ema = d2;
      ema = d1 * mult + ema * (1.0 - mult);
      ema = d0 * mult + ema * (1.0 - mult);
      vel = ema;
   }
   double refVel  = MathMin(MathAbs(vel) / MathMax(atr * 0.15, 1e-10), 1.0);

   // Convexity normalized
   double convS = 0.0;
   if(bars > 5)
   {
      double velP = 0.0;
      {
         double d0p = cl[1] - cl[2];
         double d1p = cl[2] - cl[3];
         double d2p = cl[3] - cl[4];
         double mult = 2.0 / 4.0;
         double ema = d2p;
         ema = d1p * mult + ema * (1.0 - mult);
         ema = d0p * mult + ema * (1.0 - mult);
         velP = ema;
      }
      double acc = vel - velP;
      double velP2 = 0.0;
      {
         double d0pp = cl[2] - cl[3];
         double d1pp = cl[3] - cl[4];
         double d2pp = cl[4] - cl[5];
         double mult = 2.0 / 4.0;
         double ema = d2pp;
         ema = d1pp * mult + ema * (1.0 - mult);
         ema = d0pp * mult + ema * (1.0 - mult);
         velP2 = ema;
      }
      double accP = velP - velP2;
      convS = acc - accP;
   }
   double refCurv = MathMin(MathAbs(convS) / MathMax(atr * InpSE_ConvMult * 2.0, 1e-10), 1.0);

   // Compute similarity to each ideal phase template
   g_sim_Expansion    = f_idealSim(refEff, refDisp, refVel, refCurv, 0.85, 0.80, 0.80, 0.10);
   g_sim_PreConv      = f_idealSim(refEff, refDisp, refVel, refCurv, 0.60, 0.55, 0.40, 0.50);
   g_sim_Induction    = f_idealSim(refEff, refDisp, refVel, refCurv, 0.65, 0.60, 0.30, 0.60);
   g_sim_Liquidity    = f_idealSim(refEff, refDisp, refVel, refCurv, 0.45, 0.85, 0.15, 0.80);
   g_sim_Creation     = f_idealSim(refEff, refDisp, refVel, refCurv, 0.30, 0.70, 0.05, 0.90);
   g_sim_Absorption   = f_idealSim(refEff, refDisp, refVel, refCurv, 0.20, 0.25, 0.10, 0.40);
   g_sim_Retracement  = f_idealSim(refEff, refDisp, refVel, refCurv, 0.70, 0.65, 0.65, 0.25);
   g_sim_DemandReturn = f_idealSim(refEff, refDisp, refVel, refCurv, 0.50, 0.40, 0.35, 0.20);
}

//==================================================================
// CONVEXITY MATURITY ENGINE
//==================================================================
void Intel_UpdateConvexityMaturity()
{
   // Expansion weakness
   double ewEff = (g_se[TF_M5].compression < InpSE_EffThresh)
      ? (1.0 - g_se[TF_M5].compression / MathMax(InpSE_EffThresh, 1e-10)) * 40.0 : 0.0;
   double ewDecay = g_obs_DecayScore * 0.30;
   // Velocity weakening proxy (use decay as proxy)
   double ewVel = (g_obs_DecayScore > 30.0) ? 20.0 : 0.0;
   g_expWeaknessScore = MathMin((ewEff + ewDecay + ewVel) * (100.0 / 90.0), 100.0);

   // Induction maturity
   bool inductionEvid = (g_se[TF_M5].recursionBreaks >= 1);
   bool preConvEvid   = (g_obs_DecayScore > 30.0);
   double imInd   = inductionEvid ? 35.0 : 0.0;
   double imCurv  = g_obs_CurvatureScore * 0.35;
   double imPreC  = preConvEvid ? 20.0 : 0.0;
   double imDisp  = (g_obs_LiquidityScore > 40.0) ? 10.0 : 0.0;
   g_inductionMatScore = MathMin(imInd + imCurv + imPreC + imDisp, 100.0);

   // Liquidity maturity
   double lmLiq  = g_obs_LiquidityScore * 0.50;
   double lmSweep = (g_se[TF_M5].recursionBreaks >= 2) ? 30.0 : 0.0;
   double lmHeat  = (g_obs_LiquidityScore > 60) ? 20.0 : (g_obs_LiquidityScore > 30) ? 10.0 : 0.0;
   g_liqMatScore = MathMin(lmLiq + lmSweep + lmHeat, 100.0);

   // Raw convexity maturity
   g_rawConvexityMaturity = MathMin(
      g_expWeaknessScore * 0.35 +
      g_inductionMatScore * 0.35 +
      g_liqMatScore * 0.30, 100.0);

   // EMA smooth
   double alpha = Intel_GetAlpha();
   g_convexityMaturity += alpha * (g_rawConvexityMaturity - g_convexityMaturity);
   g_convexityMaturity = MathMax(0.0, MathMin(100.0, g_convexityMaturity));
}


//==================================================================
// WAVE PROGRESS ESTIMATION
// Geometry-based + Physics-based (similarity anchor + convexity weight)
//==================================================================
void Intel_UpdateWaveProgress()
{
   int dir = g_se[TF_M5].dir;
   double atr = GetATR(0);
   if(atr <= 0.0) atr = 1e-10;

   double closeNow = 0.0;
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyClose(_Symbol, PERIOD_M5, 0, 1, buf) >= 1)
      closeNow = buf[0];

   // Geometry-based progress
   double geomProgress = 30.0;
   double origin = g_se[TF_M5].invalidation;
   double target = g_se[TF_M5].target;
   double flipT  = g_se[TF_M5].flipTop;
   double flipB  = g_se[TF_M5].flipBot;

   if(origin > 0.0 && target > 0.0)
   {
      double totalMove = MathAbs(target - origin);
      double traveled  = MathAbs(closeNow - origin);
      double expProg   = (totalMove > 1e-10) ? MathMin(traveled / totalMove * 60.0, 60.0) : 30.0;

      // Retracement component
      double retrProg = 0.0;
      if(flipT > 0.0 && flipB > 0.0)
      {
         double fzMid = (flipT + flipB) / 2.0;
         double extreme = (dir == 1) ? MathMax(closeNow, target) : MathMin(closeNow, target);
         double toFzMid = MathAbs(extreme - fzMid);
         double retrMove = MathAbs(closeNow - extreme);
         if(toFzMid > 1e-10)
            retrProg = MathMin(retrMove / MathMax(toFzMid, 1e-10) * 40.0, 40.0);
      }

      double retrWeight = MathMin(g_obs_AbsorptionScore / 40.0, 1.0);
      geomProgress = expProg + retrProg * retrWeight;
   }

   // Physics-based: similarity anchor
   double simAnchor = 22.0;
   if(g_sim_DemandReturn >= g_sim_Retracement && g_sim_DemandReturn >= g_sim_Absorption &&
      g_sim_DemandReturn >= g_sim_Creation && g_sim_DemandReturn >= g_sim_Expansion)
      simAnchor = 95.0;
   else if(g_sim_Retracement >= g_sim_Absorption && g_sim_Retracement >= g_sim_Creation &&
           g_sim_Retracement >= g_sim_Expansion)
      simAnchor = 87.0;
   else if(g_sim_Absorption >= g_sim_Creation && g_sim_Absorption >= g_sim_Expansion)
      simAnchor = 75.0;
   else if(g_sim_Creation >= g_sim_Liquidity && g_sim_Creation >= g_sim_Expansion)
      simAnchor = 62.0;
   else if(g_sim_Liquidity >= g_sim_Induction && g_sim_Liquidity >= g_sim_Expansion)
      simAnchor = 52.0;
   else if(g_sim_Induction >= g_sim_PreConv && g_sim_Induction >= g_sim_Expansion)
      simAnchor = 43.0;
   else if(g_sim_PreConv >= g_sim_Expansion)
      simAnchor = 33.0;

   // Convexity adjustment
   double convBandCenter = 47.5;
   double convBandHalfW  = 14.5;
   double convWeight = MathMax(0.0, 1.0 - MathAbs(simAnchor - convBandCenter) / convBandHalfW);
   double convAdjust = (g_convexityMaturity / 100.0) * (simAnchor - 33.0) * 0.50 * convWeight;

   double physProgress = simAnchor + convAdjust;

   // Combine geometry and physics
   double rawWP = geomProgress * 0.60 + physProgress * 0.40;

   // EMA smooth
   double alpha = Intel_GetAlpha();
   g_waveProgress += alpha * (rawWP - g_waveProgress);
   g_waveProgress = MathMax(0.0, MathMin(100.0, g_waveProgress));
}


//==================================================================
// BELIEF ENGINE - 6 simultaneous beliefs with position-multiplier
// gating and EMA smoothing
//==================================================================
void Intel_UpdateBeliefs()
{
   double alpha = Intel_GetAlpha();
   int dir = g_se[TF_M5].dir;
   double eff = g_se[TF_M5].compression;
   bool preConvEvid = (g_obs_DecayScore > 30.0);
   bool inductionEvid = (g_se[TF_M5].recursionBreaks >= 1);
   bool liquidityEvid = (g_obs_LiquidityScore > 50.0 && g_obs_DecayScore > 40.0);
   bool bullImp = (dir == 1 && eff > InpSE_EffThresh);
   bool bearImp = (dir == -1 && eff > InpSE_EffThresh);
   bool anyImpulse = bullImp || bearImp;

   // Position multipliers: beliefs weighted by wave progress position
   double expPosMult = (g_waveProgress < 40.0) ? 1.20 :
                       (g_waveProgress < 60.0) ? 0.80 : 0.50;

   double convPosMult = (g_waveProgress >= 30.0 && g_waveProgress <= 65.0) ? 1.30 : 0.70;

   double creatPosMult = (g_waveProgress >= 45.0 && g_waveProgress <= 68.0) ? 1.40 : 0.60;

   // Raw Expansion Belief
   double rawExp = MathMin(
      (g_obs_ExpansionScore * 0.45 +
       (anyImpulse ? 30.0 : 0.0) +
       (eff > InpSE_EffThresh * 1.1 ? 15.0 : 0.0) +
       g_sim_Expansion * 0.10) * expPosMult,
      100.0);

   // Raw Convexity Belief
   double rawConv = MathMin(
      (g_obs_DecayScore * 0.30 +
       g_obs_CurvatureScore * 0.25 +
       (preConvEvid ? 15.0 : 0.0) +
       (inductionEvid ? 10.0 : 0.0) +
       (liquidityEvid ? 5.0 : 0.0) +
       g_convexityMaturity * 0.08) * convPosMult,
      100.0);

   // Raw Creation Belief
   double creatConv = (g_convexityMaturity > 50) ? g_convexityMaturity * 0.12 : 0.0;
   double creatDecay = (g_obs_DecayScore > 60) ? g_obs_DecayScore * 0.20 : 0.0;
   double creatLiq = (g_obs_LiquidityScore > 50) ? g_obs_LiquidityScore * 0.20 : 0.0;
   double creatAbs = (g_obs_AbsorptionScore > 20) ? g_obs_AbsorptionScore * 0.15 : 0.0;
   double creatSim = g_sim_Creation * 0.10;
   double rawCreat = MathMin(
      (creatConv + creatDecay + creatLiq + creatAbs + creatSim) * creatPosMult,
      100.0);

   // Raw Absorption Belief
   double rawAbs = MathMin(
      g_obs_AbsorptionScore * 0.50 +
      (eff < InpSE_EffThresh * 0.6 ? 25.0 : 0.0) +
      (g_obs_LiquidityScore < InpSE_DispThresh * 0.5 * 100.0 ? 15.0 : 0.0) +
      g_sim_Absorption * 0.10,
      100.0);

   // Raw Retracement Belief
   bool counterImpulse = (dir == 1 && g_obs_ExpansionScore < 30.0 && g_obs_DecayScore > 40.0) ||
                         (dir == -1 && g_obs_ExpansionScore < 30.0 && g_obs_DecayScore > 40.0);
   double rawRetr = MathMin(
      (counterImpulse ? 45.0 : 0.0) +
      (rawAbs > 50 ? rawAbs * 0.30 : 0.0) +
      (g_obs_CurvatureScore > 40 ? 15.0 : 0.0) +
      g_sim_Retracement * 0.10,
      100.0);

   // Raw Demand Return Belief
   double closeNow = 0.0;
   double bufC[];
   ArraySetAsSeries(bufC, true);
   if(CopyClose(_Symbol, PERIOD_M5, 0, 1, bufC) >= 1)
      closeNow = bufC[0];

   double flipT = g_se[TF_M5].flipTop;
   double flipB = g_se[TF_M5].flipBot;
   bool closeInside = (flipT > 0.0 && flipB > 0.0 && closeNow <= flipT && closeNow >= flipB);

   double rawDR = MathMin(
      (closeInside ? 35.0 : 0.0) +
      (rawRetr > 60 ? rawRetr * 0.30 : 0.0) +
      (g_obs_LiquidityScore > 50 ? g_obs_LiquidityScore * 0.15 : 0.0) +
      (g_se[TF_M5].recursionBreaks >= 2 ? 20.0 : 0.0) +
      g_sim_DemandReturn * 0.10,
      100.0);

   // EMA smooth all beliefs
   g_expansionBelief    += alpha * (rawExp  - g_expansionBelief);
   g_convexityBelief    += alpha * (rawConv - g_convexityBelief);
   g_creationBelief     += alpha * (rawCreat - g_creationBelief);
   g_absorptionBelief   += alpha * (rawAbs  - g_absorptionBelief);
   g_retracementBelief  += alpha * (rawRetr - g_retracementBelief);
   g_demandReturnBelief += alpha * (rawDR   - g_demandReturnBelief);

   // Clamp 0-100
   g_expansionBelief    = MathMax(0.0, MathMin(100.0, g_expansionBelief));
   g_convexityBelief    = MathMax(0.0, MathMin(100.0, g_convexityBelief));
   g_creationBelief     = MathMax(0.0, MathMin(100.0, g_creationBelief));
   g_absorptionBelief   = MathMax(0.0, MathMin(100.0, g_absorptionBelief));
   g_retracementBelief  = MathMax(0.0, MathMin(100.0, g_retracementBelief));
   g_demandReturnBelief = MathMax(0.0, MathMin(100.0, g_demandReturnBelief));
}


//==================================================================
// HYPOTHESIS ENGINE - 6 hypothesis scores normalized to 0-100
//==================================================================
void Intel_UpdateHypothesis()
{
   double fitMult = MathMax(0.60, g_intel_waveModelFit / 100.0);

   // Hypothesis: Late Expansion
   double hypLE = (
      g_expansionBelief * 0.35 +
      (g_waveProgress < 38.0 ? (38.0 - g_waveProgress) * 0.80 : 0.0) +
      (g_convexityMaturity < 30 ? (30.0 - g_convexityMaturity) * 0.30 : 0.0) +
      g_sim_Expansion * 0.20 +
      (g_expansionBelief > 55 && g_convexityBelief > 30 ? 10.0 : 0.0)
   ) * fitMult;

   // Hypothesis: Terminal Convexity
   double hypTC = (
      g_convexityBelief * 0.30 +
      (g_convexityMaturity > 50 ? g_convexityMaturity * 0.25 : 0.0) +
      (g_waveProgress >= 38.0 && g_waveProgress <= 62.0 ? 20.0 : 0.0) +
      (g_sim_Induction + g_sim_Liquidity) * 0.10 +
      (g_waveProgress < 55.0 ? (55.0 - g_waveProgress) * 0.30 : 0.0)
   ) * fitMult;

   // Hypothesis: Creation Forming
   double hypCF = (
      g_creationBelief * 0.40 +
      (g_convexityMaturity > 65 ? (g_convexityMaturity - 65.0) * 0.40 : 0.0) +
      (g_waveProgress >= 55.0 ? (g_waveProgress - 55.0) * 0.50 : 0.0) +
      g_sim_Creation * 0.20
   ) * fitMult;

   // Hypothesis: Absorption Active
   double hypAA = (
      g_absorptionBelief * 0.45 +
      (g_waveProgress >= 68.0 && g_waveProgress <= 80.0 ? 20.0 : 0.0) +
      g_sim_Absorption * 0.25 +
      (g_obs_AbsorptionScore > 50 ? 10.0 : 0.0)
   ) * fitMult;

   // Hypothesis: Retracement Active
   double hypRA = (
      g_retracementBelief * 0.45 +
      (g_waveProgress >= 78.0 && g_waveProgress <= 92.0 ? 20.0 : 0.0) +
      g_sim_Retracement * 0.25 +
      (g_obs_DecayScore > 50 ? 10.0 : 0.0)
   ) * fitMult;

   // Hypothesis: Demand Return
   double hypDR = (
      g_demandReturnBelief * 0.45 +
      (g_waveProgress >= 88.0 ? (g_waveProgress - 88.0) * 1.20 : 0.0) +
      g_sim_DemandReturn * 0.25 +
      (g_se[TF_M5].flipBot > 0 && g_se[TF_M5].flipTop > 0 ? 15.0 : 0.0)
   ) * fitMult;

   // Fixed theoretical maxima normalization to 0-100
   double HYP_MAX_LE  = 105.0;
   double HYP_MAX_TC  = 108.0;
   double HYP_MAX_CF  = 97.0;
   double HYP_MAX_AA  = 100.0;
   double HYP_MAX_RA  = 100.0;
   double HYP_MAX_DR  = 100.0;

   g_hyp_LateExpansion     = MathMax(0.0, MathMin(hypLE / HYP_MAX_LE * 100.0, 100.0));
   g_hyp_TerminalConvexity = MathMax(0.0, MathMin(hypTC / HYP_MAX_TC * 100.0, 100.0));
   g_hyp_CreationForming   = MathMax(0.0, MathMin(hypCF / HYP_MAX_CF * 100.0, 100.0));
   g_hyp_AbsorptionActive  = MathMax(0.0, MathMin(hypAA / HYP_MAX_AA * 100.0, 100.0));
   g_hyp_RetracementActive = MathMax(0.0, MathMin(hypRA / HYP_MAX_RA * 100.0, 100.0));
   g_hyp_DemandReturn      = MathMax(0.0, MathMin(hypDR / HYP_MAX_DR * 100.0, 100.0));

   // Update wave model fit (EMA of best similarity + geometric consistency)
   double bestSim = MathMax(g_sim_Expansion, MathMax(g_sim_PreConv,
                    MathMax(g_sim_Induction, MathMax(g_sim_Liquidity,
                    MathMax(g_sim_Creation, MathMax(g_sim_Absorption,
                    MathMax(g_sim_Retracement, g_sim_DemandReturn)))))));

   double geomConsist = 0.0;
   if(g_se[TF_M5].target != 0.0 && g_se[TF_M5].invalidation != 0.0)
      geomConsist += 30.0;
   if(g_se[TF_M5].flipTop != 0.0 && g_se[TF_M5].flipBot != 0.0)
      geomConsist += 25.0;
   if(g_se[TF_M5].swingHigh != 0.0 || g_se[TF_M5].swingLow != 0.0)
      geomConsist += 20.0;
   if(g_se[TF_M5].dir != 0)
      geomConsist += 25.0;
   geomConsist = MathMin(geomConsist, 100.0);

   double rawModelFit = bestSim * 0.55 + geomConsist * 0.45;
   double alpha = Intel_GetAlpha();
   g_intel_waveModelFit += alpha * (rawModelFit - g_intel_waveModelFit);
   g_intel_waveModelFit = MathMax(0.0, MathMin(100.0, g_intel_waveModelFit));
}


//==================================================================
// PREDICTION ENGINE - Scoring each possible next phase
//==================================================================
void Intel_UpdatePrediction()
{
   int dir = g_se[TF_M5].dir;
   bool htfAligned = (g_fractalStackDir == dir && dir != 0);

   // Prediction: next phase is Expansion
   g_predScore_Expansion =
      (g_waveProgress < 35.0 ? (35.0 - g_waveProgress) * 1.00 : 0.0) +
      (g_expansionBelief > 55 ? g_expansionBelief * 0.30 : 0.0) +
      (g_convexityMaturity < 25 ? 20.0 : 0.0) +
      (g_waveProgress > 30 ? 0.0 : 15.0) +
      (htfAligned ? 15.0 : 0.0);

   // Prediction: next phase is Convexity (Pre-Convexity)
   g_predScore_Convexity =
      (g_waveProgress >= 25.0 && g_waveProgress <= 60.0 ? 30.0 : 0.0) +
      (g_convexityMaturity > 20 ? g_convexityMaturity * 0.30 : 0.0) +
      (g_obs_DecayScore > 40 ? 20.0 : 0.0) +
      (g_obs_CurvatureScore > 30 ? 15.0 : 0.0) +
      (g_obs_DecayScore > 30.0 ? 15.0 : 0.0);

   // Prediction: next phase is Creation (New High/Low)
   g_predScore_Creation =
      (g_convexityMaturity > 55 ? (g_convexityMaturity - 55.0) * 1.20 : 0.0) +
      (g_waveProgress > 55 ? (g_waveProgress - 55.0) * 0.80 : 0.0) +
      (g_obs_LiquidityScore > 55 ? 20.0 : 0.0) +
      (g_se[TF_M5].recursionBreaks >= 2 ? 15.0 : 0.0) +
      (g_obs_CurvatureScore > 50 ? 10.0 : 0.0);

   // Prediction: next phase is Absorption
   g_predScore_Absorption =
      (g_predScore_Creation > 50 ? g_predScore_Creation * 0.40 : 0.0) +
      (g_obs_AbsorptionScore > 35 ? g_obs_AbsorptionScore * 0.30 : 0.0) +
      (g_obs_AbsorptionScore > 50 ? 20.0 : 0.0) +
      (g_waveProgress >= 60.0 && g_waveProgress <= 78.0 ? 15.0 : 0.0);

   // Prediction: next phase is Retracement
   g_predScore_Retracement =
      (g_absorptionBelief > 45 ? g_absorptionBelief * 0.35 : 0.0) +
      (g_obs_DecayScore > 50 && g_obs_AbsorptionScore > 40 ? 25.0 : 0.0) +
      (g_waveProgress >= 72.0 && g_waveProgress <= 90.0 ? 20.0 : 0.0) +
      (g_physicsConsensus < 40 ? 10.0 : 0.0);

   // Prediction: next phase is Demand/Supply Return
   g_predScore_DemandReturn =
      (g_retracementBelief > 45 ? g_retracementBelief * 0.35 : 0.0) +
      (g_waveProgress > 80.0 ? (g_waveProgress - 80.0) * 1.00 : 0.0) +
      (g_se[TF_M5].recursionBreaks >= 2 ? 20.0 : 0.0) +
      (g_waveProgress >= 88.0 ? (g_waveProgress - 88.0) * 1.20 : 0.0);

   // Determine highest scoring prediction
   double maxPred = MathMax(g_predScore_Expansion, MathMax(g_predScore_Convexity,
                    MathMax(g_predScore_Creation, MathMax(g_predScore_Absorption,
                    MathMax(g_predScore_Retracement, g_predScore_DemandReturn)))));

   // Select next phase
   if(g_predScore_DemandReturn >= g_predScore_Retracement &&
      g_predScore_DemandReturn >= g_predScore_Absorption &&
      g_predScore_DemandReturn >= g_predScore_Creation &&
      g_predScore_DemandReturn >= g_predScore_Convexity &&
      g_predScore_DemandReturn >= g_predScore_Expansion)
   {
      g_expectedNextPhase = (dir == -1) ? "Supply Return" : "Demand Return";
   }
   else if(g_predScore_Retracement >= g_predScore_Absorption &&
           g_predScore_Retracement >= g_predScore_Creation &&
           g_predScore_Retracement >= g_predScore_Convexity &&
           g_predScore_Retracement >= g_predScore_Expansion)
   {
      g_expectedNextPhase = "Retracement";
   }
   else if(g_predScore_Absorption >= g_predScore_Creation &&
           g_predScore_Absorption >= g_predScore_Convexity &&
           g_predScore_Absorption >= g_predScore_Expansion)
   {
      g_expectedNextPhase = "Absorption";
   }
   else if(g_predScore_Creation >= g_predScore_Convexity &&
           g_predScore_Creation >= g_predScore_Expansion)
   {
      g_expectedNextPhase = (dir == -1) ? "New Low" : "New High";
   }
   else if(g_predScore_Convexity >= g_predScore_Expansion)
   {
      g_expectedNextPhase = "Expansion Pre-Convexity";
   }
   else
   {
      g_expectedNextPhase = "Expansion";
   }

   // Probability of next phase
   g_expectedNextProb = (maxPred > 0)
      ? MathMin(maxPred / MathMax(maxPred + 30.0, 1.0) * 100.0, 95.0)
      : 50.0;
}


//==================================================================
// LIQUIDATION WAVE OVERLAY (Engine 1A.7)
// Tracks induction phases toward objective arrival with triple
// confirmation (structure + momentum + physics)
//==================================================================
void Intel_UpdateLiquidationWave()
{
   int phase = g_se[TF_M5].phase;
   double target = g_se[TF_M5].target;
   double atr = GetATR(0);
   if(atr <= 0.0) atr = 1e-10;

   double closeNow = 0.0;
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyClose(_Symbol, PERIOD_M5, 0, 1, buf) >= 1)
      closeNow = buf[0];

   // Arm condition: in Expansion Induction or Retracement Induction
   bool isRetrInd = (phase == 10);
   bool isArmable = (phase == 3 || isRetrInd);

   // Activate liquidation wave tracking
   if(isArmable && !g_liqg_active && target > 0.0)
   {
      g_liqg_active   = true;
      g_liqg_isRetr   = isRetrInd;
      g_liqg_target   = target;
      g_liqg_dir      = (target > closeNow) ? 1 : -1;
      g_liqg_initDist = MathMax(MathAbs(target - closeNow), atr * 0.5);
   }

   // Update target if still active
   if(g_liqg_active && target > 0.0)
      g_liqg_target = target;

   // Distance compression: 100% = at origin, 0% = arrived
   double remain = 0.0;
   if(g_liqg_active && g_liqg_target > 0.0)
   {
      remain = MathAbs(g_liqg_target - closeNow);
      g_liqg_distPct = MathMin(100.0, remain / MathMax(g_liqg_initDist, 1e-10) * 100.0);
   }
   else
   {
      g_liqg_distPct = 100.0;
   }

   // Triple confirmation gates for objective arrival
   bool capExhausted = (g_ede_dissipationProgress > 60 || g_convexityMaturity > 60);
   bool resolved     = (g_re_resolutionState == 2);
   bool energyLow    = (g_se[TF_M5].compression < InpSE_EffThresh * 0.7);
   bool magnet       = (g_liqg_active && g_liqg_distPct < 20);

   // STRUCTURE: price reached/exceeded target
   bool arrStruct = (g_liqg_active && g_liqg_target > 0.0 &&
                    (g_liqg_dir == 1 ? closeNow >= g_liqg_target : closeNow <= g_liqg_target));

   // PHYSICS: capacity exhausted AND (resolved or at magnet distance)
   bool arrPhys = capExhausted && (resolved || magnet);

   // OBJECTIVE ARRIVAL = all three dimensions agree
   g_liqg_objArrival = arrStruct && energyLow && arrPhys;

   // TRUE CHANGE OF CHARACTER (never from BOS alone)
   bool counterBOS = (g_liqg_dir == 1) ? (g_se[TF_M5].bosDir == -1) : (g_se[TF_M5].bosDir == 1);
   g_liqg_trueCHoCH = g_liqg_objArrival && counterBOS && energyLow && resolved;

   // Sub-phase classification from distance compression + physics
   if(!g_liqg_active)
   {
      g_liqg_subPhase = "";
   }
   else if(g_liqg_objArrival)
   {
      g_liqg_subPhase = "Objective Arrival";
   }
   else if(magnet && energyLow)
   {
      g_liqg_subPhase = "Terminal Liquidation";
   }
   else if(g_convexityMaturity > 40 || g_ede_dissipationProgress > 40)
   {
      g_liqg_subPhase = "Induction";
   }
   else if(g_liqg_distPct < 70)
   {
      g_liqg_subPhase = "Displacement";
   }
   else if(g_liqg_distPct < 95)
   {
      g_liqg_subPhase = "Push";
   }
   else
   {
      g_liqg_subPhase = "Initialization";
   }

   // Retire condition: phase leaves induction/liquidity window OR genuine completion
   bool inWindow = (phase == 3 || phase == 4 || phase == 10 || phase == 11);
   if(g_liqg_active && (!inWindow || (g_liqg_objArrival && g_liqg_trueCHoCH)))
      g_liqg_active = false;
}


//==================================================================
// SENSEEI META-INTELLIGENCE (from F16)
// 4 voters -> master direction -> 8 meta-scores -> action state
//==================================================================
void Intel_UpdateSenseei()
{
   // 4 Voters:
   // 1) waveDir: M5 direction
   int vt1 = g_se[TF_M5].dir;

   // 2) stackDir: fractal stack consensus
   int vt2 = g_fractalStackDir;

   // 3) netBias: HTF consensus (simplified from F16 Invisible Network)
   //    Uses H4+H1+M15 consensus as proxy for network bias
   int htfBull = 0;
   int htfBear = 0;
   for(int i = TF_M15; i <= TF_H4; i++)
   {
      if(g_se[i].dir == 1) htfBull++;
      if(g_se[i].dir == -1) htfBear++;
   }
   int vt3 = (htfBull > htfBear) ? 1 : (htfBear > htfBull) ? -1 : 0;

   // 4) pressureDir: buy/sell score differential (simplified)
   //    Uses M1+M3 short-TF momentum as pressure proxy
   int stfBull = 0;
   int stfBear = 0;
   for(int i = TF_M1; i <= TF_M3; i++)
   {
      if(g_se[i].dir == 1) stfBull++;
      if(g_se[i].dir == -1) stfBear++;
   }
   double pressure = 0.0;
   int stfTotal = stfBull + stfBear;
   if(stfTotal > 0)
      pressure = (double)(stfBull - stfBear) / (double)stfTotal * 100.0;
   int vt4 = (pressure > 12) ? 1 : (pressure < -12) ? -1 : 0;

   // Master direction from 4 voters
   int voterSum = vt1 + vt2 + vt3 + vt4;
   g_senseei_master = (voterSum > 0) ? 1 : (voterSum < 0) ? -1 : 0;

   // Alignment/Conflict calculation
   int castCount = (vt1 != 0 ? 1 : 0) + (vt2 != 0 ? 1 : 0) + (vt3 != 0 ? 1 : 0) + (vt4 != 0 ? 1 : 0);
   int forCount = 0;
   if(g_senseei_master != 0)
   {
      if(vt1 == g_senseei_master && vt1 != 0) forCount++;
      if(vt2 == g_senseei_master && vt2 != 0) forCount++;
      if(vt3 == g_senseei_master && vt3 != 0) forCount++;
      if(vt4 == g_senseei_master && vt4 != 0) forCount++;
   }

   g_senseei_alignment = (castCount > 0) ? (double)forCount / (double)castCount * 100.0 : 50.0;
   g_senseei_conflict  = (castCount > 0) ? (double)(castCount - forCount) / (double)castCount * 100.0 : 0.0;

   // Time alignment (simplified: use fractal stack score as proxy)
   double timeAlign = g_fractalStackScore;
   double timeConflict = 100.0 - timeAlign;

   // Residual and attractor from ERF
   double residual  = g_re_residualEnergyScore;
   double attractor = g_eae_primaryAttractorScore;
   int    resCode   = g_re_resolutionState; // 0=UNRESOLVED, 1=PARTIAL, 2=RESOLVED

   // Threat score
   double pressureThreat = (vt4 != 0 && vt4 != g_senseei_master) ? 18.0 : 0.0;
   double resThreat = (resCode == 1) ? 10.0 : 0.0;
   g_senseei_threat = MathMax(0.0, MathMin(100.0,
      g_senseei_conflict * 0.40 +
      residual * 0.28 +
      timeConflict * 0.12 +
      pressureThreat +
      resThreat));

   // Confidence score
   double stackPct = g_fractalStackScore;
   g_senseei_confidence = MathMax(0.0, MathMin(100.0,
      g_senseei_alignment * 0.40 +
      timeAlign * 0.12 +
      stackPct * 0.18 +
      attractor * 0.15 +
      MathMin(15.0, castCount * 3.0) -
      g_senseei_threat * 0.20));

   // Timing
   int phase = g_se[TF_M5].phase;
   if(phase == 7 || resCode == 2)
      g_senseei_timing = "RESOLVED";
   else if(g_waveProgress < 15)
      g_senseei_timing = "VERY EARLY";
   else if(g_waveProgress < 35)
      g_senseei_timing = "EARLY";
   else if(g_waveProgress < 55)
      g_senseei_timing = "DEVELOPING";
   else if(g_waveProgress < 80)
      g_senseei_timing = "MID CYCLE";
   else if(g_waveProgress < 96)
      g_senseei_timing = "LATE";
   else
      g_senseei_timing = "TERMINAL";

   // Intent
   if(g_senseei_conflict > 55)
      g_senseei_intent = "ABSORPTION";
   else if(g_liqg_active)
      g_senseei_intent = "DELIVERY";
   else if(phase == 1)
      g_senseei_intent = "EXPANSION";
   else if(phase == 2)
      g_senseei_intent = "CONTINUATION";
   else if(phase == 3 || phase == 10)
      g_senseei_intent = "RESOLUTION";
   else if(phase == 4 || phase == 5 || phase == 6 || phase == 11)
      g_senseei_intent = "DELIVERY";
   else if(phase == 7)
      g_senseei_intent = "ABSORPTION";
   else if(g_senseei_master == 0)
      g_senseei_intent = "BALANCE";
   else
      g_senseei_intent = "CONTINUATION";

   // Opportunity score
   double oppScore = MathMax(0.0, MathMin(100.0,
      g_senseei_alignment * 0.40 +
      attractor * 0.30 +
      stackPct * 0.30 -
      g_senseei_threat * 0.35));
   g_senseei_opportunity = oppScore;

   // Opportunity label (for display)
   string opportunity = "NONE";
   if(g_senseei_master == 0)
      opportunity = "NONE";
   else if(g_senseei_conflict > 60)
      opportunity = "DEVELOPING";
   else if(oppScore < 20)
      opportunity = "NONE";
   else if(oppScore < 40)
      opportunity = "DEVELOPING";
   else if(oppScore < 62)
      opportunity = "GOOD";
   else if(oppScore < 82)
      opportunity = "STRONG";
   else
      opportunity = "EXCEPTIONAL";

   // Action state: ATTACK / PREPARE / MANAGE / WAIT
   if(g_senseei_master == 0)
      g_senseei_action = "WAIT";
   else if(g_senseei_conflict > 60)
      g_senseei_action = "WAIT";
   else if(resCode == 2)
      g_senseei_action = "MANAGE";
   else if((opportunity == "STRONG" || opportunity == "EXCEPTIONAL") &&
           g_senseei_confidence >= InpMinConf_Attack &&
           g_senseei_threat < 45)
      g_senseei_action = "ATTACK";
   else if(opportunity == "GOOD" || opportunity == "STRONG")
      g_senseei_action = "PREPARE";
   else
      g_senseei_action = "WAIT";
}


//==================================================================
// MASTER UPDATE: Call all intelligence engines in correct order
// Order: Physics -> EDE -> RE -> EAE -> Similarity -> ConvexityMat
//        -> WaveProgress -> Beliefs -> Hypothesis -> Prediction
//        -> LiquidationWave -> Senseei
//==================================================================
void Intel_UpdateAll()
{
   // 1. Physics Observation Layer (needs M5 data)
   Intel_UpdatePhysicsObservation();

   // 2. Energy Dissipation Engine (needs physics + phase)
   Intel_UpdateEDE();

   // 3. Resolution Engine (needs EDE)
   Intel_UpdateRE();

   // 4. Energy Attractor Engine (needs RE)
   Intel_UpdateEAE();

   // 5. Wave Intelligence Similarity (needs physics)
   Intel_UpdateSimilarity();

   // 6. Convexity Maturity (needs physics + obs scores)
   Intel_UpdateConvexityMaturity();

   // 7. Wave Progress (needs similarity + convexity maturity)
   Intel_UpdateWaveProgress();

   // 8. Belief Engine (needs all above)
   Intel_UpdateBeliefs();

   // 9. Hypothesis Engine (needs beliefs + similarity + maturity)
   Intel_UpdateHypothesis();

   // 10. Prediction Engine (needs beliefs + wave progress + hypothesis)
   Intel_UpdatePrediction();

   // 11. Liquidation Wave Overlay (needs EDE + RE + phase)
   Intel_UpdateLiquidationWave();

   // 12. Senseei Meta-Intelligence (needs all above + fractal stack)
   Intel_UpdateSenseei();
}

//==================================================================
// INITIALIZATION
//==================================================================
void Intel_Init()
{
   g_velocityScore      = 0.0;
   g_accelerationScore  = 0.0;
   g_convexityScore     = 0.0;
   g_obs_ExpansionScore = 0.0;
   g_obs_DecayScore     = 0.0;
   g_obs_CurvatureScore = 0.0;
   g_obs_AbsorptionScore= 0.0;
   g_obs_LiquidityScore = 0.0;
   g_physicsMax         = 0.0;
   g_physicsDiff        = 0.0;
   g_physicsConsensus   = 0.0;

   g_ede_state               = 1;
   g_ede_cleaningState       = "Accumulating";
   g_ede_expansionEnergy     = 0.0;
   g_ede_dissipatedEnergy    = 0.0;
   g_ede_dissipationProgress = 0.0;
   g_ede_messyPriceIsDissipation = false;

   g_re_expectedCycles          = 1;
   g_re_completedCycles         = 0;
   g_re_recursiveCompletionScore= 0.0;
   g_re_residualEnergy          = 0.0;
   g_re_objectiveReached        = false;
   g_re_fullDissipation         = false;
   g_re_resolutionState         = 0;
   g_re_residualEnergyScore     = 0.0;
   g_re_revisitProbability      = 0.0;

   g_eae_primaryAttractorPrice  = 0.0;
   g_eae_primaryAttractorScore  = 0.0;
   g_eae_primaryAttractorLabel  = "No Active Attractor";
   g_eae_energyState            = "Accumulating";
   g_erf_confidence             = 0.0;
   g_erf_activeDissipation      = false;
   g_erf_suppressRotation       = false;

   g_sim_Expansion    = 0.0;
   g_sim_PreConv      = 0.0;
   g_sim_Induction    = 0.0;
   g_sim_Liquidity    = 0.0;
   g_sim_Creation     = 0.0;
   g_sim_Absorption   = 0.0;
   g_sim_Retracement  = 0.0;
   g_sim_DemandReturn = 0.0;

   g_expWeaknessScore     = 0.0;
   g_inductionMatScore    = 0.0;
   g_liqMatScore          = 0.0;
   g_rawConvexityMaturity = 0.0;
   g_convexityMaturity    = 0.0;
   g_waveProgress         = 30.0;

   g_expansionBelief    = 0.0;
   g_convexityBelief    = 0.0;
   g_creationBelief     = 0.0;
   g_absorptionBelief   = 0.0;
   g_retracementBelief  = 0.0;
   g_demandReturnBelief = 0.0;

   g_hyp_LateExpansion      = 0.0;
   g_hyp_TerminalConvexity  = 0.0;
   g_hyp_CreationForming    = 0.0;
   g_hyp_AbsorptionActive   = 0.0;
   g_hyp_RetracementActive  = 0.0;
   g_hyp_DemandReturn       = 0.0;

   g_predScore_Expansion    = 0.0;
   g_predScore_Convexity    = 0.0;
   g_predScore_Creation     = 0.0;
   g_predScore_Absorption   = 0.0;
   g_predScore_Retracement  = 0.0;
   g_predScore_DemandReturn = 0.0;
   g_expectedNextPhase      = "Expansion";
   g_expectedNextProb       = 50.0;

   g_liqg_active    = false;
   g_liqg_isRetr    = false;
   g_liqg_dir       = 0;
   g_liqg_target    = 0.0;
   g_liqg_initDist  = 0.0;
   g_liqg_distPct   = 100.0;
   g_liqg_objArrival= false;
   g_liqg_trueCHoCH = false;
   g_liqg_subPhase  = "";

   g_senseei_master     = 0;
   g_senseei_alignment  = 50.0;
   g_senseei_conflict   = 0.0;
   g_senseei_threat     = 0.0;
   g_senseei_confidence = 0.0;
   g_senseei_timing     = "DEVELOPING";
   g_senseei_intent     = "BALANCE";
   g_senseei_opportunity= 0.0;
   g_senseei_action     = "WAIT";

   g_intel_waveDepth   = 0;
   g_intel_entryCycle  = 0;
   g_intel_lastDir     = 0;
   g_intel_recursiveComplete = false;
   g_intel_waveModelFit = 50.0;
}

//==================================================================
// HELPER: Get resolution state as string (for dashboard display)
//==================================================================
string Intel_ResolutionStr()
{
   switch(g_re_resolutionState)
   {
      case 0: return("UNRESOLVED");
      case 1: return("PARTIALLY RESOLVED");
      case 2: return("RESOLVED");
   }
   return("UNRESOLVED");
}

//==================================================================
// HELPER: Get EDE cleaning state description
//==================================================================
string Intel_CleaningStateStr()
{
   return(g_ede_cleaningState);
}

//==================================================================
// HELPER: Get Senseei action state
//==================================================================
string Intel_ActionStr()
{
   return(g_senseei_action);
}

//==================================================================
// HELPER: Get dominant belief name
//==================================================================
string Intel_DominantBelief()
{
   double maxB = g_expansionBelief;
   string name = "Expansion";

   if(g_convexityBelief > maxB)    { maxB = g_convexityBelief;    name = "Convexity"; }
   if(g_creationBelief > maxB)     { maxB = g_creationBelief;     name = "Creation"; }
   if(g_absorptionBelief > maxB)   { maxB = g_absorptionBelief;   name = "Absorption"; }
   if(g_retracementBelief > maxB)  { maxB = g_retracementBelief;  name = "Retracement"; }
   if(g_demandReturnBelief > maxB) { maxB = g_demandReturnBelief; name = "Demand Return"; }

   return(name);
}

//==================================================================
// HELPER: Get liquidation wave title (for display)
//==================================================================
string Intel_LiqWaveTitle()
{
   if(!g_liqg_active) return("");

   string title = "";
   int m5Dir = g_se[TF_M5].dir;

   if(g_liqg_isRetr && m5Dir == -1)
      title = "Pre-Supply Return Liquidation Wave";
   else if(g_liqg_isRetr)
      title = "Pre-Demand Return Liquidation Wave";
   else if(m5Dir == -1)
      title = "Pre-New Low Liquidation Wave";
   else
      title = "Pre-New High Liquidation Wave";

   if(g_liqg_subPhase != "")
      title += " - " + g_liqg_subPhase;

   return(title);
}
//+------------------------------------------------------------------+
