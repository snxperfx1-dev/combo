//+------------------------------------------------------------------+
//|  FALCON OS — Kernel : FalconSeries.mqh                          |
//|  Single source of truth for price series + primitive math.      |
//|                                                                  |
//|  ATR, pivots, OHLC access exist EXACTLY ONCE here. LETRA, F16    |
//|  and Symphony each re-implemented these; FALCON OS does not.     |
//+------------------------------------------------------------------+
#ifndef FALCON_SERIES_MQH
#define FALCON_SERIES_MQH

#include "FalconConfig.mqh"

//==================================================================
// SHARED SERIES BUFFERS (series-indexed: [0] = newest)
//==================================================================
double   gClose[];
double   gHigh[];
double   gLow[];
double   gOpen[];
datetime gTime[];

int      g_atrHandle      = INVALID_HANDLE;
int      g_atrFastHandle  = INVALID_HANDLE;
int      g_atrSlowHandle  = INVALID_HANDLE;
datetime g_lastBarTime    = 0;
int      g_barCounter     = 0;   // synthetic monotonic bar index

//------------------------------------------------------------------
bool FalconRefreshSeries()
{
   int need = g_cfg.seriesBars;
   if(need < 500) need = 500;

   ArraySetAsSeries(gClose,true);
   ArraySetAsSeries(gHigh,true);
   ArraySetAsSeries(gLow,true);
   ArraySetAsSeries(gOpen,true);
   ArraySetAsSeries(gTime,true);

   ENUM_TIMEFRAMES tf = g_cfg.operatingTF;
   int c1 = CopyClose(_Symbol,tf,0,need,gClose);
   int c2 = CopyHigh (_Symbol,tf,0,need,gHigh);
   int c3 = CopyLow  (_Symbol,tf,0,need,gLow);
   int c4 = CopyOpen (_Symbol,tf,0,need,gOpen);
   int c5 = CopyTime (_Symbol,tf,0,need,gTime);

   if(c1<=0 || c2<=0 || c3<=0 || c4<=0 || c5<=0)
      return(false);
   return(true);
}

int FalconBars() { return((int)ArraySize(gClose)); }

bool FalconIsNewBar()
{
   datetime t = gTime[0];
   if(t != g_lastBarTime)
   {
      g_lastBarTime = t;
      g_barCounter++;
      return(true);
   }
   return(false);
}

//------------------------------------------------------------------
// ATR — single implementation. variant 0=main 1=fast(15) 2=slow(30)
//------------------------------------------------------------------
double FalconATR(const int shift, const int variant=0)
{
   int handle = INVALID_HANDLE;
   if(variant==0)
   {
      if(g_atrHandle==INVALID_HANDLE) g_atrHandle = iATR(_Symbol,g_cfg.operatingTF,g_cfg.atrLen);
      handle = g_atrHandle;
   }
   else if(variant==1)
   {
      if(g_atrFastHandle==INVALID_HANDLE) g_atrFastHandle = iATR(_Symbol,g_cfg.operatingTF,15);
      handle = g_atrFastHandle;
   }
   else
   {
      if(g_atrSlowHandle==INVALID_HANDLE) g_atrSlowHandle = iATR(_Symbol,g_cfg.operatingTF,30);
      handle = g_atrSlowHandle;
   }
   if(handle==INVALID_HANDLE) return(0.0);

   double buf[];
   ArraySetAsSeries(buf,true);
   if(CopyBuffer(handle,0,shift,1,buf) < 1) return(0.0);
   return(buf[0]);
}

//------------------------------------------------------------------
// Pivot detection — single implementation.
//------------------------------------------------------------------
bool FalconIsPivotHigh(const int c, const int len)
{
   int maxBars = FalconBars();
   if(c<=0 || c>=maxBars) return(false);
   double h = gHigh[c];
   for(int k=1;k<=len;k++)
   {
      if(c+k>=maxBars || c-k<0) return(false);
      if(h<=gHigh[c+k]) return(false);
      if(h<=gHigh[c-k]) return(false);
   }
   return(true);
}

bool FalconIsPivotLow(const int c, const int len)
{
   int maxBars = FalconBars();
   if(c<=0 || c>=maxBars) return(false);
   double l = gLow[c];
   for(int k=1;k<=len;k++)
   {
      if(c+k>=maxBars || c-k<0) return(false);
      if(l>=gLow[c+k]) return(false);
      if(l>=gLow[c-k]) return(false);
   }
   return(true);
}

//------------------------------------------------------------------
// Simple math helpers (single source).
//------------------------------------------------------------------
double FalconEMA(const double prev, const double value, const int period)
{
   double alpha = 2.0/(period+1.0);
   return(prev + alpha*(value-prev));
}

double FalconClamp(const double v, const double lo, const double hi)
{
   if(v<lo) return(lo);
   if(v>hi) return(hi);
   return(v);
}

double FalconHighest(const int from, const int len)
{
   int maxBars = FalconBars();
   double m = -DBL_MAX;
   for(int i=from;i<from+len && i<maxBars;i++)
      if(gHigh[i]>m) m=gHigh[i];
   return(m==-DBL_MAX ? 0.0 : m);
}

double FalconLowest(const int from, const int len)
{
   int maxBars = FalconBars();
   double m = DBL_MAX;
   for(int i=from;i<from+len && i<maxBars;i++)
      if(gLow[i]<m) m=gLow[i];
   return(m==DBL_MAX ? 0.0 : m);
}

void FalconReleaseHandles()
{
   if(g_atrHandle!=INVALID_HANDLE)     { IndicatorRelease(g_atrHandle);     g_atrHandle=INVALID_HANDLE; }
   if(g_atrFastHandle!=INVALID_HANDLE) { IndicatorRelease(g_atrFastHandle); g_atrFastHandle=INVALID_HANDLE; }
   if(g_atrSlowHandle!=INVALID_HANDLE) { IndicatorRelease(g_atrSlowHandle); g_atrSlowHandle=INVALID_HANDLE; }
}

#endif // FALCON_SERIES_MQH
//+------------------------------------------------------------------+
