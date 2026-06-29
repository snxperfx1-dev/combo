//+------------------------------------------------------------------+
//| Part7_Senseei.mqh - Senseei Meta-Intelligence Decision Engine   |
//|                     + V72 Probabilistic Entry Decision           |
//| Master MT5 EA: Symphony + Letra + F16 Combined System           |
//+------------------------------------------------------------------+
#property strict

//==================================================================
// SENSEEI META-INTELLIGENCE ENGINE
// Synthesizes all sub-engines into a unified decision framework:
//   - Master Direction (4 voters)
//   - Alignment / Conflict / Threat / Confidence
//   - Timing / Intent / Opportunity / Action
// V72 Probabilistic Entry (7 engines combined into entryProb)
//==================================================================

//==================================================================
// HELPERS: Copy string into char array (max 31 chars + null for [32])
//==================================================================
void CopyToCharArray(const string &src, char &dst[], int maxLen = 31)
{
   int len = StringLen(src);
   if(len > maxLen) len = maxLen;
   for(int i = 0; i < len; i++)
      dst[i] = (char)StringGetCharacter(src, i);
   dst[len] = 0;
}

//==================================================================
// HELPERS: Compare char array to string (returns 0 if equal)
//==================================================================
int CompareCharArray(const char &arr[], const string &cmp)
{
   int lenA = 0;
   for(int i = 0; i < 32; i++)
   {
      if(arr[i] == 0) break;
      lenA++;
   }
   int lenC = StringLen(cmp);
   if(lenA != lenC) return(1);
   for(int i = 0; i < lenA; i++)
   {
      if(arr[i] != (char)StringGetCharacter(cmp, i))
         return(1);
   }
   return(0);
}

//==================================================================
// HELPERS: Check if char array contains a substring
//==================================================================
bool CharArrayContains(const char &arr[], const string &sub)
{
   // Build string from char array
   string full = "";
   for(int i = 0; i < 32; i++)
   {
      if(arr[i] == 0) break;
      full += CharToString((uchar)arr[i]);
   }
   return(StringFind(full, sub) >= 0);
}

//==================================================================
// 1. COMPUTE SENSEEI - MASTER DIRECTION AND SCORES
//    Ported from F16 V70 PART D: meta-intelligence engine
//==================================================================
void ComputeSenseei()
{
   //=============================================================
   // (a) MASTER DIRECTION from 4 voters
   //=============================================================
   int vt1 = g_letra[2].dir;          // M5 wave direction (origin-based)
   int vt2 = g_fractalStackDir;       // Fractal stack direction
   int vt3 = g_netBias;               // Network engine bias
   int vt4 = g_pressureDir;           // Network pressure direction

   int sum = vt1 + vt2 + vt3 + vt4;
   int master = (sum > 0) ? 1 : (sum < 0) ? -1 : 0;

   // Count non-zero voters (cast) and voters matching master (forV)
   int cast = 0;
   int forV = 0;

   if(vt1 != 0) { cast++; if(vt1 == master) forV++; }
   if(vt2 != 0) { cast++; if(vt2 == master) forV++; }
   if(vt3 != 0) { cast++; if(vt3 == master) forV++; }
   if(vt4 != 0) { cast++; if(vt4 == master) forV++; }

   g_senseei.master = master;

   //=============================================================
   // (b) ALIGNMENT: forV / cast * 100
   //=============================================================
   int alignment = (cast > 0) ? (int)((double)forV / (double)cast * 100.0) : 50;
   g_senseei.alignment = alignment;

   //=============================================================
   // (c) CONFLICT: (cast - forV) / cast * 100
   //=============================================================
   int conflict = (cast > 0) ? (int)(((double)(cast - forV)) / (double)cast * 100.0) : 0;
   g_senseei.conflict = conflict;

   //=============================================================
   // (d) THREAT: composite threat score
   //     conflict*0.40 + residual*0.28 + timeConflict*0.12
   //     + (pressure opposing master ? 18 : 0)
   //     + (partially resolved ? 10 : 0)
   //=============================================================
   double pressurePenalty = (g_pressureDir != 0 && g_pressureDir != master) ? 18.0 : 0.0;
   double resolutionPenalty = (g_energy.re_resolutionState == 1) ? 10.0 : 0.0;

   double rawThreat = (double)conflict * 0.40
                    + g_energy.re_residualEnergyScore * 0.28
                    + g_timeConflict * 0.12
                    + pressurePenalty
                    + resolutionPenalty;

   int threat = (int)MathMax(0.0, MathMin(100.0, rawThreat));
   g_senseei.threat = threat;

   //=============================================================
   // (e) CONFIDENCE: composite confidence score
   //     alignment*0.40 + timeAlign*0.12 + stackScore*0.18
   //     + attractorScore*0.15 + min(15, eligNodes*1.2) - threat*0.20
   //=============================================================
   double rawConfidence = (double)alignment * 0.40
                        + g_timeAlign * 0.12
                        + g_fractalStackScore * 0.18
                        + g_energy.eae_primaryAttractorScore * 0.15
                        + MathMin(15.0, (double)g_eligibleNodes * 1.2)
                        - (double)threat * 0.20;

   int confidence = (int)MathMax(0.0, MathMin(100.0, rawConfidence));
   g_senseei.confidence = confidence;

   //=============================================================
   // (f) TIMING: from ie1a currentPhase and waveProgress
   //=============================================================
   string currentPhase = PhaseToString(g_letra[2].phase);
   double waveProgress = g_energy.waveProgress;
   string timingStr = "";

   if(StringFind(currentPhase, "Absorption") >= 0 || g_energy.re_resolutionState == 2)
      timingStr = "RESOLVED";
   else if(waveProgress < 15.0)
      timingStr = "VERY EARLY";
   else if(waveProgress < 35.0)
      timingStr = "EARLY";
   else if(waveProgress < 55.0)
      timingStr = "DEVELOPING";
   else if(waveProgress < 80.0)
      timingStr = "MID CYCLE";
   else if(waveProgress < 96.0)
      timingStr = "LATE";
   else
      timingStr = "TERMINAL";

   CopyToCharArray(timingStr, g_senseei.timing);

   //=============================================================
   // (g) INTENT: from conflict, liqg_active, currentPhase
   //=============================================================
   string intentStr = "";
   bool liqg_active = g_energyState.liqg_active;

   if(conflict > 55)
      intentStr = "ABSORPTION";
   else if(liqg_active)
      intentStr = "DELIVERY";
   else if(StringFind(currentPhase, "Expansion") >= 0 &&
           StringFind(currentPhase, "Pre-Convexity") < 0 &&
           StringFind(currentPhase, "Induction") < 0 &&
           StringFind(currentPhase, "Liquidity") < 0)
      intentStr = "EXPANSION";
   else if(StringFind(currentPhase, "Pre-Convexity") >= 0)
      intentStr = "CONTINUATION";
   else if(StringFind(currentPhase, "Induction") >= 0)
      intentStr = "RESOLUTION";
   else if(StringFind(currentPhase, "Liquidity") >= 0)
      intentStr = "DELIVERY";
   else if(StringFind(currentPhase, "New High") >= 0 || StringFind(currentPhase, "New Low") >= 0)
      intentStr = "DELIVERY";
   else if(StringFind(currentPhase, "Absorption") >= 0)
      intentStr = "ABSORPTION";
   else if(master == 0)
      intentStr = "BALANCE";
   else
      intentStr = "CONTINUATION";

   CopyToCharArray(intentStr, g_senseei.intent);

   //=============================================================
   // (h) OPPORTUNITY SCORE and GRADE
   //     oppScore = alignment*0.40 + attractor*0.30 + stackScore*0.30 - threat*0.35
   //=============================================================
   double rawOpp = (double)alignment * 0.40
                 + g_energy.eae_primaryAttractorScore * 0.30
                 + g_fractalStackScore * 0.30
                 - (double)threat * 0.35;

   double oppScore = MathMax(0.0, MathMin(100.0, rawOpp));
   g_senseei.oppScore = oppScore;

   // Opportunity Grade
   string oppGrade = "";
   if(master == 0)
      oppGrade = "NONE";
   else if(conflict > 60)
      oppGrade = "DEVELOPING";
   else if(oppScore < 20.0)
      oppGrade = "NONE";
   else if(oppScore < 40.0)
      oppGrade = "DEVELOPING";
   else if(oppScore < 62.0)
      oppGrade = "GOOD";
   else if(oppScore < 82.0)
      oppGrade = "STRONG";
   else
      oppGrade = "EXCEPTIONAL";

   CopyToCharArray(oppGrade, g_senseei.opportunity);

   //=============================================================
   // (i) ACTION DECISION
   //     Priority cascade: WAIT -> MANAGE -> ATTACK -> PREPARE -> WAIT
   //=============================================================
   string actionStr = "";

   if(master == 0)
      actionStr = "WAIT";
   else if(conflict > 60)
      actionStr = "WAIT";
   else if(g_energy.re_resolutionState == 2)
      actionStr = "MANAGE";
   else if((CompareCharArray(g_senseei.opportunity, "STRONG") == 0 ||
            CompareCharArray(g_senseei.opportunity, "EXCEPTIONAL") == 0) &&
           confidence >= InpMinConf &&
           threat < 45)
      actionStr = "ATTACK";
   else if(CompareCharArray(g_senseei.opportunity, "GOOD") == 0 ||
           CompareCharArray(g_senseei.opportunity, "STRONG") == 0)
      actionStr = "PREPARE";
   else
      actionStr = "WAIT";

   CopyToCharArray(actionStr, g_senseei.action);
}

//==================================================================
// 2. COMPUTE ENTRY PROBABILITY - V72 PROBABILISTIC ENTRY DECISION
//    7 engines combined into a single probability score (0-100)
//==================================================================
void ComputeEntryProbability()
{
   //=============================================================
   // P1: Curve Maturity (from wave progress)
   //     Score high in sweet zone [30-75], tapers outside
   //=============================================================
   double wp = g_energy.waveProgress;
   double p1 = 0.0;

   if(wp >= 30.0 && wp <= 75.0)
      p1 = 80.0 + (wp - 30.0) / 45.0 * 20.0;
   else if(wp < 30.0)
      p1 = wp / 30.0 * 60.0;
   else // wp > 75
      p1 = MathMax(0.0, 100.0 - (wp - 75.0) * 3.0);

   //=============================================================
   // P2: Hierarchical Ownership (fractal stack score, already 0-100)
   //=============================================================
   double p2 = g_fractalStackScore;

   //=============================================================
   // P3: Geometry (available space + zone precision)
   //     availableSpace: distance to flipzone mid / ATR*4 * 100
   //     zonePrecision: 100 - flipzoneWidth / (ATR*0.5) * 50, clamped
   //=============================================================
   double atr = GetATR(0);
   double availableSpace = 0.0;
   double zonePrecision  = 0.0;

   if(atr > 0.0)
   {
      // Available space: distance from price to flipzone midpoint
      double flipMid = 0.0;
      if(g_senseei.master == 1)
         flipMid = (g_spawn.flipTop + g_spawn.flipBot) / 2.0;
      else if(g_senseei.master == -1)
         flipMid = (g_spawn.flipTop + g_spawn.flipBot) / 2.0;
      else
         flipMid = (g_spawn.flipTop + g_spawn.flipBot) / 2.0;

      double distToFlip = MathAbs(Close[0] - flipMid);
      availableSpace = Clamp(distToFlip / (atr * 4.0) * 100.0, 0.0, 100.0);

      // Zone precision: narrower flipzone = higher precision
      double flipWidth = MathAbs(g_spawn.flipTop - g_spawn.flipBot);
      zonePrecision = Clamp(100.0 - (flipWidth / (atr * 0.5)) * 50.0, 0.0, 100.0);
   }

   double p3 = availableSpace * 0.6 + zonePrecision * 0.4;

   //=============================================================
   // P4: Recursion Forecast (re_recursiveCompletionScore)
   //=============================================================
   double p4 = g_energy.re_recursiveCompletionScore;

   //=============================================================
   // P5: Dynamic Destination (eae_primaryAttractorScore)
   //=============================================================
   double p5 = g_energy.eae_primaryAttractorScore;

   //=============================================================
   // P6: Curve Capacity (compression persistence force)
   //=============================================================
   double p6 = g_compression.force;

   //=============================================================
   // P7: Execution Confidence (Senseei confidence, already computed)
   //=============================================================
   double p7 = (double)g_senseei.confidence;

   //=============================================================
   // COMBINE: weighted sum of 7 engines
   // P1*0.15 + P2*0.15 + P3*0.10 + P4*0.10 + P5*0.15 + P6*0.15 + P7*0.20
   //=============================================================
   double entryProb = p1 * 0.15
                    + p2 * 0.15
                    + p3 * 0.10
                    + p4 * 0.10
                    + p5 * 0.15
                    + p6 * 0.15
                    + p7 * 0.20;

   //=============================================================
   // MASTER ALIGNMENT BONUS: all 4 voters agree with master
   //=============================================================
   if(g_senseei.master != 0)
   {
      int vt1 = g_letra[2].dir;
      int vt2 = g_fractalStackDir;
      int vt3 = g_netBias;
      int vt4 = g_pressureDir;

      if(vt1 == g_senseei.master && vt2 == g_senseei.master &&
         vt3 == g_senseei.master && vt4 == g_senseei.master)
      {
         entryProb += 5.0;
      }
   }

   //=============================================================
   // THREAT PENALTY: if threat > 50, reduce probability
   //=============================================================
   if(g_senseei.threat > 50)
      entryProb -= ((double)g_senseei.threat - 50.0) * 0.3;

   //=============================================================
   // CLAMP to 0-100
   //=============================================================
   g_senseei.entryProb = Clamp(entryProb, 0.0, 100.0);
}

//==================================================================
// 3. UPDATE SENSEEI - MASTER ENTRY POINT
//    Called once per bar after all sub-engines have updated.
//==================================================================
void UpdateSenseei()
{
   ComputeSenseei();
   ComputeEntryProbability();
}

//==================================================================
// 4. IS ENTRY ALLOWED - HELPER FOR EXECUTION LAYER
//    Returns true if probabilistic gate passes AND action is valid.
//    Combines V72 probability with Senseei action decision.
//==================================================================
bool IsEntryAllowed()
{
   // Check entry probability meets threshold
   if(g_senseei.entryProb < InpEntryProbThreshold)
      return(false);

   // Check action is ATTACK or PREPARE
   if(CompareCharArray(g_senseei.action, "ATTACK") == 0)
      return(true);
   if(CompareCharArray(g_senseei.action, "PREPARE") == 0)
      return(true);

   return(false);
}

//==================================================================
// 5. IS SYMPHONY PHASE READY - CHECK PHASE 3 OR 4 ACTIVE
//    Symphony Phase 3 = pre-convexity zone, Phase 4 = expansion break
//    This is a necessary-but-not-sufficient condition for entry.
//==================================================================
bool IsSymphonyPhaseReady()
{
   // Long side: phase 3 or 4 active
   if(g_phase.phaseLong >= 3)
      return(true);

   // Short side: phase 3 or 4 active
   if(g_phase.phaseShort >= 3)
      return(true);

   return(false);
}

//==================================================================
// 6. COMBINED ENTRY GATE - V72 PROBABILISTIC + SYMPHONY PHASE
//    Entry fires ONLY when ALL conditions are met:
//    1. Symphony phase 3 or 4 is active
//    2. Senseei action is ATTACK or PREPARE
//    3. entryProb > InpEntryProbThreshold (default 90%)
//    4. IsTradeTime() is true
//    Symphony's lot sizing and stop placement are preserved.
//==================================================================
bool IsMasterEntrySignal()
{
   // Must have Symphony phase 3 or 4
   if(!IsSymphonyPhaseReady())
      return(false);

   // Must pass V72 probabilistic gate + Senseei action
   if(!IsEntryAllowed())
      return(false);

   // Must be within trading time window
   if(!IsTradeTime())
      return(false);

   return(true);
}

//==================================================================
// 7. ATTACK SEQUENCE STATE - TRACKS ENTRY/STOP/TARGET
//    Latches flags for entered, stopHit, target hits.
//    Prices derived from flipzone/origin/objectives.
//==================================================================
struct AttackSequenceState
{
   bool     entered;            // Entry executed
   bool     stopHit;            // Stop loss hit
   bool     t1Hit;              // Target 1 hit
   bool     t2Hit;              // Target 2 hit
   bool     t3Hit;              // Target 3 hit
   double   entryPrice;         // Entry price
   double   stopPrice;          // Stop loss price
   double   target1;            // Target 1 price
   double   target2;            // Target 2 price
   double   target3;            // Target 3 price
   int      direction;          // 1=long, -1=short
};

AttackSequenceState g_attack;

//+------------------------------------------------------------------+
//| InitAttackSequence - Reset attack state for new entry            |
//+------------------------------------------------------------------+
void InitAttackSequence(int dir, double entry, double stop,
                        double t1, double t2, double t3)
{
   g_attack.entered    = true;
   g_attack.stopHit    = false;
   g_attack.t1Hit      = false;
   g_attack.t2Hit      = false;
   g_attack.t3Hit      = false;
   g_attack.entryPrice = entry;
   g_attack.stopPrice  = stop;
   g_attack.target1    = t1;
   g_attack.target2    = t2;
   g_attack.target3    = t3;
   g_attack.direction  = dir;
}

//+------------------------------------------------------------------+
//| UpdateAttackSequence - Check current price against levels         |
//+------------------------------------------------------------------+
void UpdateAttackSequence()
{
   if(!g_attack.entered) return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(g_attack.direction == 1) // Long position
   {
      // Stop hit: price below stop
      if(bid <= g_attack.stopPrice)
         g_attack.stopHit = true;

      // Target 1: price reached target1
      if(!g_attack.t1Hit && bid >= g_attack.target1 && g_attack.target1 > 0.0)
         g_attack.t1Hit = true;

      // Target 2: price reached target2
      if(!g_attack.t2Hit && bid >= g_attack.target2 && g_attack.target2 > 0.0)
         g_attack.t2Hit = true;

      // Target 3: price reached target3
      if(!g_attack.t3Hit && bid >= g_attack.target3 && g_attack.target3 > 0.0)
         g_attack.t3Hit = true;
   }
   else if(g_attack.direction == -1) // Short position
   {
      // Stop hit: price above stop
      if(bid >= g_attack.stopPrice)
         g_attack.stopHit = true;

      // Target 1: price reached target1
      if(!g_attack.t1Hit && bid <= g_attack.target1 && g_attack.target1 > 0.0)
         g_attack.t1Hit = true;

      // Target 2: price reached target2
      if(!g_attack.t2Hit && bid <= g_attack.target2 && g_attack.target2 > 0.0)
         g_attack.t2Hit = true;

      // Target 3: price reached target3
      if(!g_attack.t3Hit && bid <= g_attack.target3 && g_attack.target3 > 0.0)
         g_attack.t3Hit = true;
   }
}

//+------------------------------------------------------------------+
//| ResetAttackSequence - Clear when trade is closed                  |
//+------------------------------------------------------------------+
void ResetAttackSequence()
{
   g_attack.entered    = false;
   g_attack.stopHit    = false;
   g_attack.t1Hit      = false;
   g_attack.t2Hit      = false;
   g_attack.t3Hit      = false;
   g_attack.entryPrice = 0.0;
   g_attack.stopPrice  = 0.0;
   g_attack.target1    = 0.0;
   g_attack.target2    = 0.0;
   g_attack.target3    = 0.0;
   g_attack.direction  = 0;
}

//+------------------------------------------------------------------+
