//+------------------------------------------------------------------+
//|  FALCON OS — Kernel : FalconEventBus.mqh                         |
//|  Lightweight publish/subscribe event bus.                       |
//|                                                                  |
//|  Modules emit events instead of calling each other directly.    |
//|  The pipeline (Scheduler) runs deterministically, but engines    |
//|  raise semantic events (impulse fired, node born, verdict        |
//|  changed, order sent...) that any module can react to without    |
//|  a hard dependency. New engines plug in by subscribing.          |
//+------------------------------------------------------------------+
#ifndef FALCON_EVENTBUS_MQH
#define FALCON_EVENTBUS_MQH

//==================================================================
// EVENT TYPES
//==================================================================
enum FALCON_EVENT
{
   EVT_NONE = 0,
   EVT_NEW_BAR,
   EVT_IMPULSE_BULL,
   EVT_IMPULSE_BEAR,
   EVT_BOS,
   EVT_CHOCH,
   EVT_WAVE_SPAWN,
   EVT_PHASE_CHANGE,
   EVT_NODE_BORN,
   EVT_NODE_BROKEN,
   EVT_LIQ_SWEEP,
   EVT_RESOLUTION_CHANGE,
   EVT_VERDICT_CHANGE,
   EVT_ORDER_SENT,
   EVT_ORDER_FAILED,
   EVT_EXIT_FIRED,
   EVT_RISK_BREACH,
   EVT_TRIM
};

struct FalconEvent
{
   int      type;
   datetime time;
   double   value;     // generic numeric payload (price, score, dir...)
   string   note;
};

//==================================================================
// RING BUFFER of recent events (diagnostics + late subscribers)
//==================================================================
#define FALCON_EVT_RING 128

struct FalconEventBus
{
   FalconEvent ring[FALCON_EVT_RING];
   int         head;
   int         total;
   // per-type counters for diagnostics
   int         counts[32];
};

FalconEventBus g_bus;

//==================================================================
// SUBSCRIBERS — real publish/subscribe. Modules register a handler
// for an event type (or EVT_NONE = all). FalconPublish dispatches
// synchronously so reactions are deterministic within the bar.
//==================================================================
typedef void (*FalconEventHandler)(const FalconEvent &e);
#define FALCON_MAX_SUBS 32
struct FalconSub { int type; FalconEventHandler handler; };
FalconSub g_subs[FALCON_MAX_SUBS];
int       g_subCount=0;

void FalconSubscribe(const int type, FalconEventHandler h)
{
   if(g_subCount<FALCON_MAX_SUBS){ g_subs[g_subCount].type=type; g_subs[g_subCount].handler=h; g_subCount++; }
}

void FalconBusInit()
{
   g_bus.head  = 0;
   g_bus.total = 0;
   g_subCount  = 0;
   for(int i=0;i<32;i++) g_bus.counts[i]=0;
   for(int i=0;i<FALCON_EVT_RING;i++)
   {
      g_bus.ring[i].type = EVT_NONE;
      g_bus.ring[i].note = "";
      g_bus.ring[i].value= 0.0;
      g_bus.ring[i].time = 0;
   }
}

//------------------------------------------------------------------
// Publish an event: store in the ring, count it, and DISPATCH to any
// registered subscribers (pub/sub). Modules react to events instead
// of polling; dispatch is synchronous to stay deterministic.
//------------------------------------------------------------------
void FalconPublish(const int type, const double value=0.0, const string note="")
{
   FalconEvent e;
   e.type  = type;
   e.time  = TimeCurrent();
   e.value = value;
   e.note  = note;

   g_bus.ring[g_bus.head] = e;
   g_bus.head = (g_bus.head + 1) % FALCON_EVT_RING;
   g_bus.total++;
   if(type>=0 && type<32) g_bus.counts[type]++;

   for(int i=0;i<g_subCount;i++)
      if(g_subs[i].type==type || g_subs[i].type==EVT_NONE)
         g_subs[i].handler(e);
}

//------------------------------------------------------------------
// Did an event of this type fire since the given total marker?
// Engines snapshot g_bus.total at pipeline start, then query.
//------------------------------------------------------------------
bool FalconEventFiredSince(const int type, const int sinceTotal)
{
   int n = MathMin(g_bus.total - sinceTotal, FALCON_EVT_RING);
   for(int k=1;k<=n;k++)
   {
      int idx = (g_bus.head - k + FALCON_EVT_RING) % FALCON_EVT_RING;
      if(g_bus.ring[idx].type == type) return(true);
   }
   return(false);
}

int FalconEventCount(const int type)
{
   if(type>=0 && type<32) return(g_bus.counts[type]);
   return(0);
}

#endif // FALCON_EVENTBUS_MQH
//+------------------------------------------------------------------+
