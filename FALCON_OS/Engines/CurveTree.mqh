//+------------------------------------------------------------------+
//|  FALCON OS — Intelligence : CurveTree.mqh                       |
//|  Source: F16 Raptor — F72 RECURSIVE CURVE TREE                  |
//|                                                                  |
//|  CURVES INSIDE CURVES. Recursion is EVENT-generated, not          |
//|  timeframe-generated: a Phase-2 CHoCH against the OWNING node     |
//|  spawns a CHILD curve (same lifecycle, opposite orientation).     |
//|  Ownership = the shallowest living node that still holds energy    |
//|  (Principle 8). A child that keeps making progress GAINS energy    |
//|  and eventually owns (→ transfer); one that stalls decays and dies |
//|  (→ merge back into the parent). COMPRESSION sets the recursion     |
//|  BUDGET: a wide curve makes ~1 deep recursion, a failure-swing     |
//|  (high compression) up to 4 tiny ones.                            |
//|                                                                   |
//|  This is the genuine event-driven CurveNode array the PORT_AUDIT   |
//|  flagged as missing (the previous build only derived a per-rung    |
//|  tree). It runs AFTER MemoryEngine (owner TF resolved) and ENRICHES |
//|  g_state.curve with the recursive-tree summary. Additive: it does  |
//|  NOT change the authoritative direction/ownership (phases stay      |
//|  OUTPUTS) — it is the curve-tree the spec's Intelligence Layer asks |
//|  for, observable on the Curve tab.                                  |
//+------------------------------------------------------------------+
#ifndef FALCON_CURVE_TREE_MQH
#define FALCON_CURVE_TREE_MQH

#include "../Kernel/FalconState.mqh"
#include "../Kernel/FalconConfig.mqh"
#include "../Kernel/FalconSeries.mqh"
#include "../Kernel/FalconEventBus.mqh"

//==================================================================
// EVENT-DRIVEN CURVE NODE (port of F16 type CurveNode)
//==================================================================
struct CTNode
{
   int    id;
   int    parent;
   int    dir;
   double origin;
   double extreme;
   double energy;
   bool   alive;
   int    depth;
   string state;     // emergent phase the node owns (Principle 1: curve -> phase)
   int    bar;       // bar_index at birth
   double comp;      // this curve's own compression
   double mat;       // this curve's own maturity
   int    srcTf;     // ladder index of the source timeframe (depth-0 root only)
};

#define CT_CAP 96
CTNode ct_tree[CT_CAP];
int    ct_count = 0;
int    ct_seq   = 0;

// compression history ring (for the "tightening vs broadening" read)
double ct_compHist[6];
int    ct_compIdx = 0;
bool   ct_compFull = false;

// narrative lineage state (persists across bars)
int    ct_narrDir   = 0;
int    ct_supVotes  = 0;
int    ct_degVotes  = 0;
double ct_narrative = 50.0;

void CurveTreeInit()
{
   ct_count=0; ct_seq=0; ct_compIdx=0; ct_compFull=false;
   ct_narrDir=0; ct_supVotes=0; ct_degVotes=0; ct_narrative=50.0;
   for(int i=0;i<6;i++) ct_compHist[i]=0.0;
   for(int i=0;i<CT_CAP;i++){ ZeroMemory(ct_tree[i]); ct_tree[i].alive=false; ct_tree[i].parent=-1; }
}

//------------------------------------------------------------------
// f_nodeState — phases EMERGE from the node (Principle 1: curve -> phase)
// (faithful port of F16 f_nodeState)
//------------------------------------------------------------------
string CT_NodeState(const int d,const double e,const int dep,const double cmp,const double mat)
{
   if(dep>0)
      return(e>=70.0 ? "Transition · recursive expansion"
           : e>=40.0 ? "Transition · recursive induction"
                     : "Transition · recursive liquidation");
   if(mat<12.0) return("Point 4 Origin");
   if(e>=78.0 && mat>=70.0) return(d==1 ? "New High" : d==-1 ? "New Low" : "Climax");
   if(mat<35.0) return("Expansion");
   if(mat<55.0) return("Expansion Pre-Convexity");
   if(e>=55.0)  return("Expansion Induction");
   if(e>=35.0)  return("Expansion Liquidity");
   if(cmp>=60.0)return("Retracement Pre-Convexity");
   if(e>=18.0)  return("Retracement Induction");
   return("Retracement");
}

//------------------------------------------------------------------
// shift the oldest node out (keep the array bounded)
//------------------------------------------------------------------
void CT_Shift()
{
   for(int i=1;i<ct_count;i++) ct_tree[i-1]=ct_tree[i];
   if(ct_count>0) ct_count--;
}

//------------------------------------------------------------------
// MASTER ENTRY — Recursive Curve Tree pipeline step
//------------------------------------------------------------------
void CurveTreeRun()
{
   if(!g_cfg.useCurveTree) return;

   FalconHTF  h = g_state.htf;
   double atr   = g_state.physics.atr;
   double close1= gClose[1];
   double hi1   = gHigh[1];
   double lo1   = gLow[1];
   double expE  = g_state.physics.energy;          // expansion-energy proxy (0..100)
   double comp  = g_state.physics.compression;     // chart/operating compression
   double residual = g_state.intel.residualEnergy; // back-filled by Intelligence

   int ot = (h.ownerTF>=0 && h.ownerTF<7) ? h.ownerTF : 4;

   // CHoCH against the owner — the event that nests a child curve
   bool bullCHoCH = (g_state.structure.choch==DIR_LONG);
   bool bearCHoCH = (g_state.structure.choch==DIR_SHORT);

   double ownMinE = g_cfg.ctOwnerMinE;

   //--------------------------------------------------------------
   // PRE-OWNER (Principle 8) — shallowest living node still holding
   // energy; drives the child-spawn direction.
   //--------------------------------------------------------------
   int    preOwn=-1; double preE=-1.0; int preDepth=999;
   for(int i=0;i<ct_count;i++)
   {
      if(ct_tree[i].alive && ct_tree[i].energy>=ownMinE &&
         (ct_tree[i].depth<preDepth || (ct_tree[i].depth==preDepth && ct_tree[i].energy>preE)))
      { preDepth=ct_tree[i].depth; preE=ct_tree[i].energy; preOwn=i; }
   }
   if(preOwn<0)
      for(int i=0;i<ct_count;i++)
         if(ct_tree[i].alive && ct_tree[i].energy>preE){ preE=ct_tree[i].energy; preOwn=i; }

   //--------------------------------------------------------------
   // CONTEXT ANCHOR — the root curve is born from the timeframe-stable
   // OWNER curve, so its origin does not shift with the chart.
   //--------------------------------------------------------------
   int    ctxDir = g_tfCurve[ot].oDir;
   double ctxOrig= g_tfCurve[ot].oOrigin;
   double ctxExt = g_tfCurve[ot].oExtreme;
   if(ctxDir==DIR_NONE){ ctxDir=h.stackDir; }

   // seed / RE-SEED the root whenever no living node owns price
   if(preOwn<0 && ctxDir!=DIR_NONE && ctxOrig!=0.0)
   {
      if(ct_count>=CT_CAP) CT_Shift();
      ct_seq++;
      CTNode root; ZeroMemory(root);
      root.id=ct_seq; root.parent=-1; root.dir=ctxDir;
      root.origin=ctxOrig; root.extreme=(ctxExt!=0.0?ctxExt:close1);
      root.energy=MathMax(40.0, expE>0?expE:60.0);
      root.alive=true; root.depth=0; root.bar=g_barCounter; root.srcTf=ot;
      root.comp=comp; root.mat=g_tfCurve[ot].oCompletion;
      root.state=CT_NodeState(root.dir,root.energy,0,root.comp,root.mat);
      ct_tree[ct_count++]=root;
      FalconPublish(EVT_NODE_BORN, root.origin);
   }

   //--------------------------------------------------------------
   // COMPRESSION BUDGET (Principle 3/4) — how many curves can form.
   //--------------------------------------------------------------
   int budgetDepth = (int)MathMax(1.0, MathMin(4.0, 1.0 + MathRound(comp/33.0)));

   //--------------------------------------------------------------
   // EVENT-GENERATED CHILD — a CHoCH against the owner spawns an
   // inverse curve, while the recursion budget still has room.
   //--------------------------------------------------------------
   bool spawnedChild=false;
   if(preOwn>=0)
   {
      int pdir=ct_tree[preOwn].dir;
      bool against = (pdir==DIR_LONG && bearCHoCH) || (pdir==DIR_SHORT && bullCHoCH);
      if(against && (ct_tree[preOwn].depth+1<=budgetDepth))
      {
         if(ct_count>=CT_CAP) CT_Shift();
         ct_seq++;
         CTNode ch; ZeroMemory(ch);
         ch.id=ct_seq; ch.parent=ct_tree[preOwn].id; ch.dir=-pdir;
         ch.origin=close1; ch.extreme=close1;
         ch.energy=MathMax(25.0, (expE>0?expE:50.0)*0.85);
         ch.alive=true; ch.depth=ct_tree[preOwn].depth+1; ch.bar=g_barCounter; ch.srcTf=0;
         ch.comp=comp; ch.mat=0.0;
         ch.state=CT_NodeState(ch.dir,ch.energy,ch.depth,ch.comp,ch.mat);
         ct_tree[ct_count++]=ch;
         spawnedChild=true;
         FalconPublish(EVT_NODE_BORN, ch.origin);
      }
   }

   //--------------------------------------------------------------
   // UPDATE LIVING NODES — energy rises on progress, decays on stall.
   //--------------------------------------------------------------
   for(int i=0;i<ct_count;i++)
   {
      if(!ct_tree[i].alive) continue;
      // depth-0 root mirrors its source TF's live curve (dir/origin/extreme)
      if(ct_tree[i].depth==0)
      {
         int st=ct_tree[i].srcTf; if(st<0||st>6) st=ot;
         ct_tree[i].dir    = (g_tfCurve[st].oDir!=DIR_NONE? g_tfCurve[st].oDir : ct_tree[i].dir);
         ct_tree[i].origin = (g_tfCurve[st].oOrigin!=0.0? g_tfCurve[st].oOrigin : ct_tree[i].origin);
         ct_tree[i].extreme= (g_tfCurve[st].oExtreme!=0.0? g_tfCurve[st].oExtreme : ct_tree[i].extreme);
         ct_tree[i].mat    = g_tfCurve[st].oCompletion;
      }
      bool prog = (ct_tree[i].dir==DIR_LONG ? hi1>ct_tree[i].extreme : lo1<ct_tree[i].extreme);
      if(ct_tree[i].depth>0)
         ct_tree[i].extreme = (ct_tree[i].dir==DIR_LONG ? MathMax(ct_tree[i].extreme,hi1)
                                                        : MathMin(ct_tree[i].extreme,lo1));
      ct_tree[i].energy = prog ? MathMin(100.0, ct_tree[i].energy + g_cfg.ctProgressGain)
                               : MathMax(0.0,   ct_tree[i].energy - g_cfg.ctStallDecay);
      ct_tree[i].comp   = comp;
      ct_tree[i].state  = CT_NodeState(ct_tree[i].dir, ct_tree[i].energy, ct_tree[i].depth, ct_tree[i].comp, ct_tree[i].mat);
      if(ct_tree[i].energy<=2.0) ct_tree[i].alive=false;
   }

   // trim dead/old beyond budget
   while(ct_count > g_cfg.ctMaxNodes) CT_Shift();

   //--------------------------------------------------------------
   // FINAL OWNER (Principle 8) + tree summary
   //--------------------------------------------------------------
   int    alive=0, treeDepth=0;
   int    ownF=-1; double ownFE=-1.0; int ownDepth=999;
   for(int i=0;i<ct_count;i++)
   {
      if(!ct_tree[i].alive) continue;
      alive++;
      if(ct_tree[i].depth>treeDepth) treeDepth=ct_tree[i].depth;
      if(ct_tree[i].energy>=ownMinE &&
         (ct_tree[i].depth<ownDepth || (ct_tree[i].depth==ownDepth && ct_tree[i].energy>ownFE)))
      { ownDepth=ct_tree[i].depth; ownFE=ct_tree[i].energy; ownF=i; }
   }
   if(ownF<0)
      for(int i=0;i<ct_count;i++)
         if(ct_tree[i].alive && ct_tree[i].energy>ownFE){ ownFE=ct_tree[i].energy; ownF=i; }

   //--------------------------------------------------------------
   // COMPRESSION PERSISTENCE (Principle 10) — can the COUNTER side even
   // generate room to build? Tightening + concentrated energy + few
   // recursions ⇒ the opposite side suffocates (PERSISTING).
   //--------------------------------------------------------------
   double comp5 = (ct_compFull ? ct_compHist[(ct_compIdx)%6] : comp); // value ~5 bars ago
   double cmpTighten = comp - comp5;
   double compForce = FalconClamp(comp*0.50 + residual*0.20 - treeDepth*12.0
                                  + MathMax(0.0,cmpTighten)*0.8 + 8.0, 0, 100);
   string compState = compForce>=60.0 ? "PERSISTING" : compForce<=35.0 ? "LEAKING" : "NEUTRAL";
   // push current compression into the ring
   ct_compHist[ct_compIdx]=comp; ct_compIdx=(ct_compIdx+1)%6; if(ct_compIdx==0) ct_compFull=true;

   bool recursionComplete = (budgetDepth>0 && treeDepth>=budgetDepth);

   //--------------------------------------------------------------
   // NARRATIVE LINEAGE — each completed child (pullback) votes SUPPORT
   // (shallow retrace + tightening) or DEGRADE (deep retrace + broadening).
   // A converging sequence ⇒ strengthening; diverging ⇒ ownership about
   // to transfer.
   //--------------------------------------------------------------
   int ownDirT = (ownF>=0 ? ct_tree[ownF].dir : DIR_NONE);
   double ownOrig = (ownF>=0 ? ct_tree[ownF].origin : 0.0);
   double ownExt  = (ownF>=0 ? ct_tree[ownF].extreme: 0.0);
   if(ownDirT!=ct_narrDir){ ct_narrDir=ownDirT; ct_supVotes=0; ct_degVotes=0; ct_narrative=50.0; }
   if(spawnedChild)
   {
      double retrX = (ownExt==ownOrig) ? 50.0
                     : FalconClamp(MathAbs(ownExt-close1)/MathMax(MathAbs(ownExt-ownOrig),1e-10)*100.0,0,100);
      bool support = (retrX<45.0 && cmpTighten>0.0);
      bool degrade = (retrX>60.0 && cmpTighten<0.0);
      if(support) ct_supVotes++;
      else if(degrade) ct_degVotes++;
      ct_narrative = FalconClamp(50.0 + (ct_supVotes-ct_degVotes)*10.0, 0, 100);
   }

   // migrated ownership band — 0.5 / 0.618 retrace of the owner curve leg
   double mig50  = (ownOrig==0.0||ownExt==0.0) ? 0.0 : ownExt + 0.5  *(ownOrig-ownExt);
   double mig618 = (ownOrig==0.0||ownExt==0.0) ? 0.0 : ownExt + 0.618*(ownOrig-ownExt);

   //--------------------------------------------------------------
   // ENRICH SHARED STATE (additive — does NOT change ownerDir/phase)
   //--------------------------------------------------------------
   g_state.curve.treeNodeCount   = alive;
   g_state.curve.treeDepth       = treeDepth;
   g_state.curve.budgetDepth     = budgetDepth;
   g_state.curve.recursionComplete = recursionComplete;
   g_state.curve.ownerNodeDir    = ownDirT;
   g_state.curve.ownerNodeEnergy = (ownF>=0 ? ct_tree[ownF].energy : 0.0);
   g_state.curve.ownerNodeDepth  = (ownF>=0 ? ct_tree[ownF].depth  : 0);
   g_state.curve.ownerNodeOrigin = ownOrig;
   g_state.curve.ownerNodeExtreme= ownExt;
   g_state.curve.ownerNodeState  = (ownF>=0 ? ct_tree[ownF].state : "—");
   g_state.curve.compForce       = compForce;
   g_state.curve.compState       = compState;
   g_state.curve.migration50     = mig50;
   g_state.curve.migration618    = mig618;
   g_state.curve.narrative       = ct_narrative;
   g_state.curve.supportVotes    = ct_supVotes;
   g_state.curve.degradeVotes    = ct_degVotes;
   // emergent-node count = living recursion children (depth>0)
   int kids=0; for(int i=0;i<ct_count;i++) if(ct_tree[i].alive && ct_tree[i].depth>0) kids++;
   g_state.curve.emergentNodes   = kids;
   g_state.curve.childCount      = kids;
}

#endif // FALCON_CURVE_TREE_MQH
//+------------------------------------------------------------------+
