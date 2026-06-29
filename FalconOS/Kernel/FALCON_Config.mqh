//+------------------------------------------------------------------+
//| FALCON_Config.mqh                                                 |
//| FALCON OS - Kernel: Configuration Service                         |
//|                                                                   |
//| Centralized settings with profile support (backtest/live/        |
//| research). All module parameters live here as one config object,  |
//| read through the kernel. Profiles tune behaviour without code     |
//| changes.                                                          |
//+------------------------------------------------------------------+
#property strict

//==================================================================
// INPUT PARAMETERS (single centralized config surface)
//==================================================================

//--- Profile
input FALCON_Profile InpProfile        = PROFILE_LIVE;  // Operating profile

//--- Core Market (LETRA)
input int    CfgPivotLen          = 5;       // Pivot length
input int    CfgATRLen            = 14;      // ATR length
input int    CfgEffLen            = 10;      // Efficiency lookback
input double CfgImpulseAtrMult    = 1.5;     // Impulse ATR multiple
input double CfgEffThresh         = 0.65;    // Efficiency threshold
input double CfgDispThresh        = 1.5;     // Displacement ATR threshold
input double CfgConvMult          = 0.01;    // Convexity ATR multiplier
input double CfgChochBufferATR    = 0.75;    // CHoCH buffer (ATR)
input double CfgRetrMin           = 0.30;    // Min retracement
input double CfgRetrMax           = 0.80;    // Max retracement
input int    CfgInducLookback     = 80;      // Inducement lookback bars
input double CfgInducZoneATRWidth = 0.25;    // Inducement zone half-width

//--- ARC (Symphony)
input int    CfgArcHorizonBars    = 80;      // Arc horizon bars
input double CfgConvPower         = 1.5;     // Arc convexity power
input double CfgArcExtMult        = 1.5;     // Arc extension multiple
input double CfgOuterBandAtrMult  = 0.75;    // Outer band distance (ATR)
input double CfgArcToleranceAtr   = 0.20;    // ARC exhaust tolerance (ATR)

//--- FU detection
input double CfgFUMinBodyRatio    = 0.60;    // FU min body/range ratio
input double CfgFUMinWickRatio    = 0.25;    // FU min wick ratio
input int    CfgFUMaxBarsActive   = 75;      // FU zone max active bars
input int    CfgFULookback        = 3;       // FU detection lookback
input double CfgWickFrac          = 0.30;    // Network node wick fraction

//--- Network
input int    CfgNodeMax           = 250;     // Max network nodes
input int    CfgAuthMin           = 45;      // Min node authority
input int    CfgDormantBars       = 120;     // Bars until dormant
input int    CfgHistoryBars       = 600;     // Bars until historical


//--- Intelligence
input int    CfgBeliefSmooth      = 3;       // Belief EMA smoothing
input int    CfgResetBars         = 20;      // Min bars before reset
input double CfgERFEntryThreshold = 45.0;    // ERF entry gate threshold
input bool   CfgERFGateEnabled    = true;    // Enable ERF entry gate
input int    CfgMinConfAttack     = 55;      // Min confidence to ATTACK

//--- Execution / Risk
input double CfgRiskPercent       = 0.5;     // Risk % per trade
input int    CfgMagic             = 990220;  // EA magic number
input int    CfgTargetGMT         = 0;       // Target GMT offset
input int    CfgBaseLockBars      = 10;      // Lock bars after entry
input double CfgExecThreshold     = 5.0;     // Net edge threshold
input bool   CfgEnableRiskEngine  = true;    // Enable DRDWCT risk engine
input bool   CfgBlockNewIfBreach  = true;    // Block entries on VaR breach
input double CfgRDLimit           = 0.0095;  // Risk-density limit (micro-bomb)

//--- Visualization
input bool   CfgShowDashboard     = true;    // Show tabbed dashboard
input int    CfgActiveTab         = 0;       // 0=Overview...11=Diagnostics
input bool   CfgShowChartObjects  = true;    // Show chart object overlays

//==================================================================
// PROFILE-AWARE GETTERS
// Profiles adjust behaviour: research = verbose logging + all viz;
// backtest = no chart objects, minimal logging; live = balanced.
//==================================================================
bool FALCON_IsLive()      { return(InpProfile == PROFILE_LIVE); }
bool FALCON_IsBacktest()  { return(InpProfile == PROFILE_BACKTEST); }
bool FALCON_IsResearch()  { return(InpProfile == PROFILE_RESEARCH); }

bool FALCON_VisualsEnabled()
{
   // Backtest disables chart objects for speed; research/live enable
   if(FALCON_IsBacktest()) return(false);
   return(CfgShowChartObjects);
}

bool FALCON_VerboseLogging()
{
   return(FALCON_IsResearch());
}

string FALCON_ProfileName()
{
   switch(InpProfile)
   {
      case PROFILE_BACKTEST: return("BACKTEST");
      case PROFILE_LIVE:     return("LIVE");
      case PROFILE_RESEARCH: return("RESEARCH");
      default:               return("UNKNOWN");
   }
}

//+------------------------------------------------------------------+
