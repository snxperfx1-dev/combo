//+------------------------------------------------------------------+
//| FALCON_Scheduler.mqh                                              |
//| FALCON OS - Kernel: Scheduler (deterministic pipeline)            |
//|                                                                   |
//| Runs exactly one deterministic sequence per new candle, matching  |
//| the master pipeline. Each stage updates shared state then         |
//| publishes its completion event. Nothing calculates twice.         |
//|                                                                   |
//| Forward-declares the module stage functions (defined in modules). |
//+------------------------------------------------------------------+
#property strict

//==================================================================
// MODULE STAGE FUNCTION DECLARATIONS
// Defined in their respective module files. The scheduler calls
// them in strict order. (MQL5 resolves these at compile/link.)
//==================================================================
// Module 1 - Core Market
void M1_UpdatePhysics();
void M1_UpdateStructure();
void M1_UpdateLiquidity();
void M1_UpdateConvexity();
void M1_UpdateWave();
void M1_UpdateHTF();
void M1_UpdateFU();
// Module 2 - Memory
void M2_UpdateMemory();
void M2_UpdateNetwork();
void M2_UpdateCampaign();
// Module 3 - Intelligence + Decision
void M3_UpdateBelief();
void M3_UpdateHypothesis();
void M3_UpdatePrediction();
void M3_UpdateValidation();
void M3_UpdateOpportunity();
void M3_UpdateThreat();
void M3_UpdateIntent();
void M3_MakeDecision();
// Module 4 - Execution
void M4_UpdateRisk();
void M4_Execute();
// Module 5 - Visualization
void M5_Visualize();


//==================================================================
// THE MASTER PIPELINE — runs once per new candle, in fixed order.
// Each stage: update shared state -> publish event -> next stage.
// Per-module timing recorded for diagnostics.
//==================================================================
void FALCON_RunPipeline()
{
   FALCON_PipelineStart();

   //--- New candle event
   FALCON_Publish(EVT_NEW_CANDLE);

   //=== MARKET LAYER (Module 1) ===
   FALCON_TimerStart();
   M1_UpdatePhysics();    FALCON_Publish(EVT_PHYSICS_UPDATED);
   M1_UpdateStructure();  FALCON_Publish(EVT_STRUCTURE_UPDATED);
   M1_UpdateLiquidity();  FALCON_Publish(EVT_LIQUIDITY_UPDATED);
   M1_UpdateConvexity();  FALCON_Publish(EVT_CONVEXITY_UPDATED);
   M1_UpdateWave();       FALCON_Publish(EVT_WAVE_UPDATED);
   M1_UpdateHTF();
   M1_UpdateFU();
   FALCON_RecordModuleTime(0, FALCON_TimerElapsed());

   //=== MEMORY LAYER (Module 2) ===
   FALCON_TimerStart();
   M2_UpdateMemory();     FALCON_Publish(EVT_MEMORY_UPDATED);
   M2_UpdateNetwork();    FALCON_Publish(EVT_NETWORK_UPDATED);
   M2_UpdateCampaign();   FALCON_Publish(EVT_CAMPAIGN_UPDATED);
   FALCON_RecordModuleTime(1, FALCON_TimerElapsed());

   //=== INTELLIGENCE LAYER (Module 3) ===
   FALCON_TimerStart();
   M3_UpdateBelief();     FALCON_Publish(EVT_BELIEF_UPDATED);
   M3_UpdateHypothesis(); FALCON_Publish(EVT_HYPOTHESIS_UPDATED);
   M3_UpdatePrediction(); FALCON_Publish(EVT_PREDICTION_UPDATED);
   M3_UpdateValidation(); FALCON_Publish(EVT_VALIDATION_UPDATED);
   M3_UpdateOpportunity();FALCON_Publish(EVT_OPPORTUNITY_UPDATED);
   M3_UpdateThreat();     FALCON_Publish(EVT_THREAT_UPDATED);
   M3_UpdateIntent();     FALCON_Publish(EVT_INTENT_UPDATED);
   FALCON_RecordModuleTime(2, FALCON_TimerElapsed());

   //=== DECISION LAYER (Module 3 head) ===
   FALCON_TimerStart();
   M3_MakeDecision();     FALCON_Publish(EVT_DECISION_MADE);
   FALCON_RecordModuleTime(3, FALCON_TimerElapsed());

   //=== EXECUTION LAYER (Module 4) ===
   FALCON_TimerStart();
   M4_UpdateRisk();
   M4_Execute();          FALCON_Publish(EVT_EXECUTION_DONE);
   FALCON_RecordModuleTime(4, FALCON_TimerElapsed());

   //=== VISUALIZATION LAYER (Module 5) ===
   FALCON_TimerStart();
   M5_Visualize();        FALCON_Publish(EVT_VISUAL_DONE);
   FALCON_RecordModuleTime(5, FALCON_TimerElapsed());

   //--- health + timing
   FALCON_RunHealthChecks();
   gState.diag.pipelineMicros = FALCON_PipelineElapsed();
   gState.diag.barsProcessed++;
}

//+------------------------------------------------------------------+
