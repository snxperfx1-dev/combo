//+------------------------------------------------------------------+
//| Part3_PhysicsWavePhaseEngine.mqh                                  |
//| MASTER ALGO - Physics & Wave Phase Engine                         |
//| Chart-TF physics (vel/acc/conv/eff/disp), observation scores,     |
//| Symphony impulse/phase engine (P1-P4), liquidity heatmap,         |
//| convexity maturity, wave progress, similarity engine              |
//+------------------------------------------------------------------+
#property strict

//==================================================================
// PHYSICS ENGINE
//
// Computes on chart timeframe (execution context):
//   - Velocity, Acceleration, Convexity (smoothed)
//   - Efficiency, Displacement
//   - Impulse/Decay/ConvShift flags
//   - Observation layer scores (Expansion/Decay/Curvature/Absorption/Liquidity)
//   - Phase similarity vectors
//   - Convexity maturity engine
//   - Liquidity heatmap
//   - Symphony's legacy phase engine (for P3/P4 entry compatibility)
//==================================================================

//--- Physics persistent state
double g_velocity = 0;
double g_acceleration = 0;
double g_convexity = 0;
double g_convSmooth = 0;
double g_efficiency = 0;
double g_displacement = 0;
double g_momentum = 0;

// Observation scores (persistent for EMA smoothing)
double g_obsExpansion = 0;
double g_obsDecay = 0;
double g_obsCurvature = 0;
double g_obsAbsorption = 0;
double g_obsLiquidity = 0;

// Convexity maturity (EMA smoothed)
double g_convMaturitySmoothed = 0;

// Wave model fit (EMA smoothed)
double g_waveModelFitSmoothed = 50.0;

// Similarity scores
double g_simExpansion = 0;
double g_simPreConv = 0;
double g_simInduction = 0;
double g_simLiquidity = 0;
double g_simCreation = 0;
double g_simAbsorption = 0;
double g_simRetracement = 0;
double g_simDemandReturn = 0;

// Liquidity heatmap arrays
double g_liqLevels[];
double g_liqWeights[];
int    g_liqAges[];
int    g_liqCount = 0;
#define LIQ_MAX_LEVELS 150

// Evidence flags
bool   g_preConvEvidence = false;
bool   g_inductionEvidence = false;
bool   g_liquidityEvidence = false;
bool   g_nearFlipzone = false;
bool   g_closeInside = false;

//==================================================================
// CORE PHYSICS COMPUTATION (on chart TF - executed each bar)
//==================================================================
void ComputePhysics()
{
   int barsAvail = ArraySize(Close);
   if(barsAvail < InpEffLen + 10) return;
   
   int shift = 1; // last closed bar
   double atrNow = GetATR(shift);
   if(atrNow <= 0) return;
   
   //--- Velocity (EMA(close-close[1], 3) approximation)
   double v0 = Close[shift] - Close[shift+1];
   double v1 = Close[shift+1] - Close[shift+2];
   double v2 = Close[shift+2] - Close[shift+3];
   double v3 = Close[shift+3] - Close[shift+4];
   double v4 = Close[shift+4] - Close[shift+5];
   
   // EMA(3) of velocity
   double alpha3 = 2.0 / 4.0; // EMA(3) alpha
   double vel = v0;
   vel = v0 * alpha3 + v1 * alpha3 * (1-alpha3) + v2 * (1-alpha3)*(1-alpha3);
   
   double velPrev = v1 * alpha3 + v2 * alpha3 * (1-alpha3) + v3 * (1-alpha3)*(1-alpha3);
   
   //--- Acceleration
   double acc = vel - velPrev;
   double accPrev = velPrev - (v2 * alpha3 + v3 * alpha3 * (1-alpha3) + v4 * (1-alpha3)*(1-alpha3));
   
   //--- Convexity (jerk)
   double cvx = acc - accPrev;
   
   //--- Convexity smooth (EMA(cvx, 3))
   double cSmooth = cvx * alpha3 + g_convSmooth * (1.0 - alpha3);
   
   //--- Efficiency
   double move = MathAbs(Close[shift] - Close[shift + InpEffLen]);
   double pathSum = 0;
   for(int i = shift; i < shift + InpEffLen && i < barsAvail - 1; i++)
      pathSum += MathAbs(Close[i] - Close[i+1]);
   double eff = (pathSum > 0) ? move / pathSum : 0.0;
   
   //--- Displacement
   double disp = (High[shift] - Low[shift]) / MathMax(atrNow, 1e-10);
   
   //--- Store
   g_velocity = vel;
   g_acceleration = acc;
   g_convexity = cvx;
   g_convSmooth = cSmooth;
   g_efficiency = eff;
   g_displacement = disp;
   g_momentum = vel - velPrev;
   
   //--- Physics flags
   double convThreshold = atrNow * InpConvMult;
   
   g_physics.atr = atrNow;
   g_physics.velocity = vel;
   g_physics.acceleration = acc;
   g_physics.convexity = cvx;
   g_physics.convSmooth = cSmooth;
   g_physics.efficiency = eff;
   g_physics.displacement = disp;
   
   // Impulse flags
   g_physics.bullImpulse = (eff > InpEffThresh && vel > velPrev && acc > 0 && 
                            Close[shift] > Open[shift] && disp > InpDispThresh);
   g_physics.bearImpulse = (eff > InpEffThresh && vel < velPrev && acc < 0 && 
                            Close[shift] < Open[shift] && disp > InpDispThresh);
   
   // Momentum decay flags
   g_physics.bullMomDecay = (MathAbs(acc) < MathAbs(accPrev) * 0.8 && vel > 0);
   g_physics.bearMomDecay = (MathAbs(acc) < MathAbs(accPrev) * 0.8 && vel < 0);
   
   // Convexity shift flags
   g_physics.bullConvShift = (cSmooth > convThreshold && g_convSmooth <= convThreshold);
   g_physics.bearConvShift = (cSmooth < -convThreshold && g_convSmooth >= -convThreshold);
   
   // Velocity decay flags
   g_physics.velDecay70 = (MathAbs(vel) < MathAbs(velPrev) * 0.7);
   g_physics.velDecay50 = (MathAbs(vel) < MathAbs(velPrev) * 0.5);
}

//==================================================================
// OBSERVATION LAYER SCORES (from Letra Section 9)
//==================================================================
void ComputeObservationScores()
{
   double atr = g_physics.atr;
   if(atr <= 0) return;
   
   double vel = g_physics.velocity;
   double acc = g_physics.acceleration;
   double eff = g_physics.efficiency;
   double disp = g_physics.displacement;
   double convScore = MathMin(MathAbs(g_convSmooth) / MathMax(atr * InpConvMult, 1e-10) * 25.0, 100.0);
   
   // Velocity/Acceleration scores
   double velScore = MathMin(MathAbs(vel) / MathMax(atr * 0.1, 1e-10) * 50.0, 100.0);
   double accScore = MathMin(MathAbs(acc) / MathMax(atr * 0.05, 1e-10) * 50.0, 100.0);
   
   //--- Expansion Score
   double expScr = MathMin(
      (eff > InpEffThresh ? eff * 60.0 : eff * 30.0) +
      (disp > InpDispThresh ? (disp / MathMax(InpDispThresh, 1e-10) - 1.0) * 20.0 : 0.0) +
      ((vel > 0 && acc > 0) || (vel < 0 && acc < 0) ? velScore * 0.2 : 0.0),
      100.0);
   
   //--- Decay Score
   double decScr = MathMin(
      (g_physics.bullMomDecay || g_physics.bearMomDecay ? 40.0 : 0.0) +
      (convScore > 30 ? convScore * 0.5 : 0.0) +
      (g_physics.velDecay70 ? 30.0 : 0.0),
      100.0);
   
   //--- Curvature Score
   double curvScr = convScore;
   
   //--- Absorption Score
   double absScr = MathMin(
      (eff < InpEffThresh * 0.7 ? (1.0 - eff / MathMax(InpEffThresh, 1e-10)) * 50.0 : 0.0) +
      (g_physics.velDecay50 ? 30.0 : 0.0) +
      (disp < InpDispThresh * 0.5 ? 20.0 : 0.0),
      100.0);
   
   //--- Liquidity Score
   double liqScr = MathMin(
      decScr * 0.4 +
      curvScr * 0.4 +
      (disp > InpDispThresh * 1.2 && (g_physics.bullMomDecay || g_physics.bearMomDecay) ? 20.0 : 0.0),
      100.0);
   
   // Store
   g_obs.expansionScore = expScr;
   g_obs.decayScore = decScr;
   g_obs.curvatureScore = curvScr;
   g_obs.absorptionScore = absScr;
   g_obs.liquidityScore = liqScr;
   
   // Physics consensus
   double physMax = MathMax(expScr, MathMax(decScr, MathMax(absScr, liqScr)));
   double physMin = MathMin(expScr, MathMin(decScr, MathMin(absScr, liqScr)));
   g_obs.physicsConsensus = MathMax(0.0, 100.0 - (physMax - physMin));
   
   // Also update persistent for other engines
   g_obsExpansion = expScr;
   g_obsDecay = decScr;
   g_obsCurvature = curvScr;
   g_obsAbsorption = absScr;
   g_obsLiquidity = liqScr;
}

//==================================================================
// SIMILARITY ENGINE (from Letra Section 12)
// Computes how closely current physics matches each ideal phase
//==================================================================
void ComputeSimilarityScores()
{
   // Normalize physics to 0-1
   double effNorm = MathMin(g_efficiency, 1.0);
   double dispNorm = MathMin(g_displacement / MathMax(InpDispThresh * 2.0, 1e-10), 1.0);
   double velNorm = MathMin(MathAbs(g_velocity) / MathMax(g_physics.atr * 0.15, 1e-10), 1.0);
   double curvNorm = MathMin(MathAbs(g_convSmooth) / MathMax(g_physics.atr * InpConvMult * 2.0, 1e-10), 1.0);
   
   // Ideal vectors for each phase
   g_simExpansion = IdealSimilarity(effNorm, dispNorm, velNorm, curvNorm, 0.85, 0.80, 0.80, 0.10);
   g_simPreConv = IdealSimilarity(effNorm, dispNorm, velNorm, curvNorm, 0.60, 0.55, 0.40, 0.50);
   g_simInduction = IdealSimilarity(effNorm, dispNorm, velNorm, curvNorm, 0.65, 0.60, 0.30, 0.60);
   g_simLiquidity = IdealSimilarity(effNorm, dispNorm, velNorm, curvNorm, 0.45, 0.85, 0.15, 0.80);
   g_simCreation = IdealSimilarity(effNorm, dispNorm, velNorm, curvNorm, 0.30, 0.70, 0.05, 0.90);
   g_simAbsorption = IdealSimilarity(effNorm, dispNorm, velNorm, curvNorm, 0.20, 0.25, 0.10, 0.40);
   g_simRetracement = IdealSimilarity(effNorm, dispNorm, velNorm, curvNorm, 0.70, 0.65, 0.65, 0.25);
   g_simDemandReturn = IdealSimilarity(effNorm, dispNorm, velNorm, curvNorm, 0.50, 0.40, 0.35, 0.20);
}

//==================================================================
// CONVEXITY MATURITY ENGINE (from Letra Section 12-CM)
//==================================================================
void ComputeConvexityMaturity()
{
   // Expansion weakness
   double expWeakness = MathMin(
      ((g_efficiency < InpEffThresh ? (1.0 - g_efficiency / MathMax(InpEffThresh, 1e-10)) * 40.0 : 0.0) +
       g_obsDecay * 0.30 +
       (g_physics.velDecay70 ? 20.0 : 0.0)) * (100.0 / 90.0),
      100.0);
   
   // Induction maturity
   double inducMat = MathMin(
      (g_inductionEvidence ? 35.0 : 0.0) +
      g_obsCurvature * 0.35 +
      (g_preConvEvidence ? 20.0 : 0.0) +
      (g_displacement > InpDispThresh * 1.2 && (g_physics.bullMomDecay || g_physics.bearMomDecay) ? 10.0 : 0.0),
      100.0);
   
   // Liquidity maturity
   double liqMat = MathMin(
      g_obsLiquidity * 0.50 +
      (g_liqHeat > 60 ? 20.0 : g_liqHeat > 30 ? 10.0 : 0.0) +
      (g_liqSweepOK ? 30.0 : 0.0),
      100.0);
   
   // Raw maturity
   double rawMat = MathMin(expWeakness * 0.35 + inducMat * 0.35 + liqMat * 0.30, 100.0);
   
   // EMA smooth
   g_convMaturitySmoothed = SmoothEMA(g_convMaturitySmoothed, rawMat, InpBeliefSmooth);
}

//==================================================================
// WAVE PROGRESS ESTIMATION (from Letra Section 12-WP)
//==================================================================
void ComputeWaveProgressEstimate()
{
   double geomProgress = 30.0;
   
   // Geometric progress from origin/extreme/flipzone
   if(g_point4High > 0 && g_flipTop > 0 && g_flipBot > 0 && ArraySize(Close) > 1)
   {
      double origin = (g_direction == 1) ? g_point4Low : g_point4High;
      double extreme = (g_direction == 1) ? g_cycleHigh : g_cycleLow;
      double fzMid = (g_flipTop + g_flipBot) / 2.0;
      double closeNow = Close[1];
      
      double totalMove = MathAbs(extreme - origin);
      double toFzMid = MathAbs(extreme - fzMid);
      
      double expProg = (totalMove > 1e-10) ? MathMin(MathAbs(closeNow - origin) / totalMove * 60.0, 60.0) : 30.0;
      double retrMove = MathAbs(closeNow - extreme);
      double retrProg = (toFzMid > 1e-10) ? MathMin(retrMove / MathMax(toFzMid, 1e-10) * 40.0, 40.0) : 0.0;
      double retrWeight = MathMin(g_obsAbsorption / 40.0, 1.0);
      
      geomProgress = expProg + retrProg * retrWeight;
   }
   
   // Physics progress from similarity anchor
   double bestSim = MathMax(g_simExpansion, MathMax(g_simPreConv, MathMax(g_simInduction, 
                    MathMax(g_simLiquidity, MathMax(g_simCreation, MathMax(g_simAbsorption, 
                    MathMax(g_simRetracement, g_simDemandReturn)))))));
   
   double simAnchor = (g_simDemandReturn >= bestSim - 1) ? 95.0 :
                      (g_simRetracement >= bestSim - 1) ? 87.0 :
                      (g_simAbsorption >= bestSim - 1) ? 75.0 :
                      (g_simCreation >= bestSim - 1) ? 62.0 :
                      (g_simLiquidity >= bestSim - 1) ? 52.0 :
                      (g_simInduction >= bestSim - 1) ? 43.0 :
                      (g_simPreConv >= bestSim - 1) ? 33.0 : 22.0;
   
   // Convexity weight
   double convBandCenter = 47.5;
   double convBandHalf = 14.5;
   double convWeight = MathMax(0.0, 1.0 - MathAbs(simAnchor - convBandCenter) / convBandHalf);
   double convAdjust = (g_convMaturitySmoothed / 100.0) * (simAnchor - 33.0) * 0.50 * convWeight;
   double physProgress = simAnchor + convAdjust;
   
   // Blend geometric and physics
   double rawProgress = geomProgress * 0.60 + physProgress * 0.40;
   
   // EMA smooth
   g_waveProgress = SmoothEMA(g_waveProgress, rawProgress, InpBeliefSmooth);
   g_waveProgress = Clamp(g_waveProgress, 0.0, 100.0);
}

//==================================================================
// WAVE MODEL FIT (from Letra Section 12-FIT)
//==================================================================
void ComputeWaveModelFit()
{
   double bestSim = MathMax(g_simExpansion, MathMax(g_simPreConv, MathMax(g_simInduction, 
                    MathMax(g_simLiquidity, MathMax(g_simCreation, MathMax(g_simAbsorption, 
                    MathMax(g_simRetracement, g_simDemandReturn)))))));
   
   double atr = g_physics.atr;
   double geomConsistency = MathMin(
      (g_cycleHigh > 0 && g_point4High > 0 && MathAbs(g_cycleHigh - g_point4Low) > atr * 2.0 ? 30.0 : 0.0) +
      (g_flipTop > 0 && g_flipBot > 0 && (g_flipTop - g_flipBot) < atr * 4.0 ? 25.0 : 0.0) +
      (g_cycleHigh > 0 || g_cycleLow > 0 ? 20.0 : 0.0) +
      (g_direction != 0 ? 25.0 : 0.0),
      100.0);
   
   double rawFit = bestSim * 0.55 + geomConsistency * 0.45;
   g_waveModelFitSmoothed = SmoothEMA(g_waveModelFitSmoothed, rawFit, InpBeliefSmooth);
   g_waveModelFitSmoothed = Clamp(g_waveModelFitSmoothed, 0.0, 100.0);
}

//==================================================================
// LIQUIDITY HEATMAP ENGINE (from Letra Section 10)
//==================================================================
void InitLiquidityEngine()
{
   ArrayResize(g_liqLevels, LIQ_MAX_LEVELS);
   ArrayResize(g_liqWeights, LIQ_MAX_LEVELS);
   ArrayResize(g_liqAges, LIQ_MAX_LEVELS);
   g_liqCount = 0;
}

void UpdateLiquidityHeatmap()
{
   int barsAvail = ArraySize(Close);
   if(barsAvail < InpPivotLen + 5) return;
   
   double atr = g_physics.atr;
   if(atr <= 0) return;
   
   int shift = InpPivotLen + 1;
   
   // Detect new pivots and add to liquidity pool
   bool newPivH = IsPivotHigh(shift);
   bool newPivL = IsPivotLow(shift);
   
   if(newPivH || newPivL)
   {
      double lvl = newPivH ? High[shift] : Low[shift];
      double swRng = (High[shift] - Low[shift]) / MathMax(atr, 1e-10);
      double wt = swRng; // simplified weight (vol*range in Letra)
      
      if(g_liqCount < LIQ_MAX_LEVELS)
      {
         g_liqLevels[g_liqCount] = lvl;
         g_liqWeights[g_liqCount] = wt;
         g_liqAges[g_liqCount] = 0;
         g_liqCount++;
      }
      else
      {
         // Shift oldest out
         for(int i = 0; i < g_liqCount - 1; i++)
         {
            g_liqLevels[i] = g_liqLevels[i+1];
            g_liqWeights[i] = g_liqWeights[i+1];
            g_liqAges[i] = g_liqAges[i+1];
         }
         g_liqLevels[g_liqCount-1] = lvl;
         g_liqWeights[g_liqCount-1] = wt;
         g_liqAges[g_liqCount-1] = 0;
      }
   }
   
   // Age all levels
   for(int i = 0; i < g_liqCount; i++)
      g_liqAges[i]++;
   
   // Compute heat density
   double closeNow = Close[1];
   double liqRadius = atr * 0.25;
   double liqRadiusWide = atr * 0.75;
   double wDensity = 0, wDensityAbove = 0, wDensityBelow = 0;
   double liqAgDecay = 0.95;
   
   for(int i = 0; i < g_liqCount; i++)
   {
      double lvl = g_liqLevels[i];
      double wt = g_liqWeights[i];
      int age = g_liqAges[i];
      double dcy = MathPow(liqAgDecay, age);
      double dist = MathAbs(closeNow - lvl);
      
      if(dist < liqRadius)
         wDensity += wt * dcy;
      if(dist < liqRadiusWide)
      {
         if(lvl > closeNow)
            wDensityAbove += wt * dcy * (1.0 - dist / liqRadiusWide);
         else
            wDensityBelow += wt * dcy * (1.0 - dist / liqRadiusWide);
      }
   }
   
   // Heat score 0-100
   double liqHeatRaw = MathMin((wDensityAbove + wDensityBelow) / 2.0, 5.0) / 5.0 * 100.0;
   g_liqHeat = Clamp(liqHeatRaw, 0.0, 100.0);
   
   // Liquidity sweep check
   bool liqVacuum = (wDensity < 0.5);
   bool liqSweepBull = (g_flipTop > 0 && High[1] > g_flipTop);
   bool liqSweepBear = (g_flipBot > 0 && Low[1] < g_flipBot);
   
   g_liqSweepOK = (liqSweepBull || liqSweepBear || liqVacuum);
}

//==================================================================
// EVIDENCE FLAGS UPDATE
//==================================================================
void UpdateEvidenceFlags()
{
   if(ArraySize(Close) < 2) return;
   
   double closeNow = Close[1];
   int structBias = g_fractalStack.direction;
   
   // Pre-convexity evidence
   g_preConvEvidence = (g_physics.bullMomDecay || g_physics.bearMomDecay);
   
   // Induction evidence
   g_inductionEvidence = (g_direction == 1 && g_physics.bearImpulse && structBias == 1) ||
                         (g_direction == -1 && g_physics.bullImpulse && structBias == -1);
   
   // Liquidity evidence
   g_liquidityEvidence = (g_obsLiquidity > 50.0 && g_obsDecay > 40.0);
   
   // Flipzone proximity
   g_nearFlipzone = (g_flipTop > 0 && g_flipBot > 0 && 
                     closeNow <= g_flipTop * 1.02 && closeNow >= g_flipBot * 0.98);
   
   // Close inside flipzone
   g_closeInside = (g_flipTop > 0 && closeNow <= g_flipTop && closeNow >= g_flipBot);
}

//==================================================================
// SYMPHONY LEGACY PHASE ENGINE (for P3/P4 entry compatibility)
// Impulse detection + Phases 1-4 + inducement/flipzone
//==================================================================
void UpdateSymphonyPhaseEngine()
{
   int barsAvail = ArraySize(Close);
   if(barsAvail <= (2 * InpPivotLen + 5)) return;
   
   int shiftNow = 1;
   double closeNow = Close[shiftNow];
   double atrNow = GetATR(shiftNow);
   double atrRef = atrNow;
   
   // Detect pivots at center
   int centerShift = InpPivotLen + 1;
   int pivotDir = 0;
   double pivotPrice = 0;
   int pivotShift = -1;
   
   if(centerShift < barsAvail - InpPivotLen)
   {
      if(IsPivotHigh(centerShift))
      {
         pivotDir = 1;
         pivotPrice = High[centerShift];
         pivotShift = centerShift;
      }
      else if(IsPivotLow(centerShift))
      {
         pivotDir = -1;
         pivotPrice = Low[centerShift];
         pivotShift = centerShift;
      }
   }
   
   //--- SHORT impulse: last high -> new low
   if(pivotDir == -1 && g_lastPivotDir == 1)
   {
      double r = g_lastPivotPrice - pivotPrice;
      if(r > atrRef * InpImpulseAtrMult)
      {
         g_mode = -1;
         g_anchorHigh = g_lastPivotPrice;
         g_anchorHighShift = g_lastPivotShift;
         g_anchorLow = pivotPrice;
         g_anchorLowShift = pivotShift;
         g_phaseShort = 1;
         g_phaseLong = 0;
         g_shortPreConvSeen = false;
         g_longPreConvSeen = false;
         g_longOuterBreachSeen = false;
         g_shortOuterBreachSeen = false;
         
         // Find short inducement
         double lvlS = 0;
         int bestDistS = -1;
         if(g_anchorHighShift > 0)
         {
            for(int s = g_anchorHighShift - 1;
                s >= 0 && s >= g_anchorHighShift - InpInducLookbackBars; s--)
            {
               if(s >= barsAvail) continue;
               bool inside = (High[s] < g_anchorHigh && Low[s] > g_anchorLow);
               if(inside)
               {
                  int dist = MathAbs(g_anchorHighShift - s);
                  if(bestDistS < 0 || dist < bestDistS)
                  {
                     bestDistS = dist;
                     lvlS = (High[s] + Low[s]) * 0.5;
                  }
               }
            }
         }
         if(bestDistS >= 0)
         {
            // g_shortInducPrice etc stored in global inducement vars
         }
      }
   }
   //--- LONG impulse: last low -> new high
   else if(pivotDir == 1 && g_lastPivotDir == -1)
   {
      double r = pivotPrice - g_lastPivotPrice;
      if(r > atrRef * InpImpulseAtrMult)
      {
         g_mode = 1;
         g_anchorLow = g_lastPivotPrice;
         g_anchorLowShift = g_lastPivotShift;
         g_anchorHigh = pivotPrice;
         g_anchorHighShift = pivotShift;
         g_phaseLong = 1;
         g_phaseShort = 0;
         g_shortPreConvSeen = false;
         g_longPreConvSeen = false;
         g_longOuterBreachSeen = false;
         g_shortOuterBreachSeen = false;
      }
   }
   
   // Persist pivot history
   if(pivotDir != 0)
   {
      g_prevPivotPrice = g_lastPivotPrice;
      g_prevPivotShift = g_lastPivotShift;
      g_prevPivotDir = g_lastPivotDir;
      g_lastPivotPrice = pivotPrice;
      g_lastPivotShift = pivotShift;
      g_lastPivotDir = pivotDir;
   }
   
   // Impulse invalidation
   if(g_mode == -1 && closeNow > g_anchorHigh)
   {
      g_mode = 0;
      g_phaseShort = 0;
      g_shortPreConvSeen = false;
      g_longPreConvSeen = false;
   }
   if(g_mode == 1 && closeNow < g_anchorLow)
   {
      g_mode = 0;
      g_phaseLong = 0;
      g_shortPreConvSeen = false;
      g_longPreConvSeen = false;
   }
   
   int oldPhaseShort = g_phaseShort;
   int oldPhaseLong = g_phaseLong;
   
   //--- SHORT phase computation
   if(g_mode != -1) g_phaseShort = 0;
   if(g_mode == -1 && g_anchorHighShift >= 0 && g_anchorLowShift >= 0)
   {
      double impS = g_anchorHigh - g_anchorLow;
      double retrS = (impS > 0) ? (closeNow - g_anchorLow) / impS : 0;
      double dS = Close[shiftNow] - Close[shiftNow+1];
      
      int phaseTmpS;
      if(retrS > InpRetrMax || retrS < 0)
         phaseTmpS = 0;
      else if(closeNow <= g_anchorLow)
         phaseTmpS = 4;
      else if(retrS >= InpRetrMin)
         phaseTmpS = (dS > 0 ? 2 : 3);
      else
         phaseTmpS = 1;
      
      if(phaseTmpS == 3)
         g_shortPreConvSeen = true;
      if(phaseTmpS == 4 && !g_shortPreConvSeen)
         phaseTmpS = 2;
         
      g_phaseShort = phaseTmpS;
   }
   
   //--- LONG phase computation
   if(g_mode != 1) g_phaseLong = 0;
   if(g_mode == 1 && g_anchorHighShift >= 0 && g_anchorLowShift >= 0)
   {
      double impL = g_anchorHigh - g_anchorLow;
      double retrL = (impL > 0) ? (g_anchorHigh - closeNow) / impL : 0;
      double dL = Close[shiftNow] - Close[shiftNow+1];
      
      int phaseTmpL;
      if(retrL > InpRetrMax || retrL < 0)
         phaseTmpL = 0;
      else if(closeNow >= g_anchorHigh)
         phaseTmpL = 4;
      else if(retrL >= InpRetrMin)
         phaseTmpL = (dL < 0 ? 2 : 3);
      else
         phaseTmpL = 1;
      
      if(phaseTmpL == 3)
         g_longPreConvSeen = true;
      if(phaseTmpL == 4 && !g_longPreConvSeen)
         phaseTmpL = 2;
         
      g_phaseLong = phaseTmpL;
   }
   
   g_prevPhaseShort = oldPhaseShort;
   g_prevPhaseLong = oldPhaseLong;
}

//==================================================================
// ARC v2 CALCULATION (from Symphony - Convexity ARC)
//==================================================================
void UpdateARC()
{
   g_arcLong = 0;
   g_arcShort = 0;
   
   int bars = ArraySize(Close);
   if(bars < 10) return;
   int shift = 1;
   
   // LONG ARC
   if(g_mode == 1 && g_anchorLowShift >= 0 && g_anchorHighShift >= 0)
   {
      double impL = g_anchorHigh - g_anchorLow;
      if(impL > 0)
      {
         double targetL = g_anchorLow + impL * InpArcExtMult;
         double tL = (double)(g_anchorLowShift - shift) / (double)InpArcHorizonBars;
         tL = Clamp(tL, 0.0, 1.0);
         g_arcLong = g_anchorLow + (targetL - g_anchorLow) * MathPow(tL, InpConvPower);
      }
   }
   
   // SHORT ARC
   if(g_mode == -1 && g_anchorLowShift >= 0 && g_anchorHighShift >= 0)
   {
      double impS = g_anchorHigh - g_anchorLow;
      if(impS > 0)
      {
         double targetS = g_anchorHigh - impS * InpArcExtMult;
         double tS = (double)(g_anchorHighShift - shift) / (double)InpArcHorizonBars;
         tS = Clamp(tS, 0.0, 1.0);
         g_arcShort = g_anchorHigh + (targetS - g_anchorHigh) * MathPow(tS, InpConvPower);
      }
   }
}

//==================================================================
// PHASE CONFIDENCE & INTEGRITY (from Letra Engine 1A display authority)
//==================================================================
void ComputePhaseConfidence()
{
   if(ArraySize(Close) < 2) return;
   double closeNow = Close[1];
   
   int displayDir = g_structure[TF_M5].direction;
   double m5Inv = g_structure[TF_M5].invalidation;
   
   // 3-D Agreement
   // Structure: wave holds origin
   bool sAgree = (displayDir != 0 && (displayDir == 1 ? closeNow > m5Inv : closeNow < m5Inv));
   // Momentum: travelling with wave
   bool mAgree = (displayDir != 0 && (displayDir == 1 ? g_velocity > 0 : g_velocity < 0));
   // Physics: energy not resolved
   bool pAgree = (g_erf.resolutionState != RES_RESOLVED && g_erf.dissipationProgress < 80);
   
   g_phaseConfidence = (sAgree ? 34.0 : 0.0) + (mAgree ? 33.0 : 0.0) + (pAgree ? 33.0 : 0.0);
   g_phaseIntegrity = MathMax(0.0, MathMin(100.0, 
      g_phaseConfidence * 0.6 + (100.0 - MathMin(g_erf.dissipationProgress, 100.0)) * 0.4));
}

//==================================================================
// MASTER PHYSICS UPDATE (call from OnTick after new bar)
//==================================================================
void UpdatePhysicsEngine()
{
   // 1. Core physics computation
   ComputePhysics();
   
   // 2. Observation layer scores
   ComputeObservationScores();
   
   // 3. Similarity vectors
   ComputeSimilarityScores();
   
   // 4. Evidence flags
   UpdateEvidenceFlags();
   
   // 5. Liquidity heatmap
   UpdateLiquidityHeatmap();
   
   // 6. Convexity maturity
   ComputeConvexityMaturity();
   
   // 7. Wave progress estimate
   ComputeWaveProgressEstimate();
   
   // 8. Model fit
   ComputeWaveModelFit();
   
   // 9. Symphony legacy phase engine (P3/P4)
   UpdateSymphonyPhaseEngine();
   
   // 10. ARC calculation
   UpdateARC();
   
   // 11. Phase confidence (needs ERF - may be partial on first run)
   ComputePhaseConfidence();
}

//+------------------------------------------------------------------+
