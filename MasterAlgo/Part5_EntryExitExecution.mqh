//+------------------------------------------------------------------+
//| Part5_EntryExitExecution.mqh                                      |
//| MASTER ALGO - Entry/Exit Execution Engine                         |
//| Symphony P3/P4 entries (precise stop placement)                   |
//| + Letra belief-gated Demand/Supply Return entries                 |
//| + ARC convexity exits + Institutional sweep exits                 |
//| + ERF entry gate + Fractal stack confirmation                     |
//+------------------------------------------------------------------+
#property strict

//==================================================================
// ENTRY/EXIT EXECUTION ENGINE
//
// TWO ENTRY SYSTEMS (run in parallel, non-conflicting):
//
// SYSTEM A - SYMPHONY P3/P4 (curvature-based impulse entries)
//   - Phase 3: Retracement complete, enter with trend
//   - Phase 4: Breakout/continuation beyond anchor
//   - Stop: Anchor extreme + 0.25 ATR buffer
//   - Gated by: time filter, ERF gate, fractal alignment
//
// SYSTEM B - LETRA DEMAND/SUPPLY RETURN (lifecycle entries)  
//   - Enter when IE1A reaches Demand Return / Supply Return
//   - Requires: belief threshold, structure confirm, liq sweep
//   - Stop: Flip zone extreme + ATR buffer
//   - Gated by: ERF gate, HTF alignment, edge threshold
//
// EXIT SYSTEMS:
//   - ARC v2 Convexity Exhaustion (Symphony)
//   - Institutional Outer-Band Sweep + Re-entry (Symphony)
//   - Phase-Change Composite Exit (Symphony)
//   - Structural Invalidation Exit (Letra)
//   - IE1A Phase Transition Exit (to Absorption/Retracement)
//==================================================================

//--- Execution state
bool   g_engineArmed = true;
int    g_dynamicLockBars = 10;

//==================================================================
// 1. SYMPHONY P3/P4 ENTRY EXECUTION
// From Symphony Section 15 - precise phase-based entries
//==================================================================
void ExecuteSymphonyEntries()
{
   int barsAvail = ArraySize(Close);
   if(barsAvail < 3) return;
   
   int shiftNow = 1;
   double closeNow = Close[shiftNow];
   double atrNow = GetATR(shiftNow);
   datetime barTime = Time[0];
   
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskCash = equity * InpRiskPercent * 0.01;
   
   //--- GATES ---
   // Time filter
   if(!IsTradeTime()) return;
   
   // ERF entry gate
   if(InpERFGateEnabled && !g_erf.entryGateOpen) return;
   
   // Fractal stack minimum alignment (at least 4/6 agree)
   if(g_fractalStack.score < 66.0) return;
   
   // Senseei must not be in WAIT with high conflict
   if(g_senseei.conflict > 60) return;
   
   // Net edge threshold
   if(MathAbs(g_netEdge) < InpExecThreshold) return;
   
   //--- Symphony phase conditions
   bool L3 = (g_mode == 1 && g_phaseLong == 3);
   bool L4 = (g_mode == 1 && g_phaseLong == 4);
   bool S3 = (g_mode == -1 && g_phaseShort == 3);
   bool S4 = (g_mode == -1 && g_phaseShort == 4);
   
   //--- Additional intelligence gates for higher quality
   // Require wave direction agreement with Symphony mode
   bool dirAgree = (g_mode == 1 && g_structure[TF_M5].direction == 1) ||
                   (g_mode == -1 && g_structure[TF_M5].direction == -1);
   if(!dirAgree) return;
   
   //--- LONG P3 Entry
   if(L3 && g_lastLongTradeTime != barTime && g_netEdge > 0)
   {
      double entry = closeNow;
      double sl = g_anchorLow - atrNow * 0.25;
      double lots = ComputeLots(riskCash, entry, sl);
      
      if(sl > 0 && entry > sl && lots > 0)
      {
         string comment = StringFormat("SYM P3L c%.0f s%.0f", g_phaseConfidence, g_fractalStack.score);
         if(SendMarketOrder(+1, lots, sl, comment))
         {
            g_lastLongTradeTime = barTime;
            g_lastSignalBar = barsAvail;
            g_engineArmed = false;
            Print("ENTRY: Symphony P3 Long | SL=", sl, " | Conf=", g_phaseConfidence);
         }
      }
   }
   
   //--- LONG P4 Entry (breakout)
   if(L4 && g_lastLongTradeTime != barTime && g_netEdge > 0)
   {
      double impL = g_anchorHigh - g_anchorLow;
      if(impL > 0)
      {
         bool breakout = (closeNow > g_anchorHigh || closeNow > High[shiftNow+1] + 0.20 * atrNow);
         if(breakout)
         {
            double entry = closeNow;
            double sl = g_anchorLow - atrNow * 0.25;
            double lots = ComputeLots(riskCash, entry, sl);
            
            if(sl > 0 && entry > sl && lots > 0)
            {
               string comment = StringFormat("SYM P4L c%.0f s%.0f", g_phaseConfidence, g_fractalStack.score);
               if(SendMarketOrder(+1, lots, sl, comment))
               {
                  g_lastLongTradeTime = barTime;
                  g_lastSignalBar = barsAvail;
                  g_engineArmed = false;
                  Print("ENTRY: Symphony P4 Long Breakout | SL=", sl);
               }
            }
         }
      }
   }
   
   //--- SHORT P3 Entry
   if(S3 && g_lastShortTradeTime != barTime && g_netEdge < 0)
   {
      double entry = closeNow;
      double sl = g_anchorHigh + atrNow * 0.25;
      double lots = ComputeLots(riskCash, entry, sl);
      
      if(sl > 0 && sl > entry && lots > 0)
      {
         string comment = StringFormat("SYM P3S c%.0f s%.0f", g_phaseConfidence, g_fractalStack.score);
         if(SendMarketOrder(-1, lots, sl, comment))
         {
            g_lastShortTradeTime = barTime;
            g_lastSignalBar = barsAvail;
            g_engineArmed = false;
            Print("ENTRY: Symphony P3 Short | SL=", sl);
         }
      }
   }
   
   //--- SHORT P4 Entry (breakout)
   if(S4 && g_lastShortTradeTime != barTime && g_netEdge < 0)
   {
      double impS = g_anchorHigh - g_anchorLow;
      if(impS > 0)
      {
         bool breakout = (closeNow < g_anchorLow || closeNow < Low[shiftNow+1] - 0.20 * atrNow);
         if(breakout)
         {
            double entry = closeNow;
            double sl = g_anchorHigh + atrNow * 0.25;
            double lots = ComputeLots(riskCash, entry, sl);
            
            if(sl > 0 && sl > entry && lots > 0)
            {
               string comment = StringFormat("SYM P4S c%.0f s%.0f", g_phaseConfidence, g_fractalStack.score);
               if(SendMarketOrder(-1, lots, sl, comment))
               {
                  g_lastShortTradeTime = barTime;
                  g_lastSignalBar = barsAvail;
                  g_engineArmed = false;
                  Print("ENTRY: Symphony P4 Short Breakout | SL=", sl);
               }
            }
         }
      }
   }
}

//==================================================================
// 2. LETRA DEMAND/SUPPLY RETURN ENTRIES
// From Letra Section 21 - belief-gated lifecycle entries
//==================================================================
void ExecuteLetraEntries()
{
   int barsAvail = ArraySize(Close);
   if(barsAvail < 3) return;
   
   int shiftNow = 1;
   double closeNow = Close[shiftNow];
   double atrNow = GetATR(shiftNow);
   datetime barTime = Time[0];
   
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskCash = equity * InpRiskPercent * 0.01;
   
   //--- GATES ---
   if(!IsTradeTime()) return;
   if(InpERFGateEnabled && !g_erf.entryGateOpen) return;
   if(g_senseei.conflict > 60) return;
   
   // Lock check
   bool withinLock = (g_lastSignalBar >= 0 && (barsAvail - g_lastSignalBar) < g_dynamicLockBars);
   if(withinLock && !g_engineArmed) return;
   
   //--- Belief-based entry conditions (IE1A authority)
   bool beliefEntryLong = (g_direction == 1 &&
      g_currentPhase == PHASE_DEMAND_RETURN &&
      g_beliefDemandReturn > 50 &&
      g_beliefExpansion < 60 &&
      g_beliefAbsorption > 25);
   
   bool beliefEntryShort = (g_direction == -1 &&
      g_currentPhase == PHASE_SUPPLY_RETURN &&
      g_beliefDemandReturn > 50 &&
      g_beliefExpansion < 60 &&
      g_beliefAbsorption > 25);
   
   //--- Additional quality gates
   // Structure confirmation
   bool structLongOK = (g_fractalStack.direction == 1 || g_fractalStack.score >= 50);
   bool structShortOK = (g_fractalStack.direction == -1 || g_fractalStack.score >= 50);
   
   // HTF alignment (H1+H4 not opposing)
   int htfAlign = (g_structure[TF_H1].direction == g_structure[TF_H4].direction) ? 
                   g_structure[TF_H1].direction : 0;
   bool htfLongOK = (htfAlign >= 0);  // not bearish
   bool htfShortOK = (htfAlign <= 0); // not bullish
   
   // Liquidity sweep
   bool liqOK = g_liqSweepOK;
   
   // Edge filter
   bool edgeOK = (MathAbs(g_netEdge) > InpExecThreshold);
   
   // Model confidence
   bool confOK = (g_modelConfidence > 40);
   
   //--- LONG SIGNAL
   bool longSignal = beliefEntryLong && structLongOK && htfLongOK && 
                     liqOK && edgeOK && confOK && g_netEdge > 0;
   
   //--- SHORT SIGNAL
   bool shortSignal = beliefEntryShort && structShortOK && htfShortOK && 
                      liqOK && edgeOK && confOK && g_netEdge < 0;
   
   //--- Execute Long
   if(longSignal && g_lastLongTradeTime != barTime)
   {
      double entry = closeNow;
      // Stop below flip zone bottom with buffer
      double sl = (g_flipBot > 0) ? g_flipBot - atrNow * 0.3 : 
                  (g_point4Low > 0) ? g_point4Low - atrNow * 0.3 : entry - atrNow * 2.0;
      double lots = ComputeLots(riskCash, entry, sl);
      
      if(sl > 0 && entry > sl && lots > 0)
      {
         string comment = StringFormat("LTR DRL b%.0f c%.0f", g_beliefDemandReturn, g_modelConfidence);
         if(SendMarketOrder(+1, lots, sl, comment))
         {
            g_lastLongTradeTime = barTime;
            g_lastSignalBar = barsAvail;
            g_lastLongBar = barsAvail;
            g_engineArmed = false;
            Print("ENTRY: Letra Demand Return Long | Belief=", g_beliefDemandReturn,
                  " | Conf=", g_modelConfidence, " | SL=", sl);
         }
      }
   }
   
   //--- Execute Short
   if(shortSignal && g_lastShortTradeTime != barTime)
   {
      double entry = closeNow;
      // Stop above flip zone top with buffer
      double sl = (g_flipTop > 0) ? g_flipTop + atrNow * 0.3 :
                  (g_point4High > 0) ? g_point4High + atrNow * 0.3 : entry + atrNow * 2.0;
      double lots = ComputeLots(riskCash, entry, sl);
      
      if(sl > 0 && sl > entry && lots > 0)
      {
         string comment = StringFormat("LTR SRS b%.0f c%.0f", g_beliefDemandReturn, g_modelConfidence);
         if(SendMarketOrder(-1, lots, sl, comment))
         {
            g_lastShortTradeTime = barTime;
            g_lastSignalBar = barsAvail;
            g_lastShortBar = barsAvail;
            g_engineArmed = false;
            Print("ENTRY: Letra Supply Return Short | Belief=", g_beliefDemandReturn,
                  " | Conf=", g_modelConfidence, " | SL=", sl);
         }
      }
   }
}

//==================================================================
// 3. ARC + INSTITUTIONAL + PHASE COMPOSITE EXIT
// From Symphony Section 16 - multi-condition exit system
//==================================================================
void ManageArcInstitutionalExits()
{
   int barsAvail = ArraySize(Close);
   if(barsAvail <= (2 * InpPivotLen + 5)) return;
   
   int shiftNow = 1;
   double closeNow = Close[shiftNow];
   double atrNow = GetATR(shiftNow);
   
   //--- 1) ARC exhaustion flags
   bool arcExhaustLong = (g_mode == 1 && g_arcLong > 0 && 
                          closeNow >= (g_arcLong - InpArcToleranceAtr * atrNow));
   bool arcExhaustShort = (g_mode == -1 && g_arcShort > 0 && 
                           closeNow <= (g_arcShort + InpArcToleranceAtr * atrNow));
   
   //--- 2) Institutional bands
   // LONG side
   double instLevelL = (g_flipzoneInducPrice > 0) ? g_flipzoneInducPrice : 
                       (g_anchorHigh > 0 ? g_anchorHigh : 0);
   double innerTopL = (g_flipzoneInducHigh > 0) ? g_flipzoneInducHigh : instLevelL;
   double outerTopL = innerTopL + InpOuterBandAtrMult * atrNow;
   
   // SHORT side
   double instLevelS = (g_flipzoneInducPrice > 0) ? g_flipzoneInducPrice :
                       (g_anchorLow > 0 ? g_anchorLow : 0);
   double innerBotS = (g_flipzoneInducLow > 0) ? g_flipzoneInducLow : instLevelS;
   double outerBotS = innerBotS - InpOuterBandAtrMult * atrNow;
   
   //--- 3) Track outer-band sweeps
   if(g_mode == 1 && instLevelL > 0 && closeNow > outerTopL)
      g_longOuterBreachSeen = true;
   if(g_mode == -1 && instLevelS > 0 && closeNow < outerBotS)
      g_shortOuterBreachSeen = true;
   
   //--- 4) Phase-change at extreme
   bool phaseTrendEndLong = (g_mode == 1 &&
      (g_prevPhaseLong == 3 || g_prevPhaseLong == 4) &&
      g_phaseLong <= 1);
   
   bool phaseTrendEndShort = (g_mode == -1 &&
      (g_prevPhaseShort == 3 || g_prevPhaseShort == 4) &&
      g_phaseShort <= 1);
   
   //--- 5) Full exit conditions (all three must agree)
   bool exitLong = false;
   bool exitShort = false;
   
   // LONG: ARC exhaust + outer sweep + phase-end
   if(g_mode == 1 && arcExhaustLong && phaseTrendEndLong)
   {
      bool instPatternOK = (instLevelL <= 0) ||
         (g_longOuterBreachSeen && closeNow < innerTopL);
      if(instPatternOK) exitLong = true;
   }
   
   // SHORT: ARC exhaust + outer sweep + phase-end
   if(g_mode == -1 && arcExhaustShort && phaseTrendEndShort)
   {
      bool instPatternOK = (instLevelS <= 0) ||
         (g_shortOuterBreachSeen && closeNow > innerBotS);
      if(instPatternOK) exitShort = true;
   }
   
   if(!exitLong && !exitShort) return;
   
   //--- 6) Execute exits
   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      
      long type = PositionGetInteger(POSITION_TYPE);
      
      if(exitLong && type == POSITION_TYPE_BUY)
      {
         if(!ClosePositionFull(ticket))
            Print("ARC/INST LONG EXIT failed ticket ", ticket);
         else
            Print("EXIT: ARC+Institutional Long | ARC=", g_arcLong);
      }
      
      if(exitShort && type == POSITION_TYPE_SELL)
      {
         if(!ClosePositionFull(ticket))
            Print("ARC/INST SHORT EXIT failed ticket ", ticket);
         else
            Print("EXIT: ARC+Institutional Short | ARC=", g_arcShort);
      }
   }
}

//==================================================================
// 4. STRUCTURAL INVALIDATION EXIT
// Closes all positions when wave structure is invalidated
//==================================================================
void ManageStructuralExits()
{
   if(ArraySize(Close) < 2) return;
   
   double closeNow = Close[1];
   double atrNow = GetATR(1);
   
   //--- IE1A Phase transition exits
   // Exit when phase moves to Absorption or Retracement (against the trade)
   bool phaseExitLong = (g_currentPhase == PHASE_ABSORPTION || 
                         g_currentPhase == PHASE_RETRACEMENT);
   bool phaseExitShort = (g_currentPhase == PHASE_ABSORPTION ||
                          g_currentPhase == PHASE_RETRACEMENT);
   
   //--- Senseei threat exit (from F16)
   bool threatExit = (g_senseei.threat > 75 && g_senseei.action == ACTION_WAIT);
   
   //--- ERF resolution exit (energy fully resolved = no more edge)
   bool erfExit = (g_erf.resolutionState == RES_RESOLVED && g_waveProgress > 90);
   
   //--- Execute exits
   bool doExit = false;
   string exitReason = "";
   
   if(phaseExitLong || phaseExitShort)
   {
      doExit = true;
      exitReason = "Phase transition to " + g_currentDisplayPhase;
   }
   else if(threatExit)
   {
      doExit = true;
      exitReason = StringFormat("Senseei threat %.0f%%", g_senseei.threat);
   }
   else if(erfExit)
   {
      doExit = true;
      exitReason = "ERF Resolved + Progress 90%+";
   }
   
   if(!doExit) return;
   
   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      
      long type = PositionGetInteger(POSITION_TYPE);
      
      // Only exit positions aligned with the direction that's ending
      if(phaseExitLong && type == POSITION_TYPE_BUY && g_direction == 1)
      {
         ClosePositionFull(ticket);
         Print("EXIT: Structural | ", exitReason);
      }
      else if(phaseExitShort && type == POSITION_TYPE_SELL && g_direction == -1)
      {
         ClosePositionFull(ticket);
         Print("EXIT: Structural | ", exitReason);
      }
      else if(threatExit || erfExit)
      {
         ClosePositionFull(ticket);
         Print("EXIT: Intelligence | ", exitReason);
      }
   }
}

//==================================================================
// 5. TRAILING STOP MANAGEMENT
// Moves stop to breakeven then trails using M5 structure
//==================================================================
void ManageTrailingStops()
{
   double atrNow = GetATR(1);
   if(atrNow <= 0) return;
   
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      
      long type = PositionGetInteger(POSITION_TYPE);
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double profit = PositionGetDouble(POSITION_PROFIT);
      
      // Only trail if in profit > 1 ATR
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      
      if(type == POSITION_TYPE_BUY)
      {
         double unrealPts = bid - entry;
         if(unrealPts > atrNow * 1.5) // 1.5 ATR in profit
         {
            // Trail to M5 swing low or breakeven+buffer, whichever is higher
            double m5SwingLow = g_structure[TF_M5].swingLow;
            double breakeven = entry + atrNow * 0.1;
            double newSL = MathMax(breakeven, m5SwingLow > 0 ? m5SwingLow - atrNow * 0.15 : breakeven);
            
            if(newSL > currentSL && newSL < bid - atrNow * 0.5)
            {
               MqlTradeRequest req;
               MqlTradeResult res;
               ZeroMemory(req);
               ZeroMemory(res);
               req.action = TRADE_ACTION_SLTP;
               req.position = ticket;
               req.symbol = _Symbol;
               req.sl = NormalizeDouble(newSL, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
               req.tp = 0;
               OrderSend(req, res);
            }
         }
      }
      else if(type == POSITION_TYPE_SELL)
      {
         double unrealPts = entry - ask;
         if(unrealPts > atrNow * 1.5)
         {
            double m5SwingHigh = g_structure[TF_M5].swingHigh;
            double breakeven = entry - atrNow * 0.1;
            double newSL = MathMin(breakeven, m5SwingHigh > 0 ? m5SwingHigh + atrNow * 0.15 : breakeven);
            
            if(newSL < currentSL && newSL > ask + atrNow * 0.5)
            {
               MqlTradeRequest req;
               MqlTradeResult res;
               ZeroMemory(req);
               ZeroMemory(res);
               req.action = TRADE_ACTION_SLTP;
               req.position = ticket;
               req.symbol = _Symbol;
               req.sl = NormalizeDouble(newSL, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
               req.tp = 0;
               OrderSend(req, res);
            }
         }
      }
   }
}

//==================================================================
// 6. EXECUTION LOCK MANAGEMENT
//==================================================================
void UpdateExecutionLock()
{
   int barsAvail = ArraySize(Close);
   
   // Dynamic lock bars based on volatility
   double atrSma = GetATRSmooth(1, 20);
   double atrNow = GetATR(1);
   double volRatio = (atrSma > 0) ? atrNow / atrSma : 1.0;
   g_dynamicLockBars = (int)MathRound(InpBaseLockBars * MathMax(0.5, MathMin(volRatio, 2.5)));
   
   // Re-arm conditions
   // Recursive cycle fires
   if(g_recursiveComplete && !g_engineArmed)
      g_engineArmed = true;
   
   // Induction evidence in flipzone
   if(g_inductionEvidence && g_nearFlipzone && !g_engineArmed)
      g_engineArmed = true;
   
   // Lock expired
   bool lockExpired = (g_lastSignalBar >= 0 && (barsAvail - g_lastSignalBar) >= g_dynamicLockBars);
   if(lockExpired)
      g_engineArmed = true;
}

//==================================================================
// MASTER EXECUTION UPDATE (call from OnTick after new bar)
//==================================================================
void UpdateExecution()
{
   // 1. Update execution lock state
   UpdateExecutionLock();
   
   // 2. Manage trailing stops on existing positions
   ManageTrailingStops();
   
   // 3. ARC + Institutional exits (Symphony)
   ManageArcInstitutionalExits();
   
   // 4. Structural/Intelligence exits (Letra + Senseei)
   ManageStructuralExits();
   
   // 5. Symphony P3/P4 entries
   ExecuteSymphonyEntries();
   
   // 6. Letra Demand/Supply Return entries
   ExecuteLetraEntries();
}

//+------------------------------------------------------------------+
