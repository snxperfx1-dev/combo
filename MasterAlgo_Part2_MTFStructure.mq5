//+------------------------------------------------------------------+
//| MasterAlgo_Part2_MTFStructure.mq5                                |
//| Part 2: Multi-Timeframe Structure Engine (f_se port)             |
//| Contains: SE_Result struct, f_se_compute(), MTF update,          |
//|           fractal stack alignment, phase string helper            |
//| This file is #included by Part 6 (main EA file)                  |
//+------------------------------------------------------------------+
#property strict

//==================================================================
// TIMEFRAME INDEX ENUM
//==================================================================
enum ENUM_SE_TF
{
   TF_M1  = 0,
   TF_M3  = 1,
   TF_M5  = 2,
   TF_M15 = 3,
   TF_H1  = 4,
   TF_H4  = 5
};

#define SE_TF_COUNT 6

//==================================================================
// SE_RESULT STRUCT - All outputs from one timeframe's structure engine
//==================================================================
struct SE_Result
{
   int    dir;              // exported direction (origin-based)
   int    phase;            // exported lifecycle phase (live overlay)
   double swingHigh;        // current swing high
   double swingLow;         // current swing low
   double prevSwingHigh;    // previous swing high
   double prevSwingLow;     // previous swing low
   int    bosDir;           // BOS direction (1=bull, -1=bear, 0=none)
   int    chochDir;         // CHoCH direction
   double p4High;           // point-4 high (order-block top)
   double p4Low;            // point-4 low (order-block bottom)
   double invalidation;     // invalidation level (origin)
   double target;           // projected target
   double flipTop;          // flip-zone top
   double flipBot;          // flip-zone bottom
   double frzScore;         // FRZ candidate score
   double waveProgress;     // wave progress percentage
   double convexityMaturity;// convexity maturity score
   double modelFit;         // model fit score
   double compression;      // efficiency (compression metric)
   int    recursionBreaks;  // structure breaks count (bos1+bos2)
   int    recursionDominance; // phaseState (monotonic latch)
};

//==================================================================
// INPUT PARAMETERS - STRUCTURE ENGINE
//==================================================================
input int    InpSE_PivotLen      = 5;      // SE: Pivot length
input int    InpSE_StructLen     = 10;     // SE: Structure lookback
input int    InpSE_ATRLen        = 14;     // SE: ATR length
input double InpSE_EffThresh     = 0.65;   // SE: Efficiency threshold
input double InpSE_DispThresh    = 1.5;    // SE: Displacement threshold
input double InpSE_ConvMult      = 0.01;   // SE: Convexity multiplier
input double InpSE_ImpulseAtrMult= 1.5;   // SE: Impulse ATR multiple
input double InpSE_ChochBufferATR= 0.75;   // SE: CHoCH buffer (ATR fraction)
input int    InpSE_EffLen        = 10;     // SE: Efficiency calculation length

//==================================================================
// GLOBAL MTF STATE
//==================================================================
SE_Result g_se[SE_TF_COUNT];

// Internal persistent state per timeframe (needed for var-style state)
struct SE_State
{
   double curSH;
   double curSL;
   double prSH;
   double prSL;
   double lastP;
   int    lastD;
   double prevP;
   int    prevD;
   int    dir;
   double ft;
   double fb;
   double p4h;
   double p4l;
   double inv;
   double tgt;
   double cycH;
   double cycL;
   bool   bos1;
   bool   bos2;
   double protSw;
   double protSw2;
   double indOrig;
   double indExt;
   bool   indBrk;
   int    lastDirSeen;
   int    phaseState;
};

SE_State g_seState[SE_TF_COUNT];

// Fractal stack outputs
int    g_fractalStackDir   = 0;
double g_fractalStackScore = 0.0;

//==================================================================
// TIMEFRAME PERIOD MAPPING
//==================================================================
ENUM_TIMEFRAMES SE_GetPeriod(int idx)
{
   switch(idx)
   {
      case TF_M1:  return(PERIOD_M1);
      case TF_M3:  return(PERIOD_M3);
      case TF_M5:  return(PERIOD_M5);
      case TF_M15: return(PERIOD_M15);
      case TF_H1:  return(PERIOD_H1);
      case TF_H4:  return(PERIOD_H4);
   }
   return(PERIOD_M5);
}

//==================================================================
// SE STATE INITIALIZATION
//==================================================================
void SE_InitState(int idx)
{
   g_seState[idx].curSH      = 0.0;
   g_seState[idx].curSL      = 0.0;
   g_seState[idx].prSH       = 0.0;
   g_seState[idx].prSL       = 0.0;
   g_seState[idx].lastP      = 0.0;
   g_seState[idx].lastD      = 0;
   g_seState[idx].prevP      = 0.0;
   g_seState[idx].prevD      = 0;
   g_seState[idx].dir        = 0;
   g_seState[idx].ft         = 0.0;
   g_seState[idx].fb         = 0.0;
   g_seState[idx].p4h        = 0.0;
   g_seState[idx].p4l        = 0.0;
   g_seState[idx].inv        = 0.0;
   g_seState[idx].tgt        = 0.0;
   g_seState[idx].cycH       = 0.0;
   g_seState[idx].cycL       = 0.0;
   g_seState[idx].bos1       = false;
   g_seState[idx].bos2       = false;
   g_seState[idx].protSw     = 0.0;
   g_seState[idx].protSw2    = 0.0;
   g_seState[idx].indOrig    = 0.0;
   g_seState[idx].indExt     = 0.0;
   g_seState[idx].indBrk     = false;
   g_seState[idx].lastDirSeen= 0;
   g_seState[idx].phaseState = 0;

   ZeroMemory(g_se[idx]);
}

void SE_InitAll()
{
   for(int i = 0; i < SE_TF_COUNT; i++)
      SE_InitState(i);
   g_fractalStackDir   = 0;
   g_fractalStackScore = 0.0;
}

//==================================================================
// HELPER: Compute ATR from arrays
//==================================================================
double SE_ComputeATR(const double &hi[], const double &lo[], int bars, int period)
{
   if(bars < period + 1) return(0.0);
   double sum = 0.0;
   for(int i = 0; i < period; i++)
   {
      double tr = hi[i] - lo[i];
      // True range includes previous close gap but we use H-L as primary
      // (no close[i+1] available in a pure H/L array context)
      if(i + 1 < bars)
      {
         double gap1 = MathAbs(hi[i] - lo[i + 1]);
         double gap2 = MathAbs(lo[i] - hi[i + 1]);
         if(gap1 > tr) tr = gap1;
         if(gap2 > tr) tr = gap2;
      }
      sum += tr;
   }
   return(sum / period);
}

//==================================================================
// HELPER: Detect pivot high in arrays
//==================================================================
bool SE_IsPivotHigh(const double &hi[], int pos, int len, int bars)
{
   if(pos < len || pos + len >= bars) return(false);
   double h = hi[pos];
   for(int k = 1; k <= len; k++)
   {
      if(h <= hi[pos - k]) return(false);
      if(h <= hi[pos + k]) return(false);
   }
   return(true);
}

//==================================================================
// HELPER: Detect pivot low in arrays
//==================================================================
bool SE_IsPivotLow(const double &lo[], int pos, int len, int bars)
{
   if(pos < len || pos + len >= bars) return(false);
   double l = lo[pos];
   for(int k = 1; k <= len; k++)
   {
      if(l >= lo[pos - k]) return(false);
      if(l >= lo[pos + k]) return(false);
   }
   return(true);
}

//==================================================================
// F_SE_COMPUTE - Core Structure Engine (ported from PineScript f_se)
// Runs on OHLC arrays from a single timeframe, updates SE_State and
// writes results into SE_Result.
// Arrays are indexed [0]=newest, ascending = older (series order).
//==================================================================
void f_se_compute(int tfIdx,
                  const double &cl[], const double &hi[], const double &lo[],
                  int bars)
{
   if(bars < InpSE_EffLen + InpSE_PivotLen + 5) return;

   //-- PHYSICS (this tf only) -----------------------------------------------
   double _atr = SE_ComputeATR(hi, lo, bars, InpSE_ATRLen);
   if(_atr <= 0.0) _atr = 1e-10;

   // Velocity: EMA(close - close[1], 3) approximated as simple diff
   double _vel = 0.0;
   if(bars > 3)
   {
      // Simple 3-bar EMA of delta
      double d0 = cl[0] - cl[1];
      double d1 = cl[1] - cl[2];
      double d2 = cl[2] - cl[3];
      double mult = 2.0 / 4.0; // EMA(3) multiplier
      double ema = d2;
      ema = d1 * mult + ema * (1.0 - mult);
      ema = d0 * mult + ema * (1.0 - mult);
      _vel = ema;
   }

   // Prev velocity (shift by 1)
   double _velPrev = 0.0;
   if(bars > 4)
   {
      double d0p = cl[1] - cl[2];
      double d1p = cl[2] - cl[3];
      double d2p = cl[3] - cl[4];
      double mult = 2.0 / 4.0;
      double ema = d2p;
      ema = d1p * mult + ema * (1.0 - mult);
      ema = d0p * mult + ema * (1.0 - mult);
      _velPrev = ema;
   }

   double _acc     = _vel - _velPrev;
   double _accPrev = 0.0;
   // Approximate previous acceleration
   if(bars > 5)
   {
      double _velPrev2 = 0.0;
      double d0pp = cl[2] - cl[3];
      double d1pp = cl[3] - cl[4];
      double d2pp = cl[4] - cl[5];
      double mult = 2.0 / 4.0;
      double ema = d2pp;
      ema = d1pp * mult + ema * (1.0 - mult);
      ema = d0pp * mult + ema * (1.0 - mult);
      _velPrev2 = ema;
      _accPrev = _velPrev - _velPrev2;
   }

   double _conv = _acc - _accPrev;
   // CSM = EMA(conv, 3) - approximate as conv itself for simplicity
   double _csm  = _conv;

   // Efficiency: |close - close[effLen]| / sum(|close - close[1]|, effLen)
   double _mv = 0.0;
   double _ps = 0.0;
   if(bars > InpSE_EffLen)
   {
      _mv = MathAbs(cl[0] - cl[InpSE_EffLen]);
      for(int i = 0; i < InpSE_EffLen; i++)
         _ps += MathAbs(cl[i] - cl[i + 1]);
   }
   double _eff = (_ps > 0.0) ? _mv / _ps : 0.0;

   // Displacement: (high - low) / ATR (current bar)
   double _disp = (hi[0] - lo[0]) / MathMax(_atr, 1e-10);

   // Impulse conditions
   bool _bullImp = _eff > InpSE_EffThresh && _vel > _velPrev && _acc > 0
                   && cl[0] > ((hi[0] + lo[0]) * 0.5) && _disp > InpSE_DispThresh;
   bool _bearImp = _eff > InpSE_EffThresh && _vel < _velPrev && _acc < 0
                   && cl[0] < ((hi[0] + lo[0]) * 0.5) && _disp > InpSE_DispThresh;
   bool _bullDec = MathAbs(_acc) < MathAbs(_accPrev) * 0.8 && _vel > 0;
   bool _bearDec = MathAbs(_acc) < MathAbs(_accPrev) * 0.8 && _vel < 0;

   //-- SWINGS (pivot detection) -----------------------------------------------
   // Check at position = InpSE_PivotLen (confirmed pivot)
   int pvPos = InpSE_PivotLen;
   bool foundPH = SE_IsPivotHigh(hi, pvPos, InpSE_PivotLen, bars);
   bool foundPL = SE_IsPivotLow(lo, pvPos, InpSE_PivotLen, bars);

   if(foundPH)
   {
      g_seState[tfIdx].prSH  = (g_seState[tfIdx].curSH == 0.0) ? hi[pvPos] : g_seState[tfIdx].curSH;
      g_seState[tfIdx].curSH = hi[pvPos];
   }
   if(foundPL)
   {
      g_seState[tfIdx].prSL  = (g_seState[tfIdx].curSL == 0.0) ? lo[pvPos] : g_seState[tfIdx].curSL;
      g_seState[tfIdx].curSL = lo[pvPos];
   }

   //-- PIVOT MEMORY (for impulse + order-block origin) -------------------------
   int   _eD = 0;
   double _eP = 0.0;
   if(foundPH)
   {
      _eP = hi[pvPos];
      _eD = 1;
   }
   else if(foundPL)
   {
      _eP = lo[pvPos];
      _eD = -1;
   }
   if(_eD != 0)
   {
      g_seState[tfIdx].prevP = g_seState[tfIdx].lastP;
      g_seState[tfIdx].prevD = g_seState[tfIdx].lastD;
      g_seState[tfIdx].lastP = _eP;
      g_seState[tfIdx].lastD = _eD;
   }

   //-- BOS / CHoCH detection ---------------------------------------------------
   double closeNow = cl[0];
   bool _bullBOS = (g_seState[tfIdx].prSH > 0.0 && closeNow > g_seState[tfIdx].prSH);
   bool _bearBOS = (g_seState[tfIdx].prSL > 0.0 && closeNow < g_seState[tfIdx].prSL);
   bool _bullCH  = (g_seState[tfIdx].prSH > 0.0 && closeNow > g_seState[tfIdx].prSH + _atr * InpSE_ChochBufferATR);
   bool _bearCH  = (g_seState[tfIdx].prSL > 0.0 && closeNow < g_seState[tfIdx].prSL - _atr * InpSE_ChochBufferATR);

   //-- IMPULSE detection -------------------------------------------------------
   bool _eLong  = foundPH && g_seState[tfIdx].prevD == -1
                  && g_seState[tfIdx].prevP > 0.0
                  && (hi[pvPos] - g_seState[tfIdx].prevP) > _atr * InpSE_ImpulseAtrMult;
   bool _eShort = foundPL && g_seState[tfIdx].prevD == 1
                  && g_seState[tfIdx].prevP > 0.0
                  && (g_seState[tfIdx].prevP - lo[pvPos]) > _atr * InpSE_ImpulseAtrMult;

   //-- DIRECTION / POINT4 / INVALIDATION / TARGET (state machine) ---------------
   bool _hasCtx = (g_seState[tfIdx].dir != 0 && g_seState[tfIdx].ft > 0.0);
   bool _flipDn = (g_seState[tfIdx].dir == 1  && _bearCH);
   bool _flipUp = (g_seState[tfIdx].dir == -1 && _bullCH);
   bool _isRev  = (_eLong && g_seState[tfIdx].dir == -1) ||
                  (_eShort && g_seState[tfIdx].dir == 1) || _flipUp || _flipDn;
   bool _spawn  = (_eLong || _eShort || _flipUp || _flipDn) && (!_hasCtx || _isRev);

   if(_spawn)
   {
      int _nd = _eLong ? 1 : _eShort ? -1 : _flipUp ? 1 : -1;
      double _obT = (_nd == 1) ? g_seState[tfIdx].lastP : g_seState[tfIdx].prevP;
      double _obB = (_nd == 1) ? g_seState[tfIdx].prevP : g_seState[tfIdx].lastP;

      g_seState[tfIdx].dir = _nd;
      g_seState[tfIdx].ft  = _obT;
      g_seState[tfIdx].fb  = _obB;
      g_seState[tfIdx].p4h = _obT;
      g_seState[tfIdx].p4l = _obB;
      g_seState[tfIdx].cycH = hi[0];
      g_seState[tfIdx].cycL = lo[0];
      g_seState[tfIdx].inv = (_nd == 1) ? _obB : _obT;

      double _rng = (g_seState[tfIdx].prSH > 0.0 && g_seState[tfIdx].prSL > 0.0)
                    ? MathAbs(g_seState[tfIdx].prSH - g_seState[tfIdx].prSL)
                    : _atr * 5.0;
      double baseT = (_nd == 1) ? (_obT > 0.0 ? _obT : closeNow) : (_obB > 0.0 ? _obB : closeNow);
      g_seState[tfIdx].tgt = (_nd == 1) ? baseT + _rng : baseT - _rng;
   }

   // Update cycle extremes
   if(g_seState[tfIdx].dir == 1)
      g_seState[tfIdx].cycH = MathMax(g_seState[tfIdx].cycH, hi[0]);
   if(g_seState[tfIdx].dir == -1)
      g_seState[tfIdx].cycL = (g_seState[tfIdx].cycL == 0.0) ? lo[0] : MathMin(g_seState[tfIdx].cycL, lo[0]);

   //-- LIFECYCLE STATE MACHINE (monotonic, resets on direction flip) -------------
   bool _reset = (g_seState[tfIdx].dir != g_seState[tfIdx].lastDirSeen);
   g_seState[tfIdx].lastDirSeen = g_seState[tfIdx].dir;

   if(_reset)
   {
      g_seState[tfIdx].bos1       = false;
      g_seState[tfIdx].bos2       = false;
      g_seState[tfIdx].protSw     = 0.0;
      g_seState[tfIdx].protSw2    = 0.0;
      g_seState[tfIdx].indOrig    = 0.0;
      g_seState[tfIdx].indExt     = 0.0;
      g_seState[tfIdx].indBrk     = false;
      g_seState[tfIdx].phaseState = 0;
   }

   // Protected swing tracking
   if(g_seState[tfIdx].dir == 1 && foundPL)
   {
      g_seState[tfIdx].protSw2 = g_seState[tfIdx].protSw;
      g_seState[tfIdx].protSw  = lo[pvPos];
   }
   if(g_seState[tfIdx].dir == -1 && foundPH)
   {
      g_seState[tfIdx].protSw2 = g_seState[tfIdx].protSw;
      g_seState[tfIdx].protSw  = hi[pvPos];
   }

   // Opposite BOS detection (structure break against wave direction)
   bool _oppBOS = false;
   if(g_seState[tfIdx].dir == 1 && g_seState[tfIdx].protSw > 0.0 && closeNow < g_seState[tfIdx].protSw)
      _oppBOS = true;
   if(g_seState[tfIdx].dir == -1 && g_seState[tfIdx].protSw > 0.0 && closeNow > g_seState[tfIdx].protSw)
      _oppBOS = true;

   // BOS1: first structural break
   if(!g_seState[tfIdx].bos1 && _oppBOS)
   {
      g_seState[tfIdx].bos1 = true;
      g_seState[tfIdx].indOrig = (g_seState[tfIdx].dir == 1) ? g_seState[tfIdx].cycH : g_seState[tfIdx].cycL;
   }

   // BOS2: second structural break (deeper)
   if(g_seState[tfIdx].bos1 && !g_seState[tfIdx].bos2 && _oppBOS && g_seState[tfIdx].protSw2 > 0.0)
   {
      bool deeper = false;
      if(g_seState[tfIdx].dir == 1 && closeNow < g_seState[tfIdx].protSw2)
         deeper = true;
      if(g_seState[tfIdx].dir == -1 && closeNow > g_seState[tfIdx].protSw2)
         deeper = true;
      if(deeper)
         g_seState[tfIdx].bos2 = true;
   }

   // Induction extension tracking
   if(g_seState[tfIdx].bos1 && g_seState[tfIdx].dir == 1)
      g_seState[tfIdx].indExt = (g_seState[tfIdx].indExt == 0.0) ? closeNow : MathMin(g_seState[tfIdx].indExt, closeNow);
   if(g_seState[tfIdx].bos1 && g_seState[tfIdx].dir == -1)
      g_seState[tfIdx].indExt = (g_seState[tfIdx].indExt == 0.0) ? closeNow : MathMax(g_seState[tfIdx].indExt, closeNow);

   // Induction break (origin reclaim)
   if(g_seState[tfIdx].bos2 && g_seState[tfIdx].indOrig > 0.0)
   {
      if(g_seState[tfIdx].dir == 1 && closeNow > g_seState[tfIdx].indOrig)
         g_seState[tfIdx].indBrk = true;
      if(g_seState[tfIdx].dir == -1 && closeNow < g_seState[tfIdx].indOrig)
         g_seState[tfIdx].indBrk = true;
   }

   //-- SCORING (convexity, expansion, absorption) --------------------------------
   double _convScore = MathMin(MathAbs(_csm) / MathMax(_atr * InpSE_ConvMult, 1e-10) * 50.0, 100.0);
   double _expScore  = MathMin(_eff / MathMax(InpSE_EffThresh, 1e-10) * 50.0 + _disp / MathMax(InpSE_DispThresh, 1e-10) * 50.0, 100.0);
   double _absScore  = (_eff < InpSE_EffThresh * 0.7 && MathAbs(_vel) < MathAbs(_velPrev) * 0.6)
                       ? 60.0 + _convScore * 0.4
                       : _convScore * 0.3;

   // Momentum conditions
   bool _momExpStrong = _eff > InpSE_EffThresh * 0.75
                        && ((g_seState[tfIdx].dir == 1) ? _vel > 0 : _vel < 0);
   bool _momDecaying  = (g_seState[tfIdx].dir == 1) ? _bullDec : _bearDec;
   bool _momCounter   = (g_seState[tfIdx].dir == 1) ? _bearImp : _bullImp;
   bool _momExhaust   = _eff < InpSE_EffThresh * 0.65 && _absScore > 40.0;

   // Physics conditions (triple confirmation gates)
   bool _physConvexDevel  = _convScore > 35.0;
   bool _physTransfer     = _convScore > 48.0 || _absScore > 40.0;
   bool _physCapacityLow  = _absScore > 45.0 || _eff < InpSE_EffThresh * 0.6;

   //-- MONOTONIC PHASE STATE MACHINE (14 phases, advances and holds) ------------
   if(_reset)
      g_seState[tfIdx].phaseState = 0;

   if(g_seState[tfIdx].dir != 0)
   {
      bool _expanding = _momExpStrong || _eLong || _eShort ||
                        (g_seState[tfIdx].dir == 1 ? _bullImp : _bearImp);

      // Phase 0 -> 1: Expansion
      // Structure: expanding impulse present
      // Momentum: strong momentum in wave direction
      // Physics: no transfer/capacity collapse yet
      if(g_seState[tfIdx].phaseState < 1 && _expanding && !_physTransfer && !_physCapacityLow)
         g_seState[tfIdx].phaseState = 1;

      // Phase 1 -> 2: Expansion Pre-Convexity
      // Structure: first BOS against wave
      // Momentum: decaying
      // Physics: convexity developing
      if(g_seState[tfIdx].phaseState < 2 && g_seState[tfIdx].bos1 && _momDecaying && _physConvexDevel)
         g_seState[tfIdx].phaseState = 2;

      // Phase 2 -> 3: Expansion Induction
      // Structure: BOS1 confirmed
      // Momentum: counter-momentum appearing
      // Physics: energy transfer happening
      if(g_seState[tfIdx].phaseState < 3 && g_seState[tfIdx].bos1 && _momCounter && _physTransfer)
         g_seState[tfIdx].phaseState = 3;

      // Phase 3 -> 4: Expansion Liquidity
      // Structure: second BOS (deeper break)
      // Momentum: decaying or counter
      // Physics: transfer confirmed
      if(g_seState[tfIdx].phaseState < 4 && g_seState[tfIdx].bos2 && (_momDecaying || _momCounter) && _physTransfer)
         g_seState[tfIdx].phaseState = 4;

      // Phase 4 -> 5: New High (bull) / New Low (bear)
      // Structure: induction break (origin reclaimed)
      // Momentum: strong expansion restored
      // Physics: capacity available (not collapsing)
      if(g_seState[tfIdx].phaseState < 5 && g_seState[tfIdx].indBrk && _momExpStrong && !_physCapacityLow)
         g_seState[tfIdx].phaseState = 5;

      // Phase 5+ -> 7: Absorption
      // Structure: post-objective
      // Momentum: exhaustion
      // Physics: capacity low
      if(g_seState[tfIdx].phaseState >= 5 && _momExhaust && _physCapacityLow)
         g_seState[tfIdx].phaseState = 7;

      // Phase 5+ -> 8: Retracement
      // Structure: post-objective
      // Momentum: counter (not exhaust)
      // Physics: energy transfer
      if(g_seState[tfIdx].phaseState >= 5 && _momCounter && !_momExhaust && _physTransfer)
         g_seState[tfIdx].phaseState = 8;
   }

   //-- EXPORTED LIVE PHASE (behavioral overlay, not just monotonic latch) --------
   int _phase = g_seState[tfIdx].phaseState;
   if(g_seState[tfIdx].dir != 0)
   {
      if(_momExhaust && _physCapacityLow)
         _phase = 7; // Absorption
      else if(_momCounter && _physTransfer)
      {
         if(g_seState[tfIdx].phaseState >= 5)
         {
            // Post-objective retracement family
            if(_convScore > 40.0)
               _phase = 10; // Retracement Induction
            else if(_momDecaying)
               _phase = 9;  // Retracement Pre-Convexity
            else
               _phase = 8;  // Retracement
         }
         else
         {
            // Pre-objective spatial induction
            _phase = g_seState[tfIdx].bos2 ? 4 : 3;
         }
      }
      else if(_momExpStrong)
      {
         if(g_seState[tfIdx].phaseState >= 5)
            _phase = g_seState[tfIdx].phaseState;
         else if(g_seState[tfIdx].bos2 && _physTransfer)
            _phase = 4;
         else if(g_seState[tfIdx].bos1 && _physConvexDevel)
            _phase = 2;
         else
            _phase = 1;
      }
      else if(_momDecaying)
      {
         _phase = (g_seState[tfIdx].phaseState >= 5) ? g_seState[tfIdx].phaseState : 4;
      }
      else
      {
         _phase = (g_seState[tfIdx].phaseState == 0) ? 1 : g_seState[tfIdx].phaseState;
      }
   }

   // Bear wave: phase 5 becomes 6 (New Low)
   if(_phase == 5 && g_seState[tfIdx].dir == -1)
      _phase = 6;

   //-- WAVE PROGRESS PERCENTAGE ------------------------------------------------
   double _wp = 10.0;
   switch(g_seState[tfIdx].phaseState)
   {
      case 0: _wp = 10.0; break;
      case 1: _wp = 25.0; break;
      case 2: _wp = 40.0; break;
      case 3: _wp = 55.0; break;
      case 4: _wp = 68.0; break;
      case 5: _wp = 80.0; break;
      case 7: _wp = 92.0; break;
      default: _wp = 85.0; break;
   }

   //-- MODEL FIT AND CONVEXITY MATURITY ----------------------------------------
   double _cm = MathMin(_convScore, 100.0);
   double _mf = MathMin(MathMax(_expScore, MathMax(_absScore, _convScore)) * 0.70
                + (g_seState[tfIdx].dir != 0 ? 30.0 : 0.0), 100.0);

   //-- FRZ CANDIDATE SCORE ---------------------------------------------------
   double _frzS = MathMin((_eLong || _eShort ? 50.0 : 0.0) + _expScore * 0.30 + _convScore * 0.20, 100.0);

   //-- EXPORTED DIRECTION (origin-based) ----------------------------------------
   int _dirLabel = g_seState[tfIdx].dir;
   if(g_seState[tfIdx].inv > 0.0)
   {
      if(closeNow > g_seState[tfIdx].inv)
         _dirLabel = 1;
      else if(closeNow < g_seState[tfIdx].inv)
         _dirLabel = -1;
   }

   //-- BOS/CHoCH output -------------------------------------------------------
   int _bosOut = _bullBOS ? 1 : _bearBOS ? -1 : 0;
   int _chOut  = _bullCH  ? 1 : _bearCH  ? -1 : 0;

   //-- WRITE RESULTS TO g_se[tfIdx] -------------------------------------------
   g_se[tfIdx].dir              = _dirLabel;
   g_se[tfIdx].phase            = _phase;
   g_se[tfIdx].swingHigh        = g_seState[tfIdx].curSH;
   g_se[tfIdx].swingLow         = g_seState[tfIdx].curSL;
   g_se[tfIdx].prevSwingHigh    = g_seState[tfIdx].prSH;
   g_se[tfIdx].prevSwingLow     = g_seState[tfIdx].prSL;
   g_se[tfIdx].bosDir           = _bosOut;
   g_se[tfIdx].chochDir         = _chOut;
   g_se[tfIdx].p4High           = g_seState[tfIdx].p4h;
   g_se[tfIdx].p4Low            = g_seState[tfIdx].p4l;
   g_se[tfIdx].invalidation     = g_seState[tfIdx].inv;
   g_se[tfIdx].target           = g_seState[tfIdx].tgt;
   g_se[tfIdx].flipTop          = g_seState[tfIdx].ft;
   g_se[tfIdx].flipBot          = g_seState[tfIdx].fb;
   g_se[tfIdx].frzScore         = _frzS;
   g_se[tfIdx].waveProgress     = _wp;
   g_se[tfIdx].convexityMaturity= _cm;
   g_se[tfIdx].modelFit         = _mf;
   g_se[tfIdx].compression      = _eff;
   g_se[tfIdx].recursionBreaks  = (g_seState[tfIdx].bos1 ? 1 : 0) + (g_seState[tfIdx].bos2 ? 1 : 0);
   g_se[tfIdx].recursionDominance = g_seState[tfIdx].phaseState;
}

//==================================================================
// MTF DATA FETCH AND UPDATE
// Copies OHLC from each of the 6 fixed timeframes and runs
// f_se_compute on each.
//==================================================================
void SE_UpdateAll()
{
   int barsNeeded = InpSE_EffLen + InpSE_PivotLen + InpSE_ATRLen + 20;

   for(int i = 0; i < SE_TF_COUNT; i++)
   {
      ENUM_TIMEFRAMES tf = SE_GetPeriod(i);

      double tfClose[];
      double tfHigh[];
      double tfLow[];

      ArraySetAsSeries(tfClose, true);
      ArraySetAsSeries(tfHigh, true);
      ArraySetAsSeries(tfLow, true);

      int c1 = CopyClose(_Symbol, tf, 0, barsNeeded, tfClose);
      int c2 = CopyHigh(_Symbol, tf, 0, barsNeeded, tfHigh);
      int c3 = CopyLow(_Symbol, tf, 0, barsNeeded, tfLow);

      int available = MathMin(c1, MathMin(c2, c3));
      if(available < barsNeeded / 2) continue; // insufficient data

      f_se_compute(i, tfClose, tfHigh, tfLow, available);
   }

   // After computing all timeframes, update fractal stack
   SE_UpdateFractalStack();
}

//==================================================================
// WAVE DIRECTION BY ORIGIN
// Live direction based on close vs origin price.
// Used to re-evaluate HTF direction with live chart-context close.
//==================================================================
int f_waveDirByOrigin(double originPrice, int fallbackDir)
{
   if(originPrice <= 0.0) return(fallbackDir);

   // Use current symbol close (bar 0)
   double curClose = 0.0;
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyClose(_Symbol, _Period, 0, 1, buf) >= 1)
      curClose = buf[0];
   else
      return(fallbackDir);

   if(curClose > originPrice)  return(1);
   if(curClose < originPrice)  return(-1);
   return(fallbackDir);
}

//==================================================================
// FRACTAL STACK ALIGNMENT
// Counts bull/bear directions across all 6 timeframes.
// Computes direction consensus and alignment score.
//==================================================================
void SE_UpdateFractalStack()
{
   int stackBull = 0;
   int stackBear = 0;

   for(int i = 0; i < SE_TF_COUNT; i++)
   {
      // Re-evaluate direction with live close vs origin
      int liveDir = f_waveDirByOrigin(g_se[i].invalidation, g_se[i].dir);
      g_se[i].dir = liveDir; // Update to live direction

      if(liveDir == 1)  stackBull++;
      if(liveDir == -1) stackBear++;
   }

   if(stackBull > stackBear)
      g_fractalStackDir = 1;
   else if(stackBear > stackBull)
      g_fractalStackDir = -1;
   else
      g_fractalStackDir = 0;

   g_fractalStackScore = MathMax(stackBull, stackBear) / 6.0 * 100.0;
}

//==================================================================
// PHASE STRING HELPER
// Returns canonical lifecycle name for a phase code.
//==================================================================
string f_phaseStr(int phaseCode)
{
   switch(phaseCode)
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
      case 12: return("Demand Return");
      case 13: return("Supply Return");
   }
   return("Point 4 Origin");
}

//==================================================================
// PHASE FAMILY CODE (for downstream engines)
//==================================================================
int f_phaseFamilyCode(int phaseCode)
{
   if(phaseCode == 1) return(1);
   if(phaseCode >= 2 && phaseCode <= 4) return(2);
   if(phaseCode == 5 || phaseCode == 6) return(3);
   if(phaseCode == 7) return(4);
   if(phaseCode >= 8 && phaseCode <= 11) return(5);
   if(phaseCode >= 12 && phaseCode <= 13) return(6);
   return(0);
}

//==================================================================
// NEXT PHASE PREDICTION (for dashboard/narrative)
//==================================================================
string f_nextPhase(int phaseCode)
{
   switch(phaseCode)
   {
      case 1:  return("Expansion Pre-Convexity");
      case 2:  return("Expansion Induction");
      case 3:  return("Expansion Liquidity");
      case 4:  return("New High / New Low");
      case 5:  return("Absorption");
      case 6:  return("Absorption");
      case 7:  return("Retracement");
      case 8:  return("Retracement Pre-Convexity");
      case 9:  return("Retracement Induction");
      case 10: return("Retracement Liquidity");
      case 11: return("Demand/Supply Return");
      case 12: return("Expansion");
      case 13: return("Expansion");
   }
   return("Expansion");
}
//+------------------------------------------------------------------+
