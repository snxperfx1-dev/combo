//+------------------------------------------------------------------+
//| FALCON_M2_Memory.mqh                                              |
//| FALCON OS - Module 2: Market Memory Engine (Source: F16)          |
//|                                                                   |
//| Remembers. Owns: Invisible Network (node registry, authority,     |
//| conversation graph, historical memory, aging, dormancy,           |
//| revisits), FEZ corridor, Campaign Ownership, Participant          |
//| tracking, Curve Tree, MTF curve map, Narrative Lineage.           |
//| Writes into gState.network/curve/campaign/participants/curveMap/  |
//| lineage. Node registry exposed to persistence layer.              |
//+------------------------------------------------------------------+
#property strict

//==================================================================
// NODE REGISTRY (exposed globals for persistence layer)
//==================================================================
#define M2_NODE_MAX 250
double gFalconNodePrice[M2_NODE_MAX];
double gFalconNodeMid[M2_NODE_MAX];
int    gFalconNodeDir[M2_NODE_MAX];
double gFalconNodeScore[M2_NODE_MAX];
int    gFalconNodeWeight[M2_NODE_MAX];
int    gFalconNodeState[M2_NODE_MAX];
int    gFalconNodeAge[M2_NODE_MAX];
int    gFalconNodeRevisits[M2_NODE_MAX];
int    gFalconNodeCount = 0;
int    gFalconNodeSeq = 0;

//--- TF weight + names
int M2_TFWeight(ENUM_TIMEFRAMES tf)
{
   if(tf==PERIOD_MN1)return(9); if(tf==PERIOD_W1)return(8); if(tf==PERIOD_D1)return(7);
   if(tf==PERIOD_H4)return(6);  if(tf==PERIOD_H1)return(5); if(tf==PERIOD_M15)return(4);
   if(tf==PERIOD_M5)return(3);  if(tf==PERIOD_M3)return(2); return(1);
}
string M2_WeightName(int wt)
{
   if(wt==9)return("MN"); if(wt==8)return("W"); if(wt==7)return("D"); if(wt==6)return("H4");
   if(wt==5)return("H1"); if(wt==4)return("M15"); if(wt==3)return("M5"); if(wt==2)return("M3");
   return("M1");
}
double M2_NodeAuthority(int i)
{
   if(i<0 || i>=gFalconNodeCount) return(0);
   return(gFalconNodeScore[i] + gFalconNodeWeight[i]*4.0 + gFalconNodeRevisits[i]*3.0);
}


//==================================================================
// NETWORK SCAN — detect FU/FLIP nodes on one TF
//==================================================================
void M2_ScanTF(ENUM_TIMEFRAMES tf)
{
   double h[],l[],c[],o[];
   ArraySetAsSeries(h,true);ArraySetAsSeries(l,true);
   ArraySetAsSeries(c,true);ArraySetAsSeries(o,true);
   int n=30;
   if(CopyHigh(_Symbol,tf,0,n,h)<n) return;
   if(CopyLow(_Symbol,tf,0,n,l)<n) return;
   if(CopyClose(_Symbol,tf,0,n,c)<n) return;
   if(CopyOpen(_Symbol,tf,0,n,o)<n) return;
   double ab[]; ArraySetAsSeries(ab,true);
   int ah=iATR(_Symbol,tf,14);
   if(ah==INVALID_HANDLE || CopyBuffer(ah,0,0,3,ab)<1) return;
   double atr=ab[0]; if(atr<=0) return;

   int wt=M2_TFWeight(tf); int lb=3; int i=1;
   double rng=MathMax(h[i]-l[i],1e-10);
   double uw=(h[i]-MathMax(o[i],c[i]))/rng;
   double lw=(MathMin(o[i],c[i])-l[i])/rng;
   double pHi=0,pLo=99999999;
   for(int k=i+1;k<=i+lb && k<n;k++){ if(h[k]>pHi)pHi=h[k]; if(l[k]<pLo)pLo=l[k]; }
   bool localTop=(h[i]>=pHi), localBot=(l[i]<=pLo);
   bool bear=(uw>=CfgWickFrac && ((pHi>0&&h[i]>=pHi&&c[i]<pHi)||(localTop&&c[i]<o[i])));
   bool bull=(lw>=CfgWickFrac && ((pLo<99999999&&l[i]<=pLo&&c[i]>pLo)||(localBot&&c[i]>o[i])));
   if(!bear && !bull) return;

   int dir=bear?-1:1;
   double tip=bear?h[i]:l[i];
   double bH=MathMax(o[i],c[i]), bL=MathMin(o[i],c[i]);
   double mid=bear?bH+(tip-bH)*0.5 : tip+(bL-tip)*0.5;
   double wkAtr=bear?(tip-bH)/atr:(bL-tip)/atr;
   bool conf=(bear&&c[0]<bL)||(bull&&c[0]>bH);
   double score=20.0+MathMin(25.0,wkAtr*15.0)+(conf?30.0:0.0)+(wkAtr>1.0?15.0:0.0)+(wkAtr>1.5?10.0:0.0);

   // dedup
   for(int j=0;j<gFalconNodeCount;j++)
      if(gFalconNodeWeight[j]==wt && MathAbs(gFalconNodePrice[j]-tip)<atr*0.1) return;
   // evict lowest authority if full
   if(gFalconNodeCount>=M2_NODE_MAX)
   {
      int ev=0; double evA=M2_NodeAuthority(0);
      for(int j=1;j<gFalconNodeCount;j++){ double a=M2_NodeAuthority(j); if(a<evA){evA=a;ev=j;} }
      for(int j=ev;j<gFalconNodeCount-1;j++)
      {
         gFalconNodePrice[j]=gFalconNodePrice[j+1]; gFalconNodeMid[j]=gFalconNodeMid[j+1];
         gFalconNodeDir[j]=gFalconNodeDir[j+1]; gFalconNodeScore[j]=gFalconNodeScore[j+1];
         gFalconNodeWeight[j]=gFalconNodeWeight[j+1]; gFalconNodeState[j]=gFalconNodeState[j+1];
         gFalconNodeAge[j]=gFalconNodeAge[j+1]; gFalconNodeRevisits[j]=gFalconNodeRevisits[j+1];
      }
      gFalconNodeCount--;
   }
   int idx=gFalconNodeCount;
   gFalconNodePrice[idx]=tip; gFalconNodeMid[idx]=mid; gFalconNodeDir[idx]=dir;
   gFalconNodeScore[idx]=score; gFalconNodeWeight[idx]=wt; gFalconNodeState[idx]=0;
   gFalconNodeAge[idx]=0; gFalconNodeRevisits[idx]=0; gFalconNodeCount++;
}


//==================================================================
// NODE STATE UPDATE + NETWORK BIAS + FEZ  (writes gState.network)
//==================================================================
void M2_UpdateNodeStates()
{
   double atr=gState.physics.atr; if(atr<=0) return;
   double cl=gState.barClose;
   for(int i=0;i<gFalconNodeCount;i++)
   {
      gFalconNodeAge[i]++;
      if(gFalconNodeState[i]==2) continue;
      if(gFalconNodeDir[i]==-1 && cl>gFalconNodePrice[i]){ gFalconNodeState[i]=2; continue; }
      if(gFalconNodeDir[i]==1 && cl<gFalconNodePrice[i]){ gFalconNodeState[i]=2; continue; }
      if(MathAbs(cl-gFalconNodePrice[i])<atr*0.25) gFalconNodeRevisits[i]++;
      int sd=CfgDormantBars*gFalconNodeWeight[i];
      int sh=CfgHistoryBars*gFalconNodeWeight[i];
      if(gFalconNodeAge[i]>sh) gFalconNodeState[i]=3;
      else if(gFalconNodeAge[i]>sd) gFalconNodeState[i]=1;
      else gFalconNodeState[i]=0;
   }
}

void M2_UpdateNetwork()
{
   // scan 7 TFs
   M2_ScanTF(PERIOD_MN1); M2_ScanTF(PERIOD_W1); M2_ScanTF(PERIOD_D1);
   M2_ScanTF(PERIOD_H4);  M2_ScanTF(PERIOD_H1); M2_ScanTF(PERIOD_M15); M2_ScanTF(PERIOD_M5);
   M2_UpdateNodeStates();

   double cl=gState.barClose;
   double bullAuth=0, bearAuth=0; int elig=0;
   FALCON_Network net; ZeroMemory(net);
   net.nodeCount=gFalconNodeCount;
   double fezHiAuth=0, fezLoAuth=0;
   double bestRank=-1;
   net.attractorIdx=-1;

   for(int i=0;i<gFalconNodeCount;i++)
   {
      if(gFalconNodeState[i]==2) continue;
      double auth=M2_NodeAuthority(i);
      if(auth<CfgAuthMin) continue;
      elig++;
      if(gFalconNodeDir[i]==1) bullAuth+=auth; else bearAuth+=auth;
      if(gFalconNodePrice[i]>cl && auth>fezHiAuth){ fezHiAuth=auth; net.fezHigh=gFalconNodePrice[i]; net.fezHighWeight=gFalconNodeWeight[i]; }
      if(gFalconNodePrice[i]<cl && auth>fezLoAuth){ fezLoAuth=auth; net.fezLow=gFalconNodePrice[i]; net.fezLowWeight=gFalconNodeWeight[i]; }
   }
   net.eligibleCount=elig;
   net.pressure=(bullAuth+bearAuth>0)?(bullAuth-bearAuth)/(bullAuth+bearAuth)*100.0:0;
   net.bias=(net.pressure>12)?1:(net.pressure<-12)?-1:0;

   // attractor = highest weight*1000+auth on bias side
   for(int i=0;i<gFalconNodeCount;i++)
   {
      if(gFalconNodeState[i]==2) continue;
      double auth=M2_NodeAuthority(i);
      if(auth<CfgAuthMin) continue;
      bool ahead=(net.bias==1)?(gFalconNodePrice[i]>cl):(net.bias==-1)?(gFalconNodePrice[i]<cl):false;
      if(!ahead) continue;
      double rank=gFalconNodeWeight[i]*1000.0+auth;
      if(rank>bestRank){ bestRank=rank; net.attractorIdx=i; net.attractorAuthority=auth; net.attractorPrice=gFalconNodePrice[i]; }
   }
   if(net.attractorIdx>=0)
      net.attractorDesc=M2_WeightName(gFalconNodeWeight[net.attractorIdx])+
         (gFalconNodeDir[net.attractorIdx]==1?" ^ ":" v ")+DoubleToString(net.attractorPrice,_Digits);
   else net.attractorDesc="-";
   net.insideFEZ=(net.fezHigh>0 && net.fezLow>0 && cl>net.fezLow && cl<net.fezHigh);
   gState.network=net;
}


//==================================================================
// CURVE TREE + CURVE OBJECT  (writes gState.curve)
//==================================================================
struct M2_CurveNode { int id; int parent; int dir; double origin; double extreme;
                      double energy; bool alive; int depth; int birthBar; };
#define M2_TREE_MAX 30
M2_CurveNode m2_tree[M2_TREE_MAX];
int m2_treeCount=0, m2_treeSeq=0;

void M2_UpdateCurve()
{
   double atr=gState.physics.atr; if(atr<=0) return;
   double cl=gState.barClose;
   FALCON_TFStructure m5=gState.tf[L_M5];

   // Curve object from M5 wave
   FALCON_Curve cv=gState.curve;
   cv.direction=m5.direction;
   cv.origin=m5.invalidation;
   cv.extreme=(m5.direction==1)?gState.wave.cycleHigh:(m5.direction==-1)?gState.wave.cycleLow:cl;
   cv.dispATR=(cv.origin>0)?MathAbs(cv.extreme-cv.origin)/MathMax(atr,1e-10):0;
   cv.energyIn=gState.erf.expansionEnergy;
   cv.energyDissipated=gState.erf.dissipatedEnergy;
   cv.energyResidual=gState.erf.residualEnergy;
   cv.convexity=gState.wave.convexity;
   cv.compression=m5.compression;
   cv.maturity=gState.wave.completion;

   // Tree: find owner
   int ownerIdx=-1; double ownerE=-1; int ownerDepth=999;
   for(int i=0;i<m2_treeCount;i++)
      if(m2_tree[i].alive && m2_tree[i].energy>=12.0)
         if(m2_tree[i].depth<ownerDepth || (m2_tree[i].depth==ownerDepth && m2_tree[i].energy>ownerE))
         { ownerDepth=m2_tree[i].depth; ownerE=m2_tree[i].energy; ownerIdx=i; }
   // seed root
   if(ownerIdx<0 && m5.direction!=0 && m5.invalidation>0 && m2_treeCount<M2_TREE_MAX)
   {
      m2_treeSeq++;
      m2_tree[m2_treeCount].id=m2_treeSeq; m2_tree[m2_treeCount].parent=-1;
      m2_tree[m2_treeCount].dir=m5.direction; m2_tree[m2_treeCount].origin=m5.invalidation;
      m2_tree[m2_treeCount].extreme=cv.extreme; m2_tree[m2_treeCount].energy=MathMax(40.0,gState.erf.expansionEnergy);
      m2_tree[m2_treeCount].alive=true; m2_tree[m2_treeCount].depth=0; m2_tree[m2_treeCount].birthBar=gState.barsAvailable;
      m2_treeCount++; ownerIdx=m2_treeCount-1;
   }
   // spawn child on CHoCH against owner
   int budget=MathMax(1,MathMin(4,1+(int)MathRound(cv.compression/33.0)));
   if(ownerIdx>=0)
   {
      int od=m2_tree[ownerIdx].dir, odp=m2_tree[ownerIdx].depth, oid=m2_tree[ownerIdx].id;
      bool bearCH=(m5.choch==-1), bullCH=(m5.choch==1);
      if(((od==1&&bearCH)||(od==-1&&bullCH)) && (odp+1<=budget) && m2_treeCount<M2_TREE_MAX)
      {
         m2_treeSeq++;
         m2_tree[m2_treeCount].id=m2_treeSeq; m2_tree[m2_treeCount].parent=oid;
         m2_tree[m2_treeCount].dir=-od; m2_tree[m2_treeCount].origin=cl; m2_tree[m2_treeCount].extreme=cl;
         m2_tree[m2_treeCount].energy=MathMax(25.0,gState.erf.expansionEnergy*0.85);
         m2_tree[m2_treeCount].alive=true; m2_tree[m2_treeCount].depth=odp+1; m2_tree[m2_treeCount].birthBar=gState.barsAvailable;
         m2_treeCount++;
      }
   }
   // update nodes
   int alive=0, maxDepth=0;
   for(int i=0;i<m2_treeCount;i++)
   {
      if(!m2_tree[i].alive) continue;
      bool prog=(m2_tree[i].dir==1)?(gState.barHigh>m2_tree[i].extreme):(gState.barLow<m2_tree[i].extreme);
      if(m2_tree[i].depth==0){ m2_tree[i].origin=m5.invalidation; m2_tree[i].extreme=(m2_tree[i].dir==1)?m5.swingHigh:m5.swingLow; m2_tree[i].dir=m5.direction; }
      else m2_tree[i].extreme=(m2_tree[i].dir==1)?MathMax(m2_tree[i].extreme,gState.barHigh):(m2_tree[i].extreme==0?gState.barLow:MathMin(m2_tree[i].extreme,gState.barLow));
      m2_tree[i].energy=prog?MathMin(100.0,m2_tree[i].energy+7.0):MathMax(0.0,m2_tree[i].energy-2.0);
      if(m2_tree[i].energy<=2.0) m2_tree[i].alive=false; else { alive++; maxDepth=MathMax(maxDepth,m2_tree[i].depth); }
   }
   while(m2_treeCount>M2_TREE_MAX-5)
   {
      bool removed=false;
      for(int i=0;i<m2_treeCount;i++) if(!m2_tree[i].alive){ for(int j=i;j<m2_treeCount-1;j++) m2_tree[j]=m2_tree[j+1]; m2_treeCount--; removed=true; break; }
      if(!removed) break;
   }
   cv.treeNodeCount=alive; cv.treeMaxDepth=maxDepth;
   M2_CurveLife(cv, ownerIdx, maxDepth, budget);
   gState.curve=cv;
}


//==================================================================
// CURVE LIFE SCORE (hold-vs-abandon) — fills cv life/force/budget
//==================================================================
void M2_CurveLife(FALCON_Curve &cv, int ownerIdx, int maxDepth, int budget)
{
   double cl=gState.barClose; double atr=gState.physics.atr;
   int ownerDir = (ownerIdx>=0)? m2_tree[ownerIdx].dir : 0;
   double ownerOrig=(ownerIdx>=0)? m2_tree[ownerIdx].origin : 0;
   double ownerExt =(ownerIdx>=0)? m2_tree[ownerIdx].extreme : 0;
   cv.ownerDir=ownerDir;
   cv.ownerEnergy=(ownerIdx>=0)? m2_tree[ownerIdx].energy : 0;

   cv.force=FClamp(cv.compression*0.50 + cv.energyResidual*0.20 - maxDepth*12.0 + 8.0, 0,100);
   cv.forceState=(cv.force>=60)?"PERSISTING":(cv.force<=35)?"LEAKING":"NEUTRAL";

   double retrX=50.0;
   if(ownerOrig>0 && ownerExt>0 && ownerExt!=ownerOrig)
      retrX=MathMin(100.0,MathAbs(ownerExt-cl)/MathAbs(ownerExt-ownerOrig)*100.0);
   bool attacking=(ownerDir==1 && gState.barHigh>=ownerExt)||(ownerDir==-1 && gState.barLow<=ownerExt);
   bool trendImp=(ownerDir==1 && gState.physics.bullImpulse)||(ownerDir==-1 && gState.physics.bearImpulse);
   bool progressing=attacking||trendImp;
   bool recComplete=(budget>0 && maxDepth>=budget);

   cv.life=FClamp(cv.force*0.45 + cv.energyResidual*0.30 +
      (progressing?28.0:0.0) +
      (retrX<25.0?16.0:retrX<45.0?6.0:retrX>75.0?-12.0:0.0) -
      (recComplete&&!progressing?25.0:0.0) -
      (cv.forceState=="LEAKING"&&!progressing?20.0:0.0) + 10.0, 0,100);
   if(progressing && cv.life>=45) cv.aliveStatus="ALIVE - ATTACKING";
   else if(cv.life>=60) cv.aliveStatus="ALIVE - HOLD";
   else if(cv.life<=32) cv.aliveStatus="DEAD - FLIP";
   else cv.aliveStatus="WEAKENING - MANAGE";

   // ODDE budget target: leaking->origin, else H4 parent, else wave obj
   double parentThreat=0;
   if(ownerDir==1) parentThreat=(gState.tf[L_H4].flipTop>0&&gState.tf[L_H4].flipTop>cl)?gState.tf[L_H4].flipTop:gState.tf[L_H4].swingHigh;
   else if(ownerDir==-1) parentThreat=(gState.tf[L_H4].flipBot>0&&gState.tf[L_H4].flipBot<cl)?gState.tf[L_H4].flipBot:gState.tf[L_H4].swingLow;
   if(cv.forceState=="LEAKING" && ownerOrig>0){ cv.budgetTarget=ownerOrig; cv.budgetSource="ORIGIN"; }
   else if(parentThreat>0){ cv.budgetTarget=parentThreat; cv.budgetSource="H4 PARENT"; }
   else if(gState.tf[L_M5].target>0){ cv.budgetTarget=gState.tf[L_M5].target; cv.budgetSource="WAVE OBJ"; }
   else { cv.budgetTarget=0; cv.budgetSource="-"; }
   cv.budgetATR=(cv.budgetTarget>0)?MathAbs(cl-cv.budgetTarget)/MathMax(atr,1e-10):0;
}

//==================================================================
// MEMORY STAGE ENTRY (curve + MTF map + lineage)
//==================================================================
void M2_UpdateMemory()
{
   M2_UpdateCurve();
   M2_UpdateMTFMap();
   M2_UpdateLineage();
}


//==================================================================
// MTF CURVE MAP (7 rungs) writes gState.curveMap
//==================================================================
double m2_mapAlign=0; string m2_mapStory=""; string m2_mapOwnerTF="";
void M2_UpdateMTFMap()
{
   double cl=gState.barClose; if(cl==0) return;
   int layers[7]={L_M1,L_M3,L_M5,L_M15,L_M15,L_H1,L_H4};
   int ownerDir=gState.curve.direction;
   int align=0;
   for(int i=0;i<7;i++)
   {
      int li=layers[i];
      FALCON_MapRung r;
      r.direction=gState.tf[li].direction;
      r.origin=gState.tf[li].invalidation;
      r.extreme=(r.direction==1)?gState.tf[li].swingHigh:gState.tf[li].swingLow;
      r.progress=gState.tf[li].waveProgress;
      double span=(r.origin>0&&r.extreme>0)?MathAbs(r.extreme-r.origin):0;
      r.retrace=(span>1e-10)?MathAbs(r.extreme-cl)/span*100.0:0;
      if(r.retrace<12) r.phase=(r.direction==1)?"New High":"New Low";
      else if(r.retrace<35) r.phase="Expansion";
      else if(r.retrace<55) r.phase="Pre-Conv";
      else if(r.retrace<78) r.phase="Retracement";
      else r.phase="Deep/Flip";
      r.relation=(ownerDir==0||r.direction==0)?"-":(r.direction==ownerDir)?"align":"counter";
      if(r.direction==ownerDir && ownerDir!=0) align++;
      gState.curveMap[i]=r;
   }
   m2_mapAlign=align;
   if(ownerDir==0) m2_mapStory="no dominant owner";
   else if(align>=7) m2_mapStory="all TFs aligned";
   else if(align>=5) m2_mapStory="HTFs lead";
   else if(align<=3) m2_mapStory="LTFs counter HTF";
   else m2_mapStory="mixed rotation";
   if(gState.curveMap[6].progress>10&&gState.curveMap[6].progress<90) m2_mapOwnerTF="H4";
   else if(gState.curveMap[5].progress>10&&gState.curveMap[5].progress<90) m2_mapOwnerTF="H1";
   else if(gState.curveMap[3].progress>10&&gState.curveMap[3].progress<90) m2_mapOwnerTF="M15";
   else m2_mapOwnerTF="M5";
}

//==================================================================
// NARRATIVE LINEAGE  writes gState.lineage
//==================================================================
double m2_legExtreme=0, m2_legPBDepth=0; int m2_lineageDir=0;
double m2_retraceSeq[5]; int m2_retraceCount=0;
void M2_UpdateLineage()
{
   double cl=gState.barClose; double atr=gState.physics.atr;
   int ownerDir=gState.curve.direction; double ownerOrig=gState.curve.origin;
   FALCON_Lineage ln=gState.lineage;

   if(ownerDir!=m2_lineageDir)
   {
      m2_lineageDir=ownerDir;
      m2_legExtreme=(ownerDir==1)?gState.barHigh:(ownerDir==-1)?gState.barLow:0;
      m2_legPBDepth=0; ln.narrative=50.0; ln.supportVotes=0; ln.degradeVotes=0;
      ln.lastVote="-"; ln.converging=false; m2_retraceCount=0;
   }
   ln.ownerDir=ownerDir;
   if(ownerDir!=0 && ownerOrig!=0)
   {
      bool newLegX=(ownerDir==1&&gState.barHigh>m2_legExtreme)||(ownerDir==-1&&gState.barLow<m2_legExtreme);
      if(newLegX)
      {
         if(m2_legPBDepth>6.0)
         {
            bool sup=(m2_legPBDepth<=50.0), deg=(m2_legPBDepth>=62.0);
            int vote=sup?1:deg?-1:0;
            ln.lastVote=(vote==1)?"SUPPORT":(vote==-1)?"DEGRADE":"NEUTRAL";
            ln.supportVotes+=(vote==1?1:0); ln.degradeVotes+=(vote==-1?1:0);
            ln.narrative=FClamp(ln.narrative+vote*12.0,0,100);
            if(m2_retraceCount<5){ m2_retraceSeq[m2_retraceCount]=m2_legPBDepth; m2_retraceCount++; }
            else { for(int j=0;j<4;j++) m2_retraceSeq[j]=m2_retraceSeq[j+1]; m2_retraceSeq[4]=m2_legPBDepth; }
         }
         m2_legExtreme=(ownerDir==1)?gState.barHigh:gState.barLow; m2_legPBDepth=0;
      }
      else
      {
         double span=MathAbs(m2_legExtreme-ownerOrig);
         if(span>1e-10){ double pbd=MathAbs(m2_legExtreme-cl)/span*100.0; m2_legPBDepth=MathMax(m2_legPBDepth,pbd); }
      }
   }
   ln.state=(ln.narrative>=65)?"STRENGTHENING":(ln.narrative<=35)?"WEAKENING":"HOLDING";
   ln.converging=(m2_retraceCount>=2 && m2_retraceSeq[m2_retraceCount-1]<m2_retraceSeq[m2_retraceCount-2]);
   ln.chainVitality=gState.curve.life;
   ln.wholeChainLife=ln.wholeChainLife+0.02*(gState.curve.life-ln.wholeChainLife);
   gState.lineage=ln;
}


//==================================================================
// CAMPAIGN STAGE — Campaign Ownership + Participant Engine
//==================================================================
void M2_UpdateCampaign()
{
   double atr=gState.physics.atr; if(atr<=0) return;
   double cl=gState.barClose;

   //--- Campaign Ownership
   FALCON_Campaign cp;
   cp.dominantSide=(gState.curve.direction!=0)?gState.curve.direction:gState.intel.masterBias;
   cp.institution=(cp.dominantSide==1)?"BUYERS":(cp.dominantSide==-1)?"SELLERS":"NONE";
   double comp=gState.curve.compression;
   cp.compRegime=(comp>=75)?"FAILURE SWING":(comp>=50)?"COMPRESSED":(comp>=25)?"MEDIUM":"WIDE";
   cp.expDepth=MathMax(1,MathMin(4,1+(int)MathRound(comp/33.0)));

   double htfZone=(gState.network.attractorIdx>=0)?gState.network.attractorPrice:0;
   double distHTF=(htfZone>0)?MathAbs(htfZone-cl):0;
   cp.curveBudget=(distHTF>0)?MathMin(100.0,distHTF/MathMax(atr*8.0,1e-10)*100.0):0;
   bool atHTF=(distHTF>0 && distHTF<atr*1.5);
   FALCON_WavePhase ph=gState.wave.phase;
   bool termPhase=(ph==WP_EXP_INDUCTION||ph==WP_EXP_LIQUIDITY||ph==WP_RETR_INDUCTION||
                   ph==WP_RETR_LIQUIDITY||ph==WP_DEMAND_RETURN||ph==WP_SUPPLY_RETURN);
   cp.owner=(atHTF||termPhase)?"TERMINAL":"EXPANSION";
   if(atHTF||termPhase) cp.location="INSIDE HTF ZONE";
   else if(cp.curveBudget<25) cp.location="APPROACHING HTF ZONE";
   else if(ph==WP_RETRACEMENT||ph==WP_RETR_PRECONVEXITY) cp.location="TRANSITIONING";
   else cp.location="BUILDING";
   cp.objective=gState.curve.budgetTarget;
   cp.remainingEnergy=gState.erf.residualEnergy;
   cp.controlScore=gState.htf.contextScore;
   cp.age=gState.wave.age;

   // ownership merge (Principle 9)
   int childDir=gState.tf[L_M5].direction;
   int parentDir=0; int sumHTF=gState.tf[L_H1].direction+gState.tf[L_H4].direction;
   parentDir=(sumHTF>0)?1:(sumHTF<0)?-1:gState.tf[L_M15].direction;
   double pFlipTop=gState.tf[L_H1].flipTop, pFlipBot=gState.tf[L_H1].flipBot;
   bool counterChild=(childDir!=0 && parentDir!=0 && childDir!=parentDir);
   bool atParentFU=(pFlipTop>0&&pFlipBot>0&&cl>=pFlipBot&&cl<=pFlipTop);
   bool brokePar=(pFlipBot>0&&pFlipTop>0&&((parentDir==1&&cl<pFlipBot)||(parentDir==-1&&cl>pFlipTop)));
   bool reactPar=(parentDir==1&&(gState.physics.bullImpulse||gState.barClose>gState.barOpen))||
                 (parentDir==-1&&(gState.physics.bearImpulse||gState.barClose<gState.barOpen));
   bool merged=(counterChild&&atParentFU&&reactPar&&!brokePar);
   bool transferred=(counterChild&&brokePar);
   cp.ownershipState=transferred?"TRANSFERRED":merged?"MERGED (B->A)":counterChild?"child recursion":"aligned";
   gState.campaign=cp;

   //--- Participant Engine (Fib interference)
   FALCON_Participants pa=gState.participants;
   double pcHi=gState.curve.extreme, pcLo=gState.curve.origin;
   if(pcHi<pcLo){ double t=pcHi; pcHi=pcLo; pcLo=t; }
   double pcRng=pcHi-pcLo;
   if(pcRng>1e-10)
   {
      pa.fib618=pcHi-0.618*pcRng; pa.fib70=pcHi-0.70*pcRng; pa.fib786=pcHi-0.786*pcRng;
      pa.flipLevel=(gState.curve.direction==1)?gState.wave.flipBot:gState.wave.flipTop;
      pa.retrAbs=MathAbs(pcHi-cl)/pcRng;
      if(pa.retrAbs<0.55) pa.zone="pre-0.618 clean";
      else if(pa.retrAbs<0.66) pa.zone="0.618 participants";
      else if(pa.retrAbs<0.74) pa.zone="0.70 interference";
      else if(pa.retrAbs<0.82) pa.zone="0.786 heavy";
      else pa.zone="FLIP true induction";
      pa.displacing=(pa.retrAbs>=0.55 && (gState.physics.bullImpulse||gState.physics.bearImpulse));
      bool interfDom=(ph==WP_RETRACEMENT||ph==WP_RETR_PRECONVEXITY||ph==WP_RETR_INDUCTION||
                      ph==WP_DEMAND_RETURN||ph==WP_SUPPLY_RETURN);
      pa.interferenceState=interfDom?"DOMINANT":pa.displacing?"active displacement":"absorbed";
   }
   // participation flow from impulse + structure
   pa.buyer=FClamp((gState.physics.bullImpulse?60.0:0.0)+(gState.structure.trend==1?40.0:0.0),0,100);
   pa.seller=FClamp((gState.physics.bearImpulse?60.0:0.0)+(gState.structure.trend==-1?40.0:0.0),0,100);
   pa.aggressive=FClamp(gState.physics.displacement/MathMax(CfgDispThresh,1e-10)*50.0,0,100);
   pa.passive=FClamp(100.0-pa.aggressive,0,100);
   pa.interference=FClamp(pa.retrAbs*100.0,0,100);
   pa.participationScore=FClamp((pa.buyer+pa.seller)/2.0,0,100);
   pa.marketPressure=pa.buyer-pa.seller;
   gState.participants=pa;
}

//+------------------------------------------------------------------+
