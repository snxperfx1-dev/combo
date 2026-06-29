//+------------------------------------------------------------------+
//| Part13_VisualSystems.mqh                                          |
//| MASTER ALGO - Visual Systems                                      |
//| Wave Arcs, Traceability Zones, Region Display, Network Web,       |
//| FEZ Corridor, Participant Fibs, Budget Target, FU Zones           |
//| All rendered as MT5 native chart objects (OBJ_HLINE/RECTANGLE/    |
//| OBJ_TREND/OBJ_TEXT)                                               |
//+------------------------------------------------------------------+
#property strict

//==================================================================
// VISUAL SYSTEMS
// Renders all intelligence layers onto the chart using MT5 objects:
//
// 1. WAVE ARCS: H4+H1 swing trend lines (approximating curves)
// 2. TRACEABILITY ZONES: Per-TF boxes showing each layer's range
// 3. REGION DISPLAY: Phase region labels with debounce
// 4. NETWORK WEB: Lines connecting eligible nodes
// 5. FEZ CORRIDOR: Rectangle between above/below nodes
// 6. PARTICIPANT FIBS: 0.618/0.70/0.786/flip horizontal lines
// 7. BUDGET TARGET: Arrow line from price to ODDE target
// 8. FU ZONES: Rectangles for active FU order blocks
// 9. ENERGY REGISTRY: Dotted lines for unresolved energy levels
//==================================================================

// Visual toggle inputs
input bool InpShowWaveArcs     = true;   // Show H4+H1 wave arcs
input bool InpShowTraceZones   = true;   // Show per-TF traceability zones
input bool InpShowRegions      = true;   // Show phase region labels
input bool InpShowNetworkWeb   = true;   // Show network node web
input bool InpShowFEZ          = true;   // Show FEZ corridor
input bool InpShowParticipants = true;   // Show participant Fib levels
input bool InpShowBudgetTarget = true;   // Show curve budget target arrow
input bool InpShowFUZones      = true;   // Show FU order block zones
input bool InpShowEnergyLevels = true;   // Show unresolved energy levels

// Region display debounce
int    g_regionConfirmBars = 2;
string g_regionPhase = "";
int    g_regionStartBar = 0;
string g_pendingPhase = "";
int    g_pendingCount = 0;

// Object name prefixes (for cleanup)
#define VIS_PREFIX "MA_"


//==================================================================
// CLEANUP: Remove all visual objects on deinit or refresh
//==================================================================
void CleanupVisualObjects()
{
   int total = ObjectsTotal(0);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, VIS_PREFIX) == 0)
         ObjectDelete(0, name);
   }
}

//--- Helper: create or move an HLine
void SetHLine(string name, double price, color clr, int style, int width, string tooltip)
{
   if(price <= 0) { ObjectDelete(0, name); return; }
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
}

//--- Helper: create or move a rectangle
void SetRectangle(string name, datetime t1, double p1, datetime t2, double p2, 
                  color clr, int style, bool fill)
{
   if(p1 == 0 || p2 == 0) { ObjectDelete(0, name); return; }
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_TIME, 0, t1);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 0, p1);
   ObjectSetInteger(0, name, OBJPROP_TIME, 1, t2);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 1, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_FILL, fill);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
}

//--- Helper: create or move a trend line (for arcs/arrows)
void SetTrendLine(string name, datetime t1, double p1, datetime t2, double p2,
                  color clr, int style, int width)
{
   if(p1 == 0 || p2 == 0) { ObjectDelete(0, name); return; }
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_TIME, 0, t1);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 0, p1);
   ObjectSetInteger(0, name, OBJPROP_TIME, 1, t2);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 1, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
}

//--- Helper: create or move a text label on chart
void SetChartLabel(string name, datetime t, double price, string text, 
                   color clr, int fontSize)
{
   if(price == 0) { ObjectDelete(0, name); return; }
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TEXT, 0, t, price);
   ObjectSetInteger(0, name, OBJPROP_TIME, t);
   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT);
}


//==================================================================
// 1. WAVE ARCS (H4 + H1 swing trend lines)
// Approximates curves by connecting confirmed swing pivots
//==================================================================
void DrawWaveArcs()
{
   if(!InpShowWaveArcs) return;
   datetime now = TimeCurrent();
   int period = PeriodSeconds();
   
   // H4 arc: origin → extreme as a trend line
   double h4Orig = g_structure[TF_H4].invalidation;
   double h4Ext = (g_structure[TF_H4].direction == 1) ? 
                   g_structure[TF_H4].swingHigh : g_structure[TF_H4].swingLow;
   if(h4Orig > 0 && h4Ext > 0)
   {
      datetime t1 = now - 200 * period;
      datetime t2 = now;
      SetTrendLine(VIS_PREFIX + "ARC_H4", t1, h4Orig, t2, h4Ext,
                   clrOrange, STYLE_DASH, 3);
   }
   
   // H1 arc: origin → extreme
   double h1Orig = g_structure[TF_H1].invalidation;
   double h1Ext = (g_structure[TF_H1].direction == 1) ?
                   g_structure[TF_H1].swingHigh : g_structure[TF_H1].swingLow;
   if(h1Orig > 0 && h1Ext > 0)
   {
      datetime t1 = now - 80 * period;
      datetime t2 = now;
      SetTrendLine(VIS_PREFIX + "ARC_H1", t1, h1Orig, t2, h1Ext,
                   clrYellow, STYLE_DASH, 2);
   }
}

//==================================================================
// 2. TRACEABILITY ZONES (per-TF boxes right of price)
// Shows each TF's wave range as a colored band
//==================================================================
void DrawTraceabilityZones()
{
   if(!InpShowTraceZones) return;
   datetime now = TimeCurrent();
   int period = PeriodSeconds();
   datetime rightEdge = now + 20 * period;
   
   color tfColors[] = {clrGray, clrMagenta, clrLime, clrAqua, clrAqua, clrYellow, clrOrange};
   string tfNames[] = {"M1", "M3", "M5", "M15", "M30", "H1", "H4"};
   int widths[] = {3, 5, 8, 10, 10, 14, 18}; // bar offset right for stacking
   
   for(int i = 0; i < 7; i++)
   {
      if(i == 4) continue; // skip M30 placeholder
      
      int layerIdx = (i < 4) ? i : (i == 5) ? TF_H1 : TF_H4;
      if(i >= 7) break;
      layerIdx = (i == 0) ? TF_M1 : (i == 1) ? TF_M3 : (i == 2) ? TF_M5 : 
                 (i == 3) ? TF_M15 : (i == 5) ? TF_H1 : TF_H4;
      
      double swH = g_structure[layerIdx].swingHigh;
      double swL = g_structure[layerIdx].swingLow;
      if(swH == 0 || swL == 0) continue;
      
      string name = VIS_PREFIX + "TZ_" + tfNames[i];
      datetime t1 = now + widths[i] * period;
      datetime t2 = t1 + 3 * period;
      
      SetRectangle(name, t1, swH, t2, swL, tfColors[i], STYLE_SOLID, false);
      
      // Label
      string lblName = VIS_PREFIX + "TZL_" + tfNames[i];
      int dir = g_structure[layerIdx].direction;
      string dirStr = (dir == 1) ? "^" : (dir == -1) ? "v" : "-";
      SetChartLabel(lblName, t2, swH, tfNames[i] + " " + dirStr, tfColors[i], 7);
   }
}

//==================================================================
// 3. REGION DISPLAY (phase region labels with debounce)
// Shows current phase as a persistent text object
//==================================================================
void DrawRegionDisplay()
{
   if(!InpShowRegions) return;
   
   string currentPhase = g_currentDisplayPhase;
   
   // Debounce: require new phase to hold for N bars before committing
   if(currentPhase != g_regionPhase)
   {
      if(currentPhase == g_pendingPhase)
         g_pendingCount++;
      else
      {
         g_pendingPhase = currentPhase;
         g_pendingCount = 1;
      }
      
      if(g_pendingCount >= g_regionConfirmBars)
      {
         g_regionPhase = currentPhase;
         g_regionStartBar = ArraySize(Close);
         g_pendingPhase = "";
         g_pendingCount = 0;
      }
   }
   else
   {
      g_pendingPhase = "";
      g_pendingCount = 0;
   }
   
   // Draw current region label
   if(g_regionPhase != "")
   {
      datetime now = TimeCurrent();
      double atr = g_physics.atr;
      double yPos = (g_direction == 1) ? 
         ((ArraySize(High) > 1) ? High[1] + atr * 1.5 : 0) :
         ((ArraySize(Low) > 1) ? Low[1] - atr * 1.5 : 0);
      
      if(yPos > 0)
      {
         color regCol = clrWhite;
         if(StringFind(g_regionPhase, "Liquidation") >= 0) regCol = clrOrange;
         else if(StringFind(g_regionPhase, "Induction") >= 0) regCol = clrYellow;
         else if(StringFind(g_regionPhase, "Pre-Conv") >= 0) regCol = clrMagenta;
         else if(StringFind(g_regionPhase, "New High") >= 0 || StringFind(g_regionPhase, "New Low") >= 0) regCol = clrLime;
         else if(StringFind(g_regionPhase, "Return") >= 0) regCol = clrAqua;
         else if(StringFind(g_regionPhase, "Expansion") >= 0) regCol = clrLimeGreen;
         else if(StringFind(g_regionPhase, "Retracement") >= 0) regCol = clrSilver;
         
         SetChartLabel(VIS_PREFIX + "REGION", now, yPos, g_regionPhase, regCol, 9);
      }
   }
}


//==================================================================
// 4. NETWORK WEB (lines connecting eligible nodes sorted by price)
//==================================================================
void DrawNetworkWeb()
{
   if(!InpShowNetworkWeb) return;
   
   // Delete old web lines
   for(int i = 0; i < 60; i++)
      ObjectDelete(0, VIS_PREFIX + "WEB_" + IntegerToString(i));
   
   if(g_nodeCount < 2) return;
   datetime now = TimeCurrent();
   int period = PeriodSeconds();
   
   // Collect eligible nodes sorted by price
   double prices[];
   int indices[];
   ArrayResize(prices, 0);
   ArrayResize(indices, 0);
   
   for(int i = 0; i < g_nodeCount; i++)
   {
      if(g_nodes[i].state == 2) continue; // skip consumed
      double auth = NodeAuthority(i);
      if(auth < InpAuthMin) continue;
      
      int sz = ArraySize(prices);
      ArrayResize(prices, sz + 1);
      ArrayResize(indices, sz + 1);
      prices[sz] = g_nodes[i].price;
      indices[sz] = i;
   }
   
   // Sort by price (insertion sort)
   int cnt = ArraySize(prices);
   for(int a = 1; a < cnt; a++)
   {
      double keyP = prices[a];
      int keyI = indices[a];
      int b = a - 1;
      while(b >= 0 && prices[b] > keyP)
      {
         prices[b+1] = prices[b];
         indices[b+1] = indices[b];
         b--;
      }
      prices[b+1] = keyP;
      indices[b+1] = keyI;
   }
   
   // Draw connecting lines (max 60 edges)
   int edges = MathMin(cnt - 1, 60);
   datetime x1 = now + 2 * period;
   for(int i = 0; i < edges; i++)
   {
      datetime x2 = x1 + 3 * period;
      color ec = clrDarkSlateGray;
      int wt = g_nodes[indices[i]].weight;
      if(wt >= 7) ec = clrGold;
      else if(wt >= 5) ec = clrDodgerBlue;
      else if(wt >= 3) ec = clrMediumSeaGreen;
      
      string name = VIS_PREFIX + "WEB_" + IntegerToString(i);
      SetTrendLine(name, x1, prices[i], x2, prices[i+1], ec, STYLE_DOT, 1);
      x1 = x2;
   }
}

//==================================================================
// 5. FEZ CORRIDOR (rectangle between above/below nodes)
//==================================================================
void DrawFEZCorridor()
{
   if(!InpShowFEZ)
   {
      ObjectDelete(0, VIS_PREFIX + "FEZ");
      return;
   }
   
   if(g_fezHigh <= 0 || g_fezLow <= 0)
   {
      ObjectDelete(0, VIS_PREFIX + "FEZ");
      return;
   }
   
   datetime now = TimeCurrent();
   int period = PeriodSeconds();
   SetRectangle(VIS_PREFIX + "FEZ", now - period, g_fezHigh, 
                now + 10 * period, g_fezLow, clrSlateBlue, STYLE_SOLID, true);
}

//==================================================================
// 6. PARTICIPANT FIB LEVELS (0.618/0.70/0.786/flip)
//==================================================================
void DrawParticipantLevels()
{
   if(!InpShowParticipants)
   {
      ObjectDelete(0, VIS_PREFIX + "PART_618");
      ObjectDelete(0, VIS_PREFIX + "PART_70");
      ObjectDelete(0, VIS_PREFIX + "PART_786");
      ObjectDelete(0, VIS_PREFIX + "PART_FLIP");
      return;
   }
   
   SetHLine(VIS_PREFIX + "PART_618", g_participants.fib618, 
            clrDodgerBlue, STYLE_DOT, 1, "0.618 participants");
   SetHLine(VIS_PREFIX + "PART_70", g_participants.fib70,
            clrGold, STYLE_DOT, 1, "0.70 interference");
   SetHLine(VIS_PREFIX + "PART_786", g_participants.fib786,
            clrOrangeRed, STYLE_DOT, 1, "0.786 heavy");
   SetHLine(VIS_PREFIX + "PART_FLIP", g_participants.flipLevel,
            clrCrimson, STYLE_SOLID, 2, "FLIP true induction");
}


//==================================================================
// 7. CURVE BUDGET TARGET (arrow from price to ODDE target)
//==================================================================
void DrawBudgetTarget()
{
   if(!InpShowBudgetTarget || g_curveBudgetTarget <= 0)
   {
      ObjectDelete(0, VIS_PREFIX + "BUDGET");
      ObjectDelete(0, VIS_PREFIX + "BUDGET_LBL");
      return;
   }
   
   datetime now = TimeCurrent();
   int period = PeriodSeconds();
   double closeNow = (ArraySize(Close) > 0) ? Close[0] : 0;
   if(closeNow == 0) return;
   
   // Arrow line from current price to budget target
   color budCol = (g_curve.direction == 1) ? clrGold : clrCrimson;
   SetTrendLine(VIS_PREFIX + "BUDGET", now, closeNow, 
                now + 25 * period, g_curveBudgetTarget,
                budCol, STYLE_SOLID, 3);
   
   // Label at target
   string txt = "BUDGET " + g_curveBudgetSource + " " + 
                DoubleToString(g_curveBudgetATR, 1) + " ATR";
   SetChartLabel(VIS_PREFIX + "BUDGET_LBL", now + 26 * period, 
                 g_curveBudgetTarget, txt, budCol, 8);
}

//==================================================================
// 8. FU ORDER BLOCK ZONES (rectangles for active FU blocks)
//==================================================================
void DrawFUZones()
{
   if(!InpShowFUZones)
   {
      for(int i = 0; i < FU_MAX_BLOCKS; i++)
         ObjectDelete(0, VIS_PREFIX + "FU_" + IntegerToString(i));
      return;
   }
   
   datetime now = TimeCurrent();
   int period = PeriodSeconds();
   
   for(int i = 0; i < FU_MAX_BLOCKS; i++)
   {
      string name = VIS_PREFIX + "FU_" + IntegerToString(i);
      
      if(i >= g_fuBlockCount)
      {
         ObjectDelete(0, name);
         continue;
      }
      
      FUBlock *blk = GetPointer(g_fuBlocks[i]);
      if(blk.state >= 3) // exhausted or invalidated
      {
         ObjectDelete(0, name);
         continue;
      }
      
      // Zone rectangle
      datetime t1 = now - blk.birthBar * period;
      datetime t2 = now + 10 * period;
      color zoneCol = (blk.direction == 1) ? clrMediumSeaGreen : clrCrimson;
      if(blk.state == 2) zoneCol = clrDarkGoldenrod; // interacting
      
      SetRectangle(name, t1, blk.top, t2, blk.bot, zoneCol, STYLE_DASH, false);
   }
}

//==================================================================
// 9. ENERGY REGISTRY LEVELS (dotted lines for unresolved events)
//==================================================================
void DrawEnergyLevels()
{
   if(!InpShowEnergyLevels)
   {
      for(int i = 0; i < REGISTRY_MAX; i++)
         ObjectDelete(0, VIS_PREFIX + "ERG_" + IntegerToString(i));
      return;
   }
   
   for(int i = 0; i < REGISTRY_MAX; i++)
   {
      string name = VIS_PREFIX + "ERG_" + IntegerToString(i);
      
      if(i >= g_registryCount)
      {
         ObjectDelete(0, name);
         continue;
      }
      
      EnergyEvent *ev = GetPointer(g_energyRegistry[i]);
      
      // Only show unresolved or partial
      if(ev.resolution >= 2)
      {
         ObjectDelete(0, name);
         continue;
      }
      
      color evCol = (ev.resolution == 0) ? clrOrangeRed : clrDarkOrange;
      string tip = StringFormat("Energy #%d %s res=%d E=%.0f",
                   i+1, (ev.direction == 1 ? "BULL" : "BEAR"),
                   ev.resolution, ev.residualEnergy);
      
      SetHLine(name, ev.price, evCol, STYLE_DOT, 1, tip);
   }
}

//==================================================================
// 10. FU WICK AUTHORITY + INDUCTION BAND
//==================================================================
void DrawFUWickAuthority()
{
   if(!g_fuWick.validated || g_fuWick.tip == 0)
   {
      ObjectDelete(0, VIS_PREFIX + "FUWK_TIP");
      ObjectDelete(0, VIS_PREFIX + "FUWK_MID");
      ObjectDelete(0, VIS_PREFIX + "FUWK_BAND");
      ObjectDelete(0, VIS_PREFIX + "FUWK_MAG");
      return;
   }
   
   SetHLine(VIS_PREFIX + "FUWK_TIP", g_fuWick.tip, clrOrange, STYLE_SOLID, 1, "FU Tip");
   SetHLine(VIS_PREFIX + "FUWK_MID", g_fuWick.mid, clrAqua, STYLE_DASH, 1, "FU Mid");
   
   // Induction band as rectangle
   double bandHi = MathMax(g_fuWick.band38, g_fuWick.band62);
   double bandLo = MathMin(g_fuWick.band38, g_fuWick.band62);
   if(bandHi > 0 && bandLo > 0)
   {
      datetime now = TimeCurrent();
      int period = PeriodSeconds();
      SetRectangle(VIS_PREFIX + "FUWK_BAND", now - 5*period, bandHi, 
                   now + 12*period, bandLo, clrYellow, STYLE_SOLID, true);
   }
   
   // Magnet (captured left-pool)
   if(g_fuWick.leftPool > 0)
      SetHLine(VIS_PREFIX + "FUWK_MAG", g_fuWick.leftPool, clrMagenta, STYLE_DASH, 1, "MAGNET");
}


//==================================================================
// 11. FU CONVERSATION ROUTE (line from price through FU nodes)
//==================================================================
void DrawFUConversationRoute()
{
   // Delete old route lines
   for(int i = 0; i < 6; i++)
      ObjectDelete(0, VIS_PREFIX + "CONV_" + IntegerToString(i));
   ObjectDelete(0, VIS_PREFIX + "CONV_LBL");
   
   if(g_convConfidence < 35 || g_convSeekPx <= 0) return;
   
   datetime now = TimeCurrent();
   int period = PeriodSeconds();
   double closeNow = (ArraySize(Close) > 0) ? Close[0] : 0;
   if(closeNow == 0) return;
   
   // Draw arrow from price to sought FU
   SetTrendLine(VIS_PREFIX + "CONV_0", now, closeNow, 
                now + 9 * period, g_convSeekPx,
                clrMediumPurple, STYLE_SOLID, 2);
   
   // Label
   string lbl = g_convSeekTf + " FU " + IntegerToString((int)g_convConfidence) + "%";
   SetChartLabel(VIS_PREFIX + "CONV_LBL", now + 10 * period, g_convSeekPx, lbl, clrMediumPurple, 8);
}

//==================================================================
// 12. AFE FLIP-ECHO ARROW (destination arrow)
//==================================================================
void DrawAFEArrow()
{
   if(g_afe.step < 1 || g_afe.activeDest == 0)
   {
      ObjectDelete(0, VIS_PREFIX + "AFE");
      return;
   }
   
   datetime now = TimeCurrent();
   int period = PeriodSeconds();
   double closeNow = (ArraySize(Close) > 0) ? Close[0] : 0;
   if(closeNow == 0) return;
   
   SetTrendLine(VIS_PREFIX + "AFE", now, closeNow,
                now + 18 * period, g_afe.activeDest,
                clrOrchid, STYLE_DASH, 2);
}

//==================================================================
// MASTER VISUAL UPDATE (call every tick for responsive display)
//==================================================================
void UpdateVisualSystems()
{
   // 1. Wave arcs (H4 + H1)
   DrawWaveArcs();
   
   // 2. Traceability zones (per-TF bands)
   DrawTraceabilityZones();
   
   // 3. Phase region label (with debounce)
   DrawRegionDisplay();
   
   // 4. Network web (node connections)
   DrawNetworkWeb();
   
   // 5. FEZ corridor
   DrawFEZCorridor();
   
   // 6. Participant Fib levels
   DrawParticipantLevels();
   
   // 7. Curve budget target arrow
   DrawBudgetTarget();
   
   // 8. FU order block zones
   DrawFUZones();
   
   // 9. Energy registry unresolved levels
   DrawEnergyLevels();
   
   // 10. FU Wick Authority + induction band
   DrawFUWickAuthority();
   
   // 11. FU Conversation route arrow
   DrawFUConversationRoute();
   
   // 12. AFE flip-echo arrow
   DrawAFEArrow();
}

//+------------------------------------------------------------------+
