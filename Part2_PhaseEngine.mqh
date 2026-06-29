//+------------------------------------------------------------------+
//| Part2_PhaseEngine.mqh - Phase Engine (Curvature-Based Impulse   |
//|   Detection + Phases 1-4) and ARC v2 Convexity Exit System      |
//| Ported verbatim from Symphony sections 6, 6B, 16               |
//| Dependencies: Part1_Core.mqh (structs, inputs, helpers, series) |
//+------------------------------------------------------------------+
#property strict

//==================================================================
// 6. PHASE ENGINE - IMPULSE + PHASES (1-4)
//==================================================================
void UpdatePhaseEngine()
{
   int barsAvail = (int)ArraySize(Close);
   if(barsAvail <= (2 * InpPivotLen + 5)) return;

   int    shiftNow   = 1;
   double closeNow   = Close[shiftNow];
   double atrNow     = GetATR(shiftNow);
   double atrRef     = atrNow;

   int    centerShift = InpPivotLen + 1;
   int    pivotDir    = 0;
   double pivotPrice  = 0.0;
   int    pivotShift  = -1;

   if(centerShift < barsAvail - InpPivotLen)
   {
      if(IsPivotHigh(centerShift))
      {
         pivotDir   = 1;
         pivotPrice = High[centerShift];
         pivotShift = centerShift;
      }
      else if(IsPivotLow(centerShift))
      {
         pivotDir   = -1;
         pivotPrice = Low[centerShift];
         pivotShift = centerShift;
      }
   }

   //--- SHORT impulse: last high -> new low ---
   if(pivotDir == -1 && g_phase.lastPivotDir == 1)
   {
      double r = g_phase.lastPivotPrice - pivotPrice;
      if(r > atrRef * InpImpulseAtrMult)
      {
         g_phase.mode            = -1;
         g_phase.anchorHigh      = g_phase.lastPivotPrice;
         g_phase.anchorHighShift = g_phase.lastPivotShift;
         g_phase.anchorLow       = pivotPrice;
         g_phase.anchorLowShift  = pivotShift;

         g_phase.phaseShort      = 1;
         g_phase.phaseLong       = 0;

         g_phase.shortPreConvSeen = false;
         g_phase.longPreConvSeen  = false;

         g_phase.shortInducPrice = 0.0;
         g_phase.shortInducLow   = 0.0;
         g_phase.shortInducHigh  = 0.0;
         g_phase.longInducPrice  = 0.0;
         g_phase.longInducLow    = 0.0;
         g_phase.longInducHigh   = 0.0;

         g_phase.longOuterBreachSeen  = false;
         g_phase.shortOuterBreachSeen = false;

         // Find flipzone inducement: closest inside bar
         double lvlS = 0.0;
         int    bestDistS = -1;
         if(g_phase.anchorHighShift > 0)
         {
            for(int s = g_phase.anchorHighShift - 1;
                s >= 0 && s >= g_phase.anchorHighShift - InpInducLookbackBars;
                s--)
            {
               bool inside = (High[s] < g_phase.anchorHigh && Low[s] > g_phase.anchorLow);
               if(inside)
               {
                  int dist = MathAbs(g_phase.anchorHighShift - s);
                  if(bestDistS < 0 || dist < bestDistS)
                  {
                     bestDistS = dist;
                     lvlS      = (High[s] + Low[s]) * 0.5;
                  }
               }
            }
         }
         if(bestDistS >= 0)
         {
            g_phase.shortInducPrice = lvlS;
            g_phase.shortInducLow   = lvlS - atrRef * InpInducZoneATRWidth;
            g_phase.shortInducHigh  = lvlS + atrRef * InpInducZoneATRWidth;
         }
      }
   }
   //--- LONG impulse: last low -> new high ---
   else if(pivotDir == 1 && g_phase.lastPivotDir == -1)
   {
      double r = pivotPrice - g_phase.lastPivotPrice;
      if(r > atrRef * InpImpulseAtrMult)
      {
         g_phase.mode            = 1;
         g_phase.anchorLow       = g_phase.lastPivotPrice;
         g_phase.anchorLowShift  = g_phase.lastPivotShift;
         g_phase.anchorHigh      = pivotPrice;
         g_phase.anchorHighShift = pivotShift;

         g_phase.phaseLong       = 1;
         g_phase.phaseShort      = 0;

         g_phase.shortPreConvSeen = false;
         g_phase.longPreConvSeen  = false;

         g_phase.shortInducPrice = 0.0;
         g_phase.shortInducLow   = 0.0;
         g_phase.shortInducHigh  = 0.0;
         g_phase.longInducPrice  = 0.0;
         g_phase.longInducLow    = 0.0;
         g_phase.longInducHigh   = 0.0;

         g_phase.longOuterBreachSeen  = false;
         g_phase.shortOuterBreachSeen = false;

         // Find flipzone inducement: closest inside bar
         double lvlL = 0.0;
         int    bestDistL = -1;
         if(g_phase.anchorLowShift > 0)
         {
            for(int s = g_phase.anchorLowShift - 1;
                s >= 0 && s >= g_phase.anchorLowShift - InpInducLookbackBars;
                s--)
            {
               bool inside = (High[s] < g_phase.anchorHigh && Low[s] > g_phase.anchorLow);
               if(inside)
               {
                  int dist = MathAbs(g_phase.anchorLowShift - s);
                  if(bestDistL < 0 || dist < bestDistL)
                  {
                     bestDistL = dist;
                     lvlL      = (High[s] + Low[s]) * 0.5;
                  }
               }
            }
         }
         if(bestDistL >= 0)
         {
            g_phase.longInducPrice = lvlL;
            g_phase.longInducLow   = lvlL - atrRef * InpInducZoneATRWidth;
            g_phase.longInducHigh  = lvlL + atrRef * InpInducZoneATRWidth;
         }
      }
   }

   //--- Persist pivot history ---
   if(pivotDir != 0)
   {
      g_phase.prevPivotPrice = g_phase.lastPivotPrice;
      g_phase.prevPivotShift = g_phase.lastPivotShift;
      g_phase.prevPivotDir   = g_phase.lastPivotDir;

      g_phase.lastPivotPrice = pivotPrice;
      g_phase.lastPivotShift = pivotShift;
      g_phase.lastPivotDir   = pivotDir;
   }

   //--- Impulse invalidation: close beyond anchor resets mode ---
   if(g_phase.mode == -1 && closeNow > g_phase.anchorHigh)
   {
      g_phase.mode             = 0;
      g_phase.phaseShort       = 0;
      g_phase.shortInducPrice  = 0.0;
      g_phase.shortInducLow    = 0.0;
      g_phase.shortInducHigh   = 0.0;
      g_phase.shortPreConvSeen = false;
      g_phase.longPreConvSeen  = false;
      g_phase.longOuterBreachSeen  = false;
      g_phase.shortOuterBreachSeen = false;
   }
   if(g_phase.mode == 1 && closeNow < g_phase.anchorLow)
   {
      g_phase.mode             = 0;
      g_phase.phaseLong        = 0;
      g_phase.longInducPrice   = 0.0;
      g_phase.longInducLow     = 0.0;
      g_phase.longInducHigh    = 0.0;
      g_phase.shortPreConvSeen = false;
      g_phase.longPreConvSeen  = false;
      g_phase.longOuterBreachSeen  = false;
      g_phase.shortOuterBreachSeen = false;
   }

   int oldPhaseShort = g_phase.phaseShort;
   int oldPhaseLong  = g_phase.phaseLong;

   //--- SHORT side phase assignment ---
   if(g_phase.mode != -1) g_phase.phaseShort = 0;
   if(g_phase.mode == -1 && g_phase.anchorHighShift >= 0 && g_phase.anchorLowShift >= 0)
   {
      double impS  = g_phase.anchorHigh - g_phase.anchorLow;
      double retrS = (impS > 0.0) ? (closeNow - g_phase.anchorLow) / impS : 0.0;
      double dS    = Close[shiftNow] - Close[shiftNow + 1];

      int phaseTmpS;
      if(retrS > InpRetrMax || retrS < 0.0)
         phaseTmpS = 0;
      else if(closeNow <= g_phase.anchorLow)
         phaseTmpS = 4;
      else if(retrS >= InpRetrMin)
         phaseTmpS = (dS > 0.0 ? 2 : 3);
      else
         phaseTmpS = 1;

      // Gate phase 3 by inducement zone
      bool hasShortZone = (g_phase.shortInducLow != 0.0 || g_phase.shortInducHigh != 0.0);
      if(phaseTmpS == 3 && hasShortZone && closeNow <= g_phase.shortInducHigh)
         phaseTmpS = 2;
      else if(phaseTmpS == 3)
         g_phase.shortPreConvSeen = true;

      // Gate phase 4 by pre-conv seen
      if(phaseTmpS == 4 && !g_phase.shortPreConvSeen)
         phaseTmpS = 2;

      g_phase.phaseShort = phaseTmpS;
   }

   //--- LONG side phase assignment (mirror of short) ---
   if(g_phase.mode != 1) g_phase.phaseLong = 0;
   if(g_phase.mode == 1 && g_phase.anchorHighShift >= 0 && g_phase.anchorLowShift >= 0)
   {
      double impL  = g_phase.anchorHigh - g_phase.anchorLow;
      double retrL = (impL > 0.0) ? (g_phase.anchorHigh - closeNow) / impL : 0.0;
      double dL    = Close[shiftNow] - Close[shiftNow + 1];

      int phaseTmpL;
      if(retrL > InpRetrMax || retrL < 0.0)
         phaseTmpL = 0;
      else if(closeNow >= g_phase.anchorHigh)
         phaseTmpL = 4;
      else if(retrL >= InpRetrMin)
         phaseTmpL = (dL < 0.0 ? 2 : 3);
      else
         phaseTmpL = 1;

      // Gate phase 3 by inducement zone
      bool hasLongZone = (g_phase.longInducLow != 0.0 || g_phase.longInducHigh != 0.0);
      if(phaseTmpL == 3 && hasLongZone && closeNow >= g_phase.longInducLow)
         phaseTmpL = 2;
      else if(phaseTmpL == 3)
         g_phase.longPreConvSeen = true;

      // Gate phase 4 by pre-conv seen
      if(phaseTmpL == 4 && !g_phase.longPreConvSeen)
         phaseTmpL = 2;

      g_phase.phaseLong = phaseTmpL;
   }

   //--- Track previous phase ---
   g_phase.prevPhaseShort = oldPhaseShort;
   g_phase.prevPhaseLong  = oldPhaseLong;
}

//==================================================================
// 6B. ARC v2 CALCULATION (CONVEXITY ARC)
//==================================================================
void UpdateARC()
{
   g_phase.arcLong  = 0.0;
   g_phase.arcShort = 0.0;

   int bars = ArraySize(Close);
   if(bars < 10) return;

   int shift = 1; // last closed bar

   //--- LONG ARC: from anchorLow projected to high target ---
   if(g_phase.mode == 1 && g_phase.anchorLowShift >= 0 && g_phase.anchorHighShift >= 0)
   {
      double impL = g_phase.anchorHigh - g_phase.anchorLow;
      if(impL > 0)
      {
         double targetL = g_phase.anchorLow + impL * InpArcExtMult;

         double tL = (double)(g_phase.anchorLowShift - shift) / (double)InpArcHorizonBars;
         if(tL < 0.0) tL = 0.0;
         if(tL > 1.0) tL = 1.0;

         g_phase.arcLong = g_phase.anchorLow + (targetL - g_phase.anchorLow) * MathPow(tL, InpConvPower);
      }
   }

   //--- SHORT ARC: from anchorHigh projected to low target ---
   if(g_phase.mode == -1 && g_phase.anchorLowShift >= 0 && g_phase.anchorHighShift >= 0)
   {
      double impS = g_phase.anchorHigh - g_phase.anchorLow;
      if(impS > 0)
      {
         double targetS = g_phase.anchorHigh - impS * InpArcExtMult;

         double tS = (double)(g_phase.anchorHighShift - shift) / (double)InpArcHorizonBars;
         if(tS < 0.0) tS = 0.0;
         if(tS > 1.0) tS = 1.0;

         g_phase.arcShort = g_phase.anchorHigh + (targetS - g_phase.anchorHigh) * MathPow(tS, InpConvPower);
      }
   }
}

//==================================================================
// POSITION CLOSE HELPERS (needed by exit system)
//==================================================================
bool ClosePositionPartial(ulong ticket, double lotsToClose)
{
   if(lotsToClose <= 0.0) return(false);
   if(!PositionSelectByTicket(ticket)) return(false);

   string sym  = PositionGetString(POSITION_SYMBOL);
   long   mgc  = PositionGetInteger(POSITION_MAGIC);
   long   type = PositionGetInteger(POSITION_TYPE);
   double posLots = PositionGetDouble(POSITION_VOLUME);

   if(sym != _Symbol) return(false);
   if(mgc != InpMagic) return(false);

   lotsToClose = NormalizeDouble(lotsToClose, 2);
   if(lotsToClose > posLots) lotsToClose = posLots;
   if(lotsToClose <= 0) return(false);

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);

   req.action       = TRADE_ACTION_DEAL;
   req.symbol       = _Symbol;
   req.magic        = InpMagic;
   req.position     = ticket;
   req.volume       = lotsToClose;
   req.deviation    = 20;
   req.type_filling = ORDER_FILLING_IOC;
   req.type_time    = ORDER_TIME_GTC;
   req.comment      = "SYM EXIT";

   if(type == POSITION_TYPE_BUY)
   {
      req.type  = ORDER_TYPE_SELL;
      req.price = bid;
   }
   else
   {
      req.type  = ORDER_TYPE_BUY;
      req.price = ask;
   }

   if(!OrderSend(req, res))
   {
      Print("ClosePositionPartial failed ticket=", ticket, " lots=", lotsToClose, " retcode=", res.retcode);
      return(false);
   }

   if(res.retcode != TRADE_RETCODE_DONE && res.retcode != TRADE_RETCODE_DONE_PARTIAL)
   {
      Print("ClosePositionPartial not DONE ticket=", ticket, " retcode=", res.retcode);
      return(false);
   }

   return(true);
}

bool ClosePositionFull(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return(false);
   double lots = PositionGetDouble(POSITION_VOLUME);
   return(ClosePositionPartial(ticket, lots));
}

//==================================================================
// 16. ARC + INSTITUTIONAL + PHASE EXIT (COMPOSITE EXIT SYSTEM)
//==================================================================
void ManageArcInstitutionalExits()
{
   int barsAvail = (int)ArraySize(Close);
   if(barsAvail <= (2 * InpPivotLen + 5)) return;

   int    shiftNow = 1;
   double closeNow = Close[shiftNow];
   double atrNow   = GetATR(shiftNow);

   //--- 1) ARC exhaustion flags ---
   bool arcExhaustLong  = (g_phase.mode == 1  && g_phase.arcLong  > 0.0 &&
                           closeNow >= (g_phase.arcLong  - InpArcToleranceAtr * atrNow));
   bool arcExhaustShort = (g_phase.mode == -1 && g_phase.arcShort > 0.0 &&
                           closeNow <= (g_phase.arcShort + InpArcToleranceAtr * atrNow));

   //--- 2) INSTITUTIONAL BANDS ---

   // LONG side
   double instLevelL = (g_phase.longInducPrice != 0.0 ? g_phase.longInducPrice :
                        (g_phase.anchorHigh > 0.0 ? g_phase.anchorHigh : 0.0));
   double innerTopL  = (g_phase.longInducHigh > 0.0 ? g_phase.longInducHigh : instLevelL);
   double outerTopL  = innerTopL + InpOuterBandAtrMult * atrNow;

   // SHORT side
   double instLevelS = (g_phase.shortInducPrice != 0.0 ? g_phase.shortInducPrice :
                        (g_phase.anchorLow > 0.0 ? g_phase.anchorLow : 0.0));
   double innerBotS  = (g_phase.shortInducLow != 0.0 ? g_phase.shortInducLow : instLevelS);
   double outerBotS  = innerBotS - InpOuterBandAtrMult * atrNow;

   //--- 3) TRACK OUTER-BAND SWEEPS PER IMPULSE ---

   if(g_phase.mode == 1 && instLevelL > 0.0)
   {
      if(closeNow > outerTopL)
         g_phase.longOuterBreachSeen = true;
   }

   if(g_phase.mode == -1 && instLevelS > 0.0)
   {
      if(closeNow < outerBotS)
         g_phase.shortOuterBreachSeen = true;
   }

   //--- 4) PHASE-CHANGE AT EXTREME ---

   bool phaseTrendEndLong =
      (g_phase.mode == 1 &&
       (g_phase.prevPhaseLong == 3 || g_phase.prevPhaseLong == 4) &&
       (g_phase.phaseLong <= 1));

   bool phaseTrendEndShort =
      (g_phase.mode == -1 &&
       (g_phase.prevPhaseShort == 3 || g_phase.prevPhaseShort == 4) &&
       (g_phase.phaseShort <= 1));

   //--- 5) FULL EXIT CONDITIONS ---

   bool exitLong  = false;
   bool exitShort = false;

   // LONG: ARC exhaust + phase-end + (no inst level OR (outer breach seen AND close back inside inner))
   if(g_phase.mode == 1 && arcExhaustLong && phaseTrendEndLong)
   {
      bool hasInstL = (instLevelL > 0.0);
      bool instPatternOK =
         !hasInstL ||
         (g_phase.longOuterBreachSeen && closeNow < innerTopL);

      if(instPatternOK)
         exitLong = true;
   }

   // SHORT: ARC exhaust + phase-end + (no inst level OR (outer breach seen AND close back inside inner))
   if(g_phase.mode == -1 && arcExhaustShort && phaseTrendEndShort)
   {
      bool hasInstS = (instLevelS > 0.0);
      bool instPatternOK =
         !hasInstS ||
         (g_phase.shortOuterBreachSeen && closeNow > innerBotS);

      if(instPatternOK)
         exitShort = true;
   }

   if(!exitLong && !exitShort)
      return;

   //--- 6) EXECUTE EXITS ON MATCHING POSITIONS ---
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;

      string sym  = PositionGetString(POSITION_SYMBOL);
      long   mgc  = PositionGetInteger(POSITION_MAGIC);
      long   type = PositionGetInteger(POSITION_TYPE);

      if(sym != _Symbol) continue;
      if(mgc != InpMagic) continue;

      // LONG positions: close if long exit signal
      if(exitLong && type == POSITION_TYPE_BUY)
      {
         if(!ClosePositionFull(ticket))
            Print("ARC/INST LONG EXIT failed ticket ", ticket, " err ", GetLastError());
      }

      // SHORT positions: close if short exit signal
      if(exitShort && type == POSITION_TYPE_SELL)
      {
         if(!ClosePositionFull(ticket))
            Print("ARC/INST SHORT EXIT failed ticket ", ticket, " err ", GetLastError());
      }
   }
}

//+------------------------------------------------------------------+
