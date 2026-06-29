//+------------------------------------------------------------------+
//|  FALCON OS — MODULE 2: MEMORY ENGINE                            |
//|  Source: F16.                                                    |
//|  Invisible Network (nodes · authority · dormancy · revisits ·   |
//|  FEZ · pressure) · F72 Curve Object · Recursive Curve Tree ·    |
//|  Campaign Ownership · Participant Engine.                        |
//|  The Memory Engine REMEMBERS — it does not decide or execute.   |
//+------------------------------------------------------------------+
#ifndef FALCON_MEMORY_MQH
#define FALCON_MEMORY_MQH
#include "Kernel.mqh"

// TF index -> network node weight (M1=1 .. H4=6)
int MEM_Weight(int idx){ return(idx+1); }

double g_prevFUTip[FAL_TF_COUNT];

//==================================================================
// INVISIBLE NETWORK
//==================================================================
void MEM_NodeAdd(FAL_Network &n,double tip,double mid,int dir,double score,int wt)
  {
   if(n.count>=FAL_NODE_MAX)
     {
      // shift out oldest
      for(int i=0;i<FAL_NODE_MAX-1;i++)
        {
         n.px[i]=n.px[i+1]; n.mid[i]=n.mid[i+1]; n.dir[i]=n.dir[i+1];
         n.score[i]=n.score[i+1]; n.wt[i]=n.wt[i+1]; n.state[i]=n.state[i+1];
         n.bar[i]=n.bar[i+1]; n.revisits[i]=n.revisits[i+1];
        }
      n.count=FAL_NODE_MAX-1;
     }
   int k=n.count;
   n.px[k]=tip; n.mid[k]=mid; n.dir[k]=dir; n.score[k]=score; n.wt[k]=wt;
   n.state[k]=0; n.bar[k]=iTime(_Symbol,_Period,0); n.revisits[k]=0;
   n.count++;
  }

double MEM_Auth(FAL_Network &n,int i)
  {
   return(n.score[i] + n.wt[i]*4.0 + n.revisits[i]*3.0);
  }

void MEM_Network(FAL_Network &n)
  {

   // ── add nodes from newly-validated multi-TF FU pools ──────────
   for(int idx=0;idx<FAL_TF_COUNT;idx++)
     {
      if(g_state.fu.valid[idx] && g_state.fu.tip[idx]!=EMPTY_VALUE)
        {
         double tip=g_state.fu.tip[idx];
         if(tip!=g_prevFUTip[idx])
           {
            MEM_NodeAdd(n,tip,tip,g_state.fu.dir[idx],g_state.fu.score[idx],MEM_Weight(idx));
            g_prevFUTip[idx]=tip;
           }
        }
     }

   double close=g_state.spot;
   double atr=g_state.physics.atr; if(atr<=0) atr=_Point*10;

   // ── aging / dormancy / consumption / revisits ─────────────────
   datetime now=iTime(_Symbol,_Period,0);
   for(int i=0;i<n.count;i++)
     {
      if(n.state[i]==2) continue;
      double np=n.px[i]; int nd=n.dir[i];
      int age=(int)((now-n.bar[i])/MathMax(PeriodSeconds(_Period),1));
      if((nd==-1 && close>np) || (nd==1 && close<np)) { n.state[i]=2; continue; }
      if(MathAbs(close-np)<atr*0.25) n.revisits[i]++;
      int wtn=n.wt[i];
      n.state[i] = (age>g_cfg.historyBars*wtn)?3:(age>g_cfg.dormantBars*wtn?1:0);
     }

   // ── network bias = highest-TF valid FU dir, else EMA50 ────────
   int nb=0;
   for(int idx=FAL_TF_COUNT-1;idx>=0;idx--){ if(g_state.fu.valid[idx]){ nb=g_state.fu.dir[idx]; break; } }
   if(nb==0)
     {
      double e[]; ArraySetAsSeries(e,true);
      double ema=close;
      if(CopyClose(_Symbol,_Period,0,60,e)>0)
        { ema=e[1]; double a=2.0/51.0; for(int i=50;i>=1;i--) ema=ema+a*(e[i]-ema); }
      nb = close>ema?1:(close<ema?-1:0);
     }
   n.bias=nb;

   // ── authority tally · pressure · FEZ · dominant attractor ─────
   double bullAuth=0,bearAuth=0,domAuth=0,attrRank=-1,fezHiA=0,fezLoA=0;
   int elig=0,domIdx=-1,attrIdx=-1; double fezHi=EMPTY_VALUE,fezLo=EMPTY_VALUE;
   for(int i=0;i<n.count;i++)
     {
      if(n.state[i]==2) continue;
      double a=MEM_Auth(n,i);
      if(a<g_cfg.nodeAuthMin) continue;
      elig++;
      double np=n.px[i]; int nd=n.dir[i]; int wt=n.wt[i];
      if(nd==1) bullAuth+=a; else if(nd==-1) bearAuth+=a;
      if(a>domAuth){ domAuth=a; domIdx=i; }
      bool onBias = (nb==-1)?(np<close):(np>close);
      if(onBias){ double rk=wt*1000.0+a; if(rk>attrRank){ attrRank=rk; attrIdx=i; } }
      if(np>close && a>fezHiA){ fezHi=np; fezHiA=a; }
      if(np<close && a>fezLoA){ fezLo=np; fezLoA=a; }
     }
   n.eligible=elig;
   n.pressure=(bullAuth+bearAuth)>0?(bullAuth-bearAuth)/(bullAuth+bearAuth)*100.0:0.0;
   n.fezHi=fezHi; n.fezLo=fezLo;
   n.attractorIdx=attrIdx;
   n.attractorScore=attrIdx>=0?MEM_Auth(n,attrIdx):0.0;
  }

//==================================================================
// F72 CURVE OBJECT + RECURSIVE CURVE TREE
//==================================================================
#define MEM_TREE_MAX 60
struct MEM_Node { int id,parent,dir,depth,srcTf; double origin,extreme,energy,comp,mat; bool alive; string state; };
MEM_Node g_tree[MEM_TREE_MAX]; int g_treeN=0; int g_nodeSeq=0;

string MEM_NodeState(int d,double e,int dep,double cmp,double mat)
  {
   if(dep>0)
      return(e>=70.0?"Transition · recursive expansion":e>=40.0?"Transition · recursive induction":"Transition · recursive liquidation");
   if(mat<12.0) return("Point 4 Origin");
   if(e>=78.0 && mat>=70.0) return(d==1?"New High":d==-1?"New Low":"Climax");
   if(mat<35.0) return("Expansion");
   if(mat<55.0) return("Expansion Pre-Convexity");
   if(e>=55.0) return("Expansion Induction");
   if(e>=35.0) return("Expansion Liquidity");
   if(cmp>=60.0) return("Retracement Pre-Convexity");
   if(e>=18.0) return("Retracement Induction");
   return("Retracement");
  }

void MEM_TreePush(int parent,int dir,double origin,double extreme,double energy,int depth,int srcTf)
  {
   if(g_treeN>=MEM_TREE_MAX)
     { for(int i=0;i<MEM_TREE_MAX-1;i++) g_tree[i]=g_tree[i+1]; g_treeN=MEM_TREE_MAX-1; }
   g_nodeSeq++;
   MEM_Node nd; nd.id=g_nodeSeq; nd.parent=parent; nd.dir=dir; nd.origin=origin; nd.extreme=extreme;
   nd.energy=energy; nd.alive=true; nd.depth=depth; nd.srcTf=srcTf; nd.comp=0; nd.mat=0; nd.state="";
   g_tree[g_treeN]=nd; g_treeN++;
  }

// narrative lineage persistent
double g_legX=EMPTY_VALUE, g_legPB=0, g_narrative=50.0, g_wholeChainLife=50.0;
int    g_narrDir=0, g_supVotes=0, g_degVotes=0;
double g_cmpHist[6]; int g_cmpHistN=0;

void MEM_Curve(FAL_Curve &cv)
  {
   FAL_TFStruct m5=g_state.structure.tf[FAL_L0];
   FAL_TFStruct h1=g_state.structure.tf[4];
   FAL_TFStruct h4=g_state.structure.tf[5];
   double atr=g_state.physics.atr; if(atr<=0) atr=_Point*10;
   double high=iHigh(_Symbol,_Period,1), low=iLow(_Symbol,_Period,1), close=g_state.spot;

   // ── Curve object (energy state) from M5 ───────────────────────
   int cvDir=m5.dir;
   double cvOrig=m5.invalidation;
   double cvExt = cvDir==1?g_state.wave.cycleHigh:(cvDir==-1?g_state.wave.cycleLow:close);
   if(cvExt==EMPTY_VALUE||cvExt==0) cvExt = cvDir==1?high:low;
   cv.dir=cvDir; cv.origin=cvOrig; cv.extreme=cvExt;
   cv.dispATR = cvOrig!=EMPTY_VALUE?MathAbs(cvExt-cvOrig)/MathMax(atr,1e-10):0.0;
   cv.eIn=g_state.erf.expansionEnergy; cv.eDiss=g_state.erf.dissipatedEnergy; cv.eRes=g_state.erf.residualEnergy;
   cv.convex=g_state.physics.obsCurvature;
   cv.compress=m5.compression;
   cv.maturity=g_state.wave.waveProgress;

   // ── compression history for tightening trend ──────────────────
   double cmpNow=cv.compress;
   double cmpPrev = (g_cmpHistN>=6)?g_cmpHist[0]:cmpNow;
   if(g_cmpHistN<6){ g_cmpHist[g_cmpHistN]=cmpNow; g_cmpHistN++; }
   else { for(int i=0;i<5;i++) g_cmpHist[i]=g_cmpHist[i+1]; g_cmpHist[5]=cmpNow; }
   double cmpTighten=cmpNow-cmpPrev;

   // ── recursion budget from compression ─────────────────────────
   int budgetDepth=(int)MathMax(1,MathMin(4,1+MathRound(cmpNow/33.0)));

   // ── owner (shallowest alive node with energy>=12) ─────────────
   double ownMinE=12.0;
   int preOwn=-1; double preE=-1; int preDepth=999;
   for(int i=0;i<g_treeN;i++)
      if(g_tree[i].alive && g_tree[i].energy>=ownMinE && (g_tree[i].depth<preDepth || (g_tree[i].depth==preDepth && g_tree[i].energy>preE)))
        { preDepth=g_tree[i].depth; preE=g_tree[i].energy; preOwn=i; }
   if(preOwn<0)
      for(int i=0;i<g_treeN;i++)
         if(g_tree[i].alive && g_tree[i].energy>preE){ preE=g_tree[i].energy; preOwn=i; }

   // ── seed root if nobody owns price ────────────────────────────
   int ctxDir=m5.dir; double ctxOrig=m5.invalidation;
   double ctxExt = ctxDir==1?MathMax(g_state.wave.cycleHigh,high):(ctxDir==-1?MathMin(g_state.wave.cycleLow,low):close);
   if(preOwn<0 && ctxDir!=0 && ctxOrig!=EMPTY_VALUE)
      MEM_TreePush(-1,ctxDir,ctxOrig,ctxExt,MathMax(40.0,g_state.erf.expansionEnergy),0,0);

   // ── event-generated child on M5 Phase-2 CHoCH against owner ───
   if(preOwn>=0)
     {
      MEM_Node po=g_tree[preOwn];
      bool counterCH=(po.dir==1 && g_state.structure.bearCHoCH)||(po.dir==-1 && g_state.structure.bullCHoCH);
      if(counterCH && po.depth+1<=budgetDepth)
         MEM_TreePush(po.id,-po.dir,close,close,MathMax(25.0,g_state.erf.expansionEnergy*0.85),po.depth+1,0);
     }

   // ── update living nodes ───────────────────────────────────────
   for(int i=0;i<g_treeN;i++)
     {
      if(!g_tree[i].alive) continue;
      if(g_tree[i].depth==0)
        {
         g_tree[i].dir=m5.dir;
         g_tree[i].origin=m5.invalidation;
         g_tree[i].extreme=(g_tree[i].dir==1)?m5.swingHigh:m5.swingLow;
        }
      bool prog=(g_tree[i].dir==1)?(high>FAL_NZ(g_tree[i].extreme,high)):(low<FAL_NZ(g_tree[i].extreme,low));
      if(g_tree[i].depth>0)
         g_tree[i].extreme=(g_tree[i].dir==1)?MathMax(FAL_NZ(g_tree[i].extreme,high),high):MathMin(FAL_NZ(g_tree[i].extreme,low),low);
      g_tree[i].energy = prog?MathMin(100.0,g_tree[i].energy+7.0):MathMax(0.0,g_tree[i].energy-2.0);
      g_tree[i].mat=m5.waveProgress; g_tree[i].comp=m5.compression;
      g_tree[i].state=MEM_NodeState(g_tree[i].dir,g_tree[i].energy,g_tree[i].depth,g_tree[i].comp,g_tree[i].mat);
      if(g_tree[i].energy<=2.0) g_tree[i].alive=false;
     }

   // ── final owner ───────────────────────────────────────────────
   int alive=0,treeDepth=0,ownF=-1; double ownFE=-1; int ownDepth=999;
   for(int i=0;i<g_treeN;i++)
     {
      if(!g_tree[i].alive) continue;
      alive++; if(g_tree[i].depth>treeDepth) treeDepth=g_tree[i].depth;
      if(g_tree[i].energy>=ownMinE && (g_tree[i].depth<ownDepth || (g_tree[i].depth==ownDepth && g_tree[i].energy>ownFE)))
        { ownDepth=g_tree[i].depth; ownFE=g_tree[i].energy; ownF=i; }
     }
   if(ownF<0)
      for(int i=0;i<g_treeN;i++)
         if(g_tree[i].alive && g_tree[i].energy>ownFE){ ownFE=g_tree[i].energy; ownF=i; }

   int ownDir=ownF>=0?g_tree[ownF].dir:0;
   double ownEnergy=ownF>=0?g_tree[ownF].energy:0;
   double ownOrig=ownF>=0?g_tree[ownF].origin:m5.invalidation;
   double ownExt =ownF>=0?g_tree[ownF].extreme:(ownDir==1?m5.swingHigh:m5.swingLow);

   // ── compression persistence (can the counter side build?) ─────
   double cpForce=FAL_Clamp(cmpNow*0.50 + cv.eRes*0.20 - treeDepth*12.0 + MathMax(0.0,cmpTighten)*0.8 + 8.0,0,100);
   string cpState = cpForce>=60.0?"PERSISTING":cpForce<=35.0?"LEAKING":"NEUTRAL";

   // ── life score (hold-vs-flip) ─────────────────────────────────
   bool recursionComplete = budgetDepth>0 && treeDepth>=budgetDepth;
   bool attacking=(ownDir==1)?(high>=FAL_NZ(ownExt,high)):(ownDir==-1?(low<=FAL_NZ(ownExt,low)):false);
   bool trendImp=(ownDir==1&&g_state.physics.bullImpulse)||(ownDir==-1&&g_state.physics.bearImpulse);
   bool progressing=attacking||trendImp;
   double retrX=(ownExt==EMPTY_VALUE||ownOrig==EMPTY_VALUE||ownExt==ownOrig)?50.0:MathMin(100.0,MathAbs(ownExt-close)/MathAbs(ownExt-ownOrig)*100.0);
   double life=FAL_Clamp(cpForce*0.45 + cv.eRes*0.30 + (cmpTighten>0?12.0:0.0)
                         - (recursionComplete&&!progressing?25.0:0.0)
                         - (cpState=="LEAKING"&&!progressing?20.0:0.0)
                         + (progressing?28.0:0.0)
                         + (retrX<25.0?16.0:retrX<45.0?6.0:retrX>75.0?-12.0:0.0) + 10.0,0,100);

   // ── narrative lineage ─────────────────────────────────────────
   if(ownDir!=g_narrDir)
     { g_narrDir=ownDir; g_legX=(ownDir==1)?high:(ownDir==-1?low:EMPTY_VALUE); g_legPB=0; g_narrative=50.0; g_supVotes=0; g_degVotes=0; }
   if(ownDir!=0 && ownOrig!=EMPTY_VALUE)
     {
      bool newLeg=(ownDir==1)?(high>FAL_NZ(g_legX,high)):(low<FAL_NZ(g_legX,low));
      if(newLeg)
        {
         if(g_legPB>6.0)
           {
            bool sup=g_legPB<=50.0 && cmpTighten>=-1.0;
            bool deg=g_legPB>=62.0 || cmpTighten<-3.0;
            int vote=sup?1:(deg?-1:0);
            if(vote==1) g_supVotes++; if(vote==-1) g_degVotes++;
            g_narrative=FAL_Clamp(g_narrative+vote*12.0+(cmpTighten>0?3.0:-3.0),0,100);
           }
         g_legX=(ownDir==1)?high:low; g_legPB=0;
        }
      else
        {
         double pbd=MathAbs(FAL_NZ(g_legX,close)-ownOrig)>1e-9?MathAbs(FAL_NZ(g_legX,close)-close)/MathAbs(FAL_NZ(g_legX,close)-ownOrig)*100.0:0.0;
         g_legPB=MathMax(g_legPB,pbd);
        }
     }
   g_wholeChainLife=g_wholeChainLife+0.02*(life-g_wholeChainLife);
   string narrState=g_narrative>=65.0?"STRENGTHENING":g_narrative<=35.0?"WEAKENING":"HOLDING";

   // ── budget target ─────────────────────────────────────────────
   double parentThreat = ownDir==1?(h4.flipTop!=EMPTY_VALUE&&h4.flipTop>close?h4.flipTop:h4.swingHigh):
                         ownDir==-1?(h4.flipBot!=EMPTY_VALUE&&h4.flipBot<close?h4.flipBot:h4.swingLow):EMPTY_VALUE;
   double budTgt = (cpState=="LEAKING"&&ownOrig!=EMPTY_VALUE)?ownOrig:(parentThreat!=EMPTY_VALUE?parentThreat:FAL_NZ(m5.target,ownExt));

   // ── write curve state ─────────────────────────────────────────
   cv.treeAlive=alive; cv.treeDepth=treeDepth; cv.budgetDepth=budgetDepth;
   cv.ownerDir=ownDir; cv.ownerEnergy=ownEnergy; cv.ownerOrigin=ownOrig; cv.ownerExtreme=ownExt;
   cv.life=life; cv.cpState=cpState; cv.cpForce=cpForce;
   cv.narrative=g_narrative; cv.narrState=narrState; cv.budgetTarget=budTgt;

   if(life<33.0) FAL_Publish("CAMPAIGN_DYING");
   if(life>60.0) FAL_Publish("CAMPAIGN_ALIVE");
  }

//==================================================================
// CAMPAIGN OWNERSHIP + PARTICIPANT ENGINE
//==================================================================
void MEM_Campaign(FAL_Campaign &cp)
  {
   FAL_Curve cv=g_state.curve;
   double atr=g_state.physics.atr; if(atr<=0) atr=_Point*10;
   double close=g_state.spot;

   double htfZone = (g_state.network.attractorIdx>=0)?g_state.network.px[g_state.network.attractorIdx]:EMPTY_VALUE;
   double distHTF = htfZone!=EMPTY_VALUE?MathAbs(htfZone-close):EMPTY_VALUE;
   double curveBudget = distHTF!=EMPTY_VALUE?FAL_Clamp(distHTF/MathMax(atr*8.0,1e-10)*100.0,0,100):EMPTY_VALUE;
   double gComp=cv.compress;
   cp.compRegime = gComp>=75?"FAILURE SWING":gComp>=50?"COMPRESSED":gComp>=25?"MEDIUM":"WIDE";
   bool atHTF = distHTF!=EMPTY_VALUE && distHTF<atr*1.5;
   bool nearHTF = curveBudget!=EMPTY_VALUE && curveBudget<25.0;
   int ph=g_state.intel.phaseCode;
   bool termPhase = (ph==PH_INDUCTION||ph==PH_LIQUIDATION||ph==PH_TERMINAL||ph==PH_HTF_FLIP||ph==PH_DEMAND_RTN||ph==PH_SUPPLY_RTN);
   cp.state = (atHTF||termPhase)?"TERMINAL":"EXPANSION";
   cp.location = (atHTF||termPhase)?"INSIDE HTF ZONE":nearHTF?"APPROACHING HTF ZONE":(ph==PH_TRANSITION||ph==PH_RETRACE)?"TRANSITIONING":"BUILDING";
   cp.ownerDir = cv.dir!=0?cv.dir:g_state.intel.master;
   cp.htfZone=htfZone; cp.curveBudget=curveBudget;
   cp.expDepth = cp.state=="EXPANSION"?0:(int)MathMax(1,MathMin(4,1+MathRound(gComp/33.0)));

   // participant fib band of owner curve
   double pcHi=cv.extreme, pcLo=cv.origin;
   double rng=(pcHi!=EMPTY_VALUE&&pcLo!=EMPTY_VALUE)?pcHi-pcLo:EMPTY_VALUE;
   cp.f618 = rng!=EMPTY_VALUE?pcHi-0.618*rng:EMPTY_VALUE;
   cp.f70  = rng!=EMPTY_VALUE?pcHi-0.70 *rng:EMPTY_VALUE;
   cp.f786 = rng!=EMPTY_VALUE?pcHi-0.786*rng:EMPTY_VALUE;
   cp.flipLvl = cv.dir==1?g_state.wave.flipBot:(cv.dir==-1?g_state.wave.flipTop:EMPTY_VALUE);
   double retrAbs=(rng!=EMPTY_VALUE&&MathAbs(rng)>1e-10)?MathAbs(pcHi-close)/MathAbs(rng):EMPTY_VALUE;
   cp.partZone = retrAbs==EMPTY_VALUE?"-":retrAbs<0.55?"pre-0.618 clean":retrAbs<0.66?"0.618 participants in":retrAbs<0.74?"0.70 interference":retrAbs<0.82?"0.786 heavy":"FLIP true induction";
   bool interfDom=(ph==PH_TRANSITION||ph==PH_RETRACE||ph==PH_DEMAND_RTN||ph==PH_SUPPLY_RTN||ph==PH_INDUCTION||ph==PH_LIQUIDATION||ph==PH_TERMINAL);
   bool displacing=(retrAbs!=EMPTY_VALUE&&retrAbs>=0.55)&&(g_state.physics.bullImpulse||g_state.physics.bearImpulse);
   cp.interference = interfDom?"DOMINANT recursive owns":displacing?"active displacement":"absorbed parent continues";
  }

//==================================================================
// MODULE 2 INIT + RUN
//==================================================================
void MEM_Init()
  {
   g_state.network.count=0;
   g_treeN=0; g_nodeSeq=0;
   for(int i=0;i<FAL_TF_COUNT;i++) g_prevFUTip[i]=EMPTY_VALUE;
   g_legX=EMPTY_VALUE; g_narrative=50.0; g_wholeChainLife=50.0; g_cmpHistN=0;
   FAL_SetModuleStatus(1,"ready");
  }
// Runs AFTER core+intelligence-phase so it can use ERF/phase; called by scheduler
// in two parts: network/curve early (memory), campaign after phase. For
// determinism we run network+curve here (consume previous-bar ERF/phase, then
// Intelligence refreshes), and campaign is refreshed at the end of Intelligence.
void MEM_RunEarly()
  {
   MEM_Network(g_state.network);
   MEM_Curve(g_state.curve);
   FAL_Publish("MEMORY_UPDATED");
   FAL_SetModuleStatus(1,"ok");
  }
void MEM_RunCampaign(){ MEM_Campaign(g_state.campaign); }

#endif // FALCON_MEMORY_MQH
