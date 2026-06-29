//+------------------------------------------------------------------+
//|  FALCON OS — Intelligence Layer : MemoryEngine.mqh              |
//|  Source: F16 Raptor (Invisible Network)                         |
//|                                                                  |
//|  The OS REMEMBERS. It maintains the node registry across         |
//|  timeframes, scores authority, ages nodes into dormancy/history, |
//|  tracks revisits (conversation weight), measures campaign         |
//|  ownership + participant pressure, and resolves curve-tree        |
//|  ownership. Writes g_state.{network,curve,campaign,participants}. |
//+------------------------------------------------------------------+
#ifndef FALCON_MEMORY_ENGINE_MQH
#define FALCON_MEMORY_ENGINE_MQH

#include "../Kernel/FalconState.mqh"
#include "../Kernel/FalconConfig.mqh"
#include "../Kernel/FalconSeries.mqh"
#include "../Kernel/FalconEventBus.mqh"

//==================================================================
// PERSISTENT NODE REGISTRY (mirrors F16 nPx/nMid/nDir/... arrays)
//==================================================================
double mem_px[FALCON_MAX_NODES];
double mem_mid[FALCON_MAX_NODES];
int    mem_dir[FALCON_MAX_NODES];
double mem_score[FALCON_MAX_NODES];
int    mem_weight[FALCON_MAX_NODES];
int    mem_state[FALCON_MAX_NODES];   // 0 active,1 dormant,2 broken,3 historical
int    mem_birth[FALCON_MAX_NODES];
int    mem_rev[FALCON_MAX_NODES];
int    mem_count=0;

// last seen FU tip per timeframe rung (dedup)
double mem_lastTip[7];

void MemoryEngineInit()
{
   mem_count=0;
   for(int i=0;i<7;i++) mem_lastTip[i]=0.0;
}

//------------------------------------------------------------------
// Node authority = base score + timeframe weight + revisit memory
//------------------------------------------------------------------
double MEM_Auth(const int i)
{
   return(mem_score[i] + mem_weight[i]*4.0 + mem_rev[i]*3.0);
}

void MEM_AddNode(const double tip, const double mid, const int dir, const double sc, const int wt)
{
   if(mem_count>=FALCON_MAX_NODES)
   {
      for(int i=1;i<FALCON_MAX_NODES;i++)
      {
         mem_px[i-1]=mem_px[i]; mem_mid[i-1]=mem_mid[i]; mem_dir[i-1]=mem_dir[i];
         mem_score[i-1]=mem_score[i]; mem_weight[i-1]=mem_weight[i];
         mem_state[i-1]=mem_state[i]; mem_birth[i-1]=mem_birth[i]; mem_rev[i-1]=mem_rev[i];
      }
      mem_count=FALCON_MAX_NODES-1;
   }
   mem_px[mem_count]=tip; mem_mid[mem_count]=mid; mem_dir[mem_count]=dir;
   mem_score[mem_count]=sc; mem_weight[mem_count]=wt; mem_state[mem_count]=0;
   mem_birth[mem_count]=g_barCounter; mem_rev[mem_count]=0;
   mem_count++;
   FalconPublish(EVT_NODE_BORN, tip);
}

//------------------------------------------------------------------
// Scan each fixed timeframe for a fresh FU node and register it.
// weights: M1=3 M5=4 M15=5 M30=6(approx H1) H1=5... we follow F16's
// MN..M1 weighting scaled to our 7 rungs (higher TF => higher wt).
//------------------------------------------------------------------
void MEM_ScanTF(const ENUM_TIMEFRAMES tf, const int rung, const int wt)
{
   int lb = g_cfg.fuLookback;
   int need = lb*2+20;
   double h[],l[],o[],c[];
   ArraySetAsSeries(h,true); ArraySetAsSeries(l,true);
   ArraySetAsSeries(o,true); ArraySetAsSeries(c,true);
   if(CopyHigh(_Symbol,tf,0,need,h)<need) return;
   if(CopyLow (_Symbol,tf,0,need,l)<need) return;
   if(CopyOpen(_Symbol,tf,0,need,o)<need) return;
   if(CopyClose(_Symbol,tf,0,need,c)<need) return;

   double rng=MathMax(h[1]-l[1],1e-10);
   double pHi=-DBL_MAX,pLo=DBL_MAX;
   for(int i=2;i<2+lb;i++){ if(h[i]>pHi)pHi=h[i]; if(l[i]<pLo)pLo=l[i]; }
   double locHi=-DBL_MAX,locLo=DBL_MAX;
   for(int i=1;i<1+lb;i++){ if(h[i]>locHi)locHi=h[i]; if(l[i]<locLo)locLo=l[i]; }

   double uw=(h[1]-MathMax(o[1],c[1]))/rng;
   double lw=(MathMin(o[1],c[1])-l[1])/rng;
   bool bear = uw>=g_cfg.wickFrac && ((h[1]>=pHi && c[1]<pHi)||(h[1]>=locHi && c[1]<o[1]));
   bool bull = lw>=g_cfg.wickFrac && ((l[1]<=pLo && c[1]>pLo)||(l[1]<=locLo && c[1]>o[1]));

   double tip=0,mid=0; int dir=0;
   if(bear){ dir=-1; tip=h[1]; double bH=MathMax(o[1],c[1]); mid=bH+(tip-bH)*0.5; }
   else if(bull){ dir=1; tip=l[1]; double bL=MathMin(o[1],c[1]); mid=tip+(bL-tip)*0.5; }

   if(dir!=0 && tip!=mem_lastTip[rung])
   {
      double wk = (dir==-1)?(tip-MathMax(o[1],c[1]))/MathMax(h[1]-l[1],1e-10):
                            (MathMin(o[1],c[1])-tip)/MathMax(h[1]-l[1],1e-10);
      double sc = FalconClamp(20.0+MathMin(25.0,wk*15.0)+(wk>1.0?15.0:0.0)+(wk>1.5?10.0:0.0),0,100);
      MEM_AddNode(tip,mid,dir,sc,wt);
      mem_lastTip[rung]=tip;
   }
}

//------------------------------------------------------------------
// Age every node: break/dormant/historical + revisit counting.
//------------------------------------------------------------------
void MEM_AgeNodes()
{
   double atr = g_state.physics.atr;
   double close1=gClose[1];
   for(int i=0;i<mem_count;i++)
   {
      if(mem_state[i]==2) continue;
      double np=mem_px[i];
      int    nd=mem_dir[i];
      int    age=g_barCounter-mem_birth[i];
      bool broken=(nd==-1 ? close1>np : close1<np);
      if(broken){ mem_state[i]=2; FalconPublish(EVT_NODE_BROKEN,np); continue; }
      if(MathAbs(close1-np)<atr*0.25) mem_rev[i]++;
      int wt=mem_weight[i];
      mem_state[i] = (age>g_cfg.historyBars*wt ? 3 : age>g_cfg.dormantBars*wt ? 1 : 0);
   }
}

//------------------------------------------------------------------
// Network bias / pressure / authority + nearest attractor.
//------------------------------------------------------------------
void MEM_ComputeNetwork()
{
   FalconNetwork n;
   double close1=gClose[1];
   double bullAuth=0, bearAuth=0;
   int live=0;
   double nearestDist=DBL_MAX; int nearestIdx=-1;

   // export capped active node set into state arrays
   n.count=0;
   for(int i=0;i<mem_count && n.count<FALCON_MAX_NODES;i++)
   {
      n.px[n.count]=mem_px[i]; n.mid[n.count]=mem_mid[i]; n.dir[n.count]=mem_dir[i];
      n.score[n.count]=mem_score[i]; n.weight[n.count]=mem_weight[i];
      n.nstate[n.count]=mem_state[i]; n.birthBar[n.count]=mem_birth[i]; n.revisits[n.count]=mem_rev[i];
      n.count++;

      if(mem_state[i]!=2 && MEM_Auth(i)>=g_cfg.authMin)
      {
         live++;
         if(mem_dir[i]==1) bullAuth+=MEM_Auth(i); else if(mem_dir[i]==-1) bearAuth+=MEM_Auth(i);
         double d=MathAbs(close1-mem_px[i]);
         if(d<nearestDist){ nearestDist=d; nearestIdx=i; }
      }
   }

   double pressure = (bullAuth+bearAuth>0)?(bullAuth-bearAuth)/(bullAuth+bearAuth)*100.0:0.0;
   n.bullAuthority=bullAuth; n.bearAuthority=bearAuth;
   n.pressure=pressure;
   n.pressureDir=(pressure>12?DIR_LONG:pressure<-12?DIR_SHORT:DIR_NONE);
   n.liveCount=live;
   n.nearestAttractorIdx=nearestIdx;

   // network bias: highest-weight unbroken node's direction (HTF priority)
   int bias=DIR_NONE, bestWt=-1;
   for(int i=0;i<mem_count;i++)
      if(mem_state[i]!=2 && mem_weight[i]>bestWt){ bestWt=mem_weight[i]; bias=mem_dir[i]; }
   if(bias==DIR_NONE) bias=n.pressureDir;
   n.bias=bias;

   g_state.network=n;
}

//------------------------------------------------------------------
// Curve tree ownership (who owns price, life, energy, evolution).
//------------------------------------------------------------------
void MEM_ComputeCurve()
{
   FalconCurve c;
   FalconWave w=g_state.wave;
   FalconHTF  h=g_state.htf;

   c.ownerDir    = (h.stackDir!=DIR_NONE ? h.stackDir : w.direction);
   c.ownerOrigin = w.origin;
   c.ownerExtreme= w.extreme;
   c.rootDir     = h.stackDir;
   c.emergentPhase = w.phase;
   c.childCount  = w.entryCycle;
   c.evolution   = w.dominanceTransfer;
   // life: how much of the curve has been spent (progress) inverted by residual energy
   c.life        = FalconClamp(100.0 - w.completion*0.6 - g_state.physics.compression*0.4,0,100);
   c.energy      = w.energy;

   g_state.curve=c;
}

//------------------------------------------------------------------
// Campaign ownership (dominant institutional side + control score).
//------------------------------------------------------------------
int mem_campOwner=0; int mem_campStart=0;

void MEM_ComputeCampaign()
{
   FalconCampaign cm;
   FalconHTF h=g_state.htf;
   FalconNetwork n=g_state.network;

   // control derives from fractal alignment + network pressure agreement
   int side = h.stackDir;
   double control = h.alignment;
   if(n.pressureDir==side && side!=DIR_NONE) control = MathMin(100.0, control+15.0);

   if(side!=mem_campOwner && side!=DIR_NONE){ mem_campOwner=side; mem_campStart=g_barCounter; }

   cm.owner=mem_campOwner;
   cm.controlScore=FalconClamp(control,0,100);
   cm.objectiveDir=mem_campOwner;
   cm.remainingEnergy=g_state.intel.residualEnergy; // filled later by intel; safe default
   cm.age=g_barCounter-mem_campStart;
   cm.institution=(mem_campOwner==DIR_LONG?"Accumulation":mem_campOwner==DIR_SHORT?"Distribution":"Neutral");

   g_state.campaign=cm;
}

//------------------------------------------------------------------
// Participant engine (buyer/seller/passive/aggressive pressure).
//------------------------------------------------------------------
void MEM_ComputeParticipants()
{
   FalconParticipants p;
   FalconPhysics ph=g_state.physics;
   FalconLiquidity lq=g_state.liquidity;

   double bullForce = (ph.velocity>0? MathMin(MathAbs(ph.velocity)/MathMax(ph.atr*0.15,1e-10)*100.0,100.0):0.0);
   double bearForce = (ph.velocity<0? MathMin(MathAbs(ph.velocity)/MathMax(ph.atr*0.15,1e-10)*100.0,100.0):0.0);
   p.buyer  = FalconClamp(bullForce*0.6 + (lq.pressure>0?lq.pressure*0.4:0.0),0,100);
   p.seller = FalconClamp(bearForce*0.6 + (lq.pressure<0?-lq.pressure*0.4:0.0),0,100);
   p.aggressive = FalconClamp(ph.expansion,0,100);
   p.passive    = FalconClamp(100.0-ph.expansion,0,100);
   p.interference = FalconClamp(MathAbs(p.buyer-p.seller)<20?60.0:20.0,0,100);
   p.participationScore = FalconClamp((p.buyer+p.seller)/2.0,0,100);
   p.marketPressure = p.buyer - p.seller;

   g_state.participants=p;
}

//==================================================================
// MASTER ENTRY — Memory Engine pipeline step
//==================================================================
void MemoryEngineRun()
{
   // scan fixed timeframe ladder for fresh nodes (HTF heavier weight)
   MEM_ScanTF(PERIOD_H4, 5, 6);
   MEM_ScanTF(PERIOD_H1, 4, 5);
   MEM_ScanTF(PERIOD_M30,3, 5);
   MEM_ScanTF(PERIOD_M15,2, 4);
   MEM_ScanTF(PERIOD_M5, 1, 3);
   MEM_ScanTF(PERIOD_M1, 0, 3);

   MEM_AgeNodes();
   MEM_ComputeNetwork();
   MEM_ComputeCurve();
   MEM_ComputeCampaign();
   MEM_ComputeParticipants();
}

#endif // FALCON_MEMORY_ENGINE_MQH
//+------------------------------------------------------------------+
