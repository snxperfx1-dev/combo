//+------------------------------------------------------------------+
//|  FALCON OS — Kernel : FalconLog.mqh                             |
//|  Structured logging, timing metrics, module health checks.      |
//+------------------------------------------------------------------+
#ifndef FALCON_LOG_MQH
#define FALCON_LOG_MQH

#include "FalconConfig.mqh"

//==================================================================
// MODULE REGISTRY — for health checks + timing
//==================================================================
enum FALCON_MODULE
{
   MOD_MARKET = 0,
   MOD_MEMORY,
   MOD_INTEL,
   MOD_DECISION,
   MOD_EXEC,
   MOD_VIZ,
   MOD_COUNT
};

struct FalconModuleHealth
{
   bool   ok;
   ulong  lastMicros;     // last run duration (microseconds)
   ulong  totalMicros;
   int    runs;
   string lastError;
};

struct FalconDiagnostics
{
   FalconModuleHealth health[MOD_COUNT];
   ulong  pipelineMicros;
   int    pipelineRuns;
   datetime bootTime;
};

FalconDiagnostics g_diag;

string FalconModuleName(const int m)
{
   switch(m)
   {
      case MOD_MARKET:   return("MarketEngine");
      case MOD_MEMORY:   return("MemoryEngine");
      case MOD_INTEL:    return("IntelligenceEngine");
      case MOD_DECISION: return("DecisionEngine");
      case MOD_EXEC:     return("ExecutionEngine");
      case MOD_VIZ:      return("VisualizationEngine");
      default:           return("Unknown");
   }
}

void FalconLogInit()
{
   for(int i=0;i<MOD_COUNT;i++)
   {
      g_diag.health[i].ok          = true;
      g_diag.health[i].lastMicros  = 0;
      g_diag.health[i].totalMicros = 0;
      g_diag.health[i].runs        = 0;
      g_diag.health[i].lastError   = "";
   }
   g_diag.pipelineMicros = 0;
   g_diag.pipelineRuns   = 0;
   g_diag.bootTime       = TimeCurrent();
}

//------------------------------------------------------------------
// Record a module run timing + health.
//------------------------------------------------------------------
void FalconModuleStart(const int m, ulong &t0)
{
   t0 = GetMicrosecondCount();
}

void FalconModuleEnd(const int m, const ulong t0, const bool ok=true, const string err="")
{
   if(m<0 || m>=MOD_COUNT) return;
   ulong dt = GetMicrosecondCount() - t0;
   g_diag.health[m].lastMicros   = dt;
   g_diag.health[m].totalMicros += dt;
   g_diag.health[m].runs++;
   g_diag.health[m].ok           = ok;
   if(!ok) g_diag.health[m].lastError = err;
}

//------------------------------------------------------------------
// Structured log line. Honors verbose flag for INFO.
//------------------------------------------------------------------
void FalconLog(const string level, const string module, const string msg)
{
   if(level=="INFO" && !g_cfg.verboseLog) return;
   PrintFormat("[FALCON][%s][%s] %s", level, module, msg);
}

void FalconInfo (const string module, const string msg) { FalconLog("INFO", module, msg); }
void FalconWarn (const string module, const string msg) { FalconLog("WARN", module, msg); }
void FalconError(const string module, const string msg) { FalconLog("ERROR",module, msg); }

double FalconAvgMicros(const int m)
{
   if(m<0 || m>=MOD_COUNT || g_diag.health[m].runs<=0) return(0.0);
   return((double)g_diag.health[m].totalMicros / (double)g_diag.health[m].runs);
}

#endif // FALCON_LOG_MQH
//+------------------------------------------------------------------+
