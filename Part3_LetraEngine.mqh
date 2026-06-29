//+------------------------------------------------------------------+
//| Part3_LetraEngine.mqh - Fixed-Timeframe Structure Engine         |
//|                  Ported from Letra 37's f_se and f_phys          |
//| Master MT5 EA: Symphony + Letra + F16 Combined System           |
//+------------------------------------------------------------------+
#property strict

//==================================================================
// 0. INTERNAL STATE STRUCT (persists across ticks per timeframe)
//==================================================================

struct LetraInternalState
{
   // Swing tracking
   double   curSwingHigh;
   double   curSwingLow;
   double   prevSwingHigh;
   double   prevSwingLow;

   // Pivot memory
   double   lastPivotPrice;
   int      lastPivotDir;      // 1=high, -1=low
   double   prevPivotPrice;
   int      prevPivotDir;

   // Direction / lifecycle state machine
   int      dir;               // 1=bull, -1=bear, 0=none
   double   ft;                // flip top
   double   fb;                // flip bot
   double   p4h;               // point4 high
   double   p4l;               // point4 low
   double   inv;               // invalidation
   double   tgt;               // target
   double   cycleHigh;
   double   cycleLow;

   // Lifecycle monotonic state machine
   int      phaseState;
   int      lastDirSeen;

   // Lifecycle BOS tracking
   bool     bos1;
   bool     bos2;
   double   protSw;
   double   protSw2;
   double   indOrig;
   double   indExt;
   bool     indBrk;

   // Recursive transition tracking
   int      recBrkCount;       // Phase-2 CHoCH count after extreme
   double   extremePrice;      // tracked extreme for dominance

   // Physics EMA state
   double   prevVelocity;
   double   prevConvSmooth;
};

//--- Global internal state array (one per timeframe: M1,M3,M5,M15,H1,H4)
LetraInternalState g_letraState[6];

//==================================================================
// 1. PHYSICS OUTPUT STRUCT
//==================================================================

struct LetraPhysicsOutput
{
   double   atr;
   double   velocity;
   double   acceleration;
   double   convexity;
   double   convSmooth;
   double   efficiency;
   double   displacement;
   bool     bullImpulse;
   bool     bearImpulse;
   bool     bullMomDecay;
   bool     bearMomDecay;
   bool     bullConvShift;
   bool     bearConvShift;
   bool     vd70;
   bool     vd50;
};

//==================================================================
// 2. COMPUTE PHYSICS - Port of f_phys from Letra 37
//==================================================================

void ComputePhysics(double &closeArr[], double &highArr[], double &lowArr[],
                    int bars, LetraPhysicsOutput &out)
{
   // Initialize output
   out.atr = 0.0;
   out.velocity = 0.0;
   out.acceleration = 0.0;
   out.convexity = 0.0;
   out.convSmooth = 0.0;
   out.efficiency = 0.0;
   out.displacement = 0.0;
   out.bullImpulse = false;
   out.bearImpulse = false;
   out.bullMomDecay = false;
   out.bearMomDecay = false;
   out.bullConvShift = false;
   out.bearConvShift = false;
   out.vd70 = false;
   out.vd50 = false;

   if(bars < InpATRLen + 2) return;

   //--- Manual ATR (SMA of true range over InpATRLen)
   double sumTR = 0.0;
   for(int i = 0; i < InpATRLen; i++)
   {
      if(i + 1 >= bars) break;
      double trueHigh = highArr[i];
      double trueLow  = lowArr[i];
      double prevClose = closeArr[i + 1];
      if(prevClose > trueHigh) trueHigh = prevClose;
      if(prevClose < trueLow)  trueLow  = prevClose;
      sumTR += (trueHigh - trueLow);
   }
   out.atr = sumTR / InpATRLen;
   if(out.atr <= 0.0) out.atr = 1e-10;

   //--- Velocity: EMA(close - close[1], 3)
   //    We compute from recent bars, using EMA with period 3
   double velAlpha = 2.0 / (3.0 + 1.0);
   double vel = 0.0;
   double prevVel = 0.0;
   // Initialize with first difference
   if(bars > 1) vel = closeArr[0] - closeArr[1];
   // Apply EMA over available bars (up to 20 for convergence)
   int velBars = (bars - 1 < 20) ? bars - 1 : 20;
   double emaVel = (velBars > 0 && bars > 1) ? closeArr[velBars - 1] - closeArr[velBars] : 0.0;
   for(int i = velBars - 2; i >= 0; i--)
   {
      double diff = closeArr[i] - closeArr[i + 1];
      emaVel = velAlpha * diff + (1.0 - velAlpha) * emaVel;
   }
   vel = emaVel;

   // Previous velocity (shift by 1)
   double emaVelPrev = (velBars > 0 && bars > 2) ? closeArr[velBars] - closeArr[velBars + 1 < bars ? velBars + 1 : velBars] : 0.0;
   for(int i = velBars - 2; i >= 1; i--)
   {
      double diff = closeArr[i] - closeArr[i + 1];
      emaVelPrev = velAlpha * diff + (1.0 - velAlpha) * emaVelPrev;
   }
   prevVel = emaVelPrev;

   out.velocity = vel;

   //--- Acceleration: vel - vel[1]
   out.acceleration = vel - prevVel;

   //--- Convexity (jerk): acc - acc[1]
   // We need acc[1] which is vel[1] - vel[2]
   // vel[2] requires another step back
   double emaVelPrev2 = (velBars > 0 && bars > 3) ? closeArr[velBars + 1 < bars ? velBars + 1 : velBars] - closeArr[velBars + 2 < bars ? velBars + 2 : velBars] : 0.0;
   for(int i = velBars - 2; i >= 2; i--)
   {
      double diff = closeArr[i] - closeArr[i + 1];
      emaVelPrev2 = velAlpha * diff + (1.0 - velAlpha) * emaVelPrev2;
   }
   double accPrev = prevVel - emaVelPrev2;
   out.convexity = out.acceleration - accPrev;

   //--- ConvSmooth: EMA(convexity, 3) - simplified as single-bar EMA update
   double convAlpha = 2.0 / (3.0 + 1.0);
   out.convSmooth = convAlpha * out.convexity + (1.0 - convAlpha) * 0.0;
   // Note: proper multi-bar convSmooth requires series. Use EMA approach with state.

   //--- Efficiency: abs(close - close[effLen]) / sum(abs(close-close[1]), effLen)
   int effLen = InpEffLen;
   if(effLen >= bars) effLen = bars - 1;
   if(effLen > 0)
   {
      double moveAbs = MathAbs(closeArr[0] - closeArr[effLen]);
      double pathSum = 0.0;
      for(int i = 0; i < effLen; i++)
      {
         if(i + 1 < bars)
            pathSum += MathAbs(closeArr[i] - closeArr[i + 1]);
      }
      out.efficiency = (pathSum > 0.0) ? moveAbs / pathSum : 0.0;
   }

   //--- Displacement: (high - low) / ATR
   out.displacement = (highArr[0] - lowArr[0]) / out.atr;

   //--- Convexity threshold
   double convThreshold = out.atr * InpConvMult;

   //--- Bull/Bear Impulse
   // bullImpulse: eff > effThresh AND vel > vel[1] AND acc > 0 AND close > open AND disp > dispThresh
   // In bars context close > open not available directly (no open array),
   // approximate with close > close[1] for directional impulse
   out.bullImpulse = (out.efficiency > InpEffThresh &&
                      vel > prevVel &&
                      out.acceleration > 0 &&
                      closeArr[0] > closeArr[1] &&
                      out.displacement > InpDispThresh);

   out.bearImpulse = (out.efficiency > InpEffThresh &&
                      vel < prevVel &&
                      out.acceleration < 0 &&
                      closeArr[0] < closeArr[1] &&
                      out.displacement > InpDispThresh);

   //--- Momentum Decay: abs(acc) < abs(acc[1])*0.8 AND vel direction
   out.bullMomDecay = (MathAbs(out.acceleration) < MathAbs(accPrev) * 0.8 && vel > 0);
   out.bearMomDecay = (MathAbs(out.acceleration) < MathAbs(accPrev) * 0.8 && vel < 0);

   //--- Convexity Shift: convSmooth crosses threshold
   // Use state-based cross detection (simplified here)
   out.bullConvShift = (out.convSmooth > convThreshold);
   out.bearConvShift = (out.convSmooth < -convThreshold);

   //--- Velocity Decay flags
   if(MathAbs(prevVel) > 0.0)
   {
      out.vd70 = (MathAbs(vel) < MathAbs(prevVel) * 0.7);
      out.vd50 = (MathAbs(vel) < MathAbs(prevVel) * 0.5);
   }
}

//==================================================================
// 3. PHASE TO STRING - Maps phase code to canonical lifecycle string
//==================================================================

string PhaseToString(int phase)
{
   switch(phase)
   {
      case 0:  return("Point 4 Origin");
      case 1:  return("Expansion");
      case 2:  return("Expansion Pre-Convexity");
      case 3:  return("Expansion Induction");
      case 4:  return("Expansion Liquidity");
      case 5:  return("New High");
      case 6:  return("New Low");
      case 7:  return("Absorption");
      case 8:  return("Retracement");
      case 9:  return("Retracement Pre-Convexity");
      case 10: return("Retracement Induction");
      case 11: return("Retracement Liquidity");
      case 12: return("Terminal Curve");
      case 13: return("Demand Return");
      case 14: return("Supply Return");
      default: return("Point 4 Origin");
   }
}

//==================================================================
// 4. WAVE DIRECTION BY ORIGIN
//==================================================================

int WaveDirByOrigin(double origin, double closePrice, int fallbackDir)
{
   if(origin == 0.0) return(fallbackDir);
   if(closePrice > origin) return(1);
   if(closePrice < origin) return(-1);
   return(fallbackDir);
}

//==================================================================
// 5. PIVOT DETECTION HELPERS (for structure engine)
//==================================================================

// Check if bar at index 'c' is a pivot high in the given array
bool IsPivotHighArr(double &highArr[], int c, int pvLen, int maxBars)
{
   if(c < pvLen || c + pvLen >= maxBars) return(false);
   double h = highArr[c];
   for(int k = 1; k <= pvLen; k++)
   {
      if(h <= highArr[c + k]) return(false);
      if(h <= highArr[c - k]) return(false);
   }
   return(true);
}

// Check if bar at index 'c' is a pivot low in the given array
bool IsPivotLowArr(double &lowArr[], int c, int pvLen, int maxBars)
{
   if(c < pvLen || c + pvLen >= maxBars) return(false);
   double l = lowArr[c];
   for(int k = 1; k <= pvLen; k++)
   {
      if(l >= lowArr[c + k]) return(false);
      if(l >= lowArr[c - k]) return(false);
   }
   return(true);
}

//==================================================================
// 6. COMPUTE STRUCTURE ENGINE - Port of f_se from Letra 37
//    The MAIN engine: physics + swings + BOS/CHoCH + lifecycle
//==================================================================

void ComputeStructureEngine(double &closeArr[], double &highArr[], double &lowArr[],
                            int bars, int tfIdx, LetraStructureResult &result)
{
   // Initialize result
   result.dir = 0;
   result.phase = 0;
   result.swingHigh = 0.0;
   result.swingLow = 0.0;
   result.prevSwingHigh = 0.0;
   result.prevSwingLow = 0.0;
   result.bos = false;
   result.choch = false;
   result.p4h = 0.0;
   result.p4l = 0.0;
   result.inv = 0.0;
   result.tgt = 0.0;
   result.ft = 0.0;
   result.fb = 0.0;
   result.frzScore = 0.0;
   result.waveProgress = 0.0;
   result.convexityMaturity = 0.0;
   result.modelFit = 0.0;
   result.compression = 0.0;
   result.recBrk = false;
   result.recDom = 0;

   if(bars < InpPivotLen * 2 + 2) return;
   if(tfIdx < 0 || tfIdx > 5) return;

   // Get reference to persistent state for this timeframe
   LetraInternalState *st = &g_letraState[tfIdx];

   //--- Compute internal physics
   LetraPhysicsOutput phys;
   ComputePhysics(closeArr, highArr, lowArr, bars, phys);

   //--- Update convSmooth with EMA state
   double convAlpha = 2.0 / (3.0 + 1.0);
   st.prevConvSmooth = convAlpha * phys.convexity + (1.0 - convAlpha) * st.prevConvSmooth;
   phys.convSmooth = st.prevConvSmooth;

   // Update convexity shift using state-based crossing
   double convThreshold = phys.atr * InpConvMult;
   phys.bullConvShift = (phys.convSmooth > convThreshold);
   phys.bearConvShift = (phys.convSmooth < -convThreshold);

   //--- Detect swing highs/lows using pivotLen
   int pvLen = InpPivotLen;
   bool foundPivH = false;
   bool foundPivL = false;
   double pivHPrice = 0.0;
   double pivLPrice = 0.0;

   // Check for pivot at offset pvLen (confirmed pivot)
   if(IsPivotHighArr(highArr, pvLen, pvLen, bars))
   {
      foundPivH = true;
      pivHPrice = highArr[pvLen];
   }
   if(IsPivotLowArr(lowArr, pvLen, pvLen, bars))
   {
      foundPivL = true;
      pivLPrice = lowArr[pvLen];
   }

   //--- Update swing memory
   if(foundPivH)
   {
      if(st.curSwingHigh == 0.0)
         st.prevSwingHigh = pivHPrice;
      else
         st.prevSwingHigh = st.curSwingHigh;
      st.curSwingHigh = pivHPrice;
   }
   if(foundPivL)
   {
      if(st.curSwingLow == 0.0)
         st.prevSwingLow = pivLPrice;
      else
         st.prevSwingLow = st.curSwingLow;
      st.curSwingLow = pivLPrice;
   }

   //--- Pivot memory (last/prev price and direction)
   int eventDir = 0;
   double eventPrice = 0.0;
   if(foundPivH)
   {
      eventDir = 1;
      eventPrice = pivHPrice;
   }
   else if(foundPivL)
   {
      eventDir = -1;
      eventPrice = pivLPrice;
   }

   if(eventDir != 0)
   {
      st.prevPivotPrice = st.lastPivotPrice;
      st.prevPivotDir   = st.lastPivotDir;
      st.lastPivotPrice = eventPrice;
      st.lastPivotDir   = eventDir;
   }

   //--- BOS detection: close > prevSwingHigh (bull) or close < prevSwingLow (bear)
   bool bullBOS = (st.prevSwingHigh > 0.0 && closeArr[0] > st.prevSwingHigh);
   bool bearBOS = (st.prevSwingLow > 0.0  && closeArr[0] < st.prevSwingLow);

   //--- CHoCH detection: close > prevSwingHigh + ATR*chochBuffer (bull)
   bool bullCHoCH = (st.prevSwingHigh > 0.0 &&
                     closeArr[0] > st.prevSwingHigh + phys.atr * InpChochBufferATR);
   bool bearCHoCH = (st.prevSwingLow > 0.0 &&
                     closeArr[0] < st.prevSwingLow - phys.atr * InpChochBufferATR);

   //--- Impulse detection: pivot follows opposite pivot with range > ATR*impulseMult
   bool eLong  = (foundPivH && st.prevPivotDir == -1 &&
                  (pivHPrice - st.prevPivotPrice) > phys.atr * InpImpulseAtrMult);
   bool eShort = (foundPivL && st.prevPivotDir == 1 &&
                  (st.prevPivotPrice - pivLPrice) > phys.atr * InpImpulseAtrMult);

   //--- Direction / lifecycle state machine
   bool hasCtx = (st.dir != 0 && st.ft != 0.0);
   bool flipDn = (st.dir == 1 && bearCHoCH);
   bool flipUp = (st.dir == -1 && bullCHoCH);
   bool isRev  = (eLong && st.dir == -1) || (eShort && st.dir == 1) || flipUp || flipDn;
   bool spawn  = (eLong || eShort || flipUp || flipDn) && (!hasCtx || isRev);

   if(spawn)
   {
      int nd = eLong ? 1 : (eShort ? -1 : (flipUp ? 1 : -1));
      double obT = (nd == 1) ? st.lastPivotPrice : st.prevPivotPrice;
      double obB = (nd == 1) ? st.prevPivotPrice : st.lastPivotPrice;

      st.dir = nd;
      st.ft  = obT;
      st.fb  = obB;
      st.p4h = obT;
      st.p4l = obB;
      st.cycleHigh = highArr[0];
      st.cycleLow  = lowArr[0];
      st.inv = (nd == 1) ? obB : obT;

      // Target: range projection
      double rng = 0.0;
      if(st.prevSwingHigh > 0.0 && st.prevSwingLow > 0.0)
         rng = MathAbs(st.prevSwingHigh - st.prevSwingLow);
      else
         rng = phys.atr * 5.0;

      st.tgt = (nd == 1) ? obT + rng : obB - rng;

      // Reset lifecycle
      st.phaseState = 0;
      st.lastDirSeen = nd;
      st.bos1 = false;
      st.bos2 = false;
      st.protSw = 0.0;
      st.protSw2 = 0.0;
      st.indOrig = 0.0;
      st.indExt = 0.0;
      st.indBrk = false;
      st.recBrkCount = 0;
      st.extremePrice = 0.0;
   }

   //--- Track cycle high/low
   if(st.dir == 1)
   {
      if(highArr[0] > st.cycleHigh || st.cycleHigh == 0.0)
         st.cycleHigh = highArr[0];
   }
   if(st.dir == -1)
   {
      if(lowArr[0] < st.cycleLow || st.cycleLow == 0.0)
         st.cycleLow = lowArr[0];
   }

   //--- Lifecycle BOS tracking (for phase advancement)
   // Reset on direction change
   if(st.dir != st.lastDirSeen)
   {
      st.bos1 = false;
      st.bos2 = false;
      st.protSw = 0.0;
      st.protSw2 = 0.0;
      st.indOrig = 0.0;
      st.indExt = 0.0;
      st.indBrk = false;
   }
   st.lastDirSeen = st.dir;

   // Track protective swings
   if(st.dir == 1 && foundPivL)
   {
      st.protSw2 = st.protSw;
      st.protSw  = pivLPrice;
   }
   if(st.dir == -1 && foundPivH)
   {
      st.protSw2 = st.protSw;
      st.protSw  = pivHPrice;
   }

   // Opposite BOS detection for lifecycle
   bool oppBOS = false;
   if(st.dir == 1 && st.protSw > 0.0 && closeArr[0] < st.protSw)
      oppBOS = true;
   if(st.dir == -1 && st.protSw > 0.0 && closeArr[0] > st.protSw)
      oppBOS = true;

   if(!st.bos1 && oppBOS)
   {
      st.bos1 = true;
      st.indOrig = (st.dir == 1) ? st.cycleHigh : st.cycleLow;
   }
   if(st.bos1 && !st.bos2 && oppBOS && st.protSw2 > 0.0)
   {
      if(st.dir == 1 && closeArr[0] < st.protSw2)
         st.bos2 = true;
      if(st.dir == -1 && closeArr[0] > st.protSw2)
         st.bos2 = true;
   }

   // Track induction extreme
   if(st.bos1 && st.dir == 1)
   {
      if(st.indExt == 0.0 || closeArr[0] < st.indExt)
         st.indExt = closeArr[0];
   }
   if(st.bos1 && st.dir == -1)
   {
      if(st.indExt == 0.0 || closeArr[0] > st.indExt)
         st.indExt = closeArr[0];
   }

   // Induction break (reclaim of origin after bos2)
   if(st.bos2 && st.indOrig > 0.0)
   {
      if(st.dir == 1 && closeArr[0] > st.indOrig)
         st.indBrk = true;
      if(st.dir == -1 && closeArr[0] < st.indOrig)
         st.indBrk = true;
   }

   //--- Physics behaviour flags for phase advancement
   double convScore = 0.0;
   if(phys.atr * InpConvMult > 0.0)
      convScore = Clamp(MathAbs(phys.convSmooth) / (phys.atr * InpConvMult) * 50.0, 0.0, 100.0);

   double expScore = 0.0;
   if(InpEffThresh > 0.0 && InpDispThresh > 0.0)
      expScore = Clamp(phys.efficiency / InpEffThresh * 50.0 +
                       phys.displacement / InpDispThresh * 50.0, 0.0, 100.0);

   double absScore = 0.0;
   if(phys.efficiency < InpEffThresh * 0.7 && MathAbs(phys.velocity) < MathAbs(st.prevVelocity) * 0.6)
      absScore = 60.0 + convScore * 0.4;
   else
      absScore = convScore * 0.3;
   absScore = Clamp(absScore, 0.0, 100.0);

   bool momExpStrong = (phys.efficiency > InpEffThresh * 0.75 &&
                        ((st.dir == 1 && phys.velocity > 0) ||
                         (st.dir == -1 && phys.velocity < 0)));
   bool momDecaying  = (st.dir == 1) ? phys.bullMomDecay : phys.bearMomDecay;
   bool momCounter   = (st.dir == 1) ? phys.bearImpulse : phys.bullImpulse;
   bool momExhaust   = (phys.efficiency < InpEffThresh * 0.65 && absScore > 40.0);

   bool physConvexDevel  = (convScore > 35.0);
   bool physTransfer     = (convScore > 48.0 || absScore > 40.0);
   bool physCapacityLow  = (absScore > 45.0 || phys.efficiency < InpEffThresh * 0.6);

   //--- Monotonic phase state machine (advances forward only within a wave)
   if(st.dir != 0)
   {
      bool expanding = momExpStrong || eLong || eShort ||
                       ((st.dir == 1) ? phys.bullImpulse : phys.bearImpulse);

      if(st.phaseState < 1 && expanding && !physTransfer && !physCapacityLow)
         st.phaseState = 1;   // Expansion
      if(st.phaseState < 2 && st.bos1 && momDecaying && physConvexDevel)
         st.phaseState = 2;   // Expansion Pre-Convexity
      if(st.phaseState < 3 && st.bos1 && momCounter && physTransfer)
         st.phaseState = 3;   // Expansion Induction
      if(st.phaseState < 4 && st.bos2 && (momDecaying || momCounter) && physTransfer)
         st.phaseState = 4;   // Expansion Liquidity
      if(st.phaseState < 5 && st.indBrk && momExpStrong && !physCapacityLow)
         st.phaseState = 5;   // New High (bull) / New Low (bear)
      if(st.phaseState >= 5 && momExhaust && physCapacityLow)
         st.phaseState = 7;   // Absorption
      if(st.phaseState >= 5 && momCounter && !momExhaust && physTransfer)
         st.phaseState = 8;   // Retracement
   }

   //--- Export live phase (behavioral read per bar)
   int phase = st.phaseState;
   if(st.dir != 0)
   {
      if(momExhaust && physCapacityLow)
         phase = 7;  // Absorption
      else if(momCounter && physTransfer)
      {
         if(st.phaseState >= 5)
         {
            if(convScore > 40.0)
               phase = 10;  // Retracement Induction
            else if(momDecaying)
               phase = 9;   // Retracement Pre-Convexity
            else
               phase = 8;   // Retracement
         }
         else
         {
            phase = st.bos2 ? 4 : 3;  // Expansion Liquidity or Induction
         }
      }
      else if(momExpStrong)
      {
         if(st.phaseState >= 5)
            phase = st.phaseState;
         else if(st.bos2 && physTransfer)
            phase = 4;
         else if(st.bos1 && physConvexDevel)
            phase = 2;
         else
            phase = 1;
      }
      else if(momDecaying)
      {
         phase = (st.phaseState >= 5) ? st.phaseState : 4;
      }
      else if(st.phaseState == 0)
         phase = 1;
      else
         phase = st.phaseState;

      // New Low for bear wave
      if(phase == 5 && st.dir == -1)
         phase = 6;
   }

   //--- Recursive transition tracking
   // Count Phase-2 CHoCH events after extreme
   if(st.phaseState >= 5 && (bullCHoCH || bearCHoCH))
   {
      st.recBrkCount++;
   }
   // Track extreme price for dominance
   if(st.dir == 1 && st.cycleHigh > st.extremePrice)
      st.extremePrice = st.cycleHigh;
   if(st.dir == -1 && (st.extremePrice == 0.0 || st.cycleLow < st.extremePrice))
      st.extremePrice = st.cycleLow;

   //--- Compute dominance transfer from recBrk count and retrace fraction
   double retraceFrac = 0.0;
   if(st.dir == 1 && st.extremePrice > st.inv && st.inv > 0.0)
      retraceFrac = (st.extremePrice - closeArr[0]) / (st.extremePrice - st.inv);
   else if(st.dir == -1 && st.inv > st.extremePrice && st.extremePrice > 0.0)
      retraceFrac = (closeArr[0] - st.extremePrice) / (st.inv - st.extremePrice);
   retraceFrac = Clamp(retraceFrac, 0.0, 1.0);

   int recDom = 0;
   if(st.recBrkCount >= 2 && retraceFrac > 0.5)
      recDom = -st.dir;  // dominance transferring to opposing side

   //--- Compute waveProgress from phaseState
   double wp = 10.0;
   switch(st.phaseState)
   {
      case 0:  wp = 10.0; break;
      case 1:  wp = 25.0; break;
      case 2:  wp = 40.0; break;
      case 3:  wp = 55.0; break;
      case 4:  wp = 68.0; break;
      case 5:  wp = 80.0; break;
      case 6:  wp = 80.0; break;
      case 7:  wp = 92.0; break;
      default: wp = 85.0; break;
   }

   //--- Compute convexityMaturity from convScore
   double cm = Clamp(convScore, 0.0, 100.0);

   //--- Compute modelFit from expansion/absorption/convexity scores
   double bestScore = expScore;
   if(absScore > bestScore) bestScore = absScore;
   if(convScore > bestScore) bestScore = convScore;
   double mf = Clamp(bestScore * 0.70 + ((st.dir != 0) ? 30.0 : 0.0), 0.0, 100.0);

   //--- Compute compression index:
   //    (1 - disp/dispThresh)*60 + (1 - eff/effThresh)*40 clamped 0-100
   double compDisp = 0.0;
   if(InpDispThresh > 0.0)
      compDisp = (1.0 - phys.displacement / InpDispThresh) * 60.0;
   double compEff = 0.0;
   if(InpEffThresh > 0.0)
      compEff = (1.0 - phys.efficiency / InpEffThresh) * 40.0;
   double compression = Clamp(compDisp + compEff, 0.0, 100.0);

   //--- FRZ score candidate
   double frzS = 0.0;
   if(eLong || eShort)
      frzS += 50.0;
   frzS += expScore * 0.30 + convScore * 0.20;
   frzS = Clamp(frzS, 0.0, 100.0);

   //--- Output direction: origin-based
   int dirLabel = st.dir;
   if(st.inv > 0.0)
   {
      if(closeArr[0] > st.inv) dirLabel = 1;
      else if(closeArr[0] < st.inv) dirLabel = -1;
   }

   //--- Update velocity state for next tick
   st.prevVelocity = phys.velocity;

   //--- Fill result struct
   result.dir = dirLabel;
   result.phase = phase;
   result.swingHigh = st.curSwingHigh;
   result.swingLow = st.curSwingLow;
   result.prevSwingHigh = st.prevSwingHigh;
   result.prevSwingLow = st.prevSwingLow;
   result.bos = (bullBOS || bearBOS);
   result.choch = (bullCHoCH || bearCHoCH);
   result.p4h = st.p4h;
   result.p4l = st.p4l;
   result.inv = st.inv;
   result.tgt = st.tgt;
   result.ft = st.ft;
   result.fb = st.fb;
   result.frzScore = frzS;
   result.waveProgress = wp / 100.0;
   result.convexityMaturity = cm / 100.0;
   result.modelFit = mf / 100.0;
   result.compression = compression;
   result.recBrk = (st.recBrkCount > 0);
   result.recDom = recDom;
}

//==================================================================
// 7. UPDATE ALL LETRA ENGINES - Multi-TF instantiation
//==================================================================

void UpdateAllLetraEngines()
{
   int dataBars = 200;  // Number of bars to retrieve per timeframe

   for(int i = 0; i < 6; i++)
   {
      double closeData[];
      double highData[];
      double lowData[];

      // Copy data from the appropriate timeframe
      if(!CopyTFData(i, dataBars, closeData, highData, lowData))
         continue;

      int copied = ArraySize(closeData);
      if(copied < InpPivotLen * 2 + 2)
         continue;

      // Run structure engine for this timeframe
      ComputeStructureEngine(closeData, highData, lowData, copied, i, g_letra[i]);
   }

   //--- Compute fractal stack alignment
   int stackBull = 0;
   int stackBear = 0;
   for(int i = 0; i < 6; i++)
   {
      if(g_letra[i].dir == 1)  stackBull++;
      if(g_letra[i].dir == -1) stackBear++;
   }

   if(stackBull > stackBear)
      g_fractalStackDir = 1;
   else if(stackBear > stackBull)
      g_fractalStackDir = -1;
   else
      g_fractalStackDir = 0;

   int maxStack = stackBull;
   if(stackBear > maxStack) maxStack = stackBear;
   g_fractalStackScore = (maxStack / 6.0) * 100.0;
}

//==================================================================
// 8. ENGINE 1A OUTPUT HELPERS
//==================================================================

// Get Engine 1A current phase string (from M5 = index 2)
string GetEngine1APhase()
{
   return(PhaseToString(g_letra[2].phase));
}

// Get Engine 1A phase confidence (from fractal context + model fit + wave progress)
double GetEngine1AConfidence()
{
   double fracCtx = g_fractalStackScore;
   double mf = g_letra[2].modelFit * 100.0;
   double wp = g_letra[2].waveProgress * 100.0;
   double conf = fracCtx * 0.50 + mf * 0.30 + wp * 0.20;
   return(Clamp(conf, 20.0, 100.0));
}

//+------------------------------------------------------------------+
