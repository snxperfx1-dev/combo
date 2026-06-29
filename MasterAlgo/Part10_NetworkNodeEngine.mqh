//+------------------------------------------------------------------+
//| Part10_NetworkNodeEngine.mqh                                       |
//| MASTER ALGO - Invisible Network Node Engine + FEZ Corridor        |
//| From F16: Multi-TF FU/FLIP node registry with authority scoring,  |
//| dormant/historical classification, path sorting, FEZ corridor     |
//+------------------------------------------------------------------+
#property strict

//==================================================================
// INVISIBLE NETWORK NODE ENGINE (from F16 Part A)
//
// Scans MN/W/D/H4/H1/M15/M5 for FU/FLIP rejection spikes, registers
// each as a node with:
//   - Price (tip), Mid, Direction, Score, Weight (TF), State, Age, Reversals
// Authority = Score + Weight*4 + Reversals*3
// States: 0=Active, 1=Dormant, 2=Consumed, 3=Historical
//
// FEZ CORRIDOR: the box between the nearest high-authority node
// ABOVE and BELOW current price — the execution corridor
//==================================================================


//--- Node struct
struct NetworkNode
{
   double price;        // tip price (the rejection extreme)
   double mid;          // midpoint of the body zone
   int    direction;    // 1=bull support, -1=bear resistance
   double score;        // raw detection score 0-100
   int    weight;       // TF weight (9=MN,8=W,7=D,6=H4,5=H1,4=M15,3=M5)
   int    state;        // 0=Active, 1=Dormant, 2=Consumed, 3=Historical
   int    birthBar;     // bar_index at creation (age = current - birth)
   int    reversals;    // times price has reversed at this node
};

#define NODE_MAX 250
NetworkNode g_nodes[NODE_MAX];
int         g_nodeCount = 0;

// Network parameters
input int    InpNodeMax       = 250;   // Max remembered nodes
input int    InpDormantBars   = 120;   // Bars until dormant
input int    InpHistoryBars   = 600;   // Bars until historical
input double InpWickFrac      = 0.30;  // FU spike min wick/range

// Network output
int    g_netBias = 0;           // network directional bias
double g_netPressure = 0;       // bull-bear pressure (-100 to +100)
int    g_netEligibleCount = 0;  // live eligible nodes

// FEZ corridor
double g_fezHigh = 0;     // nearest high-authority node ABOVE price
double g_fezLow = 0;      // nearest high-authority node BELOW price
int    g_fezHighWeight = 0;
int    g_fezLowWeight = 0;

// Path nodes (sorted by distance from price)
#define PATH_MAX 20
int    g_pathForward[PATH_MAX];   // indices of nodes ahead (on-bias side)
int    g_pathForwardCount = 0;
int    g_pathBehind[PATH_MAX];    // indices of nodes behind
int    g_pathBehindCount = 0;

// Dominant attractor (nearest high-authority on-bias node)
int    g_attrIdx = -1;       // index of primary attractor node
double g_attrAuth = 0;       // its authority score


//--- TF weight mapping (matches F16: 9=MN, 8=W, 7=D, 6=H4, 5=H1, 4=M15, 3=M5)
int TFToWeight(ENUM_TIMEFRAMES tf)
{
   if(tf == PERIOD_MN1) return(9);
   if(tf == PERIOD_W1)  return(8);
   if(tf == PERIOD_D1)  return(7);
   if(tf == PERIOD_H4)  return(6);
   if(tf == PERIOD_H1)  return(5);
   if(tf == PERIOD_M15) return(4);
   if(tf == PERIOD_M5)  return(3);
   if(tf == PERIOD_M3)  return(2);
   return(1);
}

string WeightToTFName(int wt)
{
   if(wt == 9) return("MN");
   if(wt == 8) return("W");
   if(wt == 7) return("D");
   if(wt == 6) return("H4");
   if(wt == 5) return("H1");
   if(wt == 4) return("M15");
   if(wt == 3) return("M5");
   if(wt == 2) return("M3");
   return("M1");
}

//--- Authority score (from F16)
double NodeAuthority(int idx)
{
   if(idx < 0 || idx >= g_nodeCount) return(0);
   return(g_nodes[idx].score + g_nodes[idx].weight * 4.0 + g_nodes[idx].reversals * 3.0);
}

//==================================================================
// 1. FU/FLIP DETECTOR PER TIMEFRAME
// Detects dominant rejection wicks at local extremes
//==================================================================
void ScanTFForNodes(ENUM_TIMEFRAMES tf)
{
   double h[], l[], c[], o[];
   ArraySetAsSeries(h, true); ArraySetAsSeries(l, true);
   ArraySetAsSeries(c, true); ArraySetAsSeries(o, true);
   
   int n = 30;
   if(CopyHigh(_Symbol, tf, 0, n, h) < n) return;
   if(CopyLow(_Symbol, tf, 0, n, l) < n) return;
   if(CopyClose(_Symbol, tf, 0, n, c) < n) return;
   if(CopyOpen(_Symbol, tf, 0, n, o) < n) return;
   
   double atrBuf[];
   ArraySetAsSeries(atrBuf, true);
   int atrH = iATR(_Symbol, tf, 14);
   if(atrH == INVALID_HANDLE) return;
   if(CopyBuffer(atrH, 0, 0, 3, atrBuf) < 1) return;
   double tfAtr = atrBuf[0];
   if(tfAtr <= 0) return;
   
   int wt = TFToWeight(tf);
   int lb = 3; // lookback for local structure
   
   // Check bar index 1 (last closed bar on this TF)
   int i = 1;
   double rng = MathMax(h[i] - l[i], 1e-10);
   double uw = (h[i] - MathMax(o[i], c[i])) / rng;
   double lw = (MathMin(o[i], c[i]) - l[i]) / rng;
   
   // Local extremes
   double pHi = 0, pLo = 99999999;
   for(int k = i+1; k <= i+lb && k < n; k++)
   {
      if(h[k] > pHi) pHi = h[k];
      if(l[k] < pLo) pLo = l[k];
   }
   
   bool localTop = (h[i] >= pHi);
   bool localBot = (l[i] <= pLo);
   
   // Bear FU node: upper wick dominant + (swept prior high OR local top with close < open)
   bool bearNode = (uw >= InpWickFrac && 
                    ((pHi > 0 && h[i] >= pHi && c[i] < pHi) || (localTop && c[i] < o[i])));
   
   // Bull FU node: lower wick dominant
   bool bullNode = (lw >= InpWickFrac &&
                    ((pLo < 99999999 && l[i] <= pLo && c[i] > pLo) || (localBot && c[i] > o[i])));
   
   if(!bearNode && !bullNode) return;
   
   // Compute score
   int dir = bearNode ? -1 : 1;
   double tip = bearNode ? h[i] : l[i];
   double bH = MathMax(o[i], c[i]);
   double bL = MathMin(o[i], c[i]);
   double mid = bearNode ? bH + (tip - bH) * 0.5 : tip + (bL - tip) * 0.5;
   
   double wkAtr = bearNode ? (tip - bH) / tfAtr : (bL - tip) / tfAtr;
   
   // Check if confirmed (close below body for bear, above for bull)
   bool confirmed = false;
   if(bearNode && c[0] < bL) confirmed = true;
   if(bullNode && c[0] > bH) confirmed = true;
   
   double nodeScore = 20.0 + MathMin(25.0, wkAtr * 15.0) + (confirmed ? 30.0 : 0.0) +
                      (wkAtr > 1.0 ? 15.0 : 0.0) + (wkAtr > 1.5 ? 10.0 : 0.0);


   // Dedup: don't add if a node at same price already exists for this TF
   for(int j = 0; j < g_nodeCount; j++)
   {
      if(g_nodes[j].weight == wt && MathAbs(g_nodes[j].price - tip) < tfAtr * 0.1)
         return; // already registered
   }
   
   // Add to registry
   if(g_nodeCount >= NODE_MAX)
   {
      // Evict oldest/lowest authority
      int evictIdx = 0;
      double evictAuth = NodeAuthority(0);
      for(int j = 1; j < g_nodeCount; j++)
      {
         double a = NodeAuthority(j);
         if(a < evictAuth) { evictAuth = a; evictIdx = j; }
      }
      // Shift to remove
      for(int j = evictIdx; j < g_nodeCount - 1; j++)
         g_nodes[j] = g_nodes[j+1];
      g_nodeCount--;
   }
   
   NetworkNode node;
   node.price = tip;
   node.mid = mid;
   node.direction = dir;
   node.score = nodeScore;
   node.weight = wt;
   node.state = 0; // Active
   node.birthBar = 0;
   node.reversals = 0;
   g_nodes[g_nodeCount] = node;
   g_nodeCount++;
}

//==================================================================
// 2. SCAN ALL TIMEFRAMES FOR NODES
//==================================================================
void ScanAllTFsForNodes()
{
   ScanTFForNodes(PERIOD_MN1);
   ScanTFForNodes(PERIOD_W1);
   ScanTFForNodes(PERIOD_D1);
   ScanTFForNodes(PERIOD_H4);
   ScanTFForNodes(PERIOD_H1);
   ScanTFForNodes(PERIOD_M15);
   ScanTFForNodes(PERIOD_M5);
}

//==================================================================
// 3. UPDATE NODE STATES (age, consumed, dormant, reversals)
//==================================================================
void UpdateNodeStates()
{
   if(g_nodeCount <= 0) return;
   double atr = g_physics.atr;
   if(atr <= 0) return;
   double closeNow = (ArraySize(Close) > 0) ? Close[0] : 0;
   if(closeNow == 0) return;
   
   for(int i = 0; i < g_nodeCount; i++)
   {
      NetworkNode *n = GetPointer(g_nodes[i]);
      n.birthBar++;
      
      if(n.state == 2) continue; // already consumed
      
      // Check if consumed (price broke through)
      if(n.direction == -1 && closeNow > n.price)
      { n.state = 2; continue; }
      if(n.direction == 1 && closeNow < n.price)
      { n.state = 2; continue; }
      
      // Check for reversal (price came close and bounced)
      if(MathAbs(closeNow - n.price) < atr * 0.25)
         n.reversals++;
      
      // Age-based state transition (scaled by TF weight)
      int scaledDormant = InpDormantBars * n.weight;
      int scaledHistory = InpHistoryBars * n.weight;
      
      if(n.birthBar > scaledHistory)
         n.state = 3; // Historical
      else if(n.birthBar > scaledDormant)
         n.state = 1; // Dormant
      else
         n.state = 0; // Active
   }
}

//==================================================================
// 4. NETWORK BIAS + PRESSURE (from F16)
// Bull/bear authority balance determines directional bias
//==================================================================
void ComputeNetworkBias()
{
   double bullAuth = 0;
   double bearAuth = 0;
   g_netEligibleCount = 0;
   
   double closeNow = (ArraySize(Close) > 0) ? Close[0] : 0;
   
   for(int i = 0; i < g_nodeCount; i++)
   {
      if(g_nodes[i].state == 2) continue; // skip consumed
      double auth = NodeAuthority(i);
      if(auth < InpAuthMin) continue;
      
      g_netEligibleCount++;
      if(g_nodes[i].direction == 1)
         bullAuth += auth;
      else if(g_nodes[i].direction == -1)
         bearAuth += auth;
   }
   
   // Network bias from EMA50 fallback if no strong nodes
   if(bullAuth + bearAuth > 0)
      g_netPressure = (bullAuth - bearAuth) / (bullAuth + bearAuth) * 100.0;
   else
      g_netPressure = 0;
   
   g_netBias = (g_netPressure > 12) ? 1 : (g_netPressure < -12) ? -1 : 0;
}


//==================================================================
// 5. PATH NODES (sorted by distance from price, split by bias side)
//==================================================================
void ComputePathNodes()
{
   g_pathForwardCount = 0;
   g_pathBehindCount = 0;
   g_attrIdx = -1;
   g_attrAuth = 0;
   
   double closeNow = (ArraySize(Close) > 0) ? Close[0] : 0;
   if(closeNow == 0 || g_nodeCount == 0) return;
   
   // Collect eligible nodes into forward/behind arrays
   for(int i = 0; i < g_nodeCount; i++)
   {
      if(g_nodes[i].state == 2) continue;
      double auth = NodeAuthority(i);
      if(auth < InpAuthMin) continue;
      
      bool ahead = (g_netBias == 1) ? (g_nodes[i].price > closeNow) : (g_nodes[i].price < closeNow);
      
      if(ahead && g_pathForwardCount < PATH_MAX)
      {
         g_pathForward[g_pathForwardCount] = i;
         g_pathForwardCount++;
      }
      else if(!ahead && g_pathBehindCount < PATH_MAX)
      {
         g_pathBehind[g_pathBehindCount] = i;
         g_pathBehindCount++;
      }
   }
   
   // Sort forward by distance (nearest first) using insertion sort
   for(int a = 1; a < g_pathForwardCount; a++)
   {
      int key = g_pathForward[a];
      double kd = MathAbs(closeNow - g_nodes[key].price);
      int b = a - 1;
      while(b >= 0 && MathAbs(closeNow - g_nodes[g_pathForward[b]].price) > kd)
      {
         g_pathForward[b+1] = g_pathForward[b];
         b--;
      }
      g_pathForward[b+1] = key;
   }
   
   // Sort behind by distance (nearest first)
   for(int a = 1; a < g_pathBehindCount; a++)
   {
      int key = g_pathBehind[a];
      double kd = MathAbs(closeNow - g_nodes[key].price);
      int b = a - 1;
      while(b >= 0 && MathAbs(closeNow - g_nodes[g_pathBehind[b]].price) > kd)
      {
         g_pathBehind[b+1] = g_pathBehind[b];
         b--;
      }
      g_pathBehind[b+1] = key;
   }
   
   // Primary attractor = nearest on-bias node with highest TF weight * authority
   double bestRank = -1;
   for(int i = 0; i < g_pathForwardCount; i++)
   {
      int idx = g_pathForward[i];
      double rank = g_nodes[idx].weight * 1000.0 + NodeAuthority(idx);
      if(rank > bestRank)
      {
         bestRank = rank;
         g_attrIdx = idx;
         g_attrAuth = NodeAuthority(idx);
      }
   }
}

//==================================================================
// 6. FEZ CORRIDOR (Focused Execution Zone)
// Nearest high-authority node ABOVE + BELOW price = the corridor
//==================================================================
void ComputeFEZCorridor()
{
   g_fezHigh = 0;
   g_fezLow = 0;
   g_fezHighWeight = 0;
   g_fezLowWeight = 0;
   
   double closeNow = (ArraySize(Close) > 0) ? Close[0] : 0;
   if(closeNow == 0 || g_nodeCount == 0) return;
   
   double bestAboveAuth = 0;
   double bestBelowAuth = 0;
   
   for(int i = 0; i < g_nodeCount; i++)
   {
      if(g_nodes[i].state == 2) continue; // skip consumed
      double auth = NodeAuthority(i);
      if(auth < InpAuthMin) continue;
      
      if(g_nodes[i].price > closeNow && auth > bestAboveAuth)
      {
         bestAboveAuth = auth;
         g_fezHigh = g_nodes[i].price;
         g_fezHighWeight = g_nodes[i].weight;
      }
      if(g_nodes[i].price < closeNow && auth > bestBelowAuth)
      {
         bestBelowAuth = auth;
         g_fezLow = g_nodes[i].price;
         g_fezLowWeight = g_nodes[i].weight;
      }
   }
}

// Check if price is inside FEZ corridor
bool IsInsideFEZ()
{
   if(g_fezHigh == 0 || g_fezLow == 0) return(false);
   double closeNow = (ArraySize(Close) > 0) ? Close[0] : 0;
   return(closeNow > g_fezLow && closeNow < g_fezHigh);
}

// Get attractor node description string
string AttrNodeDesc()
{
   if(g_attrIdx < 0) return("-");
   return(WeightToTFName(g_nodes[g_attrIdx].weight) + " " + 
          (g_nodes[g_attrIdx].direction == 1 ? "^" : "v") + " " +
          DoubleToString(g_nodes[g_attrIdx].price, 2));
}


//==================================================================
// MASTER NETWORK UPDATE (call from OnTick pipeline)
//==================================================================
void UpdateNetworkEngine()
{
   // 1. Scan all 7 TFs for new FU/FLIP nodes
   ScanAllTFsForNodes();
   
   // 2. Update node states (age, consumed, dormant, reversals)
   UpdateNodeStates();
   
   // 3. Compute network directional bias + pressure
   ComputeNetworkBias();
   
   // 4. Compute path nodes (forward/behind sorted by distance)
   ComputePathNodes();
   
   // 5. Compute FEZ corridor
   ComputeFEZCorridor();
}

//+------------------------------------------------------------------+
