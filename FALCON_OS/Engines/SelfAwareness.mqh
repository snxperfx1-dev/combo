//+------------------------------------------------------------------+
//|  FALCON OS — Intelligence : SelfAwareness.mqh                   |
//|                                                                  |
//|  METACOGNITION — the OS watching ITSELF, not the market.        |
//|                                                                  |
//|  It maintains a live model of its own reliability and form, and  |
//|  modulates how much it trusts itself right now:                  |
//|    • CALIBRATION — do my stated probabilities match my realised  |
//|      win-rate? (am I over/under-confident)                       |
//|    • FORM        — win/loss streak, equity slope, drawdown        |
//|    • REGIME FIT  — am I in conditions I perform in (learned)      |
//|    • HEALTH      — are my own inputs sane (ATR, locator conf, DD, |
//|      loss cluster)? if not, STAND DOWN.                          |
//|                                                                  |
//|  Output: selfConfidence (0..100) and a global risk THROTTLE that |
//|  scales size; a hard stand-down veto when health fails. Reads the |
//|  adaptive accumulators (ad_*), so include AFTER Adaptive and      |
//|  BEFORE SymphonyEngine. Writes g_state.self.                      |
//+------------------------------------------------------------------+
#ifndef FALCON_SELF_AWARENESS_MQH
#define FALCON_SELF_AWARENESS_MQH

#include "../Kernel/FalconState.mqh"
#include "../Kernel/FalconConfig.mqh"
#include "../Kernel/FalconSeries.mqh"

double sa_equityPeak = 0.0;
double sa_equityPrev = 0.0;
double sa_slope      = 0.0;

void SelfAwarenessInit()
{
   sa_equityPeak = AccountInfoDouble(ACCOUNT_EQUITY);
   sa_equityPrev = sa_equityPeak;
   sa_slope      = 0.0;
}

void SelfAwarenessRun()
{
   if(!g_cfg.useSelfAware) return;
   FalconSelfAwareness s; ZeroMemory(s);

   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(sa_equityPeak<=0.0) sa_equityPeak=eq;
   if(eq>sa_equityPeak) sa_equityPeak=eq;
   double ddPct = (sa_equityPeak>0.0 ? (sa_equityPeak-eq)/sa_equityPeak*100.0 : 0.0);
   sa_slope = FalconEMA(sa_slope, eq-sa_equityPrev, 10);
   sa_equityPrev = eq;

   s.winStreak     = ad_winStreak;
   s.lossStreak    = ad_lossStreak;
   s.ddFromPeakPct = ddPct;
   s.equitySlope   = sa_slope;

   // 1) CALIBRATION — |avg predicted prob - actual win rate| (lower = better)
   if(ad_calN>=5)
   {
      double avgPred = ad_calPredSum/ad_calN;
      double actWin  = ad_calWinSum /ad_calN;
      s.calibration  = FalconClamp(100.0 - MathAbs(avgPred-actWin)*100.0, 0, 100);
   }
   else s.calibration = 60.0;   // neutral until enough samples

   // 2) FORM — streak + equity slope, penalised by drawdown
   double streakF = FalconClamp(55.0 + s.winStreak*8.0 - s.lossStreak*12.0, 0, 100);
   double slopeF  = (sa_slope>0?60.0:sa_slope<0?40.0:50.0);
   s.form = FalconClamp(0.6*streakF + 0.2*slopeF + 0.2*FalconClamp(100.0-ddPct*5.0,0,100), 0, 100);

   // 3) REGIME FIT — am I in conditions I perform in? best learned bucket edge at
   //    the current curve band, blended with HTF fractal agreement.
   int bL=AD_Bucket(DIR_LONG), bS=AD_Bucket(DIR_SHORT);
   double edge = MathMax(ad_ewmaR[bL], ad_ewmaR[bS]);          // best available edge here
   double edgeF = FalconClamp(50.0 + edge*40.0, 0, 100);
   s.regimeFit = FalconClamp(0.5*edgeF + 0.5*g_state.htf.alignment, 0, 100);

   // 4) HEALTH — own-input integrity. If broken, do not trust self.
   double atr = FalconATR(1);
   s.health = true; s.healthNote = "ok";
   if(atr<=0.0)                                   { s.health=false; s.healthNote="no ATR/data"; }
   else if(g_cfg.useCurveLocator && g_state.curveLocator.conf < 20.0) { s.health=false; s.healthNote="lost on curve"; }
   else if(ddPct >= g_cfg.maxDrawdownPct)         { s.health=false; s.healthNote="drawdown halt"; }
   else if(ad_lossStreak >= g_cfg.selfLossHalt)   { s.health=false; s.healthNote="loss cluster"; }

   // SYNTHESIS — one self-confidence, then a bounded throttle.
   s.selfConfidence = FalconClamp(0.30*s.calibration + 0.35*s.form + 0.20*s.regimeFit
                                  + 0.15*(s.health?100.0:0.0), 0, 100);
   // THROTTLE — full size in normal conditions; only ramp DOWN when confidence
   //   drops below selfFullConf. (Previously a linear conf/100 map haircut size
   //   even at middling confidence and slowed the whole system down.)
   if(!s.health)                          s.throttle = 0.0;                 // stand down
   else if(s.selfConfidence >= g_cfg.selfFullConf) s.throttle = 1.0;        // full size
   else s.throttle = FalconClamp(g_cfg.selfMinThrottle
                     + (1.0-g_cfg.selfMinThrottle)*(s.selfConfidence/MathMax(g_cfg.selfFullConf,1.0)),
                     g_cfg.selfMinThrottle, 1.0);

   s.label = (!s.health ? "STANDDOWN"
              : s.selfConfidence>70 ? "CONFIDENT"
              : s.selfConfidence>45 ? "CAUTIOUS" : "DEFENSIVE");

   g_state.self = s;
}

// helpers for the entry path
double SA_Throttle(){ return(g_cfg.useSelfAware ? g_state.self.throttle : 1.0); }
bool   SA_StandDown(){ return(g_cfg.useSelfAware && !g_state.self.health); }

#endif // FALCON_SELF_AWARENESS_MQH
//+------------------------------------------------------------------+
