//+------------------------------------------------------------------+
//| Part11_LiquidationWaveRegistry.mqh                                |
//| MASTER ALGO - Engine 1A.7 Liquidation Wave + Energy Registry      |
//| Full pre-objective liquidation wave sub-phase tracking            |
//| + Energy Displacement Registry (execution-integrated)             |
//+------------------------------------------------------------------+
#property strict

//==================================================================
// ENGINE 1A.7 — PRE-OBJECTIVE LIQUIDATION WAVE
//
// When Engine 1A enters Induction phase, the market is building a
// liquidation wave TOWARD the M5 objective. This engine tracks:
//   Init → Push → Displacement → Induction → Terminal Liq → Obj Arrival
// Distance compression (100%=at origin, 0%=arrived) gives the %
// remaining. True CHoCH requires Structure ∧ Momentum ∧ Physics.
//
// EXECUTION INTEGRATION:
//   - While active and NOT arrived: suppress reversal signals
//   - On objective arrival: boost reversal probability
//   - True CHoCH = genuine phase transition (unlocks Absorption label)
//==================================================================


//--- Liquidation Wave State
struct LiqWaveState
{
   bool   active;         // liquidation wave in progress
   bool   isRetracement;  // true if from Retracement Induction
   int    direction;      // 1=heading up to target, -1=heading down
   double target;         // M5 objective price
   double initDist;       // initial distance to target (for compression %)
   double distPct;        // distance remaining 0-100 (100=at origin, 0=arrived)
   bool   objArrival;     // structural arrival at target
   bool   trueCHoCH;      // genuine change of character confirmed
   string subPhase;       // Init/Push/Displacement/Induction/Terminal/Arrival
   string title;          // display title
};

LiqWaveState g_liqWave;

// Absorption gate: only unlocked after genuine objective arrival + true CHoCH
bool g_absorbUnlocked = false;

//--- Energy Displacement Registry
struct EnergyEvent
{
   double price;          // entry-cycle price level
   int    direction;      // 1=bull, -1=bear
   int    birthBar;       // age tracking
   int    resolution;     // 0=unresolved, 1=partial, 2=resolved
   double peakEnergy;     // max expansion energy recorded
   double residualEnergy; // energy remaining at last update
   int    entryCycle;     // which cycle spawned this
   int    waveGen;        // wave generation number
};

#define REGISTRY_MAX 50
EnergyEvent g_energyRegistry[REGISTRY_MAX];
int         g_registryCount = 0;
int         g_registryTotalSpawned = 0;

// Registry outputs for execution decisions
int    g_nearestUnresolvedIdx = -1;
double g_nearestUnresolvedPrice = 0;
double g_nearestUnresolvedDist = 0;
int    g_unresolvedCount = 0;


//==================================================================
// 1. LIQUIDATION WAVE ENGINE (Engine 1A.7)
//==================================================================
void UpdateLiquidationWave()
{
   if(ArraySize(Close) < 2) return;
   double atr = g_physics.atr;
   if(atr <= 0) return;
   double closeNow = Close[1];
   
   // Arm condition: IE1A enters Induction phase
   bool isRetrInduction = (g_currentPhase == PHASE_RETR_INDUCTION);
   bool armCondition = (g_currentPhase == PHASE_EXP_INDUCTION || isRetrInduction);
   double m5Target = g_structure[TF_M5].target;
   
   // Activate on arm (first time entering induction with a valid target)
   if(armCondition && !g_liqWave.active && m5Target > 0)
   {
      g_liqWave.active = true;
      g_liqWave.isRetracement = isRetrInduction;
      g_liqWave.target = m5Target;
      g_liqWave.direction = (m5Target > closeNow) ? 1 : -1;
      g_liqWave.initDist = MathMax(MathAbs(m5Target - closeNow), atr * 0.5);
      g_liqWave.objArrival = false;
      g_liqWave.trueCHoCH = false;
      Print("LIQWAVE ACTIVATED: target=", m5Target, " dir=", g_liqWave.direction);
   }
   
   // Update target if M5 target moves while active
   if(g_liqWave.active && m5Target > 0)
      g_liqWave.target = m5Target;
   
   // Distance compression (100%=at origin, 0%=arrived)
   double remain = 0;
   if(g_liqWave.active && g_liqWave.target > 0)
      remain = MathAbs(g_liqWave.target - closeNow);
   g_liqWave.distPct = (g_liqWave.active && g_liqWave.initDist > 0) ?
      MathMin(100.0, remain / g_liqWave.initDist * 100.0) : 0;
   
   // Physics gates for arrival
   bool capExhaust = (g_erf.dissipationProgress > 60 || g_convMaturitySmoothed > 60);
   bool resolved = (g_erf.resolutionState == RES_RESOLVED);
   bool energyLow = (g_efficiency < InpEffThresh * 0.7);
   bool magnet = (g_liqWave.active && g_liqWave.distPct < 20);
   
   // OBJECTIVE ARRIVAL: Structure ∧ Momentum ∧ Physics simultaneously
   bool arrStruct = (g_liqWave.active && g_liqWave.target > 0 &&
      (g_liqWave.direction == 1 ? closeNow >= g_liqWave.target : closeNow <= g_liqWave.target));
   bool arrPhys = (capExhaust && (resolved || magnet));
   g_liqWave.objArrival = (arrStruct && energyLow && arrPhys);
   
   // TRUE CHANGE OF CHARACTER: never from BOS alone
   bool counterBOS = (g_liqWave.direction == 1) ? 
      (g_structure[TF_M5].bosSignal == -1) : (g_structure[TF_M5].bosSignal == 1);
   g_liqWave.trueCHoCH = (g_liqWave.objArrival && counterBOS && energyLow && resolved);
   
   // Sub-phase from distance compression + physics
   if(!g_liqWave.active)
      g_liqWave.subPhase = "";
   else if(g_liqWave.objArrival)
      g_liqWave.subPhase = "Objective Arrival";
   else if(magnet && energyLow)
      g_liqWave.subPhase = "Terminal Liquidation";
   else if(g_convMaturitySmoothed > 40 || g_erf.dissipationProgress > 40)
      g_liqWave.subPhase = "Induction";
   else if(g_liqWave.distPct < 70)
      g_liqWave.subPhase = "Displacement";
   else if(g_liqWave.distPct < 95)
      g_liqWave.subPhase = "Push";
   else
      g_liqWave.subPhase = "Initialization";


   // Title construction
   int dispDir = g_structure[TF_M5].direction;
   if(!g_liqWave.active)
      g_liqWave.title = "";
   else if(g_liqWave.isRetracement && dispDir == -1)
      g_liqWave.title = "Pre-Supply Return Liquidation Wave";
   else if(g_liqWave.isRetracement)
      g_liqWave.title = "Pre-Demand Return Liquidation Wave";
   else if(dispDir == -1)
      g_liqWave.title = "Pre-New Low Liquidation Wave";
   else
      g_liqWave.title = "Pre-New High Liquidation Wave";
   
   // Retire when canonical phase leaves the induction/liquidity window
   bool inWindow = (g_currentPhase == PHASE_EXP_INDUCTION || 
                    g_currentPhase == PHASE_EXP_LIQUIDITY ||
                    g_currentPhase == PHASE_RETR_INDUCTION || 
                    g_currentPhase == PHASE_RETR_LIQUIDITY);
   
   if(g_liqWave.active && (!inWindow || (g_liqWave.objArrival && g_liqWave.trueCHoCH)))
   {
      g_liqWave.active = false;
      if(g_liqWave.trueCHoCH)
         Print("LIQWAVE COMPLETE: True CHoCH confirmed at target");
   }
   
   // ABSORPTION GATE: unlock only after genuine arrival + CHoCH
   if(g_liqWave.objArrival && g_liqWave.trueCHoCH)
      g_absorbUnlocked = true;
   if(g_currentPhase == PHASE_EXPANSION || g_currentPhase == PHASE_POINT4_ORIGIN)
      g_absorbUnlocked = false;
   
   // UPDATE DISPLAY PHASE with liquidation wave overlay
   if(g_liqWave.active && g_liqWave.title != "")
   {
      g_currentDisplayPhase = g_liqWave.title + " - " + g_liqWave.subPhase;
   }
}

//==================================================================
// 2. EXECUTION INTEGRATION - Liquidation Wave Gates
// These modify execution probability and signal gating
//==================================================================

// Should reversal signals be suppressed? (liq wave active, not yet arrived)
bool LiqWaveSuppressReversal()
{
   return(g_liqWave.active && !g_liqWave.objArrival);
}

// Should reversal be boosted? (objective just arrived)
bool LiqWaveBoostReversal()
{
   return(g_liqWave.objArrival && !g_liqWave.trueCHoCH);
}

// Is absorption label allowed? (only after genuine arrival + CHoCH)
bool IsAbsorptionUnlocked()
{
   return(g_absorbUnlocked);
}

// Get liquidation wave arrival status string
string LiqWaveArrivalStr()
{
   if(!g_liqWave.active) return("Inactive");
   if(g_liqWave.objArrival) return("ARRIVED");
   if(g_liqWave.distPct < 12) return("Imminent");
   return("In Progress " + IntegerToString((int)(100.0 - g_liqWave.distPct)) + "%");
}


//==================================================================
// 3. ENERGY DISPLACEMENT REGISTRY
// Persistently tracks every entry-cycle event so execution knows
// where unresolved energy sits and can use it for decisions
//==================================================================
void SpawnRegistryEvent()
{
   // Only spawn on new wave or recursive cycle
   // Called externally when g_direction changes or recursiveJustFired
   if(g_direction == 0) return;
   
   double closeNow = (ArraySize(Close) > 1) ? Close[1] : 0;
   if(closeNow == 0) return;
   
   // Check for dedup (don't register same price twice)
   double atr = g_physics.atr;
   for(int i = 0; i < g_registryCount; i++)
   {
      if(MathAbs(g_energyRegistry[i].price - closeNow) < atr * 0.3 &&
         g_energyRegistry[i].direction == g_direction)
         return; // already registered nearby
   }
   
   // Evict oldest RESOLVED event if at capacity
   if(g_registryCount >= REGISTRY_MAX)
   {
      int evictIdx = -1;
      int oldestAge = 0;
      for(int i = 0; i < g_registryCount; i++)
      {
         if(g_energyRegistry[i].resolution == 2 && g_energyRegistry[i].birthBar > oldestAge)
         { oldestAge = g_energyRegistry[i].birthBar; evictIdx = i; }
      }
      // If no resolved to evict, evict oldest regardless
      if(evictIdx < 0)
      {
         evictIdx = 0;
         for(int i = 1; i < g_registryCount; i++)
            if(g_energyRegistry[i].birthBar > g_energyRegistry[evictIdx].birthBar)
               evictIdx = i;
      }
      // Shift to remove
      for(int j = evictIdx; j < g_registryCount - 1; j++)
         g_energyRegistry[j] = g_energyRegistry[j+1];
      g_registryCount--;
   }
   
   // Spawn new event
   g_registryTotalSpawned++;
   EnergyEvent ev;
   ev.price = closeNow;
   ev.direction = g_direction;
   ev.birthBar = 0;
   ev.resolution = 0; // unresolved
   ev.peakEnergy = g_erf.expansionEnergy;
   ev.residualEnergy = g_erfResidualEnergy;
   ev.entryCycle = g_entryCycle;
   ev.waveGen = g_waveGeneration;
   g_energyRegistry[g_registryCount] = ev;
   g_registryCount++;
   
   Print("ENERGY EVENT #", g_registryTotalSpawned, " spawned @ ", closeNow, 
         " dir=", g_direction, " cycle=", g_entryCycle);
}

//==================================================================
// 4. REGISTRY UPDATE (age + resolution state tracking)
//==================================================================
void UpdateEnergyRegistry()
{
   if(g_registryCount <= 0) return;
   double atr = g_physics.atr;
   if(atr <= 0) return;
   double closeNow = (ArraySize(Close) > 1) ? Close[1] : 0;
   if(closeNow == 0) return;
   
   g_nearestUnresolvedIdx = -1;
   g_nearestUnresolvedPrice = 0;
   g_nearestUnresolvedDist = 99999999;
   g_unresolvedCount = 0;
   
   for(int i = 0; i < g_registryCount; i++)
   {
      EnergyEvent *ev = GetPointer(g_energyRegistry[i]);
      ev.birthBar++;
      
      // Update residual energy (decays with age)
      ev.residualEnergy = MathMax(0, ev.peakEnergy - ev.birthBar * 0.5);
      
      // Resolution: check if price has returned and resolved this level
      double dist = MathAbs(closeNow - ev.price);
      
      if(ev.resolution < 2)
      {
         // Partial resolution: price came within 1 ATR
         if(dist < atr * 1.0 && ev.resolution == 0)
            ev.resolution = 1;
         
         // Full resolution: price closed through the level with impulse
         if(ev.direction == 1 && closeNow < ev.price - atr * 0.3)
            ev.resolution = 2;
         if(ev.direction == -1 && closeNow > ev.price + atr * 0.3)
            ev.resolution = 2;
         
         // Also resolve if ERF says RESOLVED and we're near the level
         if(g_erf.resolutionState == RES_RESOLVED && dist < atr * 2.0)
            ev.resolution = 2;
      }
      
      // Track nearest unresolved for execution decisions
      if(ev.resolution < 2)
      {
         g_unresolvedCount++;
         if(dist < g_nearestUnresolvedDist)
         {
            g_nearestUnresolvedDist = dist;
            g_nearestUnresolvedPrice = ev.price;
            g_nearestUnresolvedIdx = i;
         }
      }
   }
}


//==================================================================
// 5. REGISTRY EXECUTION INTEGRATION
// Provides actionable signals based on unresolved energy positions
//==================================================================

// Is price approaching an unresolved energy level? (potential reaction zone)
bool IsNearUnresolvedEnergy()
{
   if(g_nearestUnresolvedIdx < 0) return(false);
   double atr = g_physics.atr;
   return(g_nearestUnresolvedDist < atr * 1.5);
}

// Should we expect a return to an unresolved level? (energy attractor)
bool UnresolvedEnergyPulling()
{
   if(g_unresolvedCount == 0) return(false);
   if(g_nearestUnresolvedIdx < 0) return(false);
   // High residual energy at unresolved level = strong pull
   return(g_energyRegistry[g_nearestUnresolvedIdx].residualEnergy > 30.0);
}

// Get the dominant unresolved target price (for TP/destination)
double GetUnresolvedTarget()
{
   if(g_nearestUnresolvedIdx < 0) return(0);
   return(g_nearestUnresolvedPrice);
}

// Get registry summary for dashboard
string RegistrySummary()
{
   int resolved = 0, partial = 0, unresolved = 0;
   for(int i = 0; i < g_registryCount; i++)
   {
      if(g_energyRegistry[i].resolution == 2) resolved++;
      else if(g_energyRegistry[i].resolution == 1) partial++;
      else unresolved++;
   }
   return(StringFormat("Total:%d Unres:%d Part:%d Res:%d", 
          g_registryCount, unresolved, partial, resolved));
}

//==================================================================
// MASTER LIQUIDATION + REGISTRY UPDATE
//==================================================================
void UpdateLiqWaveAndRegistry()
{
   // 1. Liquidation wave state machine
   UpdateLiquidationWave();
   
   // 2. Energy registry age + resolution tracking
   UpdateEnergyRegistry();
}

// Called from wave spawn engine when a new wave/cycle fires
void OnNewWaveOrCycle()
{
   SpawnRegistryEvent();
}

//+------------------------------------------------------------------+
