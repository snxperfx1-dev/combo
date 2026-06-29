//+------------------------------------------------------------------+
//| FALCON_EventBus.mqh                                               |
//| FALCON OS - Kernel: Event Bus (publish/subscribe)                 |
//|                                                                   |
//| Modules react to events instead of polling. Each pipeline stage   |
//| publishes a completion event; downstream modules subscribe.       |
//| Lightweight: a fixed event registry with handler dispatch.        |
//+------------------------------------------------------------------+
#property strict

//==================================================================
// EVENT TYPES (one per pipeline stage + lifecycle events)
//==================================================================
enum FALCON_Event
{
   EVT_NEW_CANDLE = 0,
   EVT_PHYSICS_UPDATED,
   EVT_STRUCTURE_UPDATED,
   EVT_LIQUIDITY_UPDATED,
   EVT_CONVEXITY_UPDATED,
   EVT_WAVE_UPDATED,
   EVT_MEMORY_UPDATED,
   EVT_NETWORK_UPDATED,
   EVT_CAMPAIGN_UPDATED,
   EVT_BELIEF_UPDATED,
   EVT_HYPOTHESIS_UPDATED,
   EVT_PREDICTION_UPDATED,
   EVT_VALIDATION_UPDATED,
   EVT_OPPORTUNITY_UPDATED,
   EVT_THREAT_UPDATED,
   EVT_INTENT_UPDATED,
   EVT_DECISION_MADE,
   EVT_EXECUTION_DONE,
   EVT_VISUAL_DONE,
   EVT_ENTRY_FIRED,
   EVT_EXIT_FIRED,
   EVT_RISK_BREACH,
   EVT_COUNT
};

// Event counters for diagnostics
int g_evtPublishCount[EVT_COUNT];
int g_evtTotalPublished = 0;
int g_evtTotalHandled = 0;


//==================================================================
// SUBSCRIBER REGISTRY
// Each event can have up to MAX_SUBS handlers. Handlers are
// registered by name (for diagnostics) and dispatched in order.
// In MQL5 we use a typedef function pointer for handlers.
//==================================================================
#define MAX_SUBS_PER_EVENT 8

typedef void (*FALCON_Handler)();

FALCON_Handler g_handlers[EVT_COUNT][MAX_SUBS_PER_EVENT];
string         g_handlerNames[EVT_COUNT][MAX_SUBS_PER_EVENT];
int            g_handlerCount[EVT_COUNT];

//--- Event name (for logging)
string FALCON_EventName(FALCON_Event e)
{
   switch(e)
   {
      case EVT_NEW_CANDLE:        return("NewCandle");
      case EVT_PHYSICS_UPDATED:   return("Physics");
      case EVT_STRUCTURE_UPDATED: return("Structure");
      case EVT_LIQUIDITY_UPDATED: return("Liquidity");
      case EVT_CONVEXITY_UPDATED: return("Convexity");
      case EVT_WAVE_UPDATED:      return("Wave");
      case EVT_MEMORY_UPDATED:    return("Memory");
      case EVT_NETWORK_UPDATED:   return("Network");
      case EVT_CAMPAIGN_UPDATED:  return("Campaign");
      case EVT_BELIEF_UPDATED:    return("Belief");
      case EVT_HYPOTHESIS_UPDATED:return("Hypothesis");
      case EVT_PREDICTION_UPDATED:return("Prediction");
      case EVT_VALIDATION_UPDATED:return("Validation");
      case EVT_OPPORTUNITY_UPDATED:return("Opportunity");
      case EVT_THREAT_UPDATED:    return("Threat");
      case EVT_INTENT_UPDATED:    return("Intent");
      case EVT_DECISION_MADE:     return("Decision");
      case EVT_EXECUTION_DONE:    return("Execution");
      case EVT_VISUAL_DONE:       return("Visual");
      case EVT_ENTRY_FIRED:       return("EntryFired");
      case EVT_EXIT_FIRED:        return("ExitFired");
      case EVT_RISK_BREACH:       return("RiskBreach");
      default:                    return("Unknown");
   }
}

//==================================================================
// SUBSCRIBE: register a handler for an event
//==================================================================
void FALCON_Subscribe(FALCON_Event e, FALCON_Handler handler, string name)
{
   int c = g_handlerCount[e];
   if(c >= MAX_SUBS_PER_EVENT) return;
   g_handlers[e][c] = handler;
   g_handlerNames[e][c] = name;
   g_handlerCount[e] = c + 1;
}

//==================================================================
// PUBLISH: fire an event, dispatch to all subscribers in order
//==================================================================
void FALCON_Publish(FALCON_Event e)
{
   g_evtPublishCount[e]++;
   g_evtTotalPublished++;
   gState.diag.eventsPublished = g_evtTotalPublished;

   int c = g_handlerCount[e];
   for(int i = 0; i < c; i++)
   {
      if(g_handlers[e][i] != NULL)
      {
         g_handlers[e][i]();
         g_evtTotalHandled++;
      }
   }
   gState.diag.eventsHandled = g_evtTotalHandled;
}

//--- Reset bus (kernel boot)
void FALCON_ResetEventBus()
{
   for(int e = 0; e < EVT_COUNT; e++)
   {
      g_handlerCount[e] = 0;
      g_evtPublishCount[e] = 0;
   }
   g_evtTotalPublished = 0;
   g_evtTotalHandled = 0;
}

//+------------------------------------------------------------------+
