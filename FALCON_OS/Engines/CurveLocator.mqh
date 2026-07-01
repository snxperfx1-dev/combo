//+------------------------------------------------------------------+
//|  FALCON OS — Intelligence : CurveLocator.mqh                    |
//|                                                                  |
//|  "NEVER LOSE WHERE YOU ARE ON THE CURVE."                        |
//|                                                                  |
//|  A single always-on, continuous, multi-TF coordinate of where    |
//|  price sits between the OWNING curve's origin and destination.   |
//|  It is never undefined:                                          |
//|    • continuous (geometric interpolation, not a phase bucket),    |
//|    • anchored to the OWNER TF and cascading UP the ladder when a  |
//|      lower curve resets,                                          |
//|    • confidence DECAYS and the last good position PERSISTS on a   |
//|      reset instead of snapping to zero,                           |
//|    • velocity tells which way along the curve price is moving.    |
//|                                                                  |
//|  Reads the per-TF curves (g_tfCurve) the Market Engine already    |
//|  builds. Run after the Memory layer (ownership final). Writes     |
//|  g_state.curveLocator. Phases stay OUTPUTS — labels off `pos`.    |
//+------------------------------------------------------------------+
#ifndef FALCON_CURVE_LOCATOR_MQH
#define FALCON_CURVE_LOCATOR_MQH

#include "../Kernel/FalconState.mqh"
#include "../Kernel/FalconConfig.mqh"
#include "../Kernel/FalconSeries.mqh"

double cl_prevPos     = -1.0;
double cl_vel         = 0.0;
double cl_conf        = 0.0;
double cl_lastGoodPos = 0.5;
int    cl_lastGoodDir = 0;

void CurveLocatorInit()
{
   cl_prevPos=-1.0; cl_vel=0.0; cl_conf=0.0; cl_lastGoodPos=0.5; cl_lastGoodDir=0;
}

// Continuous position on one TF's leg: 0 at origin, 1 at destination.
// The formula self-normalises for both long and short curves (dest-origin
// flips sign with direction). Returns -1 when the leg is undefined.
double CL_LegPos(const int idx, const double price)
{
   double o = g_tfCurve[idx].oOrigin;
   double d = g_tfCurve[idx].oObjective;
   if(o==0.0 || d==0.0 || MathAbs(d-o)<1e-9) return(-1.0);
   double p = (price - o) / (d - o);
   return(FalconClamp(p, 0.0, 1.2));   // small overshoot allowed past target
}

void CurveLocatorRun()
{
   if(!g_cfg.useCurveLocator) return;

   FalconCurveLocator cl; ZeroMemory(cl);
   double price = gClose[1];

   // per-TF positions (the fractal "you are here" on every rung)
   for(int i=0;i<7;i++) cl.legPos[i] = CL_LegPos(i, price);

   // master = OWNER TF; cascade UP the ladder if the owner leg is undefined,
   // then DOWN, so a location is essentially always found.
   int oi = g_state.htf.ownerTF; if(oi<0 || oi>6) oi=4;
   double pos=-1.0; int usedTF=oi;
   for(int i=oi;i<7;i++)   { if(cl.legPos[i]>=0.0){ pos=cl.legPos[i]; usedTF=i; break; } }
   if(pos<0.0) for(int i=oi-1;i>=0;i--){ if(cl.legPos[i]>=0.0){ pos=cl.legPos[i]; usedTF=i; break; } }

   double conf;
   if(pos>=0.0)
   {
      cl_lastGoodPos = pos;
      cl_lastGoodDir = g_tfCurve[usedTF].oDir;
      conf = FalconClamp(60.0 + g_state.htf.alignment*0.4, 0, 100);
   }
   else
   {
      // GRACEFUL DEGRADATION — keep the last known location, decay confidence.
      pos    = cl_lastGoodPos;
      usedTF = oi;
      conf   = cl_conf*0.85;
   }

   // velocity (EMA of position change) — advancing toward destination when >= 0
   if(cl_prevPos>=0.0) cl_vel = FalconEMA(cl_vel, pos-cl_prevPos, 3);
   cl_prevPos = pos;
   cl_conf    = conf;

   int usedDir = (g_tfCurve[usedTF].oDir!=0 ? g_tfCurve[usedTF].oDir : cl_lastGoodDir);
   cl.pos       = pos;
   cl.dir       = usedDir;
   cl.vel       = cl_vel;
   cl.conf      = conf;
   cl.ownerTF   = usedTF;
   cl.advancing = (cl_vel >= 0.0);
   cl.label     = (pos<0.20?"Early":pos<0.50?"Developing":pos<0.80?"Mid":pos<0.95?"Late":"Terminal");

   g_state.curveLocator = cl;
}

#endif // FALCON_CURVE_LOCATOR_MQH
//+------------------------------------------------------------------+
