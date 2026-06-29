//+------------------------------------------------------------------+
//| Part5_Network.mqh - Invisible Network Engine & Time Intelligence |
//|                     Engine (ported from F16 V70)                 |
//| Master MT5 EA: Symphony + Letra + F16 Combined System           |
//+------------------------------------------------------------------+
#property strict

//==================================================================
// GLOBALS - NETWORK ENGINE
//==================================================================
int      g_netBias       = 0;       // Network bias direction (1=bull, -1=bear, 0=neutral)
int      g_pressureDir   = 0;       // Pressure direction (1=bull, -1=bear, 0=neutral)
double   g_pressure      = 0.0;     // Network pressure (-100 to +100)
int      g_attractorIdx  = -1;      // Index of attractor node
int      g_eligibleNodes = 0;       // Count of eligible (live) nodes

//==================================================================
// GLOBALS - TIME INTELLIGENCE ENGINE
//==================================================================
int      g_timeDir       = 0;       // Time direction (1=bull, -1=bear, 0=neutral)
double   g_timeAlign     = 50.0;    // Time alignment (0-100)
double   g_timeConflict  = 50.0;    // Time conflict (0-100)
double   g_ema50         = 0.0;     // EMA50 value for bias fallback

//==================================================================
// EMA50 HANDLE
//==================================================================
int      g_ema50Handle   = INVALID_HANDLE;

//==================================================================
// PREVIOUS SCAN TIP VALUES (for detecting new nodes)
//==================================================================
double   g_prevTipMN  = 0.0;
double   g_prevTipW   = 0.0;
double   g_prevTipD   = 0.0;
double   g_prevTipH4  = 0.0;
double   g_prevTipH1  = 0.0;
double   g_prevTipM15 = 0.0;
double   g_prevTipM5  = 0.0;

//==================================================================
// NETWORK TIMEFRAME MAPPING (7 timeframes for scanning)
//==================================================================
ENUM_TIMEFRAMES GetNetworkTF(int idx)
{
   switch(idx)
   {
      case 0: return(PERIOD_MN1);
      case 1: return(PERIOD_W1);
      case 2: return(PERIOD_D1);
      case 3: return(PERIOD_H4);
      case 4: return(PERIOD_H1);
      case 5: return(PERIOD_M15);
      case 6: return(PERIOD_M5);
      default: return(PERIOD_M5);
   }
}

// Weight per TF index (MN=9, W=8, D=7, H4=6, H1=5, M15=4, M5=3)
int GetNetworkWeight(int idx)
{
   switch(idx)
   {
      case 0: return(9);
      case 1: return(8);
      case 2: return(7);
      case 3: return(6);
      case 4: return(5);
      case 5: return(4);
      case 6: return(3);
      default: return(3);
   }
}

//==================================================================
// PART A: INVISIBLE NETWORK ENGINE
//==================================================================

//+------------------------------------------------------------------+
//| DetectFU - FU/Flip detector: dominant rejection wick at local     |
//|            extreme (swept OR not). Ported from f_fuPool.          |
//+------------------------------------------------------------------+
void DetectFU(double &high[], double &low[], double &open[], double &close[],
              int bars, int lookback, double wickFrac, double atr,
              double &tip, double &mid, int &dir, int &valid, double &score)
{
   // Initialize outputs
   tip   = 0.0;
   mid   = 0.0;
   dir   = 0;
   valid = 0;
   score = 0.0;

   if(bars < lookback + 1 || bars <= 0) return;

   // Current bar values (index 0 = most recent with ArraySetAsSeries)
   double curHigh  = high[0];
   double curLow   = low[0];
   double curOpen  = open[0];
   double curClose = close[0];

   // Compute range
   double range = MathMax(curHigh - curLow, 1e-10);

   // Prior high/low from lookback (excluding current bar)
   double priorHigh = high[1];
   double priorLow  = low[1];
   for(int i = 1; i < lookback; i++)
   {
      if(i >= bars) break;
      if(high[i] > priorHigh) priorHigh = high[i];
      if(low[i] < priorLow)   priorLow  = low[i];
   }

   // Wick ratios
   double bodyHigh   = MathMax(curOpen, curClose);
   double bodyLow    = MathMin(curOpen, curClose);
   double upperWick  = (curHigh - bodyHigh) / range;
   double lowerWick  = (bodyLow - curLow) / range;

   // Local extremes (current bar vs lookback window)
   double highestHigh = curHigh;
   double lowestLow   = curLow;
   for(int i = 0; i < lookback; i++)
   {
      if(i >= bars) break;
      if(high[i] > highestHigh) highestHigh = high[i];
      if(low[i] < lowestLow)    lowestLow  = low[i];
   }
   bool localTop = (curHigh >= highestHigh);
   bool localBot = (curLow <= lowestLow);

   // Bear FU detection
   bool bearFU = (upperWick >= wickFrac) &&
                 ((curHigh >= priorHigh && curClose < priorHigh) ||
                  (localTop && curClose < curOpen));

   // Bull FU detection
   bool bullFU = (lowerWick >= wickFrac) &&
                 ((curLow <= priorLow && curClose > priorLow) ||
                  (localBot && curClose > curOpen));

   if(bearFU)
   {
      dir   = -1;
      tip   = curHigh;
      mid   = bodyHigh + (tip - bodyHigh) * 0.5;
      valid = 1;

      // Confirmation: close below body low
      bool confirmed = (curClose < bodyLow);

      // Wick size in ATR units
      double wickATR = (tip - bodyHigh) / MathMax(atr, 1e-10);

      // Score calculation
      score = 20.0 + MathMin(25.0, wickATR * 15.0) +
              (confirmed ? 30.0 : 0.0) +
              (wickATR > 1.0 ? 15.0 : 0.0) +
              (wickATR > 1.5 ? 10.0 : 0.0);
   }
   else if(bullFU)
   {
      dir   = 1;
      tip   = curLow;
      mid   = tip + (bodyLow - tip) * 0.5;
      valid = 1;

      // Confirmation: close above body high
      bool confirmed = (curClose > bodyHigh);

      // Wick size in ATR units
      double wickATR = (bodyLow - tip) / MathMax(atr, 1e-10);

      // Score calculation
      score = 20.0 + MathMin(25.0, wickATR * 15.0) +
              (confirmed ? 30.0 : 0.0) +
              (wickATR > 1.0 ? 15.0 : 0.0) +
              (wickATR > 1.5 ? 10.0 : 0.0);
   }
}

//+------------------------------------------------------------------+
//| AddNetworkNode - Add a new node to the registry, shift oldest if |
//|                  at capacity (FIFO).                              |
//+------------------------------------------------------------------+
void AddNetworkNode(double tip, double mid, int dir, double score, int weight)
{
   // If at capacity, shift all elements left (remove oldest at index 0)
   if(g_nodeCount >= InpNodeMax)
   {
      for(int i = 0; i < g_nodeCount - 1; i++)
      {
         g_nodes[i].px       = g_nodes[i + 1].px;
         g_nodes[i].mid      = g_nodes[i + 1].mid;
         g_nodes[i].dir      = g_nodes[i + 1].dir;
         g_nodes[i].score    = g_nodes[i + 1].score;
         g_nodes[i].weight   = g_nodes[i + 1].weight;
         g_nodes[i].state    = g_nodes[i + 1].state;
         g_nodes[i].bar      = g_nodes[i + 1].bar;
         g_nodes[i].revisits = g_nodes[i + 1].revisits;
      }
      g_nodeCount = InpNodeMax - 1;
   }

   // Add new node at end
   g_nodes[g_nodeCount].px       = tip;
   g_nodes[g_nodeCount].mid      = mid;
   g_nodes[g_nodeCount].dir      = dir;
   g_nodes[g_nodeCount].score    = score;
   g_nodes[g_nodeCount].weight   = weight;
   g_nodes[g_nodeCount].state    = 0;       // Active
   g_nodes[g_nodeCount].bar      = 0;       // Will be updated with current bar
   g_nodes[g_nodeCount].revisits = 0;
   g_nodeCount++;
}

//+------------------------------------------------------------------+
//| ScanNetworkNodes - Scan 7 timeframes for FU events and add new   |
//|                    nodes to the registry.                         |
//+------------------------------------------------------------------+
void ScanNetworkNodes()
{
   double highArr[], lowArr[], openArr[], closeArr[];
   int barsNeeded = InpFULookback + 2;

   for(int tfIdx = 0; tfIdx < 7; tfIdx++)
   {
      ENUM_TIMEFRAMES tf = GetNetworkTF(tfIdx);
      int weight = GetNetworkWeight(tfIdx);

      // Copy OHLC data for this timeframe
      ArraySetAsSeries(highArr, true);
      ArraySetAsSeries(lowArr, true);
      ArraySetAsSeries(openArr, true);
      ArraySetAsSeries(closeArr, true);

      int cH = CopyHigh(_Symbol, tf, 0, barsNeeded, highArr);
      int cL = CopyLow(_Symbol, tf, 0, barsNeeded, lowArr);
      int cO = CopyOpen(_Symbol, tf, 0, barsNeeded, openArr);
      int cC = CopyClose(_Symbol, tf, 0, barsNeeded, closeArr);

      if(cH < barsNeeded || cL < barsNeeded || cO < barsNeeded || cC < barsNeeded)
         continue;

      // Get ATR for this timeframe
      double tfAtr = 0.0;
      int atrHandle = iATR(_Symbol, tf, 14);
      if(atrHandle != INVALID_HANDLE)
      {
         double atrBuf[];
         ArraySetAsSeries(atrBuf, true);
         if(CopyBuffer(atrHandle, 0, 0, 1, atrBuf) > 0)
            tfAtr = atrBuf[0];
         IndicatorRelease(atrHandle);
      }
      if(tfAtr <= 0.0) continue;

      // Detect FU
      double tip = 0.0, mid = 0.0, score = 0.0;
      int dir = 0, valid = 0;
      DetectFU(highArr, lowArr, openArr, closeArr,
               barsNeeded, InpFULookback, InpWickFrac, tfAtr,
               tip, mid, dir, valid, score);

      if(valid != 1) continue;

      // Check if this is a new node (tip changed from last scan)
      bool isNew = false;
      switch(tfIdx)
      {
         case 0: isNew = (tip != g_prevTipMN);  g_prevTipMN  = tip; break;
         case 1: isNew = (tip != g_prevTipW);   g_prevTipW   = tip; break;
         case 2: isNew = (tip != g_prevTipD);   g_prevTipD   = tip; break;
         case 3: isNew = (tip != g_prevTipH4);  g_prevTipH4  = tip; break;
         case 4: isNew = (tip != g_prevTipH1);  g_prevTipH1  = tip; break;
         case 5: isNew = (tip != g_prevTipM15); g_prevTipM15 = tip; break;
         case 6: isNew = (tip != g_prevTipM5);  g_prevTipM5  = tip; break;
      }

      if(isNew)
         AddNetworkNode(tip, mid, dir, score, weight);
   }
}

//+------------------------------------------------------------------+
//| UpdateNodeStates - Update state machine for all active nodes.     |
//|   State: 0=active, 1=dormant, 2=consumed, 3=historical           |
//+------------------------------------------------------------------+
void UpdateNodeStates(double closePrice, double atr)
{
   for(int i = 0; i < g_nodeCount; i++)
   {
      // Skip already consumed nodes
      if(g_nodes[i].state == 2) continue;

      double nodePx  = g_nodes[i].px;
      int    nodeDir = g_nodes[i].dir;
      int    nodeWt  = (int)g_nodes[i].weight;

      // Check if consumed: price crossed tip in node's direction
      bool consumed = false;
      if(nodeDir == -1 && closePrice > nodePx)
         consumed = true;
      else if(nodeDir == 1 && closePrice < nodePx)
         consumed = true;

      if(consumed)
      {
         g_nodes[i].state = 2;
         continue;
      }

      // Check proximity for revisit (within 0.25 ATR of tip)
      if(MathAbs(closePrice - nodePx) < atr * 0.25)
         g_nodes[i].revisits++;

      // Update state by age
      g_nodes[i].bar++;  // Increment age (bars since creation)
      int age = g_nodes[i].bar;

      if(age > InpHistoryBars * nodeWt)
         g_nodes[i].state = 3;       // Historical
      else if(age > InpDormantBars * nodeWt)
         g_nodes[i].state = 1;       // Dormant
      else
         g_nodes[i].state = 0;       // Active
   }
}

//+------------------------------------------------------------------+
//| GetNodeAuthority - Authority scoring for a node.                  |
//|   auth = score + weight*4 + revisits*3                           |
//+------------------------------------------------------------------+
double GetNodeAuthority(int i)
{
   if(i < 0 || i >= g_nodeCount) return(0.0);
   return(g_nodes[i].score + g_nodes[i].weight * 4.0 + g_nodes[i].revisits * 3.0);
}

//+------------------------------------------------------------------+
//| ComputeNetworkBias - Cascade from highest TF valid FU node down  |
//|                      to EMA50 fallback. Also compute pressure.    |
//+------------------------------------------------------------------+
void ComputeNetworkBias(double closePrice, double ema50,
                        int &netBias, int &pressureDir, double &pressure)
{
   // Default bias: cascade from highest weight valid node
   // Find highest-weight node that is valid (state != 2, not historical)
   netBias = 0;
   int highestWeight = 0;

   for(int i = 0; i < g_nodeCount; i++)
   {
      if(g_nodes[i].state == 2 || g_nodes[i].state == 3) continue;
      int wt = (int)g_nodes[i].weight;
      if(wt > highestWeight)
      {
         highestWeight = wt;
         netBias = g_nodes[i].dir;
      }
   }

   // Fallback to EMA50
   if(netBias == 0)
   {
      if(closePrice > ema50)      netBias = 1;
      else if(closePrice < ema50) netBias = -1;
   }

   // Compute pressure from authority sum of eligible nodes
   double bullAuth = 0.0;
   double bearAuth = 0.0;
   g_eligibleNodes = 0;

   for(int i = 0; i < g_nodeCount; i++)
   {
      if(g_nodes[i].state == 2) continue;
      double auth = GetNodeAuthority(i);
      if(auth < InpAuthMin) continue;

      g_eligibleNodes++;
      int nodeDir = g_nodes[i].dir;
      if(nodeDir == 1)
         bullAuth += auth;
      else if(nodeDir == -1)
         bearAuth += auth;
   }

   // Pressure calculation
   if((bullAuth + bearAuth) > 0.0)
      pressure = (bullAuth - bearAuth) / (bullAuth + bearAuth) * 100.0;
   else
      pressure = 0.0;

   // Pressure direction (threshold +/- 12)
   if(pressure > 12.0)
      pressureDir = 1;
   else if(pressure < -12.0)
      pressureDir = -1;
   else
      pressureDir = 0;
}

//+------------------------------------------------------------------+
//| GetAttractorNodeIndex - Find highest-ranked node that is ahead of |
//|                         price on the bias side.                    |
//+------------------------------------------------------------------+
int GetAttractorNodeIndex(double closePrice, int netBias)
{
   int    bestIdx  = -1;
   double bestRank = -1.0;

   for(int i = 0; i < g_nodeCount; i++)
   {
      if(g_nodes[i].state == 2) continue;
      double auth = GetNodeAuthority(i);
      if(auth < InpAuthMin) continue;

      double nodePx = g_nodes[i].px;
      int    nodeWt = (int)g_nodes[i].weight;

      // Check if node is ahead of price on bias side
      bool onBiasSide = false;
      if(netBias == 1 && nodePx > closePrice)
         onBiasSide = true;
      else if(netBias == -1 && nodePx < closePrice)
         onBiasSide = true;

      if(!onBiasSide) continue;

      // Rank = weight * 1000 + authority
      double rank = nodeWt * 1000.0 + auth;
      if(rank > bestRank)
      {
         bestRank = rank;
         bestIdx  = i;
      }
   }

   return(bestIdx);
}

//==================================================================
// PART B: TIME INTELLIGENCE ENGINE
//==================================================================

//+------------------------------------------------------------------+
//| TIME CYCLE TIMEFRAME MAPPING (5 cycles)                          |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES GetTimeCycleTF(int idx)
{
   switch(idx)
   {
      case 0: return(PERIOD_MN1);
      case 1: return(PERIOD_W1);
      case 2: return(PERIOD_D1);
      case 3: return(PERIOD_H4);
      case 4: return(PERIOD_H1);
      default: return(PERIOD_H1);
   }
}

//+------------------------------------------------------------------+
//| UpdateTimeIntelligence - Update all 5 time cycles with current    |
//|   bar OHLC, previous bar H/L, bias, elapsed, highTaken, lowTaken |
//+------------------------------------------------------------------+
void UpdateTimeIntelligence()
{
   for(int i = 0; i < 5; i++)
   {
      ENUM_TIMEFRAMES tf = GetTimeCycleTF(i);

      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      int copied = CopyRates(_Symbol, tf, 0, 2, rates);
      if(copied < 2) continue;

      // Current bar data (index 0)
      g_timeCycles[i].open    = rates[0].open;
      g_timeCycles[i].high    = rates[0].high;
      g_timeCycles[i].low     = rates[0].low;
      g_timeCycles[i].time    = rates[0].time;

      // Previous bar high/low (index 1)
      g_timeCycles[i].prevHigh = rates[1].high;
      g_timeCycles[i].prevLow  = rates[1].low;

      // Bias: close vs open of current bar
      double curClose = rates[0].close;
      if(curClose > rates[0].open)
         g_timeCycles[i].bias = 1;
      else if(curClose < rates[0].open)
         g_timeCycles[i].bias = -1;
      else
         g_timeCycles[i].bias = 0;

      // Elapsed fraction: (TimeCurrent - bar open time) / period seconds, clamped 0-1
      long periodSec = PeriodSeconds(tf);
      if(periodSec <= 0) periodSec = 1;
      double elapsed = (double)(TimeCurrent() - rates[0].time) / (double)periodSec;
      if(elapsed < 0.0) elapsed = 0.0;
      if(elapsed > 1.0) elapsed = 1.0;
      g_timeCycles[i].elapsed = (int)MathRound(elapsed * 100.0); // Store as percentage

      // High taken: current high exceeds previous bar's high
      g_timeCycles[i].highTaken = (rates[0].high > rates[1].high);

      // Low taken: current low is below previous bar's low
      g_timeCycles[i].lowTaken = (rates[0].low < rates[1].low);
   }
}

//+------------------------------------------------------------------+
//| ComputeTimeMetrics - Compute timeDir, timeAlign, timeConflict    |
//|   from the 5 cycle biases.                                       |
//+------------------------------------------------------------------+
void ComputeTimeMetrics(int &timeDir, double &timeAlign, double &timeConflict)
{
   int bullCount = 0;
   int bearCount = 0;

   for(int i = 0; i < 5; i++)
   {
      if(g_timeCycles[i].bias == 1)
         bullCount++;
      else if(g_timeCycles[i].bias == -1)
         bearCount++;
   }

   // Time direction
   if(bullCount > bearCount)
      timeDir = 1;
   else if(bearCount > bullCount)
      timeDir = -1;
   else
      timeDir = 0;

   // Time alignment: max(bull,bear) / (bull+bear) * 100
   int total = bullCount + bearCount;
   if(total > 0)
      timeAlign = (double)MathMax(bullCount, bearCount) / (double)total * 100.0;
   else
      timeAlign = 50.0;

   // Time conflict
   timeConflict = 100.0 - timeAlign;
}

//==================================================================
// PART C: MASTER UPDATE FUNCTION
//==================================================================

//+------------------------------------------------------------------+
//| InitNetworkEngine - Initialize EMA50 handle (call in OnInit)     |
//+------------------------------------------------------------------+
bool InitNetworkEngine()
{
   g_ema50Handle = iMA(_Symbol, _Period, 50, 0, MODE_EMA, PRICE_CLOSE);
   if(g_ema50Handle == INVALID_HANDLE)
   {
      Print("Part5_Network: Failed to create EMA50 handle");
      return(false);
   }
   return(true);
}

//+------------------------------------------------------------------+
//| DeinitNetworkEngine - Release EMA50 handle (call in OnDeinit)    |
//+------------------------------------------------------------------+
void DeinitNetworkEngine()
{
   if(g_ema50Handle != INVALID_HANDLE)
   {
      IndicatorRelease(g_ema50Handle);
      g_ema50Handle = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
//| UpdateNetworkAndTimeIntel - Master update function.               |
//|   Calls all sub-engines and stores results in globals.            |
//+------------------------------------------------------------------+
void UpdateNetworkAndTimeIntel()
{
   // Get current close price
   double closePrice = 0.0;
   double closeArr[];
   ArraySetAsSeries(closeArr, true);
   if(CopyClose(_Symbol, _Period, 0, 1, closeArr) > 0)
      closePrice = closeArr[0];
   if(closePrice <= 0.0) return;

   // Get current ATR
   double atr = GetATR(0);
   if(atr <= 0.0) return;

   // Get EMA50
   g_ema50 = 0.0;
   if(g_ema50Handle != INVALID_HANDLE)
   {
      double emaBuf[];
      ArraySetAsSeries(emaBuf, true);
      if(CopyBuffer(g_ema50Handle, 0, 0, 1, emaBuf) > 0)
         g_ema50 = emaBuf[0];
   }

   // 1. Scan for new network nodes
   ScanNetworkNodes();

   // 2. Update node states (age, consumed, revisits)
   UpdateNodeStates(closePrice, atr);

   // 3. Compute network bias and pressure
   ComputeNetworkBias(closePrice, g_ema50, g_netBias, g_pressureDir, g_pressure);

   // 4. Find attractor node
   g_attractorIdx = GetAttractorNodeIndex(closePrice, g_netBias);

   // 5. Update Time Intelligence cycles
   UpdateTimeIntelligence();

   // 6. Compute time metrics
   ComputeTimeMetrics(g_timeDir, g_timeAlign, g_timeConflict);
}

//+------------------------------------------------------------------+
