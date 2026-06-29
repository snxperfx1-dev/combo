//+------------------------------------------------------------------+
//| Part8_Execution.mqh - Order Execution, Position Management,     |
//|                       and Trade Flow Orchestration               |
//| Master MT5 EA: Symphony + Letra + F16 Combined System           |
//+------------------------------------------------------------------+
#property strict

//==================================================================
// ORDER EXECUTION AND TRADE FLOW ORCHESTRATION
// Provides raw MqlTradeRequest-based execution (IOC filling, hedging
// account model), per-campaign (per-direction) position tracking,
// and position management driven by curve-alive + Senseei outputs.
//
// Functions:
//   SendMarketOrder()        - IOC market entry (Symphony section 12)
//   ClosePositionPartial()   - Partial close by ticket
//   ClosePositionFull()      - Full close wrapper
//   ModifyPositionSL()       - SL modification (TRADE_ACTION_SLTP)
//   CollectPositionsByDirection() - Per-campaign position arrays
//   ExecuteTrading()         - Entry orchestration (probabilistic gate)
//   ManagePositions()        - Curve-alive / Senseei-driven management
//==================================================================

//==================================================================
// 1. RAW ORDER EXECUTION - SendMarketOrder (Symphony Section 12)
//    IOC filling, deviation 20, direction-based price, stop loss.
//==================================================================
bool SendMarketOrder(int direction, double lots, double sl, const string comment)
{
   if(lots <= 0.0) return(false);

   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   req.action       = TRADE_ACTION_DEAL;
   req.symbol       = _Symbol;
   req.magic        = InpMagic;
   req.volume       = lots;
   req.sl           = sl;
   req.tp           = 0.0;
   req.deviation    = 20;
   req.type_filling = ORDER_FILLING_IOC;
   req.type_time    = ORDER_TIME_GTC;
   req.comment      = comment;

   if(direction > 0)
   {
      req.type  = ORDER_TYPE_BUY;
      req.price = ask;
   }
   else
   {
      req.type  = ORDER_TYPE_SELL;
      req.price = bid;
   }

   if(!OrderSend(req, res))
   {
      Print("OrderSend failed dir=", direction, " lots=", lots, " retcode=", res.retcode);
      return(false);
   }

   if(res.retcode != TRADE_RETCODE_DONE && res.retcode != TRADE_RETCODE_DONE_PARTIAL)
   {
      Print("OrderSend not DONE, retcode=", res.retcode);
      return(false);
   }

   return(true);
}

//==================================================================
// 2. CLOSE POSITION PARTIAL / FULL
//    Already defined in Part2_PhaseEngine.mqh (Symphony Section 12).
//    ClosePositionPartial(ulong ticket, double lotsToClose)
//    ClosePositionFull(ulong ticket)
//    Both use IOC filling, verify symbol/magic, send opposite direction.
//    Not duplicated here to avoid linker errors.
//==================================================================

//==================================================================
// 4. MODIFY POSITION STOP LOSS (TRADE_ACTION_SLTP)
//    Move SL to new level while keeping TP at 0.
//==================================================================
void ModifyPositionSL(ulong ticket, double newSL)
{
   if(!PositionSelectByTicket(ticket)) return;

   string sym = PositionGetString(POSITION_SYMBOL);
   long   mgc = PositionGetInteger(POSITION_MAGIC);

   if(sym != _Symbol) return;
   if(mgc != InpMagic) return;

   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);

   req.action   = TRADE_ACTION_SLTP;
   req.symbol   = _Symbol;
   req.position = ticket;
   req.sl       = newSL;
   req.tp       = 0.0;

   if(!OrderSend(req, res))
   {
      Print("ModifyPositionSL failed ticket=", ticket, " newSL=", newSL, " retcode=", res.retcode);
   }
}

//==================================================================
// 5. COLLECT POSITIONS BY DIRECTION
//    Iterate PositionsTotal(), filter by symbol/magic/direction.
//    Returns count, fills ticket/lots/entry arrays.
//==================================================================
int CollectPositionsByDirection(int dir, ulong &tickets[], double &lots[], double &entries[])
{
   int total = PositionsTotal();
   int count = 0;

   // Resize arrays to max possible
   ArrayResize(tickets, total);
   ArrayResize(lots, total);
   ArrayResize(entries, total);

   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;

      string sym  = PositionGetString(POSITION_SYMBOL);
      long   mgc  = PositionGetInteger(POSITION_MAGIC);
      long   type = PositionGetInteger(POSITION_TYPE);

      if(sym != _Symbol) continue;
      if(mgc != InpMagic) continue;

      // Direction filter: dir=+1 means BUY, dir=-1 means SELL
      if(dir > 0 && type != POSITION_TYPE_BUY) continue;
      if(dir < 0 && type != POSITION_TYPE_SELL) continue;

      tickets[count] = ticket;
      lots[count]    = PositionGetDouble(POSITION_VOLUME);
      entries[count] = PositionGetDouble(POSITION_PRICE_OPEN);
      count++;
   }

   // Resize to actual count
   ArrayResize(tickets, count);
   ArrayResize(lots, count);
   ArrayResize(entries, count);

   return(count);
}

//==================================================================
// 6. EXECUTE TRADING - ENTRY ORCHESTRATION
//    Modified from Symphony section 15 with probabilistic gate.
//    Entry fires only when IsMasterEntrySignal() returns true
//    (Phase 3/4 + Senseei ATTACK/PREPARE + entryProb > threshold
//     + IsTradeTime()).
//==================================================================
void ExecuteTrading()
{
   int barsAvail = (int)ArraySize(Close);
   if(barsAvail < 3) return;

   //--- Probabilistic gate: checks phase, probability, action, and time
   if(!IsMasterEntrySignal())
      return;

   //--- Prepare entry variables
   int      shiftNow = 1;
   double   closeNow = Close[shiftNow];
   double   atrNow   = GetATR(shiftNow);
   datetime barTime  = Time[0];

   double equity   = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskCash = equity * InpRiskPercent * 0.01;

   //--- Impulse measurement
   double impL = g_phase.anchorHigh - g_phase.anchorLow;
   double impS = g_phase.anchorHigh - g_phase.anchorLow;

   //===============================================================
   // LONG ENTRIES (mode == 1 AND (phaseLong == 3 OR phaseLong == 4))
   //===============================================================
   bool L3 = (g_phase.mode == 1  && g_phase.phaseLong == 3);
   bool L4 = (g_phase.mode == 1  && g_phase.phaseLong == 4);

   // LONG P3 - Phase 3 entry
   if(L3 && g_phase.lastLongTradeTime != barTime)
   {
      double entry = closeNow;
      double sl    = g_phase.anchorLow - atrNow * 0.25;
      double lots  = ComputeLots(riskCash, entry, sl);

      if(sl > 0 && entry > sl && lots > 0)
      {
         if(SendMarketOrder(+1, lots, sl, "MASTER P3 Long"))
            g_phase.lastLongTradeTime = barTime;
      }
   }

   // LONG P4 - Phase 4 breakout entry
   if(L4 && g_phase.lastLongTradeTime != barTime && impL > 0)
   {
      bool breakout = (closeNow > g_phase.anchorHigh ||
                       closeNow > High[shiftNow + 1] + 0.20 * atrNow);
      if(breakout)
      {
         double entry = closeNow;
         double sl    = g_phase.anchorLow - atrNow * 0.25;
         double lots  = ComputeLots(riskCash, entry, sl);

         if(sl > 0 && entry > sl && lots > 0)
         {
            if(SendMarketOrder(+1, lots, sl, "MASTER P4 Long"))
               g_phase.lastLongTradeTime = barTime;
         }
      }
   }

   //===============================================================
   // SHORT ENTRIES (mode == -1 AND (phaseShort == 3 OR phaseShort == 4))
   //===============================================================
   bool S3 = (g_phase.mode == -1 && g_phase.phaseShort == 3);
   bool S4 = (g_phase.mode == -1 && g_phase.phaseShort == 4);

   // SHORT P3 - Phase 3 entry
   if(S3 && g_phase.lastShortTradeTime != barTime)
   {
      double entry = closeNow;
      double sl    = g_phase.anchorHigh + atrNow * 0.25;
      double lots  = ComputeLots(riskCash, entry, sl);

      if(sl > 0 && sl > entry && lots > 0)
      {
         if(SendMarketOrder(-1, lots, sl, "MASTER P3 Short"))
            g_phase.lastShortTradeTime = barTime;
      }
   }

   // SHORT P4 - Phase 4 breakout entry
   if(S4 && g_phase.lastShortTradeTime != barTime && impS > 0)
   {
      bool breakout = (closeNow < g_phase.anchorLow ||
                       closeNow < Low[shiftNow + 1] - 0.20 * atrNow);
      if(breakout)
      {
         double entry = closeNow;
         double sl    = g_phase.anchorHigh + atrNow * 0.25;
         double lots  = ComputeLots(riskCash, entry, sl);

         if(sl > 0 && sl > entry && lots > 0)
         {
            if(SendMarketOrder(-1, lots, sl, "MASTER P4 Short"))
               g_phase.lastShortTradeTime = barTime;
         }
      }
   }
}

//==================================================================
// 7. MANAGE POSITIONS - CURVE-ALIVE AND SENSEEI DRIVEN
//    (a) DEAD verdict: close all positions in the dying direction
//    (b) WEAKENING verdict: trail SL to breakeven for profitable
//    (c) Senseei MANAGE action: close positions at target 1+
//    (d) ARC exits handled separately by ManageArcInstitutionalExits()
//==================================================================
void ManagePositions()
{
   int barsAvail = (int)ArraySize(Close);
   if(barsAvail < 3) return;

   double closeNow = Close[1];
   double atrNow   = GetATR(1);

   //===============================================================
   // (a) DEAD VERDICT - Close all positions in the curve owner's
   //     direction. This is the ownership transfer signal.
   //===============================================================
   if(StringFind(g_tradeAlive.verdict, "DEAD") >= 0)
   {
      // The dying direction is the curve's current direction
      int deadDir = g_curve.dir;

      if(deadDir != 0)
      {
         ulong  tickets[];
         double posLots[];
         double posEntries[];
         int count = CollectPositionsByDirection(deadDir, tickets, posLots, posEntries);

         for(int i = 0; i < count; i++)
         {
            if(!ClosePositionFull(tickets[i]))
               Print("ManagePositions DEAD close failed ticket=", tickets[i]);
         }
      }
   }

   //===============================================================
   // (b) WEAKENING VERDICT - Move SL to breakeven for profitable
   //     positions in that direction.
   //===============================================================
   if(StringFind(g_tradeAlive.verdict, "WEAKENING") >= 0)
   {
      int weakDir = g_curve.dir;

      if(weakDir != 0)
      {
         ulong  tickets[];
         double posLots[];
         double posEntries[];
         int count = CollectPositionsByDirection(weakDir, tickets, posLots, posEntries);

         for(int i = 0; i < count; i++)
         {
            if(!PositionSelectByTicket(tickets[i])) continue;

            double entryPrice = posEntries[i];
            double currentSL  = PositionGetDouble(POSITION_SL);
            double profit     = PositionGetDouble(POSITION_PROFIT);

            // Only move to breakeven if position is profitable
            if(profit > 0.0)
            {
               // For longs: move SL up to entry if current SL is below entry
               // For shorts: move SL down to entry if current SL is above entry
               if(weakDir > 0 && (currentSL < entryPrice || currentSL == 0.0))
               {
                  ModifyPositionSL(tickets[i], entryPrice);
               }
               else if(weakDir < 0 && (currentSL > entryPrice || currentSL == 0.0))
               {
                  ModifyPositionSL(tickets[i], entryPrice);
               }
            }
         }
      }
   }

   //===============================================================
   // (c) SENSEEI MANAGE ACTION - Close positions at target 1+
   //     If close has reached beyond 1.5x impulse from entry,
   //     position is considered at target and should be closed.
   //===============================================================
   if(CompareCharArray(g_senseei.action, "MANAGE") == 0)
   {
      int total = PositionsTotal();

      for(int i = total - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;

         string sym  = PositionGetString(POSITION_SYMBOL);
         long   mgc  = PositionGetInteger(POSITION_MAGIC);
         long   type = PositionGetInteger(POSITION_TYPE);

         if(sym != _Symbol) continue;
         if(mgc != InpMagic) continue;

         double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double profit     = PositionGetDouble(POSITION_PROFIT);

         // Only consider profitable positions
         if(profit <= 0.0) continue;

         // Calculate impulse distance (anchor high - anchor low)
         double impulse = g_phase.anchorHigh - g_phase.anchorLow;
         if(impulse <= 0.0) continue;

         // Check if price has moved beyond 1.5x impulse from entry
         double distFromEntry = 0.0;
         if(type == POSITION_TYPE_BUY)
            distFromEntry = closeNow - entryPrice;
         else
            distFromEntry = entryPrice - closeNow;

         // Target 1 threshold: 1.5x the impulse distance
         double targetThreshold = impulse * 1.5;

         if(distFromEntry >= targetThreshold)
         {
            if(!ClosePositionFull(ticket))
               Print("ManagePositions MANAGE close failed ticket=", ticket);
         }
      }
   }

   // (d) ARC exits are handled separately by ManageArcInstitutionalExits()
   //     in Part2_PhaseEngine.mqh - not duplicated here.
}

//+------------------------------------------------------------------+
