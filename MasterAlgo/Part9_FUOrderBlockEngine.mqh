//+------------------------------------------------------------------+
//| Part9_FUOrderBlockEngine.mqh                                      |
//| MASTER ALGO - FU Order Block + Wick Capture + Conversation Route  |
//| From Letra DIE-2, Engine 1A.8/1A.9, 1A.10/1A.11/1A.12            |
//+------------------------------------------------------------------+
#property strict

//==================================================================
// FU ORDER BLOCK ENGINE (DIE-2)
// Gap-confirmed FU candle detection with zone lifecycle tracking
//
// FU WICK CAPTURE AUTHORITY (Engine 1A.8/1A.9)
// Multi-TF validated FU spike detection with captured left-pool
// magnets, induction band (38-62%), recursive target hierarchy
//
// FU CONVERSATION ROUTE (Engine 1A.10/1A.11/1A.12)
// Path through highest-authority FU nodes + AFE flip-echo
//==================================================================


//--- FU Block struct
struct FUBlock
{
   double top;
   double bot;
   int    birthBar;
   int    direction;     // 1=bull demand, -1=bear supply
   int    state;         // 0=Fresh, 1=Active, 2=Interacting, 3=Exhausted, 4=Invalidated
   bool   gapConfirmed;  // true if gap-leave validated
   double score;         // structural authority 0-100
};

#define FU_MAX_BLOCKS 30
FUBlock g_fuBlocks[FU_MAX_BLOCKS];
int     g_fuBlockCount = 0;

// FU detection parameters (from Letra inputs)
input double InpFUMinBodyRatio  = 0.60;   // Min body/range ratio
input double InpFUMinWickRatio  = 0.25;   // Min wick ratio (bear=upper, bull=lower)
input int    InpFUMaxBarsActive = 75;     // FU zone max active bars
input int    InpFULookback      = 3;      // FU detection lookback bars

//--- FU Wick Authority persistent state
struct FUWickState
{
   double tip;           // wick extreme (manipulation point)
   double bodyHigh;
   double bodyLow;
   double mid;           // 50% of captured wick
   double band38;        // induction band low
   double band62;        // induction band high
   int    direction;     // 1=bull FU spike, -1=bear FU spike
   double leftPool;      // swept swing = captured liquidity = future magnet
   int    bar;
   bool   validated;     // opposite extreme destroyed
   double strength;      // 0-100 structural score
};

FUWickState g_fuWick;


//--- Per-TF FU Pool results (recursive target hierarchy)
struct FUPoolResult
{
   double pool;       // captured left-liquidity pool price
   double mid;        // 50% wick midpoint
   double bandHi;     // 62% of wick
   double bandLo;     // 38% of wick
   int    direction;  // 1=bull, -1=bear
   bool   valid;      // validated (opposite extreme broken)
   double tip;        // wick extreme price
   double score;      // structural score 0-100
};

FUPoolResult g_fuPoolW;    // Weekly
FUPoolResult g_fuPoolD;    // Daily
FUPoolResult g_fuPoolH4;   // H4
FUPoolResult g_fuPoolH1;   // H1
FUPoolResult g_fuPoolM15;  // M15
FUPoolResult g_fuPoolM5;   // M5

// Recursive alignment & winning target
double g_fuRecursiveAlign = 0;   // % of TFs with valid FU (0-100)
double g_fuWinTarget = 0;        // highest-TF valid pool price
string g_fuWinSource = "-";      // which TF owns the winner
double g_fuWinBand = 0;          // winner's induction band mid

//--- AFE (Alternating Flip Echo) state machine
struct AFEState
{
   int    step;           // 0-5 state machine
   double origin;         // FU authority extreme (permanent)
   int    originDir;      // -1=bear FU top, 1=bull FU bottom
   double upperFlip;      // near flip (FU midpoint)
   double lowerFlip;      // far flip (opposing swing)
   string upperFlipRole;  // "Destination" or "Liquidity"
   double activeDest;     // current target
   double target;
   bool   selfReturnDone;
   bool   continuation;
};

AFEState g_afe;

// FU Conversation route
double g_convSeekPx = 0;      // parent FU being sought
string g_convSeekTf = "-";
double g_convSeekScore = 0;
double g_convConfidence = 0;  // path confidence 0-100
int    g_convBias = 0;        // directional bias for route


//==================================================================
// 1. FU ORDER BLOCK DETECTION (gap-confirmed + same-bar)
//==================================================================
void DetectFUBlocks()
{
   int barsAvail = ArraySize(Close);
   if(barsAvail < 5) return;
   double atr = g_physics.atr;
   if(atr <= 0) return;
   
   int shift = 1;
   double range0 = High[shift] - Low[shift];
   double body0 = MathAbs(Close[shift] - Open[shift]);
   double upperWick0 = High[shift] - MathMax(Open[shift], Close[shift]);
   double lowerWick0 = MathMin(Open[shift], Close[shift]) - Low[shift];
   
   // Previous bar metrics (for gap-confirmed detection)
   double range1 = High[shift+1] - Low[shift+1];
   double body1 = MathAbs(Close[shift+1] - Open[shift+1]);
   double upperWick1 = High[shift+1] - MathMax(Open[shift+1], Close[shift+1]);
   double lowerWick1 = MathMin(Open[shift+1], Close[shift+1]) - Low[shift+1];
   double bodyRatio1 = (range1 > 1e-10) ? body1 / range1 : 0;
   double upperWickRatio1 = (range1 > 1e-10) ? upperWick1 / range1 : 0;
   double lowerWickRatio1 = (range1 > 1e-10) ? lowerWick1 / range1 : 0;
   
   // Gap detection
   bool bearGapLeave = (Open[shift] < Close[shift+1] - atr * 0.05);
   bool bullGapLeave = (Open[shift] > Close[shift+1] + atr * 0.05);
   
   // Left liquidity (prior swing swept)
   bool liqLeftBear = (g_structure[TF_M5].swingHigh > 0 && 
                       High[shift+1] > g_structure[TF_M5].swingHigh * 0.998);
   bool liqLeftBull = (g_structure[TF_M5].swingLow > 0 && 
                       Low[shift+1] < g_structure[TF_M5].swingLow * 1.002);
   
   // BEAR FU (gap-confirmed): prev bar was FU, current gapped away
   bool isBearFU_gc = (range1 > atr * 0.5 && bodyRatio1 >= InpFUMinBodyRatio &&
                       Close[shift+1] < Open[shift+1] &&
                       upperWickRatio1 >= InpFUMinWickRatio &&
                       liqLeftBear && bearGapLeave);
   
   // BULL FU (gap-confirmed)
   bool isBullFU_gc = (range1 > atr * 0.5 && bodyRatio1 >= InpFUMinBodyRatio &&
                       Close[shift+1] > Open[shift+1] &&
                       lowerWickRatio1 >= InpFUMinWickRatio &&
                       liqLeftBull && bullGapLeave);
   
   // Same-bar detection (lower conviction)
   double bodyRatio0 = (range0 > 1e-10) ? body0 / range0 : 0;
   double upperWickRatio0 = (range0 > 1e-10) ? upperWick0 / range0 : 0;
   double lowerWickRatio0 = (range0 > 1e-10) ? lowerWick0 / range0 : 0;
   
   bool isBearFU_sb = (range0 > atr * 0.5 && bodyRatio0 >= InpFUMinBodyRatio &&
                       Close[shift] < Open[shift] && upperWickRatio0 >= InpFUMinWickRatio);
   bool isBullFU_sb = (range0 > atr * 0.5 && bodyRatio0 >= InpFUMinBodyRatio &&
                       Close[shift] > Open[shift] && lowerWickRatio0 >= InpFUMinWickRatio);


   // Spawn gap-confirmed bear FU zone
   if(isBearFU_gc && g_fuBlockCount < FU_MAX_BLOCKS)
   {
      FUBlock blk;
      blk.top = MathMax(Open[shift+1], Close[shift+1]);
      blk.bot = Low[shift+1];
      blk.birthBar = 0;
      blk.direction = -1;
      blk.state = 0; // Fresh
      blk.gapConfirmed = true;
      blk.score = 80.0; // gap-confirmed = high conviction
      g_fuBlocks[g_fuBlockCount] = blk;
      g_fuBlockCount++;
      Print("FU BEAR (gap-confirmed) zone: ", blk.bot, "-", blk.top);
   }
   
   // Spawn gap-confirmed bull FU zone
   if(isBullFU_gc && g_fuBlockCount < FU_MAX_BLOCKS)
   {
      FUBlock blk;
      blk.top = High[shift+1];
      blk.bot = MathMin(Open[shift+1], Close[shift+1]);
      blk.birthBar = 0;
      blk.direction = 1;
      blk.state = 0; // Fresh
      blk.gapConfirmed = true;
      blk.score = 80.0;
      g_fuBlocks[g_fuBlockCount] = blk;
      g_fuBlockCount++;
      Print("FU BULL (gap-confirmed) zone: ", blk.bot, "-", blk.top);
   }
   
   // Spawn same-bar bear FU (lower conviction, no gap-confirm)
   if(isBearFU_sb && !isBearFU_gc && g_fuBlockCount < FU_MAX_BLOCKS)
   {
      FUBlock blk;
      blk.top = MathMax(Open[shift], Close[shift]);
      blk.bot = Low[shift];
      blk.birthBar = 0;
      blk.direction = -1;
      blk.state = 0;
      blk.gapConfirmed = false;
      blk.score = 55.0;
      g_fuBlocks[g_fuBlockCount] = blk;
      g_fuBlockCount++;
   }
   
   // Spawn same-bar bull FU
   if(isBullFU_sb && !isBullFU_gc && g_fuBlockCount < FU_MAX_BLOCKS)
   {
      FUBlock blk;
      blk.top = High[shift];
      blk.bot = MathMin(Open[shift], Close[shift]);
      blk.birthBar = 0;
      blk.direction = 1;
      blk.state = 0;
      blk.gapConfirmed = false;
      blk.score = 55.0;
      g_fuBlocks[g_fuBlockCount] = blk;
      g_fuBlockCount++;
   }
}


//==================================================================
// 2. FU ZONE LIFECYCLE ENGINE
// Fresh -> Active -> Interacting -> Exhausted -> Invalidated
//==================================================================
void UpdateFULifecycles()
{
   if(g_fuBlockCount <= 0) return;
   double atr = g_physics.atr;
   if(atr <= 0) return;
   double closeNow = Close[1];
   
   for(int i = g_fuBlockCount - 1; i >= 0; i--)
   {
      FUBlock *blk = GetPointer(g_fuBlocks[i]);
      blk.birthBar++;
      
      // Skip already terminal
      if(blk.state >= 3) // Exhausted or Invalidated
      {
         // Remove expired/invalidated after max bars
         if(blk.birthBar >= InpFUMaxBarsActive || blk.state == 4)
         {
            // Shift array to remove
            for(int j = i; j < g_fuBlockCount - 1; j++)
               g_fuBlocks[j] = g_fuBlocks[j+1];
            g_fuBlockCount--;
         }
         continue;
      }
      
      // State transitions
      if(blk.birthBar <= 3)
         blk.state = 0; // Fresh
      else if(closeNow > blk.top && blk.direction == 1)
         blk.state = 3; // Exhausted (bull zone price passed through)
      else if(closeNow < blk.bot && blk.direction == -1)
         blk.state = 3; // Exhausted (bear zone price passed through)
      else if(closeNow <= blk.top && closeNow >= blk.bot)
         blk.state = 2; // Interacting (price inside zone)
      else if((blk.direction == 1 && closeNow < blk.bot - atr * 0.5) ||
              (blk.direction == -1 && closeNow > blk.top + atr * 0.5))
         blk.state = 4; // Invalidated (blew through from wrong side)
      else if(blk.birthBar > 3)
         blk.state = 1; // Active
      
      // Remove if expired
      if(blk.birthBar >= InpFUMaxBarsActive)
      {
         for(int j = i; j < g_fuBlockCount - 1; j++)
            g_fuBlocks[j] = g_fuBlocks[j+1];
         g_fuBlockCount--;
      }
   }
}

// Check if any active FU zone aligns with direction
bool HasActiveFUZone(int dir)
{
   for(int i = 0; i < g_fuBlockCount; i++)
   {
      if(g_fuBlocks[i].direction == dir && 
         (g_fuBlocks[i].state == 0 || g_fuBlocks[i].state == 1 || g_fuBlocks[i].state == 2))
         return(true);
   }
   return(false);
}

// Get best active FU zone score for a direction
double BestFUScore(int dir)
{
   double best = 0;
   for(int i = 0; i < g_fuBlockCount; i++)
   {
      if(g_fuBlocks[i].direction == dir &&
         (g_fuBlocks[i].state <= 2) && g_fuBlocks[i].score > best)
         best = g_fuBlocks[i].score;
   }
   return(best);
}


//==================================================================
// 3. FU WICK CAPTURE AUTHORITY (Engine 1A.8/1A.9)
// Detects the most-recent validated FU spike on the chart TF
//==================================================================
void UpdateFUWickAuthority()
{
   int barsAvail = ArraySize(Close);
   if(barsAvail < InpFULookback + 3) return;
   double atr = g_physics.atr;
   if(atr <= 0) return;
   
   int shift = 1;
   double range = MathMax(High[shift] - Low[shift], 1e-10);
   double priorHi = 0, priorLo = 99999999;
   
   // Find local structure (highest high / lowest low of prior lookback)
   for(int i = shift + 1; i <= shift + InpFULookback && i < barsAvail; i++)
   {
      if(High[i] > priorHi) priorHi = High[i];
      if(Low[i] < priorLo) priorLo = Low[i];
   }
   
   double fuwMinWickFrac = 0.4; // min wick/range for FU spike
   
   // Bear FU candidate: spike above prior high, close below it
   bool bearCand = (priorHi > 0 && High[shift] > priorHi && 
                    Close[shift] < priorHi &&
                    (High[shift] - MathMax(Open[shift], Close[shift])) / range >= fuwMinWickFrac);
   
   // Bull FU candidate: spike below prior low, close above it
   bool bullCand = (priorLo < 99999999 && Low[shift] < priorLo &&
                    Close[shift] > priorLo &&
                    (MathMin(Open[shift], Close[shift]) - Low[shift]) / range >= fuwMinWickFrac);
   
   if(bearCand)
   {
      g_fuWick.direction = -1;
      g_fuWick.tip = High[shift];
      g_fuWick.bodyHigh = MathMax(Open[shift], Close[shift]);
      g_fuWick.bodyLow = MathMin(Open[shift], Close[shift]);
      g_fuWick.mid = g_fuWick.bodyHigh + (g_fuWick.tip - g_fuWick.bodyHigh) * 0.50;
      g_fuWick.band38 = g_fuWick.bodyHigh + (g_fuWick.tip - g_fuWick.bodyHigh) * 0.38;
      g_fuWick.band62 = g_fuWick.bodyHigh + (g_fuWick.tip - g_fuWick.bodyHigh) * 0.62;
      g_fuWick.leftPool = priorHi;
      g_fuWick.bar = 0;
      g_fuWick.validated = false;
      g_fuWick.strength = MathMin(100.0, (g_fuWick.tip - g_fuWick.bodyHigh) / MathMax(atr, 1e-10) * 40.0 + 40.0);
   }
   else if(bullCand)
   {
      g_fuWick.direction = 1;
      g_fuWick.tip = Low[shift];
      g_fuWick.bodyHigh = MathMax(Open[shift], Close[shift]);
      g_fuWick.bodyLow = MathMin(Open[shift], Close[shift]);
      g_fuWick.mid = g_fuWick.tip + (g_fuWick.bodyLow - g_fuWick.tip) * 0.50;
      g_fuWick.band38 = g_fuWick.tip + (g_fuWick.bodyLow - g_fuWick.tip) * 0.38;
      g_fuWick.band62 = g_fuWick.tip + (g_fuWick.bodyLow - g_fuWick.tip) * 0.62;
      g_fuWick.leftPool = priorLo;
      g_fuWick.bar = 0;
      g_fuWick.validated = false;
      g_fuWick.strength = MathMin(100.0, (g_fuWick.bodyLow - g_fuWick.tip) / MathMax(atr, 1e-10) * 40.0 + 40.0);
   }
   
   // Increment bar age
   g_fuWick.bar++;
   
   // VALIDATION: later price destroys the opposite extreme
   if(!g_fuWick.validated && g_fuWick.bar > 1)
   {
      double closeNow = Close[shift];
      if(g_fuWick.direction == -1 && closeNow < g_fuWick.bodyLow)
         g_fuWick.validated = true;
      if(g_fuWick.direction == 1 && closeNow > g_fuWick.bodyHigh)
         g_fuWick.validated = true;
   }
}


//==================================================================
// 4. MULTI-TF FU POOL (Recursive Target Hierarchy)
// Each TF independently detects its own validated FU pool
// The HIGHEST TF pool becomes the dominant magnet target
//==================================================================
void ComputeFUPoolForTF(ENUM_TIMEFRAMES tf, FUPoolResult &result)
{
   ZeroMemory(result);
   
   double h[], l[], c[], o[];
   ArraySetAsSeries(h, true); ArraySetAsSeries(l, true);
   ArraySetAsSeries(c, true); ArraySetAsSeries(o, true);
   
   int n = 50;
   if(CopyHigh(_Symbol, tf, 0, n, h) < n) return;
   if(CopyLow(_Symbol, tf, 0, n, l) < n) return;
   if(CopyClose(_Symbol, tf, 0, n, c) < n) return;
   if(CopyOpen(_Symbol, tf, 0, n, o) < n) return;
   
   double atrBuf[];
   ArraySetAsSeries(atrBuf, true);
   int atrH = iATR(_Symbol, tf, 14);
   if(atrH == INVALID_HANDLE) return;
   if(CopyBuffer(atrH, 0, 0, 5, atrBuf) < 1) return;
   double tfAtr = atrBuf[0];
   if(tfAtr <= 0) return;
   
   // Find most recent FU spike on this TF
   for(int i = 1; i < n - 4; i++)
   {
      double rng = MathMax(h[i] - l[i], 1e-10);
      double priorHi = 0, priorLo = 99999999;
      for(int k = i+1; k <= i+3 && k < n; k++)
      {
         if(h[k] > priorHi) priorHi = h[k];
         if(l[k] < priorLo) priorLo = l[k];
      }
      
      double upperW = (h[i] - MathMax(o[i], c[i])) / rng;
      double lowerW = (MathMin(o[i], c[i]) - l[i]) / rng;
      
      bool bearFU = (priorHi > 0 && h[i] > priorHi && c[i] < priorHi && upperW >= 0.4);
      bool bullFU = (priorLo < 99999999 && l[i] < priorLo && c[i] > priorLo && lowerW >= 0.4);
      
      if(bearFU || bullFU)
      {
         result.direction = bearFU ? -1 : 1;
         result.tip = bearFU ? h[i] : l[i];
         double bH = MathMax(o[i], c[i]);
         double bL = MathMin(o[i], c[i]);
         result.pool = bearFU ? priorHi : priorLo;
         
         if(bearFU)
         {
            result.mid = bH + (h[i] - bH) * 0.50;
            result.bandHi = bH + (h[i] - bH) * 0.62;
            result.bandLo = bH + (h[i] - bH) * 0.38;
         }
         else
         {
            result.mid = l[i] + (bL - l[i]) * 0.50;
            result.bandHi = l[i] + (bL - l[i]) * 0.62;
            result.bandLo = l[i] + (bL - l[i]) * 0.38;
         }
         
         // Validate: check if opposite extreme was broken later
         result.valid = false;
         for(int v = 0; v < i; v++)
         {
            if(bearFU && c[v] < bL) { result.valid = true; break; }
            if(bullFU && c[v] > bH) { result.valid = true; break; }
         }
         
         // Score
         double wkAtr = bearFU ? (h[i] - bH) / tfAtr : (bL - l[i]) / tfAtr;
         result.score = (result.valid ? 30.0 : 0.0) + MathMin(25.0, wkAtr * 15.0) + 
                        20.0 + (wkAtr > 1.0 ? 15.0 : 0.0) + (wkAtr > 1.5 ? 10.0 : 0.0);
         return; // take first (most recent) valid FU
      }
   }
}


void UpdateMultiTFFUPools()
{
   ComputeFUPoolForTF(PERIOD_W1, g_fuPoolW);
   ComputeFUPoolForTF(PERIOD_D1, g_fuPoolD);
   ComputeFUPoolForTF(PERIOD_H4, g_fuPoolH4);
   ComputeFUPoolForTF(PERIOD_H1, g_fuPoolH1);
   ComputeFUPoolForTF(PERIOD_M15, g_fuPoolM15);
   ComputeFUPoolForTF(PERIOD_M5, g_fuPoolM5);
   
   // Count valid FUs across TFs
   int validCount = (g_fuPoolW.valid ? 1 : 0) + (g_fuPoolD.valid ? 1 : 0) +
                    (g_fuPoolH4.valid ? 1 : 0) + (g_fuPoolH1.valid ? 1 : 0) +
                    (g_fuPoolM15.valid ? 1 : 0) + (g_fuPoolM5.valid ? 1 : 0);
   g_fuRecursiveAlign = validCount / 6.0 * 100.0;
   
   // Winner = highest TF with valid FU (recursive hierarchy)
   g_fuWinTarget = 0;
   g_fuWinSource = "-";
   g_fuWinBand = 0;
   
   if(g_fuPoolW.valid && g_fuPoolW.pool > 0)
   { g_fuWinTarget = g_fuPoolW.pool; g_fuWinSource = "W FU Pool"; g_fuWinBand = g_fuPoolW.mid; }
   else if(g_fuPoolD.valid && g_fuPoolD.pool > 0)
   { g_fuWinTarget = g_fuPoolD.pool; g_fuWinSource = "D FU Pool"; g_fuWinBand = g_fuPoolD.mid; }
   else if(g_fuPoolH4.valid && g_fuPoolH4.pool > 0)
   { g_fuWinTarget = g_fuPoolH4.pool; g_fuWinSource = "H4 FU Pool"; g_fuWinBand = g_fuPoolH4.mid; }
   else if(g_fuPoolH1.valid && g_fuPoolH1.pool > 0)
   { g_fuWinTarget = g_fuPoolH1.pool; g_fuWinSource = "H1 FU Pool"; g_fuWinBand = g_fuPoolH1.mid; }
   else if(g_fuPoolM15.valid && g_fuPoolM15.pool > 0)
   { g_fuWinTarget = g_fuPoolM15.pool; g_fuWinSource = "M15 FU Pool"; g_fuWinBand = g_fuPoolM15.mid; }
   else if(g_fuWick.validated && g_fuWick.leftPool > 0)
   { g_fuWinTarget = g_fuWick.leftPool; g_fuWinSource = "Chart FU Pool"; g_fuWinBand = g_fuWick.mid; }
}

//==================================================================
// 5. AFE FLIP-ECHO STATE MACHINE (Engine 1A.9B)
// Tracks how flip zone changes role around a validated FU origin
// 6 steps: Anchor -> Expand -> Self-Return -> Sell to Lower ->
//          Consume Upper (now Liquidity) -> FU Reject -> Continue
//==================================================================
void UpdateAFE()
{
   if(ArraySize(Close) < 2) return;
   double closeNow = Close[1];
   
   // Re-anchor on freshly validated FU wick
   if(g_fuWick.validated && (g_afe.origin == 0 || g_fuWick.tip != g_afe.origin))
   {
      g_afe.origin = g_fuWick.tip;
      g_afe.originDir = g_fuWick.direction;
      g_afe.upperFlip = g_fuWick.mid;
      // Lower flip = opposing swing
      g_afe.lowerFlip = (g_fuWick.direction == -1) ? 
         g_structure[TF_M5].swingLow : g_structure[TF_M5].swingHigh;
      g_afe.step = 1;
      g_afe.upperFlipRole = "Destination";
      g_afe.activeDest = g_fuWick.mid;
      g_afe.target = 0;
      g_afe.selfReturnDone = false;
      g_afe.continuation = false;
   }
   
   if(g_afe.step < 1 || g_afe.origin == 0 || g_afe.originDir == 0) return;
   
   bool isBear = (g_afe.originDir == -1);
   
   // Step 1->2: Price expands away from FU body
   if(g_afe.step == 1)
   {
      double bodyEdge = isBear ? g_fuWick.bodyLow : g_fuWick.bodyHigh;
      if((isBear && closeNow < bodyEdge) || (!isBear && closeNow > bodyEdge))
         g_afe.step = 2;
   }
   // Step 2->3: Self-return to upper flip
   if(g_afe.step == 2 && g_afe.upperFlip > 0)
   {
      if((isBear && High[1] >= g_afe.upperFlip) || (!isBear && Low[1] <= g_afe.upperFlip))
      {
         g_afe.step = 3;
         g_afe.selfReturnDone = true;
         g_afe.activeDest = g_afe.lowerFlip;
      }
   }
   // Step 3->4: Sell to lower flip
   if(g_afe.step == 3 && g_afe.lowerFlip > 0)
   {
      if((isBear && Low[1] <= g_afe.lowerFlip) || (!isBear && High[1] >= g_afe.lowerFlip))
      {
         g_afe.step = 4;
         g_afe.activeDest = g_afe.origin;
         g_afe.target = g_afe.origin;
         g_afe.upperFlipRole = "Liquidity"; // role changed
      }
   }
   // Step 4->5: FU origin reached (target hit)
   if(g_afe.step == 4 && g_afe.origin > 0)
   {
      if((isBear && High[1] >= g_afe.origin) || (!isBear && Low[1] <= g_afe.origin))
      {
         g_afe.step = 5;
         g_afe.continuation = true;
      }
   }
}


//==================================================================
// 6. FU CONVERSATION ROUTE (Engine 1A.10)
// Finds the parent FU being SOUGHT (highest-TF validated FU on bias side)
// Confidence blends recursive FU alignment with that FU's score
//==================================================================
void UpdateFUConversationRoute()
{
   if(ArraySize(Close) < 2) return;
   double closeNow = Close[1];
   
   // Bias = M5 wave direction, fallback to fractal stack
   g_convBias = (g_structure[TF_M5].direction != 0) ? 
                 g_structure[TF_M5].direction : g_fractalStack.direction;
   
   g_convSeekPx = 0;
   g_convSeekTf = "-";
   g_convSeekScore = 0;
   g_convConfidence = 0;
   
   if(g_convBias == 0) return;
   
   // Search from highest TF down for a valid FU on the bias side
   struct TFSearch { FUPoolResult *pool; string name; };
   
   if(g_fuPoolW.valid && g_fuPoolW.tip > 0 && 
      (g_convBias == 1 ? g_fuPoolW.tip > closeNow : g_fuPoolW.tip < closeNow))
   { g_convSeekPx = g_fuPoolW.tip; g_convSeekTf = "W"; g_convSeekScore = g_fuPoolW.score; }
   else if(g_fuPoolD.valid && g_fuPoolD.tip > 0 &&
      (g_convBias == 1 ? g_fuPoolD.tip > closeNow : g_fuPoolD.tip < closeNow))
   { g_convSeekPx = g_fuPoolD.tip; g_convSeekTf = "D"; g_convSeekScore = g_fuPoolD.score; }
   else if(g_fuPoolH4.valid && g_fuPoolH4.tip > 0 &&
      (g_convBias == 1 ? g_fuPoolH4.tip > closeNow : g_fuPoolH4.tip < closeNow))
   { g_convSeekPx = g_fuPoolH4.tip; g_convSeekTf = "H4"; g_convSeekScore = g_fuPoolH4.score; }
   else if(g_fuPoolH1.valid && g_fuPoolH1.tip > 0 &&
      (g_convBias == 1 ? g_fuPoolH1.tip > closeNow : g_fuPoolH1.tip < closeNow))
   { g_convSeekPx = g_fuPoolH1.tip; g_convSeekTf = "H1"; g_convSeekScore = g_fuPoolH1.score; }
   else if(g_fuPoolM15.valid && g_fuPoolM15.tip > 0 &&
      (g_convBias == 1 ? g_fuPoolM15.tip > closeNow : g_fuPoolM15.tip < closeNow))
   { g_convSeekPx = g_fuPoolM15.tip; g_convSeekTf = "M15"; g_convSeekScore = g_fuPoolM15.score; }
   else if(g_fuPoolM5.valid && g_fuPoolM5.tip > 0 &&
      (g_convBias == 1 ? g_fuPoolM5.tip > closeNow : g_fuPoolM5.tip < closeNow))
   { g_convSeekPx = g_fuPoolM5.tip; g_convSeekTf = "M5"; g_convSeekScore = g_fuPoolM5.score; }
   
   // Path confidence = FU score + recursive alignment
   if(g_convSeekPx > 0)
      g_convConfidence = MathMin(100.0, g_convSeekScore * 0.7 + g_fuRecursiveAlign * 0.3);
}

//==================================================================
// MASTER FU ENGINE UPDATE (call from OnTick pipeline)
//==================================================================
void UpdateFUEngine()
{
   // 1. Detect new FU blocks on chart TF
   DetectFUBlocks();
   
   // 2. Update zone lifecycles
   UpdateFULifecycles();
   
   // 3. FU Wick Capture Authority (chart TF)
   UpdateFUWickAuthority();
   
   // 4. Multi-TF FU Pool (recursive target hierarchy)
   UpdateMultiTFFUPools();
   
   // 5. AFE Flip-Echo state machine
   UpdateAFE();
   
   // 6. FU Conversation Route
   UpdateFUConversationRoute();
}

//+------------------------------------------------------------------+
