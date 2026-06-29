//+------------------------------------------------------------------+
//| FALCON_Logger.mqh                                                 |
//| FALCON OS - Kernel: Logging & Diagnostics                         |
//|                                                                   |
//| Structured logs, timing metrics, health checks, module status.   |
//| Log levels gate verbosity by profile. Timing uses GetMicrosecond |
//| Count for per-module performance.                                |
//+------------------------------------------------------------------+
#property strict

enum FALCON_LogLevel { LOG_ERROR=0, LOG_WARN=1, LOG_INFO=2, LOG_DEBUG=3 };

//--- Timing scratch
ulong g_timerStart = 0;
ulong g_pipelineStart = 0;

//--- Begin a timing block
void FALCON_TimerStart()      { g_timerStart = GetMicrosecondCount(); }
long FALCON_TimerElapsed()    { return((long)(GetMicrosecondCount() - g_timerStart)); }
void FALCON_PipelineStart()   { g_pipelineStart = GetMicrosecondCount(); }
long FALCON_PipelineElapsed() { return((long)(GetMicrosecondCount() - g_pipelineStart)); }

//==================================================================
// LOG: gated by profile (research=DEBUG, live=INFO, backtest=ERROR)
//==================================================================
void FALCON_Log(FALCON_LogLevel level, string module, string msg)
{
   FALCON_LogLevel threshold = LOG_INFO;
   if(FALCON_IsResearch())  threshold = LOG_DEBUG;
   else if(FALCON_IsBacktest()) threshold = LOG_ERROR;
   else threshold = LOG_INFO;

   if(level > threshold) return;

   string tag = (level == LOG_ERROR) ? "[ERR]" :
                (level == LOG_WARN)  ? "[WRN]" :
                (level == LOG_INFO)  ? "[INF]" : "[DBG]";
   Print("FALCON ", tag, " ", module, ": ", msg);

   if(level == LOG_ERROR)
      gState.diag.lastError = module + ": " + msg;
}


//==================================================================
// HEALTH CHECKS — verify each layer produced sane output
//==================================================================
void FALCON_RunHealthChecks()
{
   // Market layer: ATR must be positive, structure populated
   gState.diag.marketHealthy = (gState.physics.atr > 0 && gState.barsAvailable > 50);

   // Memory layer: at least the network scan ran (node array valid)
   gState.diag.memoryHealthy = (gState.network.nodeCount >= 0);

   // Intelligence layer: confidence in valid range
   gState.diag.intelHealthy = (gState.intel.modelConfidence >= 0 &&
                               gState.intel.modelConfidence <= 100);

   // Execution layer: equity readable
   gState.diag.execHealthy = (gState.exec.equity >= 0);

   if(!gState.diag.marketHealthy)
      FALCON_Log(LOG_WARN, "Health", "Market layer unhealthy (ATR/bars)");
}

//==================================================================
// MODULE TIMING RECORDER
//==================================================================
void FALCON_RecordModuleTime(int moduleIdx, long micros)
{
   if(moduleIdx >= 0 && moduleIdx < 8)
      gState.diag.moduleMicros[moduleIdx] = micros;
}

//--- Diagnostics summary string
string FALCON_DiagSummary()
{
   return(StringFormat("Pipeline %dus | Evts %d/%d | Bars %d | Health M%d Mem%d I%d E%d",
      (int)gState.diag.pipelineMicros,
      gState.diag.eventsHandled, gState.diag.eventsPublished,
      gState.diag.barsProcessed,
      gState.diag.marketHealthy, gState.diag.memoryHealthy,
      gState.diag.intelHealthy, gState.diag.execHealthy));
}

//+------------------------------------------------------------------+
