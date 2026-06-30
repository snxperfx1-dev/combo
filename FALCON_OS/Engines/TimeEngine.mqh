//+------------------------------------------------------------------+
//|  FALCON OS — Intelligence : TimeEngine.mqh                      |
//|  Source: F16 Raptor — ENGINE 8.0 (Time Intelligence Engine)     |
//|                                                                  |
//|  THE TEMPORAL LAYER. Markets do not behave uniformly across the  |
//|  clock: a London-open expansion is not a dead Asian-lunch range. |
//|  TIE models a 5-CYCLE TEMPORAL STACK and synthesises one          |
//|  continuous timeQuality + a path probability + a SOFT temporal    |
//|  permission. It is informational by default — the HARD session    |
//|  window stays in the separate session filter. (Design law:        |
//|  hard risk/time limits are kept separate from probability layers.)|
//|                                                                  |
//|  The 5 cycles (each 0..100 favourability):                       |
//|    1. SESSION cycle   — Asia / London / NY / overlap structure    |
//|    2. HOUR cycle      — gold's intraday volatility profile        |
//|    3. KILLZONE cycle  — London-open & NY-open high-prob windows   |
//|    4. WEEKDAY cycle   — Mon ramp · mid-week peak · Fri fade        |
//|    5. WEEKPOS cycle   — early/mid/late-week momentum bias          |
//|                                                                  |
//|  Writes g_state.timeIntel. Reads only the clock (TimeGMT) + the    |
//|  GMT offset already used by the session filter — no market recompute|
//+------------------------------------------------------------------+
#ifndef FALCON_TIME_ENGINE_MQH
#define FALCON_TIME_ENGINE_MQH

#include "../Kernel/FalconState.mqh"
#include "../Kernel/FalconConfig.mqh"
#include "../Kernel/FalconSeries.mqh"
#include "../Kernel/FalconEventBus.mqh"

void TimeEngineInit() { ZeroMemory(g_state.timeIntel); }

//------------------------------------------------------------------
// Gold's typical intraday volatility profile by session-adjusted hour
// (0..100). Two humps: the London open (~7-10) and the NY open + the
// London/NY overlap (~12-16). Asia (~0-6) and the post-NY lull (~17-23)
// are low. A smooth heuristic, not a fitted curve.
//------------------------------------------------------------------
double TIE_HourVol(const int hh)
{
   // hand-tuned 24-slot profile (relative expected range for XAUUSD)
   static double prof[24] =
   {
      28,24,22,20,22,30,45,68,  // 00-07  Asia -> London ramp
      82,88,80,66,72,90,95,88,  // 08-15  London peak -> NY open / overlap peak
      72,58,46,40,36,34,32,30   // 16-23  NY fade -> post-NY lull
   };
   int i = hh; if(i<0) i=0; if(i>23) i=23;
   return(prof[i]);
}

//------------------------------------------------------------------
// MASTER ENTRY — Time Intelligence Engine pipeline step
//------------------------------------------------------------------
void TimeEngineRun()
{
   FalconTime t;
   ZeroMemory(t);

   if(!g_cfg.useTimeIntel)
   {
      // neutral pass-through so downstream weighing is a no-op
      t.session=SES_CLOSED; t.sessionName="(off)";
      t.timeQuality=100.0; t.pathProbability=0.5; t.permit=true; t.label="—";
      for(int k=0;k<5;k++) t.cycle[k]=100.0;
      g_state.timeIntel=t;
      return;
   }

   MqlDateTime g; TimeGMT(g);
   int hh = g.hour + g_cfg.targetGMT;
   while(hh<0) hh+=24; while(hh>=24) hh-=24;
   int cur = hh*60 + g.min;

   t.hour      = hh;
   t.minute    = g.min;
   t.dayOfWeek = g.day_of_week;

   //--------------------------------------------------------------
   // CYCLE 1 — SESSION structure
   //   Asia 00:00-06:59 · London 07:00-15:59 · NY 12:00-20:59 ·
   //   Overlap 12:00-15:59 (London & NY both live = the prime window)
   //--------------------------------------------------------------
   int    ses=SES_CLOSED; double sesStart=0, sesLen=1; double sesFav=30;
   bool   ldn = (cur>=420 && cur<960);   // 07:00-15:59
   bool   ny  = (cur>=720 && cur<1260);  // 12:00-20:59
   bool   asia= (cur>=0   && cur<420);   // 00:00-06:59
   if(ldn && ny) { ses=SES_OVERLAP; sesStart=720; sesLen=240; sesFav=95; }
   else if(ldn)  { ses=SES_LONDON;  sesStart=420; sesLen=300; sesFav=82; }
   else if(ny)   { ses=SES_NY;      sesStart=960; sesLen=300; sesFav=78; } // NY-only portion (after overlap)
   else if(asia) { ses=SES_ASIA;    sesStart=0;   sesLen=420; sesFav=42; }
   else          { ses=SES_CLOSED;  sesStart=1260;sesLen=180; sesFav=24; } // 21:00-23:59 lull

   t.session     = ses;
   t.sessionName = FalconSessionStr(ses);
   t.sessionProgress = FalconClamp((cur - sesStart)/MathMax(sesLen,1.0), 0.0, 1.0);
   t.cycle[0]    = sesFav;

   //--------------------------------------------------------------
   // CYCLE 2 — HOUR volatility profile
   //--------------------------------------------------------------
   t.volExpectation       = TIE_HourVol(hh);
   t.liquidityExpectation = FalconClamp(t.volExpectation*0.7 + sesFav*0.3, 0, 100);
   t.cycle[1]             = t.volExpectation;

   //--------------------------------------------------------------
   // CYCLE 3 — KILLZONE windows (high-probability institutional times)
   //   London open 07:00-10:00 · NY open 12:00-15:00 (GMT-adjusted)
   //--------------------------------------------------------------
   bool kzLondon = (cur>=420 && cur<600);
   bool kzNY     = (cur>=720 && cur<900);
   t.killzone = (kzLondon || kzNY);
   t.killzoneName = kzLondon ? "LONDON OPEN" : kzNY ? "NY OPEN" : "—";
   t.cycle[2] = t.killzone ? 92.0 : (asia ? 35.0 : 55.0);

   //--------------------------------------------------------------
   // CYCLE 4 — WEEKDAY cycle (Mon ramp, Tue-Thu peak, Fri fade,
   //   weekend dead). day_of_week: 0=Sun .. 6=Sat.
   //--------------------------------------------------------------
   double dayFav;
   switch(g.day_of_week)
   {
      case 1: dayFav=70; break;  // Mon
      case 2: dayFav=90; break;  // Tue
      case 3: dayFav=95; break;  // Wed
      case 4: dayFav=90; break;  // Thu
      case 5: dayFav=62; break;  // Fri (fade into close)
      default: dayFav=15; break; // Sat/Sun
   }
   t.cycle[3]=dayFav;

   //--------------------------------------------------------------
   // CYCLE 5 — WEEK-POSITION momentum bias. Early week tends to
   //   establish the move, late week mean-reverts / books profit.
   //--------------------------------------------------------------
   double weekPos = (g.day_of_week>=1 && g.day_of_week<=5) ? (g.day_of_week-1)/4.0 : 1.0; // 0=Mon..1=Fri
   t.cycle[4] = FalconClamp(100.0 - weekPos*45.0, 0, 100); // momentum strongest early

   //--------------------------------------------------------------
   // COMPOSITE timeQuality — weighted blend of the stack. Session and
   // killzone dominate (institutional participation drives gold).
   //--------------------------------------------------------------
   t.timeQuality = FalconClamp(
        t.cycle[0]*0.28      // session
      + t.cycle[1]*0.24      // hour vol
      + t.cycle[2]*0.22      // killzone
      + t.cycle[3]*0.16      // weekday
      + t.cycle[4]*0.10,     // week position
      0, 100);

   //--------------------------------------------------------------
   // PATH probability — likelihood the clock favours a CONTINUATION
   // (expansion) rather than chop. Higher in killzones / overlap.
   //--------------------------------------------------------------
   t.pathProbability = FalconClamp(t.timeQuality/100.0*0.7 + (t.killzone?0.2:0.0) + (ses==SES_OVERLAP?0.1:0.0), 0.0, 1.0);

   //--------------------------------------------------------------
   // TEMPORAL bias — London typically EXPANDS the Asian range (its
   // direction emerges from price, not the clock), so TIE stays
   // direction-agnostic and only flags the regime, not a side.
   //--------------------------------------------------------------
   t.temporalBias = DIR_NONE;

   t.permit = (t.timeQuality >= g_cfg.timeQualityFloor);
   t.label  = (t.timeQuality>=78 ? "PRIME" : t.timeQuality>=g_cfg.timeQualityFloor ? "ACTIVE" : t.timeQuality>=22 ? "QUIET" : "DEAD");

   g_state.timeIntel=t;
}

#endif // FALCON_TIME_ENGINE_MQH
//+------------------------------------------------------------------+
