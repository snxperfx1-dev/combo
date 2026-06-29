//+------------------------------------------------------------------+
//| Part4_ERFBeliefIntelligence.mqh                                   |
//| MASTER ALGO - Energy Resolution Framework + Belief Intelligence   |
//| EDE (Energy Dissipation) + RE (Resolution) + EAE (Attractor)      |
//| Belief Engine (6 simultaneous beliefs) + Hypothesis + Prediction  |
//| + Validation + Adaptive Confidence + Direction Probability        |
//+------------------------------------------------------------------+
#property strict

//==================================================================
// ENERGY RESOLUTION FRAMEWORK (ERF)
//
// Architecture: Price -> EDE -> RE -> EAE -> Intelligence Engine
//
// FUNDAMENTAL MARKET AXIOM:
//   Market = Energy Generation System
//   Expansion       = Energy Creation
//   Pre-Convexity   = Initial Dissipation
//   Induction       = Secondary Dissipation
//   Liquidation     = Delivery Dissipation
//   Supply/Demand   = Potential Resolution Node
//   Zone Revisit    = Incomplete Resolution
//==================================================================

//--- Persistent ERF state
double g_erfExpansionEnergy = 0;
double g_erfDissipatedEnergy = 0;
double g_erfDissipationProgress = 0;
double g_erfResidualEnergy = 0;
double g_erfTradeReadiness = 0;
double g_erfConfidence = 0;
double g_erfPrimaryAttractorPrice = 0;
double g_erfPrimaryAttractorScore = 0;
double g_erfSecondaryAttractorPrice = 0;
string g_erfAttractorLabel = "No Active Attractor";

//--- Belief engine persistent state (EMA smoothed)
double g_beliefExpansion = 0;
double g_beliefConvexity = 0;
double g_beliefCreation = 0;
double g_beliefAbsorption = 0;
double g_beliefRetracement = 0;
double g_beliefDemandReturn = 0;

//--- Hypothesis engine
double g_hypLateExpansion = 0;
double g_hypTerminalConvexity = 0;
double g_hypCreationForming = 0;
double g_hypAbsorptionActive = 0;
double g_hypRetracementActive = 0;
double g_hypDemandReturn = 0;
string g_primaryHypothesis = "EXPANSION";

//--- Prediction engine
string g_expectedNextPhase = "Expansion";
double g_expectedNextProb = 50.0;

//--- Validation engine
int    g_predOutcomes[];
int    g_predTotalIdx = 0;
string g_lastExpectedPhase = "Point 4 Origin";
string g_lastIE1APhase = "Point 4 Origin";
double g_predReliability = 50.0;

//--- Adaptive confidence
double g_modelConfidence = 50.0;

//--- Direction probability (Bayesian)
double g_buyProb = 50.0;
double g_sellProb = 50.0;
double g_netEdge = 0;
string g_liveDirective = "NEUTRAL / WAIT";

//==================================================================
// 1. ENERGY DISSIPATION ENGINE (EDE)
// Answers: How is energy cleaning itself?
//==================================================================
void ComputeEDE()
{
   // State derived from M5 canonical phase
   ENUM_WAVE_PHASE phase = g_currentPhase;
   
   ENUM_EDE_STATE edeState;
   if(phase == PHASE_POINT4_ORIGIN || phase == PHASE_EXPANSION)
      edeState = EDE_ACCUMULATING;
   else if(phase == PHASE_EXP_PRECONVEXITY)
      edeState = EDE_RELEASE_INITIAL;
   else if(phase == PHASE_EXP_INDUCTION)
      edeState = EDE_RELEASE_SECONDARY;
   else if(phase == PHASE_EXP_LIQUIDITY)
      edeState = EDE_PURGE;
   else if(phase == PHASE_NEW_HIGH || phase == PHASE_NEW_LOW)
      edeState = EDE_DELIVERING;
   else
      edeState = EDE_RESOLVING;
   
   g_erf.edeState = edeState;
   
   // Expansion energy: proxy from physics during expansion
   g_erfExpansionEnergy = MathMin(
      g_obsExpansion * 0.50 +
      (g_physics.bullImpulse || g_physics.bearImpulse ? 30.0 : 0.0) +
      (g_efficiency * 20.0), 100.0);
   g_erf.expansionEnergy = g_erfExpansionEnergy;
   
   // Dissipated energy: accumulates through lifecycle
   g_erfDissipatedEnergy = MathMin(
      (edeState >= EDE_RELEASE_INITIAL ? g_obsDecay * 0.40 : 0.0) +
      (edeState >= EDE_RELEASE_SECONDARY ? g_obsCurvature * 0.30 : 0.0) +
      (edeState >= EDE_PURGE ? g_obsLiquidity * 0.30 : 0.0), 100.0);
   g_erf.dissipatedEnergy = g_erfDissipatedEnergy;
   
   // Dissipation progress 0-100
   g_erfDissipationProgress = MathMin(
      (edeState >= EDE_RELEASE_INITIAL ? 25.0 : 0.0) +
      (edeState >= EDE_RELEASE_SECONDARY ? 25.0 : 0.0) +
      (edeState >= EDE_PURGE ? 25.0 : 0.0) +
      (edeState >= EDE_DELIVERING ? 25.0 : 0.0), 100.0);
   g_erf.dissipationProgress = g_erfDissipationProgress;
}

//==================================================================
// 2. RESOLUTION ENGINE (RE)
// Answers: Did the process actually finish?
// Key axiom: Objective Hit != Process Complete
//==================================================================
void ComputeResolution()
{
   // Expected recursive cycles based on wave depth
   int expectedCycles = MathMax(1, MathMin(g_waveDepth + 2, 4));
   int completedCycles = MathMax(0, MathMin(g_entryCycle, expectedCycles));
   
   // Recursive completion score 0-100
   double recursiveCompletion = (expectedCycles > 0) ?
      MathMin((double)completedCycles / (double)expectedCycles * 100.0, 100.0) : 0.0;
   g_erf.recursiveCompletion = recursiveCompletion;
   
   // Residual energy
   g_erfResidualEnergy = MathMax(0.0, g_erfExpansionEnergy - g_erfDissipatedEnergy);
   g_erf.residualEnergy = g_erfResidualEnergy;
   
   // Resolution state determination
   bool objectiveReached = (g_erf.edeState >= EDE_DELIVERING);
   bool fullDissipation = (g_erfDissipationProgress >= 75.0);
   bool absorbedAndReturned = (g_currentPhase == PHASE_DEMAND_RETURN || 
                               g_currentPhase == PHASE_SUPPLY_RETURN) && g_recursiveComplete;
   
   if(absorbedAndReturned && fullDissipation && recursiveCompletion >= 75.0)
      g_erf.resolutionState = RES_RESOLVED;
   else if(objectiveReached && g_erfDissipationProgress >= 50.0)
      g_erf.resolutionState = RES_PARTIALLY_RESOLVED;
   else
      g_erf.resolutionState = RES_UNRESOLVED;
}

//==================================================================
// 3. ENERGY ATTRACTOR ENGINE (EAE)
// Answers: Where is unresolved energy pulling price?
// Principle: Price attracted to unresolved energy (not just liquidity)
//==================================================================
void ComputeEnergyAttractor()
{
   double atr = g_physics.atr;
   if(atr <= 0 || ArraySize(Close) < 2) return;
   double closeNow = Close[1];
   
   // Primary attractor: most significant unresolved energy node
   if(g_direction == 0)
   {
      g_erfPrimaryAttractorPrice = 0;
      g_erfPrimaryAttractorScore = 0;
      g_erfAttractorLabel = "No Active Attractor";
   }
   else if(g_erf.resolutionState == RES_UNRESOLVED)
   {
      g_erfPrimaryAttractorPrice = (g_direction == 1) ? 
         (g_flipBot > 0 ? g_flipBot : closeNow - atr * 2.0) :
         (g_flipTop > 0 ? g_flipTop : closeNow + atr * 2.0);
      g_erfAttractorLabel = "Flip Zone (High Residual)";
   }
   else if(g_erf.resolutionState == RES_PARTIALLY_RESOLVED)
   {
      g_erfPrimaryAttractorPrice = (g_direction == 1) ?
         (g_point4Low > 0 ? g_point4Low : closeNow - atr) :
         (g_point4High > 0 ? g_point4High : closeNow + atr);
      g_erfAttractorLabel = "Origin Zone (Partial)";
   }
   else
   {
      g_erfPrimaryAttractorPrice = 0;
      g_erfAttractorLabel = "No Active Attractor";
   }
   
   // Attractor scoring
   g_erfPrimaryAttractorScore = MathMin(
      g_erfResidualEnergy * 0.40 +
      (g_erf.resolutionState == RES_UNRESOLVED ? 30.0 :
       g_erf.resolutionState == RES_PARTIALLY_RESOLVED ? 20.0 : 5.0) +
      (g_erfPrimaryAttractorPrice > 0 ?
         MathMax(0.0, 30.0 - MathAbs(closeNow - g_erfPrimaryAttractorPrice) / MathMax(atr, 1e-10) * 5.0)
         : 0.0),
      100.0);
   
   g_erf.primaryAttractorPrice = g_erfPrimaryAttractorPrice;
   g_erf.primaryAttractorScore = g_erfPrimaryAttractorScore;
   
   // Secondary attractor
   if(g_direction != 0 && g_erf.resolutionState == RES_UNRESOLVED && g_inducZoneLow > 0)
      g_erfSecondaryAttractorPrice = (g_direction == 1) ? g_inducZoneLow : g_inducZoneHigh;
   else
      g_erfSecondaryAttractorPrice = 0;
}

//==================================================================
// 4. TRADE READINESS + ENTRY GATE
//==================================================================
void ComputeTradeReadiness()
{
   g_erfTradeReadiness = MathMin(
      (g_erf.resolutionState == RES_RESOLVED ? 40.0 :
       g_erf.resolutionState == RES_PARTIALLY_RESOLVED ? 25.0 : 10.0) +
      g_erf.recursiveCompletion * 0.25 +
      (100.0 - g_erfResidualEnergy) * 0.20 +
      g_erfConfidence * 0.15,
      100.0);
   g_erf.tradeReadiness = g_erfTradeReadiness;
   
   // Entry gate: single threshold
   g_erf.entryGateOpen = (!InpERFGateEnabled || g_erfTradeReadiness >= InpERFEntryThreshold);
}

//==================================================================
// 5. ERF CONFIDENCE
//==================================================================
void ComputeERFConfidence()
{
   g_erfConfidence = MathMin(
      (g_erf.edeState != EDE_ACCUMULATING ? g_phaseConfidence * 0.40 : 20.0) +
      (g_erf.resolutionState == RES_RESOLVED ? 30.0 :
       g_erf.resolutionState == RES_PARTIALLY_RESOLVED ? 20.0 : 10.0) +
      g_erfPrimaryAttractorScore * 0.30,
      100.0);
}

//==================================================================
// MASTER ERF UPDATE
//==================================================================
void UpdateERF()
{
   ComputeEDE();
   ComputeResolution();
   ComputeEnergyAttractor();
   ComputeERFConfidence();
   ComputeTradeReadiness();
}

//==================================================================
// 6. BELIEF ENGINE (from Letra Section 12A)
// Six simultaneous beliefs - EMA smoothed
//==================================================================
void ComputeBeliefs()
{
   double wp = g_waveProgress;
   
   //--- Expansion Belief
   double expPosMult = (wp < 40.0) ? 1.20 : (wp < 60.0) ? 0.80 : 0.50;
   double rawExp = MathMin(
      (g_obsExpansion * 0.45 +
       (g_physics.bullImpulse || g_physics.bearImpulse ? 30.0 : 0.0) +
       (g_efficiency > InpEffThresh * 1.1 ? 15.0 : 0.0) +
       g_simExpansion * 0.10) * expPosMult,
      100.0);
   
   //--- Convexity Belief
   double convPosMult = (wp >= 30.0 && wp <= 65.0) ? 1.30 : 0.70;
   double rawConv = MathMin(
      (g_obsDecay * 0.30 +
       g_obsCurvature * 0.25 +
       (g_preConvEvidence ? 15.0 : 0.0) +
       (g_inductionEvidence ? 10.0 : 0.0) +
       (g_liquidityEvidence ? 5.0 : 0.0) +
       g_convMaturitySmoothed * 0.08) * convPosMult,
      100.0);
   
   //--- Creation Belief
   double creatPosMult = (wp >= 45.0 && wp <= 68.0) ? 1.40 : 0.60;
   double distToCreation = 50.0; // simplified
   if(g_cycleHigh > 0 && g_direction == 1 && ArraySize(Close) > 1)
      distToCreation = MathMin(MathAbs(g_cycleHigh - Close[1]) / MathMax(g_physics.atr * 4.0, 1e-10) * 100.0, 100.0);
   else if(g_cycleLow > 0 && g_direction == -1 && ArraySize(Close) > 1)
      distToCreation = MathMin(MathAbs(Close[1] - g_cycleLow) / MathMax(g_physics.atr * 4.0, 1e-10) * 100.0, 100.0);
   
   double rawCreat = MathMin(
      ((g_convMaturitySmoothed > 50 ? g_convMaturitySmoothed * 0.12 : 0.0) +
       (g_obsDecay > 60 ? g_obsDecay * 0.20 : 0.0) +
       (g_obsLiquidity > 50 ? g_obsLiquidity * 0.20 : 0.0) +
       (g_obsAbsorption > 20 ? g_obsAbsorption * 0.15 : 0.0) +
       g_simCreation * 0.10 +
       (distToCreation < 15.0 ? (15.0 - distToCreation) * 1.0 : 0.0)) * creatPosMult,
      100.0);
   
   //--- Absorption Belief
   double rawAbs = MathMin(
      g_obsAbsorption * 0.50 +
      (g_efficiency < InpEffThresh * 0.6 ? 25.0 : 0.0) +
      (g_displacement < InpDispThresh * 0.5 ? 15.0 : 0.0) +
      g_simAbsorption * 0.10,
      100.0);
   
   //--- Retracement Belief
   double rawRetr = MathMin(
      ((g_direction == 1 && g_physics.bearImpulse) || (g_direction == -1 && g_physics.bullImpulse) ? 45.0 : 0.0) +
      (rawAbs > 50 ? rawAbs * 0.30 : 0.0) +
      (g_obsCurvature > 40 ? 15.0 : 0.0) +
      g_simRetracement * 0.10,
      100.0);
   
   //--- Demand Return Belief
   double rawDR = MathMin(
      (g_flipTop > 0 && g_flipBot > 0 && g_closeInside ? 35.0 : 0.0) +
      (rawRetr > 60 ? rawRetr * 0.30 : 0.0) +
      (g_liqHeat > 50 ? g_liqHeat * 0.15 : 0.0) +
      (g_liqSweepOK ? 20.0 : 0.0) +
      g_simDemandReturn * 0.10,
      100.0);
   
   // EMA smooth all beliefs
   g_beliefExpansion = SmoothEMA(g_beliefExpansion, rawExp, InpBeliefSmooth);
   g_beliefConvexity = SmoothEMA(g_beliefConvexity, rawConv, InpBeliefSmooth);
   g_beliefCreation = SmoothEMA(g_beliefCreation, rawCreat, InpBeliefSmooth);
   g_beliefAbsorption = SmoothEMA(g_beliefAbsorption, rawAbs, InpBeliefSmooth);
   g_beliefRetracement = SmoothEMA(g_beliefRetracement, rawRetr, InpBeliefSmooth);
   g_beliefDemandReturn = SmoothEMA(g_beliefDemandReturn, rawDR, InpBeliefSmooth);
   
   // Store in struct
   g_beliefs.expansion = Clamp(g_beliefExpansion, 0, 100);
   g_beliefs.convexity = Clamp(g_beliefConvexity, 0, 100);
   g_beliefs.creation = Clamp(g_beliefCreation, 0, 100);
   g_beliefs.absorption = Clamp(g_beliefAbsorption, 0, 100);
   g_beliefs.retracement = Clamp(g_beliefRetracement, 0, 100);
   g_beliefs.demandReturn = Clamp(g_beliefDemandReturn, 0, 100);
}

//==================================================================
// 7. HYPOTHESIS ENGINE (from Letra Section 12D)
//==================================================================
void ComputeHypothesis()
{
   double fitMult = MathMax(0.60, g_waveModelFitSmoothed / 100.0);
   double wp = g_waveProgress;
   
   // Late Expansion
   g_hypLateExpansion = (
      g_beliefExpansion * 0.35 +
      (wp < 38.0 ? (38.0 - wp) * 0.80 : 0.0) +
      (g_convMaturitySmoothed < 30 ? (30.0 - g_convMaturitySmoothed) * 0.30 : 0.0) +
      g_simExpansion * 0.20) * fitMult;
   
   // Terminal Convexity
   g_hypTerminalConvexity = (
      g_beliefConvexity * 0.30 +
      (g_convMaturitySmoothed > 50 ? g_convMaturitySmoothed * 0.25 : 0.0) +
      (wp >= 38.0 && wp <= 62.0 ? 20.0 : 0.0) +
      (g_simInduction + g_simLiquidity) * 0.10) * fitMult;
   
   // Creation Forming
   g_hypCreationForming = (
      g_beliefCreation * 0.40 +
      (g_convMaturitySmoothed > 65 ? (g_convMaturitySmoothed - 65.0) * 0.40 : 0.0) +
      g_simCreation * 0.20) * fitMult;
   
   // Absorption Active
   g_hypAbsorptionActive = (
      g_beliefAbsorption * 0.45 +
      (wp >= 68.0 && wp <= 80.0 ? 20.0 : 0.0) +
      g_simAbsorption * 0.25) * fitMult;
   
   // Retracement Active
   g_hypRetracementActive = (
      g_beliefRetracement * 0.45 +
      (wp >= 78.0 && wp <= 92.0 ? 20.0 : 0.0) +
      g_simRetracement * 0.25) * fitMult;
   
   // Demand Return
   g_hypDemandReturn = (
      g_beliefDemandReturn * 0.45 +
      (wp >= 88.0 ? (wp - 88.0) * 1.20 : 0.0) +
      g_simDemandReturn * 0.25 +
      (g_closeInside ? 15.0 : 0.0)) * fitMult;
   
   // Primary hypothesis = Engine 1A family (display only)
   ENUM_WAVE_PHASE ph = g_currentPhase;
   if(ph == PHASE_EXPANSION)
      g_primaryHypothesis = "EXPANSION";
   else if(ph == PHASE_EXP_PRECONVEXITY || ph == PHASE_EXP_INDUCTION || ph == PHASE_EXP_LIQUIDITY)
      g_primaryHypothesis = "CONVEXITY FORMING";
   else if(ph == PHASE_NEW_HIGH || ph == PHASE_NEW_LOW)
      g_primaryHypothesis = "CREATION FORMING";
   else if(ph == PHASE_ABSORPTION)
      g_primaryHypothesis = "ABSORPTION";
   else if(ph == PHASE_RETRACEMENT || ph == PHASE_RETR_PRECONVEXITY || 
           ph == PHASE_RETR_INDUCTION || ph == PHASE_RETR_LIQUIDITY)
      g_primaryHypothesis = "RETRACEMENT";
   else if(ph == PHASE_DEMAND_RETURN || ph == PHASE_SUPPLY_RETURN)
      g_primaryHypothesis = "DEMAND/SUPPLY RETURN";
   else
      g_primaryHypothesis = "EXPANSION";
}

//==================================================================
// 8. PREDICTION ENGINE (from Letra Section 12E)
//==================================================================
void ComputePrediction()
{
   double predExp = (g_waveProgress < 35.0 ? (35.0 - g_waveProgress) * 1.0 : 0.0) +
      (g_beliefExpansion > 55 ? g_beliefExpansion * 0.30 : 0.0) +
      (g_convMaturitySmoothed < 25 ? 20.0 : 0.0);
   
   double predConv = (g_waveProgress >= 25.0 && g_waveProgress <= 60.0 ? 30.0 : 0.0) +
      (g_convMaturitySmoothed > 20 ? g_convMaturitySmoothed * 0.30 : 0.0) +
      (g_obsDecay > 40 ? 20.0 : 0.0) +
      (g_preConvEvidence ? 15.0 : 0.0);
   
   double predCreat = (g_convMaturitySmoothed > 55 ? (g_convMaturitySmoothed - 55.0) * 1.20 : 0.0) +
      (g_obsLiquidity > 55 ? 20.0 : 0.0) +
      (g_liqSweepOK ? 15.0 : 0.0);
   
   double predAbs = (predCreat > 50 ? predCreat * 0.40 : 0.0) +
      (g_obsAbsorption > 35 ? g_obsAbsorption * 0.30 : 0.0) +
      (g_waveProgress >= 60.0 && g_waveProgress <= 78.0 ? 15.0 : 0.0);
   
   double predRetr = (g_beliefAbsorption > 45 ? g_beliefAbsorption * 0.35 : 0.0) +
      ((g_direction == 1 && g_physics.bearImpulse) || (g_direction == -1 && g_physics.bullImpulse) ? 25.0 : 0.0) +
      (g_waveProgress >= 72.0 && g_waveProgress <= 90.0 ? 20.0 : 0.0);
   
   double predDR = (g_beliefRetracement > 45 ? g_beliefRetracement * 0.35 : 0.0) +
      (g_liqSweepOK ? 20.0 : 0.0) +
      (g_waveProgress >= 88.0 ? (g_waveProgress - 88.0) * 1.20 : 0.0);
   
   // Find max prediction
   double maxPred = MathMax(predExp, MathMax(predConv, MathMax(predCreat,
                    MathMax(predAbs, MathMax(predRetr, predDR)))));
   
   if(predDR >= maxPred - 0.1)
      g_expectedNextPhase = (g_direction == -1) ? "Supply Return" : "Demand Return";
   else if(predRetr >= maxPred - 0.1)
      g_expectedNextPhase = "Retracement";
   else if(predAbs >= maxPred - 0.1)
      g_expectedNextPhase = "Absorption";
   else if(predCreat >= maxPred - 0.1)
      g_expectedNextPhase = (g_direction == -1) ? "New Low" : "New High";
   else if(predConv >= maxPred - 0.1)
      g_expectedNextPhase = "Expansion Pre-Convexity";
   else
      g_expectedNextPhase = "Expansion";
   
   g_expectedNextProb = (maxPred > 0) ? MathMin(maxPred / MathMax(maxPred + 30.0, 1.0) * 100.0, 95.0) : 50.0;
}

//==================================================================
// 9. VALIDATION ENGINE (from Letra Section 12F)
// Tracks prediction accuracy over rolling window
//==================================================================
void InitValidationEngine()
{
   ArrayResize(g_predOutcomes, 100);
   ArrayFill(g_predOutcomes, 0, 100, 0);
   g_predTotalIdx = 0;
}

void UpdateValidation()
{
   string currentIE1A = g_currentDisplayPhase;
   
   // Check if phase transitioned
   bool transition = (currentIE1A != g_lastIE1APhase);
   bool succeeded = (transition && currentIE1A == g_lastExpectedPhase);
   
   if(transition)
   {
      g_predOutcomes[g_predTotalIdx % 100] = succeeded ? 1 : 0;
      g_predTotalIdx++;
   }
   
   g_lastExpectedPhase = g_expectedNextPhase;
   g_lastIE1APhase = currentIE1A;
   
   // Compute rolling accuracy
   int cnt = MathMin(25, g_predTotalIdx);
   int sum = 0;
   int start = MathMax(0, g_predTotalIdx - cnt);
   for(int i = start; i < g_predTotalIdx; i++)
      sum += g_predOutcomes[i % 100];
   
   g_predReliability = (cnt > 0) ? (double)sum / (double)cnt * 100.0 : 50.0;
}

//==================================================================
// 10. ADAPTIVE CONFIDENCE ENGINE (from Letra Section 12G)
//==================================================================
void UpdateAdaptiveConfidence()
{
   string currentIE1A = g_currentDisplayPhase;
   bool transition = (currentIE1A != g_lastIE1APhase);
   bool succeeded = (transition && currentIE1A == g_lastExpectedPhase);
   
   double confIncrease = 
      (succeeded ? 3.0 : 0.0) +
      (g_obs.physicsConsensus > 70 ? 2.0 : 0.0) +
      (g_fractalStack.direction == g_direction && g_direction != 0 ? 1.5 : 0.0);
   
   double confDecrease =
      (transition && !succeeded ? 2.0 : 0.0) +
      ((g_obs.expansionScore - g_obs.absorptionScore) > 60 ? 2.0 : 0.0) +
      (g_fractalStack.direction != g_direction && g_direction != 0 ? 1.5 : 0.0);
   
   double decayRate = 0.02;
   g_modelConfidence = Clamp(
      g_modelConfidence + confIncrease - confDecrease - decayRate * (g_modelConfidence - 50.0),
      10.0, 100.0);
}

//==================================================================
// 11. DIRECTION PROBABILITY (Bayesian model from Letra Section 16)
//==================================================================
void ComputeDirectionProbability()
{
   if(ArraySize(Close) < 2) return;
   
   int waveDir = g_structure[TF_M5].direction;
   int htfAlign = (g_structure[TF_H1].direction == g_structure[TF_H4].direction && 
                   g_structure[TF_H1].direction != 0) ? g_structure[TF_H1].direction : 0;
   int structBias = g_fractalStack.direction;
   
   // Bayesian factors
   double bayesStruct = (structBias == waveDir) ? 0.90 : (structBias == 0) ? 0.50 : 0.15;
   
   double bayesMomentum = 0.50;
   if((waveDir == 1 && g_velocity > 0 && g_acceleration > 0) ||
      (waveDir == -1 && g_velocity < 0 && g_acceleration < 0))
      bayesMomentum = 0.85;
   else if((waveDir == 1 && g_velocity > 0) || (waveDir == -1 && g_velocity < 0))
      bayesMomentum = 0.60;
   else
      bayesMomentum = 0.30;
   
   double bayesLiq = (g_liqHeat > 70) ? 0.80 : (g_liqHeat > 30) ? 0.55 : 0.35;
   double bayesHTF = (htfAlign == waveDir && htfAlign != 0) ? 0.90 : (htfAlign == 0) ? 0.55 : 0.20;
   double bayesDisp = (g_displacement > InpDispThresh * 1.5) ? 0.85 : 
                      (g_displacement > InpDispThresh) ? 0.65 : 0.35;
   
   double bayesFlipzone = 0.25;
   if(g_currentPhase == PHASE_DEMAND_RETURN || g_currentPhase == PHASE_SUPPLY_RETURN)
      bayesFlipzone = 0.92;
   else if(g_currentPhase == PHASE_RETRACEMENT || g_currentPhase == PHASE_RETR_PRECONVEXITY)
      bayesFlipzone = 0.75;
   else if(g_waveProgress >= 60)
      bayesFlipzone = 0.58;
   
   // Weights
   double w1=0.15, w2=0.14, w3=0.10, w4=0.14, w5=0.11, w6=0.17;
   
   // Log-odds computation
   double logOdds =
      w1 * MathLog(MathMax(bayesStruct, 1e-10) / MathMax(1.0 - bayesStruct, 1e-10)) +
      w2 * MathLog(MathMax(bayesMomentum, 1e-10) / MathMax(1.0 - bayesMomentum, 1e-10)) +
      w3 * MathLog(MathMax(bayesLiq, 1e-10) / MathMax(1.0 - bayesLiq, 1e-10)) +
      w4 * MathLog(MathMax(bayesHTF, 1e-10) / MathMax(1.0 - bayesHTF, 1e-10)) +
      w5 * MathLog(MathMax(bayesDisp, 1e-10) / MathMax(1.0 - bayesDisp, 1e-10)) +
      w6 * MathLog(MathMax(bayesFlipzone, 1e-10) / MathMax(1.0 - bayesFlipzone, 1e-10));
   
   double finalProb = 1.0 / (1.0 + MathExp(-logOdds)) * 100.0;
   
   // Compute buy/sell scores incorporating fractal context
   double confMult = MathMax(0.7, MathMin(g_modelConfidence / 100.0 * 1.3, 1.3));
   double fracBonus = g_fractalStack.contextScore * 0.30;
   
   double baseTrend = g_efficiency * 30;
   double impulseS = (g_displacement > InpDispThresh) ? 20 : 0;
   double momentumS = (g_momentum > 0) ? 10 : -10;
   double structS = (structBias == 1) ? 20 : (structBias == -1) ? -20 : 0;
   double htfS = (htfAlign == 1) ? 20 : (htfAlign == -1) ? -20 : 0;
   double zoneS = g_closeInside ? 15 : 0;
   double beliefBonus = (g_beliefDemandReturn > 60) ? g_beliefDemandReturn * 0.10 : 0;
   
   g_buyProb = MathMin(MathMax(
      (baseTrend + impulseS + MathMax(momentumS, 0.0) + MathMax(structS, 0.0) + 
       MathMax(htfS, 0.0) + zoneS + beliefBonus +
       (g_fractalStack.direction == 1 ? fracBonus : 0.0)) * confMult,
      0.0), 100.0);
   
   g_sellProb = MathMin(MathMax(
      (baseTrend + impulseS + MathMax(-momentumS, 0.0) + MathMax(-structS, 0.0) +
       MathMax(-htfS, 0.0) + zoneS + beliefBonus +
       (g_fractalStack.direction == -1 ? fracBonus : 0.0)) * confMult,
      0.0), 100.0);
   
   g_netEdge = g_buyProb - g_sellProb;
   
   // Live directive
   if(g_netEdge > 25)
      g_liveDirective = "BUY PRESSURE";
   else if(g_netEdge > 10)
      g_liveDirective = "BULLISH BIAS";
   else if(g_netEdge < -25)
      g_liveDirective = "SELL PRESSURE";
   else if(g_netEdge < -10)
      g_liveDirective = "BEARISH BIAS";
   else
      g_liveDirective = "NEUTRAL / WAIT";
}

//==================================================================
// 12. EXECUTION PROBABILITY V2 (from Letra P3-10)
// Multi-TF consensus-aware, direction/conflict-aware
//==================================================================
struct ExecProbabilities
{
   double continuation;
   double reversal;
   double expansion;
   double creation;
   double absorption;
   double standDown;
   string directive;
};

ExecProbabilities g_execProb;

void ComputeExecutionProbability()
{
   // HTF bias = H1 + H4
   int htfSum = g_structure[TF_H1].direction + g_structure[TF_H4].direction;
   int htfBias = (htfSum > 0) ? 1 : (htfSum < 0) ? -1 : 0;
   
   // LTF bias = M1 + M3 + M5
   int ltfSum = g_structure[TF_M1].direction + g_structure[TF_M3].direction + g_structure[TF_M5].direction;
   int ltfBias = (ltfSum > 0) ? 1 : (ltfSum < 0) ? -1 : 0;
   
   bool aligned = (htfBias != 0 && ltfBias == htfBias);
   bool conflict = (htfBias != 0 && ltfBias == -htfBias);
   double consensus = g_fractalStack.score;
   
   // Continuation
   g_execProb.continuation = Clamp(
      (aligned ? 40.0 : 0.0) +
      (aligned && g_structure[TF_H1].phase == PHASE_EXPANSION ? 20.0 : 0.0) +
      (consensus * 0.25) -
      (conflict ? 55.0 : 0.0),
      0.0, 100.0);
   
   // Reversal
   g_execProb.reversal = MathMin(
      (conflict ? 35.0 : 0.0) +
      (g_convMaturitySmoothed > 60 ? g_convMaturitySmoothed * 0.15 : 0.0) +
      (g_obsAbsorption > 40 ? 15.0 : 0.0),
      100.0);
   
   // Expansion
   g_execProb.expansion = MathMin(
      (aligned ? consensus * 0.25 : 0.0) +
      (aligned && g_obsExpansion > 60 ? 35.0 : 0.0) +
      (g_liqSweepOK ? 15.0 : 0.0),
      100.0);
   
   // Creation
   g_execProb.creation = MathMin(
      (g_beliefCreation > 50 ? g_beliefCreation * 0.45 : 0.0) +
      (g_convMaturitySmoothed > 65 ? 20.0 : 0.0),
      100.0);
   
   // Absorption
   g_execProb.absorption = MathMin(
      (g_beliefAbsorption > 40 ? g_beliefAbsorption * 0.45 : 0.0) +
      (conflict ? 15.0 : 0.0) +
      (g_obsAbsorption > 50 ? 20.0 : 0.0),
      100.0);
   
   // Stand Down
   g_execProb.standDown = MathMin(
      (htfBias == 0 ? 30.0 : 0.0) +
      (g_fractalStack.direction == 0 ? 25.0 : 0.0) +
      (g_obs.physicsConsensus < 30 ? 20.0 : 0.0),
      100.0);
   
   // Directive
   double maxProb = MathMax(g_execProb.continuation, MathMax(g_execProb.reversal,
                    MathMax(g_execProb.expansion, MathMax(g_execProb.creation,
                    MathMax(g_execProb.absorption, g_execProb.standDown)))));
   
   if(g_execProb.standDown >= 55)
      g_execProb.directive = "STAND DOWN";
   else if(conflict && g_execProb.reversal >= 45)
      g_execProb.directive = "TRANSITION";
   else if(g_execProb.absorption >= maxProb - 0.1)
      g_execProb.directive = "ABSORPTION - PREPARE REVERSAL";
   else if(g_execProb.reversal >= maxProb - 0.1)
      g_execProb.directive = "REVERSAL DOMINANT";
   else if(g_execProb.creation >= maxProb - 0.1)
      g_execProb.directive = "NEW HIGH/LOW FORMING";
   else if(g_execProb.expansion >= maxProb - 0.1)
      g_execProb.directive = "EXPANSION ENTRY";
   else if(g_execProb.continuation >= maxProb - 0.1)
      g_execProb.directive = "CONTINUATION - HOLD";
   else
      g_execProb.directive = "AWAIT ALIGNMENT";
}

//==================================================================
// MASTER BELIEF/INTELLIGENCE UPDATE
//==================================================================
void UpdateBeliefIntelligence()
{
   // 1. Belief engine (6 simultaneous)
   ComputeBeliefs();
   
   // 2. Hypothesis engine
   ComputeHypothesis();
   
   // 3. Prediction engine
   ComputePrediction();
   
   // 4. Validation engine
   UpdateValidation();
   
   // 5. Adaptive confidence
   UpdateAdaptiveConfidence();
   
   // 6. Direction probability (Bayesian)
   ComputeDirectionProbability();
   
   // 7. Execution probability V2
   ComputeExecutionProbability();
}

//+------------------------------------------------------------------+
