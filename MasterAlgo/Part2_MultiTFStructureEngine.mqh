//+------------------------------------------------------------------+
//| Part2_MultiTFStructureEngine.mqh                                  |
//| MASTER ALGO - Multi-Timeframe Structure Engine                    |
//| Port of Letra's f_se() - runs independently on each fixed TF     |
//| Produces: swings, BOS, CHoCH, direction, point4, invalidation,   |
//|           targets, lifecycle phase, wave progress per timeframe   |
//+------------------------------------------------------------------+
#property strict

//==================================================================
// MULTI-TF STRUCTURE ENGINE
// 
// Each of the 6 fixed timeframes (M1/M3/M5/M15/H1/H4) gets its own
// independent structure engine instance. The engine detects:
//   - Swing highs/lows (pivot detection)
//   - Break of Structure (BOS)
//   - Change of Character (CHoCH) with ATR buffer
//   - Impulse legs
//   - Wave direction (origin-based)
//   - Point 4 order block zones
//   - Invalidation levels
//   - Target projections
//   - Monotonic lifecycle phase (0-14)
//   - Wave progress, convexity maturity, model fit
//
// This is the SOLE source of structural truth - no chart-dependent
// structure exists. Fractal stack alignment is computed from these.
//==================================================================

//--- Per-TF persistent state (stored between ticks)
struct TFEngineState
{
   // ATR handle for this TF
   int    atrHandle;
   
   // Series data
   double closeSeries[];
   double highSeries[];
   double lowSeries[];
   double openSeries[];
   int    barsLoaded;
   
   // Swing memory
   double curSwingHigh;
   double curSwingLow;
   double prevSwingHigh;
   double prevSwingLow;
   
   // Pivot memory (for impulse + order-block)
   double lastPivotPrice;
   int    lastPivotDir;   // 1=high, -1=low
   double prevPivotPrice;
   int    prevPivotDir;
   
   // Direction / lifecycle state machine
   int    direction;       // 1=bull, -1=bear, 0=none
   double flipTop;
   double flipBot;
   double p4High;
   double p4Low;
   double invalidation;
   double target;
   double cycleHigh;
   double cycleLow;
   
   // Lifecycle monotonic state
   int    phaseState;      // 0-8 monotonic
   int    lastDirSeen;
   
   // BOS tracking
   bool   bos1;
   bool   bos2;
   double protSwing;
   double protSwing2;
   double indOrig;
   double indExt;
   bool   indBrk;
   
   // Recursive tracking
   int    recursiveBreaks;
   bool   recursiveArmed;
   double recursiveDominance;
   
   // Output scores
   double waveProgress;
   double convexityMaturity;
   double modelFit;
   double compression;
};

// Global array of per-TF engine states
TFEngineState g_tfState[TF_COUNT];

//==================================================================
// INITIALIZATION
//==================================================================
void InitStructureEngines()
{
   for(int i = 0; i < TF_COUNT; i++)
   {
      g_tfState[i].atrHandle = INVALID_HANDLE;
      g_tfState[i].barsLoaded = 0;
      g_tfState[i].curSwingHigh = 0;
      g_tfState[i].curSwingLow = 0;
      g_tfState[i].prevSwingHigh = 0;
      g_tfState[i].prevSwingLow = 0;
      g_tfState[i].lastPivotPrice = 0;
      g_tfState[i].lastPivotDir = 0;
      g_tfState[i].prevPivotPrice = 0;
      g_tfState[i].prevPivotDir = 0;
      g_tfState[i].direction = 0;
      g_tfState[i].flipTop = 0;
      g_tfState[i].flipBot = 0;
      g_tfState[i].p4High = 0;
      g_tfState[i].p4Low = 0;
      g_tfState[i].invalidation = 0;
      g_tfState[i].target = 0;
      g_tfState[i].cycleHigh = 0;
      g_tfState[i].cycleLow = 0;
      g_tfState[i].phaseState = 0;
      g_tfState[i].lastDirSeen = 0;
      g_tfState[i].bos1 = false;
      g_tfState[i].bos2 = false;
      g_tfState[i].protSwing = 0;
      g_tfState[i].protSwing2 = 0;
      g_tfState[i].indOrig = 0;
      g_tfState[i].indExt = 0;
      g_tfState[i].indBrk = false;
      g_tfState[i].recursiveBreaks = 0;
      g_tfState[i].recursiveArmed = true;
      g_tfState[i].recursiveDominance = 0;
      g_tfState[i].waveProgress = 0;
      g_tfState[i].convexityMaturity = 0;
      g_tfState[i].modelFit = 50;
      g_tfState[i].compression = 0;
      
      // Create ATR handle for each TF
      ENUM_TIMEFRAMES tf = LayerToTimeframe((ENUM_TF_LAYER)i);
      g_tfState[i].atrHandle = iATR(_Symbol, tf, InpATRLen);
      if(g_tfState[i].atrHandle == INVALID_HANDLE)
         Print("Failed to create ATR handle for ", LayerName((ENUM_TF_LAYER)i));
   }
}

//==================================================================
// REFRESH TF DATA - Load OHLC series for a specific timeframe
//==================================================================
bool RefreshTFData(ENUM_TF_LAYER layer, int barsNeeded = 300)
{
   ENUM_TIMEFRAMES tf = LayerToTimeframe(layer);
   TFEngineState *state = GetPointer(g_tfState[layer]);
   
   ArraySetAsSeries(state.closeSeries, true);
   ArraySetAsSeries(state.highSeries, true);
   ArraySetAsSeries(state.lowSeries, true);
   ArraySetAsSeries(state.openSeries, true);
   
   int c1 = CopyClose(_Symbol, tf, 0, barsNeeded, state.closeSeries);
   int c2 = CopyHigh(_Symbol, tf, 0, barsNeeded, state.highSeries);
   int c3 = CopyLow(_Symbol, tf, 0, barsNeeded, state.lowSeries);
   int c4 = CopyOpen(_Symbol, tf, 0, barsNeeded, state.openSeries);
   
   if(c1 < 50 || c2 < 50 || c3 < 50 || c4 < 50)
      return(false);
      
   state.barsLoaded = MathMin(c1, MathMin(c2, MathMin(c3, c4)));
   return(true);
}

//--- Get ATR for a specific TF at shift
double GetTFAtr(ENUM_TF_LAYER layer, int shift)
{
   if(g_tfState[layer].atrHandle == INVALID_HANDLE) return(0.0);
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(g_tfState[layer].atrHandle, 0, shift, 1, buf) < 1) return(0.0);
   return(buf[0]);
}

//==================================================================
// PIVOT DETECTION ON TF DATA
//==================================================================
bool IsTFPivotHigh(ENUM_TF_LAYER layer, int c)
{
   TFEngineState *s = GetPointer(g_tfState[layer]);
   if(c <= 0 || c >= s.barsLoaded - InpPivotLen) return(false);
   double h = s.highSeries[c];
   for(int k = 1; k <= InpPivotLen; k++)
   {
      if(c + k >= s.barsLoaded || c - k < 0) return(false);
      if(h <= s.highSeries[c + k]) return(false);
      if(h <= s.highSeries[c - k]) return(false);
   }
   return(true);
}

bool IsTFPivotLow(ENUM_TF_LAYER layer, int c)
{
   TFEngineState *s = GetPointer(g_tfState[layer]);
   if(c <= 0 || c >= s.barsLoaded - InpPivotLen) return(false);
   double l = s.lowSeries[c];
   for(int k = 1; k <= InpPivotLen; k++)
   {
      if(c + k >= s.barsLoaded || c - k < 0) return(false);
      if(l >= s.lowSeries[c + k]) return(false);
      if(l >= s.lowSeries[c - k]) return(false);
   }
   return(true);
}

//==================================================================
// CORE STRUCTURE ENGINE - Runs on one TF per call
// This is the MQL5 port of Letra's f_se() function
//==================================================================
void RunStructureEngine(ENUM_TF_LAYER layer)
{
   TFEngineState *s = GetPointer(g_tfState[layer]);
   if(s.barsLoaded < 50) return;
   
   double atr = GetTFAtr(layer, 1);
   if(atr <= 0) return;
   
   // Current bar reference (shift 1 = last closed bar on this TF)
   int shift = 1;
   double closeNow = s.closeSeries[shift];
   double highNow = s.highSeries[shift];
   double lowNow = s.lowSeries[shift];
   double openNow = s.openSeries[shift];
   
   //--- PHYSICS ON THIS TF ---
   // Velocity
   double vel = 0, acc = 0, conv = 0, convSm = 0;
   double eff = 0, disp = 0;
   if(s.barsLoaded > InpEffLen + 5)
   {
      // Simple velocity (EMA approximation via 3-bar)
      vel = (s.closeSeries[shift] - s.closeSeries[shift+1]);
      double vel1 = (s.closeSeries[shift+1] - s.closeSeries[shift+2]);
      double vel2 = (s.closeSeries[shift+2] - s.closeSeries[shift+3]);
      vel = (vel + vel1 + vel2) / 3.0; // crude EMA(3) approximation
      
      double velPrev = (vel1 + vel2 + (s.closeSeries[shift+3] - s.closeSeries[shift+4])) / 3.0;
      acc = vel - velPrev;
      conv = acc - (velPrev - ((vel2 + (s.closeSeries[shift+3] - s.closeSeries[shift+4]) + (s.closeSeries[shift+4] - s.closeSeries[shift+5])) / 3.0));
      convSm = conv; // simplified (would be EMA(conv,3) in production)
      
      // Efficiency
      double move = MathAbs(s.closeSeries[shift] - s.closeSeries[shift + InpEffLen]);
      double pathSum = 0;
      for(int i = shift; i < shift + InpEffLen && i < s.barsLoaded - 1; i++)
         pathSum += MathAbs(s.closeSeries[i] - s.closeSeries[i+1]);
      eff = (pathSum > 0) ? move / pathSum : 0.0;
      
      // Displacement
      disp = (s.highSeries[shift] - s.lowSeries[shift]) / MathMax(atr, 1e-10);
   }
   
   // Physics flags
   bool bullImp = (eff > InpEffThresh && vel > velPrev && acc > 0 && closeNow > openNow && disp > InpDispThresh);
   bool bearImp = (eff > InpEffThresh && vel < velPrev && acc < 0 && closeNow < openNow && disp > InpDispThresh);
   bool bullDec = (MathAbs(acc) < MathAbs(acc) * 0.8 && vel > 0); // simplified
   bool bearDec = (MathAbs(acc) < MathAbs(acc) * 0.8 && vel < 0);
   
   double velPrev = vel - acc; // reconstruct for flag checks
   bool momExpStrong = (eff > InpEffThresh * 0.75 && (s.direction == 1 ? vel > 0 : vel < 0));
   bool momDecaying = (s.direction == 1 ? bullDec : bearDec);
   bool momCounter = (s.direction == 1 ? bearImp : bullImp);
   bool momExhaust = (eff < InpEffThresh * 0.65);
   
   double convScore = MathMin(MathAbs(convSm) / MathMax(atr * InpConvMult, 1e-10) * 50.0, 100.0);
   double expScore = MathMin(eff / MathMax(InpEffThresh, 1e-10) * 50.0 + disp / MathMax(InpDispThresh, 1e-10) * 50.0, 100.0);
   double absScore = (eff < InpEffThresh * 0.7 && MathAbs(vel) < MathAbs(velPrev) * 0.6) ? 
                     60.0 + convScore * 0.4 : convScore * 0.3;
   
   bool physConvexDevel = (convScore > 35.0);
   bool physTransfer = (convScore > 48.0 || absScore > 40.0);
   bool physCapacityLow = (absScore > 45.0 || eff < InpEffThresh * 0.6);
   
   // Compression index (0-100, high = tight)
   double compIdx = MathMin(100.0, MathMax(0.0, 
      (1.0 - MathMin(disp / MathMax(InpDispThresh, 1e-10), 1.0)) * 60.0 +
      (1.0 - MathMin(eff / MathMax(InpEffThresh, 1e-10), 1.0)) * 40.0));
   s.compression = compIdx;
   
   //--- SWING DETECTION ---
   int centerShift = InpPivotLen + 1;
   double pivotH = 0, pivotL = 0;
   bool hasPivH = false, hasPivL = false;
   
   if(centerShift < s.barsLoaded - InpPivotLen)
   {
      if(IsTFPivotHigh(layer, centerShift))
      {
         pivotH = s.highSeries[centerShift];
         hasPivH = true;
      }
      if(IsTFPivotLow(layer, centerShift))
      {
         pivotL = s.lowSeries[centerShift];
         hasPivL = true;
      }
   }
   
   // Update swing memory
   if(hasPivH)
   {
      s.prevSwingHigh = (s.curSwingHigh == 0) ? pivotH : s.curSwingHigh;
      s.curSwingHigh = pivotH;
   }
   if(hasPivL)
   {
      s.prevSwingLow = (s.curSwingLow == 0) ? pivotL : s.curSwingLow;
      s.curSwingLow = pivotL;
   }
   
   //--- PIVOT MEMORY (for impulse + order-block) ---
   int pivotDir = 0;
   double pivotPrice = 0;
   if(hasPivH) { pivotDir = 1; pivotPrice = pivotH; }
   else if(hasPivL) { pivotDir = -1; pivotPrice = pivotL; }
   
   if(pivotDir != 0)
   {
      s.prevPivotPrice = s.lastPivotPrice;
      s.prevPivotDir = s.lastPivotDir;
      s.lastPivotPrice = pivotPrice;
      s.lastPivotDir = pivotDir;
   }
   
   //--- BOS / CHoCH ---
   bool bullBOS = (s.prevSwingHigh > 0 && closeNow > s.prevSwingHigh);
   bool bearBOS = (s.prevSwingLow > 0 && closeNow < s.prevSwingLow);
   bool bullCH = (s.prevSwingHigh > 0 && closeNow > s.prevSwingHigh + atr * InpChochBufferATR);
   bool bearCH = (s.prevSwingLow > 0 && closeNow < s.prevSwingLow - atr * InpChochBufferATR);
   
   //--- IMPULSE DETECTION ---
   bool eLong = (hasPivH && s.prevPivotDir == -1 && 
                 (pivotH - s.prevPivotPrice) > atr * InpImpulseAtrMult);
   bool eShort = (hasPivL && s.prevPivotDir == 1 && 
                  (s.prevPivotPrice - pivotL) > atr * InpImpulseAtrMult);
   
   //--- DIRECTION / POINT4 / TARGET STATE MACHINE ---
   bool hasCtx = (s.direction != 0 && s.flipTop > 0);
   bool flipDn = (s.direction == 1 && bearCH);
   bool flipUp = (s.direction == -1 && bullCH);
   bool isRev = (eLong && s.direction == -1) || (eShort && s.direction == 1) || flipUp || flipDn;
   bool spawn = (eLong || eShort || flipUp || flipDn) && (!hasCtx || isRev);
   
   if(spawn)
   {
      int nd = eLong ? 1 : eShort ? -1 : flipUp ? 1 : -1;
      double hi = MathMax(s.lastPivotPrice, s.prevPivotPrice);
      double lo = MathMin(s.lastPivotPrice, s.prevPivotPrice);
      double obT = hi;
      double obB = lo;
      
      s.direction = nd;
      s.flipTop = obT;
      s.flipBot = obB;
      s.p4High = obT;
      s.p4Low = obB;
      s.cycleHigh = highNow;
      s.cycleLow = lowNow;
      s.invalidation = (nd == 1) ? lo : hi;
      
      double rng = (s.prevSwingHigh > 0 && s.prevSwingLow > 0) ? 
                   MathAbs(s.prevSwingHigh - s.prevSwingLow) : atr * 5.0;
      s.target = (nd == 1) ? obT + rng : obB - rng;
      
      // Reset lifecycle
      s.phaseState = 0;
      s.bos1 = false;
      s.bos2 = false;
      s.protSwing = 0;
      s.protSwing2 = 0;
      s.indOrig = 0;
      s.indExt = 0;
      s.indBrk = false;
      s.recursiveBreaks = 0;
      s.recursiveArmed = true;
      s.recursiveDominance = 0;
   }
   
   // Update cycle extremes
   if(s.direction == 1)
      s.cycleHigh = MathMax(s.cycleHigh, highNow);
   if(s.direction == -1)
      s.cycleLow = (s.cycleLow == 0) ? lowNow : MathMin(s.cycleLow, lowNow);
   
   //--- LIFECYCLE BOS TRACKING ---
   bool reset = (s.direction != s.lastDirSeen);
   s.lastDirSeen = s.direction;
   
   if(reset)
   {
      s.bos1 = false;
      s.bos2 = false;
      s.protSwing = 0;
      s.protSwing2 = 0;
      s.indOrig = 0;
      s.indExt = 0;
      s.indBrk = false;
   }
   
   // Track protective swings
   if(s.direction == 1 && hasPivL)
   {
      s.protSwing2 = s.protSwing;
      s.protSwing = pivotL;
   }
   if(s.direction == -1 && hasPivH)
   {
      s.protSwing2 = s.protSwing;
      s.protSwing = pivotH;
   }
   
   // Opposing BOS detection
   bool oppBOS = (s.direction == 1 && s.protSwing > 0 && closeNow < s.protSwing) ||
                 (s.direction == -1 && s.protSwing > 0 && closeNow > s.protSwing);
   
   if(!s.bos1 && oppBOS)
   {
      s.bos1 = true;
      s.indOrig = (s.direction == 1) ? s.cycleHigh : s.cycleLow;
   }
   if(s.bos1 && !s.bos2 && oppBOS && s.protSwing2 > 0)
   {
      bool deeper = (s.direction == 1 ? closeNow < s.protSwing2 : closeNow > s.protSwing2);
      if(deeper) s.bos2 = true;
   }
   
   // Inducement extension tracking
   if(s.bos1 && s.direction == 1)
      s.indExt = (s.indExt == 0) ? closeNow : MathMin(s.indExt, closeNow);
   if(s.bos1 && s.direction == -1)
      s.indExt = (s.indExt == 0) ? closeNow : MathMax(s.indExt, closeNow);
   
   // Inducement break
   if(s.bos2 && s.indOrig > 0)
   {
      if(s.direction == 1 && closeNow > s.indOrig) s.indBrk = true;
      if(s.direction == -1 && closeNow < s.indOrig) s.indBrk = true;
   }
   
   //--- RECURSIVE TRANSITION TRACKING ---
   bool phase2CH = (s.direction == 1 && bearCH) || (s.direction == -1 && bullCH);
   bool atExtreme = (s.direction == 1 ? highNow >= s.cycleHigh : lowNow <= s.cycleLow);
   bool extended = (s.invalidation > 0 && 
                    MathAbs((s.direction == 1 ? s.cycleHigh : s.cycleLow) - s.invalidation) > atr * 1.5);
   
   if(reset || (atExtreme && extended))
   {
      s.recursiveBreaks = 0;
      s.recursiveArmed = true;
   }
   if((s.direction == 1 && hasPivH) || (s.direction == -1 && hasPivL))
      s.recursiveArmed = true;
   if((phase2CH || oppBOS) && s.recursiveArmed && !atExtreme)
   {
      s.recursiveBreaks++;
      s.recursiveArmed = false;
   }
   
   // Dominance transfer
   double extr = (s.direction == 1) ? s.cycleHigh : s.cycleLow;
   double fzMid = (s.flipTop > 0 && s.flipBot > 0) ? (s.flipTop + s.flipBot) / 2.0 : 0.0;
   double retrFrac = 0;
   if(fzMid > 0 && MathAbs(extr - fzMid) > 1e-10)
      retrFrac = MathAbs(extr - closeNow) / MathAbs(extr - fzMid);
   s.recursiveDominance = MathMin(100.0, MathMax(s.recursiveBreaks * (30.0 - compIdx * 0.15), retrFrac * 80.0));
   
   //--- MONOTONIC LIFECYCLE PHASE STATE MACHINE ---
   if(reset) s.phaseState = 0;
   
   if(s.direction != 0 && !reset)
   {
      bool expanding = momExpStrong || eLong || eShort || 
                       (s.direction == 1 ? bullImp : bearImp);
      
      if(s.phaseState < 1 && expanding)
         s.phaseState = 1;  // Expansion
      if(s.phaseState < 2 && s.bos1 && momDecaying && physConvexDevel)
         s.phaseState = 2;  // Pre-Convexity
      if(s.phaseState < 3 && s.bos1 && momCounter && physTransfer)
         s.phaseState = 3;  // Induction
      if(s.phaseState < 4 && s.bos2 && (momDecaying || momCounter) && physTransfer)
         s.phaseState = 4;  // Liquidity
      if(s.phaseState < 5 && s.indBrk && momExpStrong && !physCapacityLow)
         s.phaseState = 5;  // New High/Low
      if(s.phaseState >= 5 && momExhaust && physCapacityLow)
         s.phaseState = 7;  // Absorption
      if(s.phaseState >= 5 && momCounter && !momExhaust && physTransfer)
         s.phaseState = 8;  // Retracement
   }
   
   //--- LIVE BEHAVIOURAL PHASE (exported, not latched) ---
   int phase = s.phaseState;
   if(s.direction != 0)
   {
      phase = momExhaust && physCapacityLow ? 7 :
              momCounter && physTransfer ? (s.phaseState >= 5 ? (convScore > 40.0 ? 10 : momDecaying ? 9 : 8) : (s.bos2 ? 4 : 3)) :
              momExpStrong ? (s.phaseState >= 5 ? s.phaseState : (s.bos2 && physTransfer) ? 4 : (s.bos1 && physConvexDevel) ? 2 : 1) :
              momDecaying ? (s.phaseState >= 5 ? s.phaseState : 4) :
              s.phaseState == 0 ? 1 : s.phaseState;
   }
   if(phase == 5 && s.direction == -1) phase = 6; // New Low
   
   //--- WAVE PROGRESS ---
   double wp = (s.phaseState == 0) ? 10.0 : (s.phaseState == 1) ? 25.0 : 
               (s.phaseState == 2) ? 40.0 : (s.phaseState == 3) ? 55.0 :
               (s.phaseState == 4) ? 68.0 : (s.phaseState == 5) ? 80.0 :
               (s.phaseState == 7) ? 92.0 : 85.0;
   s.waveProgress = wp;
   
   //--- CONVEXITY MATURITY ---
   double cm = MathMin(convScore, 100.0);
   s.convexityMaturity = cm;
   
   //--- MODEL FIT ---
   double mf = MathMin(MathMax(expScore, MathMax(absScore, convScore)) * 0.70 + 
               (s.direction != 0 ? 30.0 : 0.0), 100.0);
   s.modelFit = mf;
   
   //--- WRITE OUTPUT TO GLOBAL STRUCTURE ---
   StructureEngineOutput *out = GetPointer(g_structure[layer]);
   
   // Direction = origin-based (live price vs invalidation)
   out.direction = WaveDirByOrigin(s.invalidation, closeNow, s.direction);
   out.phaseCode = phase;
   out.phase = (ENUM_WAVE_PHASE)phase;
   out.swingHigh = s.curSwingHigh;
   out.swingLow = s.curSwingLow;
   out.prevSwingHigh = s.prevSwingHigh;
   out.prevSwingLow = s.prevSwingLow;
   out.bosSignal = bullBOS ? 1 : bearBOS ? -1 : 0;
   out.chochSignal = bullCH ? 1 : bearCH ? -1 : 0;
   out.point4High = s.p4High;
   out.point4Low = s.p4Low;
   out.invalidation = s.invalidation;
   out.target = s.target;
   out.flipTop = s.flipTop;
   out.flipBot = s.flipBot;
   out.waveProgress = wp;
   out.convexityMaturity = cm;
   out.modelFit = mf;
   out.compression = compIdx;
   out.recursiveBreaks = s.recursiveBreaks;
   out.recursiveDominance = s.recursiveDominance;
}

//==================================================================
// RUN ALL STRUCTURE ENGINES (called once per new bar)
//==================================================================
void UpdateAllStructureEngines()
{
   for(int i = 0; i < TF_COUNT; i++)
   {
      ENUM_TF_LAYER layer = (ENUM_TF_LAYER)i;
      if(RefreshTFData(layer, 300))
         RunStructureEngine(layer);
   }
}

//==================================================================
// FRACTAL STACK ALIGNMENT
// Computes how unified the 6 fixed-TF structure layers are
// Higher TFs (H4, H1) carry more contextual weight
//==================================================================
void ComputeFractalStack()
{
   int bullCount = 0;
   int bearCount = 0;
   
   for(int i = 0; i < TF_COUNT; i++)
   {
      if(g_structure[i].direction == 1) bullCount++;
      if(g_structure[i].direction == -1) bearCount++;
   }
   
   g_fractalStack.bullCount = bullCount;
   g_fractalStack.bearCount = bearCount;
   g_fractalStack.direction = (bullCount > bearCount) ? 1 : (bearCount > bullCount) ? -1 : 0;
   g_fractalStack.score = MathMax(bullCount, bearCount) / 6.0 * 100.0;
   
   // Weighted context score (higher TFs matter more)
   // Weights: H4=30, H1=26, M15=20, M5=14, M3=6, M1=4
   double weights[] = {4.0, 6.0, 14.0, 20.0, 26.0, 30.0};
   double ctxScore = 0;
   int stackDir = g_fractalStack.direction;
   
   if(stackDir != 0)
   {
      for(int i = 0; i < TF_COUNT; i++)
      {
         if(g_structure[i].direction == stackDir)
            ctxScore += weights[i];
      }
   }
   g_fractalStack.contextScore = MathMin(ctxScore, 100.0);
}

//==================================================================
// WAVE SPAWN ENGINE (from Letra Section 13 - governs execution context)
// Uses M5 (TF_M5) structure engine as primary authority
//==================================================================
void UpdateWaveSpawnEngine()
{
   int l0Dir = g_structure[TF_M5].direction;
   
   // Spawn condition: M5 structure flips direction
   bool allowSpawn = (l0Dir != 0 && l0Dir != g_direction);
   
   if(allowSpawn)
   {
      int newDir = l0Dir;
      
      // Use M5 engine's point4 as the order block
      double obTop = g_structure[TF_M5].point4High;
      double obBot = g_structure[TF_M5].point4Low;
      
      if(obTop == 0 && obBot == 0)
      {
         obTop = g_structure[TF_M5].flipTop;
         obBot = g_structure[TF_M5].flipBot;
      }
      
      g_direction = newDir;
      g_flipTop = obTop;
      g_flipBot = obBot;
      g_point4High = obTop;
      g_point4Low = obBot;
      g_obBirthBar = 0; // reset age
      g_cycleHigh = (ArraySize(High) > 1) ? High[1] : 0;
      g_cycleLow = (ArraySize(Low) > 1) ? Low[1] : 0;
      g_isRecursive = false;
      g_entryCycle = 0;
      g_waveDepth = 0;
      g_recursiveComplete = false;
      
      // Find inducement price
      double atrNow = GetATR(1);
      g_flipzoneInducPrice = 0;
      g_flipzoneInducLow = 0;
      g_flipzoneInducHigh = 0;
      
      if(g_prevPivotShift > 0 && obTop > 0 && obBot > 0)
      {
         double inducP = FindInducPrice(g_prevPivotShift, obTop, obBot, InpInducLookbackBars);
         if(inducP > 0)
         {
            g_flipzoneInducPrice = inducP;
            g_flipzoneInducLow = inducP - atrNow * InpInducZoneATRWidth;
            g_flipzoneInducHigh = inducP + atrNow * InpInducZoneATRWidth;
         }
      }
      
      // Reset inducement zones
      g_inducZoneLow = 0;
      g_inducZoneHigh = 0;
      
      Print("WAVE SPAWN: dir=", newDir, " P4=[", obBot, ",", obTop, "]");
   }
   
   // Update cycle extremes from chart data
   if(g_direction == 1 && ArraySize(High) > 1 && High[1] > g_cycleHigh)
      g_cycleHigh = High[1];
   if(g_direction == -1 && ArraySize(Low) > 1)
   {
      if(g_cycleLow == 0 || Low[1] < g_cycleLow)
         g_cycleLow = Low[1];
   }
   
   // Increment OB age
   if(g_obBirthBar >= 0) g_obBirthBar++;
   
   // Update display phase from M5 engine (Engine 1A authority)
   g_currentPhase = g_structure[TF_M5].phase;
   g_currentDisplayPhase = PhaseToString(g_currentPhase);
   g_waveProgress = g_structure[TF_M5].waveProgress;
}

//==================================================================
// RECURSIVE WAVE TRIGGER (from Letra Section 13 recursive spawning)
//==================================================================
void CheckRecursiveTrigger()
{
   if(g_direction == 0) return;
   if(g_flipTop == 0 || g_flipBot == 0) return;
   
   // Check if we're in Demand/Supply Return phase on M5
   bool inReturnPhase = (g_currentPhase == PHASE_DEMAND_RETURN || 
                         g_currentPhase == PHASE_SUPPLY_RETURN);
   if(!inReturnPhase) return;
   
   // Check for true CHoCH or structural flip
   bool trigger = false;
   double closeNow = (ArraySize(Close) > 1) ? Close[1] : 0;
   
   // Price entered demand zone (bull wave) or supply zone (bear wave)
   bool priceInDemand = (g_direction == 1 && closeNow < g_flipBot && closeNow <= g_point4High);
   bool priceInSupply = (g_direction == -1 && closeNow > g_flipTop && closeNow >= g_point4Low);
   
   // Check M5 has confirming impulse
   bool m5BullImp = (g_structure[TF_M5].bosSignal == 1);
   bool m5BearImp = (g_structure[TF_M5].bosSignal == -1);
   
   if(priceInDemand && m5BullImp && g_liqSweepOK)
      trigger = true;
   if(priceInSupply && m5BearImp && g_liqSweepOK)
      trigger = true;
   
   // Check beliefs threshold (simplified - using wave progress as proxy)
   if(g_waveProgress < 80.0) trigger = false;
   
   if(trigger && g_entryCycle < 4)
   {
      // Store current cycle state (simplified)
      g_waveGeneration++;
      g_entryCycle = MathMin(g_entryCycle + 1, 4);
      g_isRecursive = true;
      g_waveDepth = g_entryCycle;
      g_recursiveComplete = true;
      
      // Re-spawn with new structure from M5
      int nextDir = g_structure[TF_M5].direction;
      if(nextDir != 0)
      {
         g_direction = nextDir;
         g_flipTop = g_structure[TF_M5].point4High;
         g_flipBot = g_structure[TF_M5].point4Low;
         g_point4High = g_flipTop;
         g_point4Low = g_flipBot;
         g_cycleHigh = (ArraySize(High) > 1) ? High[1] : 0;
         g_cycleLow = (ArraySize(Low) > 1) ? Low[1] : 0;
         
         Print("RECURSIVE CYCLE ", g_entryCycle, " dir=", nextDir);
      }
   }
}

//==================================================================
// WAVE INVALIDATION CHECK
//==================================================================
void CheckWaveInvalidation()
{
   if(g_direction == 0) return;
   if(ArraySize(Close) < 2) return;
   
   double closeNow = Close[1];
   double atrNow = GetATR(1);
   
   bool bullInvalid = (g_direction == 1 && g_flipBot > 0 && closeNow < g_flipBot - atrNow * 0.5);
   bool bearInvalid = (g_direction == -1 && g_flipTop > 0 && closeNow > g_flipTop + atrNow * 0.5);
   
   // Hard invalidation resets the wave
   if(bullInvalid || bearInvalid)
   {
      Print("WAVE INVALIDATED: dir was ", g_direction);
      g_direction = 0;
      g_flipTop = 0;
      g_flipBot = 0;
      g_isRecursive = false;
      g_entryCycle = 0;
      g_waveDepth = 0;
      g_recursiveComplete = false;
   }
}

//==================================================================
// MASTER UPDATE FUNCTION (call from OnTick after new bar)
//==================================================================
void UpdateMultiTFStructure()
{
   // 1. Run all 6 fixed-TF structure engines
   UpdateAllStructureEngines();
   
   // 2. Compute fractal stack alignment
   ComputeFractalStack();
   
   // 3. Update wave spawn (M5-governed execution context)
   UpdateWaveSpawnEngine();
   
   // 4. Check recursive trigger
   CheckRecursiveTrigger();
   
   // 5. Check invalidation
   CheckWaveInvalidation();
}

//+------------------------------------------------------------------+
