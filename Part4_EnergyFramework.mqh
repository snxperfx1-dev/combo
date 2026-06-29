//+------------------------------------------------------------------+
//| Part4_EnergyFramework.mqh - Energy Resolution Framework          |
//|                  EDE + RE + EAE + Wave Intelligence System       |
//|                  Ported from Letra 37 Sections 10-12             |
//| Master MT5 EA: Symphony + Letra + F16 Combined System           |
//+------------------------------------------------------------------+
#property strict

//==================================================================
// 0. PERSISTENT STATE FOR ENERGY FRAMEWORK
//==================================================================

struct EnergyPersistState
{
   double   prevWaveProgress;
   double   prevConvexityMaturity;
   double   prevBeliefs[6];
   double   prevModelConfidence;
   int      predOutcomes[100];
   int      predTotalIdx;
   int      lastExpectedPhase;
   int      lastIE1APhase;
   bool     liqg_active;
   bool     liqg_isRetr;
   int      liqg_dir;
   double   liqg_target;
   double   liqg_initDist;
   bool     liqg_absorbUnlocked;
};

EnergyPersistState g_energyState;

//==================================================================
// 1. PHYSICS OBSERVATION LAYER
//    Produces 5 observation scores [0-100] from physics primitives
//    obsScores[0] = ExpansionScore
//    obsScores[1] = DecayScore
//    obsScores[2] = CurvatureScore
//    obsScores[3] = AbsorptionScore
//    obsScores[4] = LiquidityScore
//==================================================================

void ComputePhysicsObservationLayer(LetraPhysicsOutput &phys, double atr,
                                    double &obsScores[])
{
   ArrayResize(obsScores, 5);

   double eff  = phys.efficiency;
   double disp = phys.displacement;
   double vel  = phys.velocity;
   double acc  = phys.acceleration;
   bool   momDecay = phys.bullMomDecay || phys.bearMomDecay;

   // Intermediate scores
   double velocityScore = 0.0;
   if(atr * 0.1 > 1e-10)
      velocityScore = MathMin(MathAbs(vel) / (atr * 0.1) * 50.0, 100.0);

   double convexityScore = 0.0;
   if(atr * InpConvMult > 1e-10)
      convexityScore = MathMin(MathAbs(phys.convSmooth) / (atr * InpConvMult) * 25.0, 100.0);

   //--- obsScores[0] = ExpansionScore
   double velBonus = 0.0;
   if((vel > 0 && acc > 0) || (vel < 0 && acc < 0))
      velBonus = velocityScore * 0.2;

   double effComp = (eff > InpEffThresh) ? eff * 60.0 : eff * 30.0;
   double dispComp = 0.0;
   if(disp > InpDispThresh && InpDispThresh > 1e-10)
      dispComp = (disp / InpDispThresh - 1.0) * 20.0;

   obsScores[0] = MathMin(effComp + dispComp + velBonus, 100.0);

   //--- obsScores[1] = DecayScore
   double decayVal = 0.0;
   if(momDecay) decayVal += 40.0;
   if(convexityScore > 30.0) decayVal += convexityScore * 0.5;
   if(phys.vd70) decayVal += 30.0;
   obsScores[1] = MathMin(decayVal, 100.0);

   //--- obsScores[2] = CurvatureScore (same as convexityScore)
   obsScores[2] = convexityScore;

   //--- obsScores[3] = AbsorptionScore
   double absVal = 0.0;
   if(eff < InpEffThresh * 0.7 && InpEffThresh > 1e-10)
      absVal += (1.0 - eff / InpEffThresh) * 50.0;
   if(phys.vd50) absVal += 30.0;
   if(disp < InpDispThresh * 0.5) absVal += 20.0;
   obsScores[3] = MathMin(absVal, 100.0);

   //--- obsScores[4] = LiquidityScore
   double liqVal = obsScores[1] * 0.4 + obsScores[2] * 0.4;
   if(disp > InpDispThresh * 1.2 && momDecay)
      liqVal += 20.0;
   obsScores[4] = MathMin(liqVal, 100.0);
}

//==================================================================
// 2. ENERGY DISSIPATION ENGINE (EDE)
//    Maps canonical phase to energy state, tracks expansion/dissipation
//==================================================================

void ComputeEnergyDissipation(int canonicalPhase, double &obsScores[],
                              bool hasImpulse, double efficiency)
{
   // Map canonical phase to EDE state (1-6)
   // State 1: Energy Accumulation (Point 4 Origin / Expansion)
   // State 2: Energy Release 1 (Pre-Convexity)
   // State 3: Energy Release 2 (Induction)
   // State 4: Energy Purge (Liquidity)
   // State 5: Objective Delivery (New High/Low)
   // State 6: Resolution Assessment (Absorption onward)
   int state = 6;
   switch(canonicalPhase)
   {
      case 0:  state = 1; break;  // Point 4 Origin
      case 1:  state = 1; break;  // Expansion
      case 2:  state = 2; break;  // Expansion Pre-Convexity
      case 3:  state = 3; break;  // Expansion Induction
      case 4:  state = 4; break;  // Expansion Liquidity
      case 5:  state = 5; break;  // New High
      case 6:  state = 5; break;  // New Low
      default: state = 6; break;  // Absorption, Retracement, etc.
   }
   g_energy.ede_state = state;

   // Expansion energy: physics score during expansion
   double expEnergy = obsScores[0] * 0.50 +
                      (hasImpulse ? 30.0 : 0.0) +
                      efficiency * 20.0;
   g_energy.ede_expansionEnergy = MathMin(expEnergy, 100.0);

   // Dissipated energy: accumulates through pre-conv, induction, liquidation
   double dissEnergy = 0.0;
   if(state >= 2) dissEnergy += obsScores[1] * 0.40;
   if(state >= 3) dissEnergy += obsScores[2] * 0.30;
   if(state >= 4) dissEnergy += obsScores[4] * 0.30;
   g_energy.ede_dissipatedEnergy = MathMin(dissEnergy, 100.0);

   // Dissipation progress 0-100 (25 per phase stage reached)
   double dissProgress = 0.0;
   if(state >= 2) dissProgress += 25.0;
   if(state >= 3) dissProgress += 25.0;
   if(state >= 4) dissProgress += 25.0;
   if(state >= 5) dissProgress += 25.0;
   g_energy.ede_dissipationProgress = MathMin(dissProgress, 100.0);
}

//==================================================================
// 3. RESOLUTION ENGINE (RE)
//    Determines if the energy process completed
//==================================================================

void ComputeResolutionEngine()
{
   // Expected recursive cycles based on wave depth
   int expectedCycles = (int)MathMax(1, MathMin(g_spawn.waveDepth + 2, 4));

   // Completed cycles = entryCycle capped at expected
   int completedCycles = (int)MathMax(0, MathMin(g_spawn.entryCycle, expectedCycles));

   // Recursive completion score 0-100
   double recursiveCompletion = 0.0;
   if(expectedCycles > 0)
      recursiveCompletion = MathMin((double)completedCycles / (double)expectedCycles * 100.0, 100.0);
   g_energy.re_recursiveCompletionScore = recursiveCompletion;

   // Residual energy = expansion - dissipated
   double residualEnergy = MathMax(0.0, g_energy.ede_expansionEnergy - g_energy.ede_dissipatedEnergy);
   g_energy.re_residualEnergyScore = MathMin(residualEnergy, 100.0);

   // Resolution state determination
   // Check if in Demand/Supply Return phase
   int phase = g_letra[2].phase;
   bool inReturnPhase = (phase == 13 || phase == 14);
   bool recursiveComplete = g_spawn.recursiveComplete;
   bool fullDissipation = (g_energy.ede_dissipationProgress >= 75.0);
   bool objectiveReached = (g_energy.ede_state >= 5);
   double dissProgress = g_energy.ede_dissipationProgress;

   if(inReturnPhase && recursiveComplete && fullDissipation && recursiveCompletion >= 75.0)
      g_energy.re_resolutionState = 2;  // RESOLVED
   else if(objectiveReached && dissProgress >= 50.0)
      g_energy.re_resolutionState = 1;  // PARTIALLY RESOLVED
   else
      g_energy.re_resolutionState = 0;  // UNRESOLVED
}

//==================================================================
// 4. ENERGY ATTRACTOR ENGINE (EAE)
//    Computes where unresolved energy pulls price
//==================================================================

void ComputeEnergyAttractor(double closePrice, double atr)
{
   int direction = g_spawn.direction;

   // No attractor if no active wave
   if(direction == 0)
   {
      g_energy.eae_primaryAttractorPrice = 0.0;
      g_energy.eae_primaryAttractorScore = 0.0;
      return;
   }

   double attractorPrice = 0.0;

   if(g_energy.re_resolutionState == 0)  // UNRESOLVED
   {
      // Primary attractor is the flipzone
      if(direction == 1)
         attractorPrice = (g_spawn.flipBot > 0.0) ? g_spawn.flipBot : closePrice - atr * 2.0;
      else
         attractorPrice = (g_spawn.flipTop > 0.0) ? g_spawn.flipTop : closePrice + atr * 2.0;
   }
   else if(g_energy.re_resolutionState == 1)  // PARTIALLY RESOLVED
   {
      // Secondary attractor is the point4 origin
      if(direction == 1)
         attractorPrice = (g_spawn.point4OriginLow > 0.0) ? g_spawn.point4OriginLow : closePrice - atr;
      else
         attractorPrice = (g_spawn.point4OriginHigh > 0.0) ? g_spawn.point4OriginHigh : closePrice + atr;
   }
   else  // RESOLVED
   {
      attractorPrice = 0.0;
   }

   g_energy.eae_primaryAttractorPrice = attractorPrice;

   // Attractor scoring: weighted by residual energy + resolution state + distance
   double resBonus = 0.0;
   if(g_energy.re_resolutionState == 0) resBonus = 30.0;
   else if(g_energy.re_resolutionState == 1) resBonus = 20.0;
   else resBonus = 5.0;

   double distBonus = 0.0;
   if(attractorPrice > 0.0 && atr > 1e-10)
      distBonus = MathMax(0.0, 30.0 - MathAbs(closePrice - attractorPrice) / atr * 5.0);

   double score = g_energy.re_residualEnergyScore * 0.40 + resBonus + distBonus;
   g_energy.eae_primaryAttractorScore = MathMin(score, 100.0);
}

//==================================================================
// 5. CONVEXITY MATURITY ENGINE
//    Tracks how mature the convexity development is
//==================================================================

void ComputeConvexityMaturity(LetraPhysicsOutput &phys, double &obsScores[],
                              double closePrice, double atr)
{
   double eff  = phys.efficiency;
   double disp = phys.displacement;
   double vel  = phys.velocity;
   bool   momDecay = phys.bullMomDecay || phys.bearMomDecay;
   int    direction = g_spawn.direction;

   // Expansion Weakness Score
   double expWeak = 0.0;
   if(eff < InpEffThresh && InpEffThresh > 1e-10)
      expWeak += (1.0 - eff / InpEffThresh) * 40.0;
   expWeak += obsScores[1] * 0.30;
   if(MathAbs(vel) < MathAbs(phys.velocity) * 0.6)
      expWeak += 20.0;  // velocity decay proxy
   expWeak = MathMin(expWeak * (100.0 / 90.0), 100.0);

   // Induction Maturity Score
   bool inductionEvidence = false;
   if(direction == 1 && phys.bearImpulse) inductionEvidence = true;
   if(direction == -1 && phys.bullImpulse) inductionEvidence = true;

   double indMat = 0.0;
   if(inductionEvidence) indMat += 35.0;
   indMat += obsScores[2] * 0.35;
   if(momDecay) indMat += 20.0;
   if(disp > InpDispThresh * 1.2 && momDecay) indMat += 10.0;
   indMat = MathMin(indMat, 100.0);

   // Liquidity Maturity Score (simplified: liqHeat uses default 50)
   double liqHeat = 50.0;  // Default until Part5 provides full heatmap
   double liqMat = 0.0;
   liqMat += obsScores[4] * 0.50;
   // liqSweep approximation: price near flipzone
   bool liqSweep = false;
   if(g_spawn.flipTop > 0.0 && g_spawn.flipBot > 0.0)
   {
      if(closePrice >= g_spawn.flipBot && closePrice <= g_spawn.flipTop)
         liqSweep = true;
   }
   if(liqSweep) liqMat += 30.0;
   if(liqHeat > 60.0) liqMat += 20.0;
   else if(liqHeat > 30.0) liqMat += 10.0;
   liqMat = MathMin(liqMat, 100.0);

   // Raw convexity maturity
   double rawCM = expWeak * 0.35 + indMat * 0.35 + liqMat * 0.30;
   rawCM = MathMin(rawCM, 100.0);

   // EMA smooth
   g_energyState.prevConvexityMaturity = EmaSmooth(g_energyState.prevConvexityMaturity, rawCM, InpBeliefSmooth);
   g_energy.convexityMaturity = Clamp(g_energyState.prevConvexityMaturity, 0.0, 100.0);
}

//==================================================================
// 6. WAVE PROGRESS ESTIMATION
//    Geometric + physics progress combined
//==================================================================

void ComputeWaveProgress(double closePrice, double atr, double &obsScores[])
{
   int direction = g_spawn.direction;
   double convexityMaturity = g_energy.convexityMaturity;

   //--- Geometric progress: from origin -> extreme -> flipzone midpoint
   double geomProgress = 30.0;  // default
   if(g_spawn.point4OriginHigh > 0.0 && g_spawn.flipTop > 0.0 && g_spawn.flipBot > 0.0)
   {
      double origin = (direction == 1) ? g_spawn.point4OriginLow : g_spawn.point4OriginHigh;
      double extreme = (direction == 1) ? g_spawn.cycleHigh : g_spawn.cycleLow;
      if(extreme == 0.0)
         extreme = (direction == 1) ? closePrice + atr : closePrice - atr;
      double fzMid = (g_spawn.flipTop + g_spawn.flipBot) / 2.0;

      double totalMove = MathAbs(extreme - origin);
      double toFzMid = MathAbs(extreme - fzMid);
      double traveled = MathAbs(closePrice - origin);

      // Expansion progress (0-60)
      double expProg = 30.0;
      if(totalMove > 1e-10)
         expProg = MathMin(traveled / totalMove * 60.0, 60.0);

      // Retracement progress (0-40)
      double retrMove = MathAbs(closePrice - extreme);
      double retrProg = 0.0;
      if(toFzMid > 1e-10)
         retrProg = MathMin(retrMove / toFzMid * 40.0, 40.0);
      double retrWeight = MathMin(obsScores[3] / 40.0, 1.0);

      geomProgress = expProg + retrProg * retrWeight;
   }

   //--- Physics progress: similarity anchor + convexity adjustment
   // Simplified similarity anchor based on observation score dominance
   double simAnchor = 22.0;
   if(obsScores[1] > 60.0 && obsScores[3] > 50.0)
      simAnchor = 87.0;       // Retracement-like
   else if(obsScores[3] > 50.0)
      simAnchor = 75.0;       // Absorption-like
   else if(obsScores[4] > 55.0)
      simAnchor = 62.0;       // Creation/Liquidity
   else if(obsScores[2] > 40.0 && obsScores[1] > 40.0)
      simAnchor = 52.0;       // Induction-like
   else if(obsScores[1] > 30.0)
      simAnchor = 43.0;       // Pre-convexity
   else if(obsScores[0] > 50.0)
      simAnchor = 33.0;       // Expansion
   else
      simAnchor = 22.0;       // Early/origin

   // Convexity adjustment
   double convBandCenter = 47.5;
   double convBandHalfW  = 14.5;
   double convWeight = MathMax(0.0, 1.0 - MathAbs(simAnchor - convBandCenter) / convBandHalfW);
   double convAdjust = (convexityMaturity / 100.0) * (simAnchor - 33.0) * 0.50 * convWeight;

   double physProgress = simAnchor + convAdjust;

   //--- Combined: geometric 60% + physics 40%
   double rawWP = geomProgress * 0.60 + physProgress * 0.40;

   //--- EMA smooth
   g_energyState.prevWaveProgress = EmaSmooth(g_energyState.prevWaveProgress, rawWP, InpBeliefSmooth);
   g_energy.waveProgress = Clamp(g_energyState.prevWaveProgress, 0.0, 100.0);
}

//==================================================================
// 7. BELIEF ENGINE
//    6 simultaneous beliefs, position-weighted, EMA smoothed
//    beliefs[0] = expansion
//    beliefs[1] = convexity
//    beliefs[2] = creation
//    beliefs[3] = absorption
//    beliefs[4] = retracement
//    beliefs[5] = demandReturn
//==================================================================

void ComputeBeliefs(double &obsScores[], LetraPhysicsOutput &phys,
                    double closePrice, double atr)
{
   int    direction = g_spawn.direction;
   double waveProgress = g_energy.waveProgress;
   double convexityMaturity = g_energy.convexityMaturity;
   double eff  = phys.efficiency;
   double disp = phys.displacement;
   bool   hasImpulse = phys.bullImpulse || phys.bearImpulse;
   bool   momDecay = phys.bullMomDecay || phys.bearMomDecay;

   // Evidence flags
   bool preConvEvidence = momDecay;
   bool inductionEvidence = false;
   if(direction == 1 && phys.bearImpulse) inductionEvidence = true;
   if(direction == -1 && phys.bullImpulse) inductionEvidence = true;

   // Simplified similarity scores (use obsScores as proxy)
   double sim_Expansion = obsScores[0] / 100.0 * 50.0;
   double sim_Creation = obsScores[4] / 100.0 * 50.0;
   double sim_Absorption = obsScores[3] / 100.0 * 50.0;
   double sim_Retracement = obsScores[1] / 100.0 * 50.0;
   double sim_DemandReturn = obsScores[4] / 100.0 * 40.0;

   //--- beliefs[0] = Expansion Belief
   double expPosMult = (waveProgress < 40.0) ? 1.20 : (waveProgress < 60.0) ? 0.80 : 0.50;
   double rawExp = (obsScores[0] * 0.45 +
                    (hasImpulse ? 30.0 : 0.0) +
                    (eff > InpEffThresh * 1.1 ? 15.0 : 0.0) +
                    sim_Expansion * 0.10) * expPosMult;
   rawExp = MathMin(rawExp, 100.0);

   //--- beliefs[1] = Convexity Belief
   double convPosMult = (waveProgress >= 30.0 && waveProgress <= 65.0) ? 1.30 : 0.70;
   double rawConv = (obsScores[1] * 0.30 +
                     obsScores[2] * 0.25 +
                     (preConvEvidence ? 15.0 : 0.0) +
                     (inductionEvidence ? 10.0 : 0.0) +
                     (obsScores[4] > 50.0 && obsScores[1] > 40.0 ? 5.0 : 0.0) +
                     convexityMaturity * 0.08) * convPosMult;
   rawConv = MathMin(rawConv, 100.0);

   //--- beliefs[2] = Creation Belief
   double creatPosMult = (waveProgress >= 45.0 && waveProgress <= 68.0) ? 1.40 : 0.60;
   // Cycle extreme proximity check
   bool nearCycleExtreme = false;
   if(g_spawn.cycleHigh > 0.0 && direction == 1)
      nearCycleExtreme = (closePrice >= g_spawn.cycleHigh * 0.998);
   if(g_spawn.cycleLow > 0.0 && direction == -1)
      nearCycleExtreme = (closePrice <= g_spawn.cycleLow * 1.002);

   double rawCreat = ((convexityMaturity > 50.0 ? convexityMaturity * 0.12 : 0.0) +
                      (obsScores[1] > 60.0 ? obsScores[1] * 0.20 : 0.0) +
                      (obsScores[4] > 50.0 ? obsScores[4] * 0.20 : 0.0) +
                      (obsScores[3] > 20.0 ? obsScores[3] * 0.15 : 0.0) +
                      (nearCycleExtreme ? 20.0 : 0.0) +
                      sim_Creation * 0.10) * creatPosMult;
   rawCreat = MathMin(rawCreat, 100.0);

   //--- beliefs[3] = Absorption Belief
   double rawAbs = obsScores[3] * 0.50 +
                   (eff < InpEffThresh * 0.6 ? 25.0 : 0.0) +
                   (disp < InpDispThresh * 0.5 ? 15.0 : 0.0) +
                   sim_Absorption * 0.10;
   rawAbs = MathMin(rawAbs, 100.0);

   //--- beliefs[4] = Retracement Belief
   bool counterImpulse = false;
   if(direction == 1 && phys.bearImpulse) counterImpulse = true;
   if(direction == -1 && phys.bullImpulse) counterImpulse = true;

   double rawRetr = (counterImpulse ? 45.0 : 0.0) +
                    (rawAbs > 50.0 ? rawAbs * 0.30 : 0.0) +
                    (obsScores[2] > 40.0 ? 15.0 : 0.0) +
                    sim_Retracement * 0.10;
   rawRetr = MathMin(rawRetr, 100.0);

   //--- beliefs[5] = Demand/Supply Return Belief
   // liqHeat simplified default = 50, liqSweep from flipzone proximity
   double liqHeat = 50.0;
   bool liqSweep = false;
   if(g_spawn.flipTop > 0.0 && g_spawn.flipBot > 0.0)
   {
      if(closePrice >= g_spawn.flipBot && closePrice <= g_spawn.flipTop)
         liqSweep = true;
   }

   bool insideFlipzone = false;
   if(g_spawn.flipTop > 0.0 && g_spawn.flipBot > 0.0)
      insideFlipzone = (closePrice <= g_spawn.flipTop && closePrice >= g_spawn.flipBot);

   double rawDR = (insideFlipzone ? 35.0 : 0.0) +
                  (rawRetr > 60.0 ? rawRetr * 0.30 : 0.0) +
                  (liqHeat > 50.0 ? liqHeat * 0.15 : 0.0) +
                  (liqSweep ? 20.0 : 0.0) +
                  sim_DemandReturn * 0.10;
   rawDR = MathMin(rawDR, 100.0);

   //--- EMA smooth all beliefs
   g_energyState.prevBeliefs[0] = EmaSmooth(g_energyState.prevBeliefs[0], rawExp, InpBeliefSmooth);
   g_energyState.prevBeliefs[1] = EmaSmooth(g_energyState.prevBeliefs[1], rawConv, InpBeliefSmooth);
   g_energyState.prevBeliefs[2] = EmaSmooth(g_energyState.prevBeliefs[2], rawCreat, InpBeliefSmooth);
   g_energyState.prevBeliefs[3] = EmaSmooth(g_energyState.prevBeliefs[3], rawAbs, InpBeliefSmooth);
   g_energyState.prevBeliefs[4] = EmaSmooth(g_energyState.prevBeliefs[4], rawRetr, InpBeliefSmooth);
   g_energyState.prevBeliefs[5] = EmaSmooth(g_energyState.prevBeliefs[5], rawDR, InpBeliefSmooth);

   // Store final clamped values
   for(int i = 0; i < 6; i++)
      g_energy.beliefs[i] = Clamp(g_energyState.prevBeliefs[i], 0.0, 100.0);
}

//==================================================================
// 8. HYPOTHESIS ENGINE
//    6 hypotheses normalized against fixed theoretical maxima
//    hypotheses[0] = LateExpansion
//    hypotheses[1] = TerminalConvexity
//    hypotheses[2] = CreationForming
//    hypotheses[3] = AbsorptionActive
//    hypotheses[4] = RetracementActive
//    hypotheses[5] = DemandReturn
//==================================================================

void ComputeHypotheses()
{
   double waveProgress = g_energy.waveProgress;
   double convexityMaturity = g_energy.convexityMaturity;

   // Model fit multiplier (from M5 model fit, min 0.60)
   double modelFit = g_letra[2].modelFit * 100.0;
   double fitMult = MathMax(0.60, modelFit / 100.0);

   // Reference beliefs
   double expB  = g_energy.beliefs[0];
   double convB = g_energy.beliefs[1];
   double creatB = g_energy.beliefs[2];
   double absB  = g_energy.beliefs[3];
   double retrB = g_energy.beliefs[4];
   double drB   = g_energy.beliefs[5];

   //--- hyp[0] = LateExpansion
   double hyp0 = (expB * 0.35 +
                  (waveProgress < 38.0 ? (38.0 - waveProgress) * 0.80 : 0.0) +
                  (convexityMaturity < 30.0 ? (30.0 - convexityMaturity) * 0.30 : 0.0) +
                  (expB > 55.0 && convB > 30.0 ? 10.0 : 0.0)) * fitMult;

   //--- hyp[1] = TerminalConvexity
   double hyp1 = (convB * 0.30 +
                  (convexityMaturity > 50.0 ? convexityMaturity * 0.25 : 0.0) +
                  (waveProgress >= 38.0 && waveProgress <= 62.0 ? 20.0 : 0.0)) * fitMult;

   //--- hyp[2] = CreationForming
   double hyp2 = (creatB * 0.40 +
                  (convexityMaturity > 65.0 ? (convexityMaturity - 65.0) * 0.40 : 0.0)) * fitMult;

   //--- hyp[3] = AbsorptionActive
   double hyp3 = (absB * 0.45 +
                  (waveProgress >= 68.0 && waveProgress <= 80.0 ? 20.0 : 0.0)) * fitMult;

   //--- hyp[4] = RetracementActive
   double hyp4 = (retrB * 0.45 +
                  (waveProgress >= 78.0 && waveProgress <= 92.0 ? 20.0 : 0.0)) * fitMult;

   //--- hyp[5] = DemandReturn
   bool closeInside = false;
   if(g_spawn.flipTop > 0.0 && g_spawn.flipBot > 0.0)
      closeInside = (Close[0] <= g_spawn.flipTop && Close[0] >= g_spawn.flipBot);

   double hyp5 = (drB * 0.45 +
                  (waveProgress >= 88.0 ? (waveProgress - 88.0) * 1.20 : 0.0) +
                  (closeInside ? 15.0 : 0.0)) * fitMult;

   // Fixed theoretical maxima (from Letra 37 Section 12D)
   double HYP_MAX_LATEEXP   = 105.0;
   double HYP_MAX_TERMCONV  = 108.0;
   double HYP_MAX_CREATFORM = 97.0;
   double HYP_MAX_ABS       = 100.0;
   double HYP_MAX_RETR      = 100.0;
   double HYP_MAX_DR        = 100.0;

   // Normalize to 0-100 using fixed maxima (NOT rescale-to-100)
   g_energy.hypotheses[0] = Clamp(hyp0 / HYP_MAX_LATEEXP * 100.0, 0.0, 100.0);
   g_energy.hypotheses[1] = Clamp(hyp1 / HYP_MAX_TERMCONV * 100.0, 0.0, 100.0);
   g_energy.hypotheses[2] = Clamp(hyp2 / HYP_MAX_CREATFORM * 100.0, 0.0, 100.0);
   g_energy.hypotheses[3] = Clamp(hyp3 / HYP_MAX_ABS * 100.0, 0.0, 100.0);
   g_energy.hypotheses[4] = Clamp(hyp4 / HYP_MAX_RETR * 100.0, 0.0, 100.0);
   g_energy.hypotheses[5] = Clamp(hyp5 / HYP_MAX_DR * 100.0, 0.0, 100.0);
}

//==================================================================
// 9. PREDICTION ENGINE
//    Scores each possible next phase, picks highest
//==================================================================

void ComputePrediction()
{
   double waveProgress = g_energy.waveProgress;
   double convexityMaturity = g_energy.convexityMaturity;
   int    direction = g_spawn.direction;

   // Reference beliefs
   double expB  = g_energy.beliefs[0];
   double absB  = g_energy.beliefs[3];
   double retrB = g_energy.beliefs[4];

   // Reference obsScores (reconstruct minimal needed flags)
   double decayScore = g_energy.beliefs[1];  // proxy for obs_DecayScore
   double liqScore   = g_energy.beliefs[2];  // proxy for obs_LiquidityScore
   double absScore   = g_energy.beliefs[3];  // proxy for obs_AbsorptionScore

   // HTF alignment proxy: use fractal stack
   bool htfAligned = (g_fractalStackDir == direction && direction != 0);

   //--- predScore for each candidate next phase
   // Expansion
   double ps_Expansion =
      (waveProgress < 35.0 ? (35.0 - waveProgress) * 1.00 : 0.0) +
      (expB > 55.0 ? expB * 0.30 : 0.0) +
      (convexityMaturity < 25.0 ? 20.0 : 0.0) +
      (htfAligned ? 15.0 : 0.0);

   // Convexity (Pre-Convexity)
   bool preConvEvidence = (g_letra[2].phase >= 2 && g_letra[2].phase <= 4);
   double ps_Convexity =
      (waveProgress >= 25.0 && waveProgress <= 60.0 ? 30.0 : 0.0) +
      (convexityMaturity > 20.0 ? convexityMaturity * 0.30 : 0.0) +
      (decayScore > 40.0 ? 20.0 : 0.0) +
      (preConvEvidence ? 15.0 : 0.0);

   // Creation (New High/Low)
   double ps_Creation =
      (convexityMaturity > 55.0 ? (convexityMaturity - 55.0) * 1.20 : 0.0) +
      (liqScore > 55.0 ? 20.0 : 0.0);

   // Absorption
   double ps_Absorption =
      (ps_Creation > 50.0 ? ps_Creation * 0.40 : 0.0) +
      (absScore > 35.0 ? absScore * 0.30 : 0.0) +
      (waveProgress >= 60.0 && waveProgress <= 78.0 ? 15.0 : 0.0);

   // Retracement
   double ps_Retracement =
      (absB > 45.0 ? absB * 0.35 : 0.0) +
      (waveProgress >= 72.0 && waveProgress <= 90.0 ? 20.0 : 0.0);

   // Demand/Supply Return
   double ps_DemandReturn =
      (retrB > 45.0 ? retrB * 0.35 : 0.0) +
      (waveProgress >= 88.0 ? (waveProgress - 88.0) * 1.20 : 0.0);

   //--- Find maximum scoring phase
   double scores[6];
   scores[0] = ps_Expansion;
   scores[1] = ps_Convexity;
   scores[2] = ps_Creation;
   scores[3] = ps_Absorption;
   scores[4] = ps_Retracement;
   scores[5] = ps_DemandReturn;

   double maxScore = scores[0];
   int    maxIdx = 0;
   for(int i = 1; i < 6; i++)
   {
      if(scores[i] > maxScore)
      {
         maxScore = scores[i];
         maxIdx = i;
      }
   }

   // Map index to predicted next phase code
   // 0=Expansion(1), 1=PreConv(2), 2=Creation(5/6), 3=Absorption(7), 4=Retracement(8), 5=DemandReturn(13/14)
   switch(maxIdx)
   {
      case 0: g_energy.predictionNextPhase = 1; break;
      case 1: g_energy.predictionNextPhase = 2; break;
      case 2: g_energy.predictionNextPhase = (direction == -1) ? 6 : 5; break;
      case 3: g_energy.predictionNextPhase = 7; break;
      case 4: g_energy.predictionNextPhase = 8; break;
      case 5: g_energy.predictionNextPhase = (direction == -1) ? 14 : 13; break;
      default: g_energy.predictionNextPhase = 1; break;
   }

   // Probability: score / (score + 30) * 100, capped at 95
   if(maxScore > 0.0)
      g_energy.predictionProb = MathMin(maxScore / (maxScore + 30.0) * 100.0, 95.0);
   else
      g_energy.predictionProb = 50.0;
}

//==================================================================
// 10. VALIDATION ENGINE
//     Tracks prediction accuracy over rolling windows
//==================================================================

void ComputeValidation()
{
   int currentPhase = g_letra[2].phase;
   int lastPhase = g_energyState.lastIE1APhase;

   // Detect phase transition
   bool transition = (currentPhase != lastPhase);

   if(transition)
   {
      // Check if prediction was correct
      bool succeeded = (currentPhase == g_energyState.lastExpectedPhase);

      // Store outcome in rolling buffer
      int idx = g_energyState.predTotalIdx % 100;
      g_energyState.predOutcomes[idx] = succeeded ? 1 : 0;
      g_energyState.predTotalIdx++;
   }

   // Update last expected/actual
   g_energyState.lastExpectedPhase = g_energy.predictionNextPhase;
   g_energyState.lastIE1APhase = currentPhase;
}

// Helper: compute prediction accuracy over N recent outcomes
double GetPredictionAccuracy(int n)
{
   int cnt = n;
   if(cnt > g_energyState.predTotalIdx)
      cnt = g_energyState.predTotalIdx;
   if(cnt <= 0) return(50.0);

   int sum = 0;
   int start = g_energyState.predTotalIdx - cnt;
   if(start < 0) start = 0;

   for(int i = start; i < g_energyState.predTotalIdx; i++)
   {
      sum += g_energyState.predOutcomes[i % 100];
   }
   return((double)sum / (double)cnt * 100.0);
}

//==================================================================
// 11. ADAPTIVE CONFIDENCE ENGINE
//     modelConfidence with increase/decrease drivers + decay to 50
//==================================================================

void ComputeAdaptiveConfidence()
{
   int currentPhase = g_letra[2].phase;
   int lastPhase = g_energyState.lastIE1APhase;
   bool transition = (currentPhase != lastPhase);
   bool succeeded = transition && (currentPhase == g_energyState.lastExpectedPhase);
   int direction = g_spawn.direction;

   // Physics consensus proxy
   double physMax = MathMax(g_energy.beliefs[0], MathMax(g_energy.beliefs[1],
                   MathMax(g_energy.beliefs[3], g_energy.beliefs[4])));
   double physMin = MathMin(g_energy.beliefs[0], MathMin(g_energy.beliefs[1],
                   MathMin(g_energy.beliefs[3], g_energy.beliefs[4])));
   double physicsDiff = physMax - physMin;
   double physicsConsensus = MathMax(0.0, 100.0 - physicsDiff);

   // HTF alignment
   bool htfAligned = (g_fractalStackDir == direction && direction != 0);
   bool htfConflict = (g_fractalStackDir != direction && direction != 0 && g_fractalStackDir != 0);

   // Confidence increase drivers
   double confIncrease = 0.0;
   if(succeeded) confIncrease += 3.0;
   if(physicsConsensus > 70.0) confIncrease += 2.0;
   if(htfAligned) confIncrease += 1.5;

   // Confidence decrease drivers
   double confDecrease = 0.0;
   if(transition && !succeeded) confDecrease += 2.0;
   if(physicsDiff > 60.0) confDecrease += 2.0;
   if(htfConflict) confDecrease += 1.5;

   // Decay toward 50
   double confDecayRate = 0.02;
   double prevConf = g_energyState.prevModelConfidence;
   if(prevConf == 0.0) prevConf = 50.0;

   double newConf = prevConf + confIncrease - confDecrease - confDecayRate * (prevConf - 50.0);
   newConf = Clamp(newConf, 10.0, 100.0);

   g_energyState.prevModelConfidence = newConf;
   g_energy.modelConfidence = newConf;
}

//==================================================================
// 12. LIQUIDATION WAVE OVERLAY (Engine 1A.7)
//     Activates during Induction phases, tracks distance to objective
//==================================================================

void ComputeLiquidationWaveOverlay(int canonicalPhase, double closePrice,
                                   double atr, double efficiency)
{
   // Phase classification
   bool isRetrInduction = (canonicalPhase == 10);  // Retracement Induction
   bool isExpInduction  = (canonicalPhase == 3);   // Expansion Induction
   bool armCondition    = isExpInduction || isRetrInduction;

   // Get M5 target from structure engine
   double objective = g_letra[2].tgt;

   //--- ARM: activate liquidation wave on induction if not already active
   if(armCondition && !g_energyState.liqg_active && objective != 0.0)
   {
      g_energyState.liqg_active   = true;
      g_energyState.liqg_isRetr   = isRetrInduction;
      g_energyState.liqg_target   = objective;
      g_energyState.liqg_dir      = (objective > closePrice) ? 1 : -1;
      g_energyState.liqg_initDist = MathMax(MathAbs(objective - closePrice), atr * 0.5);
   }

   // Update target if still in qualifying phase
   if(g_energyState.liqg_active && objective != 0.0)
      g_energyState.liqg_target = objective;

   if(!g_energyState.liqg_active) return;

   //--- DISTANCE COMPRESSION: 100% = at origin, 0% = arrived
   double remaining = MathAbs(g_energyState.liqg_target - closePrice);
   double distPct = 100.0;
   if(g_energyState.liqg_initDist > 1e-10)
      distPct = MathMin(100.0, remaining / g_energyState.liqg_initDist * 100.0);

   //--- Physics checks for objective arrival
   bool capExhausted = (g_energy.ede_dissipationProgress > 60.0 ||
                        g_energy.convexityMaturity > 60.0);
   bool resolved = (g_energy.re_resolutionState == 2);
   bool energyLow = (efficiency < InpEffThresh * 0.7);
   bool magnet = (distPct < 20.0);

   //--- OBJECTIVE ARRIVAL: Structure AND Momentum AND Physics
   bool arrivalStruct = false;
   if(g_energyState.liqg_dir == 1)
      arrivalStruct = (closePrice >= g_energyState.liqg_target);
   else
      arrivalStruct = (closePrice <= g_energyState.liqg_target);

   bool arrivalPhys = capExhausted && (resolved || magnet);
   bool objArrival = arrivalStruct && energyLow && arrivalPhys;

   //--- TRUE CHoCH: objective arrival + counter BOS + energy low + resolved
   bool counterBOS = false;
   if(g_energyState.liqg_dir == 1 && g_letra[2].bos && g_letra[2].dir == -1)
      counterBOS = true;
   if(g_energyState.liqg_dir == -1 && g_letra[2].bos && g_letra[2].dir == 1)
      counterBOS = true;

   bool trueCHoCH = objArrival && counterBOS && energyLow && resolved;

   //--- RETIREMENT: leave induction/liquidity window or genuine completion
   bool inWindow = (canonicalPhase == 3 || canonicalPhase == 4 ||
                    canonicalPhase == 10 || canonicalPhase == 11);
   if(!inWindow || (objArrival && trueCHoCH))
      g_energyState.liqg_active = false;

   //--- ABSORPTION GATE: unlock absorption display only after arrival+CHoCH
   if(objArrival && trueCHoCH)
      g_energyState.liqg_absorbUnlocked = true;
   if(canonicalPhase == 0)  // Reset on new wave
      g_energyState.liqg_absorbUnlocked = false;
}

//==================================================================
// 13. MASTER UPDATE FUNCTION
//     Calls all sub-engines in correct order
//==================================================================

void UpdateEnergyFramework()
{
   //--- Get M5 physics (index 2 for M5 in timeframe array)
   double closeArr[], highArr[], lowArr[];
   if(!CopyTFData(2, 200, closeArr, highArr, lowArr))
      return;

   int bars = ArraySize(closeArr);
   if(bars < InpATRLen + 2) return;

   LetraPhysicsOutput phys;
   ComputePhysics(closeArr, highArr, lowArr, bars, phys);

   double atr = phys.atr;
   if(atr <= 0.0) atr = GetATR(0);
   if(atr <= 0.0) return;

   double closePrice = closeArr[0];

   // Get canonical phase from M5 structure engine
   int canonicalPhase = g_letra[2].phase;

   // Physics flags
   bool hasImpulse = phys.bullImpulse || phys.bearImpulse;
   double efficiency = phys.efficiency;

   //--- Observation scores
   double obsScores[];
   ComputePhysicsObservationLayer(phys, atr, obsScores);

   //--- Energy Dissipation Engine (EDE)
   ComputeEnergyDissipation(canonicalPhase, obsScores, hasImpulse, efficiency);

   //--- Resolution Engine (RE)
   ComputeResolutionEngine();

   //--- Energy Attractor Engine (EAE)
   ComputeEnergyAttractor(closePrice, atr);

   //--- Convexity Maturity Engine
   ComputeConvexityMaturity(phys, obsScores, closePrice, atr);

   //--- Wave Progress Estimation
   ComputeWaveProgress(closePrice, atr, obsScores);

   //--- Belief Engine
   ComputeBeliefs(obsScores, phys, closePrice, atr);

   //--- Hypothesis Engine
   ComputeHypotheses();

   //--- Prediction Engine
   ComputePrediction();

   //--- Validation Engine
   ComputeValidation();

   //--- Adaptive Confidence Engine
   ComputeAdaptiveConfidence();

   //--- Liquidation Wave Overlay (Engine 1A.7)
   ComputeLiquidationWaveOverlay(canonicalPhase, closePrice, atr, efficiency);
}

//+------------------------------------------------------------------+
