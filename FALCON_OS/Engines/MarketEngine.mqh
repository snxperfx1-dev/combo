//+------------------------------------------------------------------+
//|  FALCON OS — Market Layer : MarketEngine.mqh                     |
//|  Source: LETRA (Core Market Intelligence)                       |
//|                                                                  |
//|  PURE MARKET MODEL. No dashboards. No execution. It observes     |
//|  reality and writes it into g_state.{physics,structure,          |
//|  liquidity,convexity,wave,fu,htf}. Phases are OUTPUTS computed    |
//|  from the engines — never inputs to any decision.                |
//|                                                                  |
//|  Consolidates (de-duplicates) physics, structure, liquidity,     |
//|  wave, FU, HTF that previously existed 3x across the codebases.  |
//+------------------------------------------------------------------+
#ifndef FALCON_MARKET_ENGINE_MQH
#define FALCON_MARKET_ENGINE_MQH

#include "../Kernel/FalconState.mqh"
#include "../Kernel/FalconConfig.mqh"
#include "../Kernel/FalconSeries.mqh"
#include "../Kernel/FalconEventBus.mqh"

//==================================================================
// PERSISTENT PHYSICS STATE (per-bar EMA chain, matches f_phys)
//==================================================================
double me_vel=0, me_velPrev=0, me_velPrev2=0;
double me_acc=0, me_accPrev=0;
double me_conv=0, me_csm=0, me_csmPrev=0;
bool   me_physInit=false;

//==================================================================
// PERSISTENT WAVE / STRUCTURE STATE (matches f_se var-state)
//==================================================================
int    me_dir          = 0;     // engine spawn direction
double me_curSH=0, me_curSL=0, me_prSH=0, me_prSL=0;
double me_lastP=0, me_prevP=0;
int    me_lastD=0,  me_prevD=0;
double me_ft=0, me_fb=0, me_p4h=0, me_p4l=0, me_inv=0, me_tgt=0;
double me_cycH=0, me_cycL=0;
int    me_pst=0, me_lastDirSeen=0;
bool   me_bos1=false, me_bos2=false;
double me_protSw=0, me_protSw2=0, me_indOrig=0, me_indExt=0;
bool   me_indBrk=false;
int    me_recBrk=0;  bool me_recArm=true;
int    me_waveSpawnBar=0;
// entry-cycle recursion tracking (ported from F16 spawn engine)
int    me_entryCycle=0; int me_waveDepth=0; bool me_isRecursive=false;
bool   me_recursiveComplete=false; int me_recursiveFiredBar=-1; int me_prevPstForCycle=0;

// Absolute HTF rung ladder: [0]M1 [1]M5 [2]M15 [3]H1 [4]H4 [5]D1 [6]W1
// (index 0 = lowest TF, index 6 = highest). Fixed/absolute so the fractal
// model is chart-invariant: the chart is only a viewport.
ENUM_TIMEFRAMES me_htfTF[7];
int             me_htfDirState[7];
double          me_htfOrigin[7];
double          me_htfExtreme[7];

//==================================================================
// PER-TIMEFRAME CURVE FSM — a REAL wave engine run on each rung so the
// HTF stack / curve tree reflect genuine nested curves (dir + phase +
// completion + recursion per timeframe), not just a direction read.
//==================================================================
struct TFCurve
{
   bool   init;
   double vel, velPrev, acc, accPrev, csm, csmPrev;
   double curSH, curSL, prSH, prSL, lastP, prevP;
   int    lastD, prevD;
   int    dir;
   double ft, fb, p4h, p4l, inv, tgt, cycH, cycL;
   int    pst, lastDirSeen;
   bool   bos1, bos2;
   double protSw, protSw2;
   int    recBrk; bool recArm;
   int    spawnBar;
   // outputs
   int    oDir, oPhase, oRecBrk;
   double oCompletion, oOrigin, oExtreme, oObjective, oDom;
};
TFCurve g_tfCurve[7];

//==================================================================
// PER-TIMEFRAME ZONES — liquidity pools/sweeps, order blocks and
// supply/demand computed on EACH absolute rung (W1..M1), so the zone
// engines are genuinely fractal, not just run on the operating TF.
// Mirrors the operating-TF definitions (OB = last opposing candle
// before an impulse; S/D = OB / flip band +- inducZoneWidth).
//==================================================================
struct FalconTFZones
{
   bool   valid;
   double atr;
   double obTop, obBot;  int obDir;
   double demTop, demBot, supTop, supBot;
   double swingHi, swingLo;
   double poolHi, poolLo;
   bool   sweptHi, sweptLo;
   bool   inDemand, inSupply;
};
FalconTFZones g_tfZones[7];
int           me_opTFIdx = -1;   // ladder index of the operating TF (-1 if not a rung)

void MarketEngineInit()
{
   me_physInit=false;
   me_vel=0; me_velPrev=0; me_velPrev2=0; me_acc=0; me_accPrev=0;
   me_conv=0; me_csm=0; me_csmPrev=0;
   me_dir=0; me_pst=0; me_lastDirSeen=0;
   me_ft=0; me_fb=0; me_p4h=0; me_p4l=0; me_inv=0; me_tgt=0;
   me_cycH=0; me_cycL=0;
   me_curSH=0; me_curSL=0; me_prSH=0; me_prSL=0;
   me_lastP=0; me_prevP=0; me_lastD=0; me_prevD=0;
   me_bos1=false; me_bos2=false; me_protSw=0; me_protSw2=0;
   me_indOrig=0; me_indExt=0; me_indBrk=false;
   me_recBrk=0; me_recArm=true;
   me_entryCycle=0; me_waveDepth=0; me_isRecursive=false;
   me_recursiveComplete=false; me_recursiveFiredBar=-1; me_prevPstForCycle=0;

   me_obCount=0;

   me_htfTF[0]=PERIOD_M1;  me_htfTF[1]=PERIOD_M5;  me_htfTF[2]=PERIOD_M15;
   me_htfTF[3]=PERIOD_H1;  me_htfTF[4]=PERIOD_H4;  me_htfTF[5]=PERIOD_D1;
   me_htfTF[6]=PERIOD_W1;
   me_opTFIdx = -1;
   for(int i=0;i<7;i++){ if(me_htfTF[i]==g_cfg.operatingTF){ me_opTFIdx=i; break; } }
   for(int i=0;i<7;i++) ZeroMemory(g_tfZones[i]);
   for(int i=0;i<7;i++){ me_htfDirState[i]=0; me_htfOrigin[i]=0; me_htfExtreme[i]=0; }
   for(int i=0;i<7;i++)
   {
      ZeroMemory(g_tfCurve[i]);
      g_tfCurve[i].init=false; g_tfCurve[i].lastD=0; g_tfCurve[i].prevD=0;
      g_tfCurve[i].dir=0; g_tfCurve[i].pst=0; g_tfCurve[i].lastDirSeen=0; g_tfCurve[i].recArm=true;
   }
}

//==================================================================
// 1. PHYSICS  (verbatim port of f_phys, per confirmed bar)
//==================================================================
void ME_UpdatePhysics()
{
   FalconPhysics p;
   double atr   = FalconATR(1,0);
   p.atr        = atr;
   p.atrFast    = FalconATR(1,1);
   p.atrSlow    = FalconATR(1,2);
   p.volatility = (p.atrSlow>0 ? p.atrFast/p.atrSlow : 1.0);

   // EMA velocity chain on last closed bar delta
   double d = gClose[1]-gClose[2];
   if(!me_physInit)
   {
      me_vel=d; me_velPrev=d; me_velPrev2=d; me_acc=0; me_accPrev=0;
      me_conv=0; me_csm=0; me_csmPrev=0; me_physInit=true;
   }
   else
   {
      me_velPrev2 = me_velPrev;
      me_velPrev  = me_vel;
      me_vel      = FalconEMA(me_vel, d, 3);
      me_accPrev  = me_acc;
      me_acc      = me_vel - me_velPrev;
      double convNow = me_acc - me_accPrev;
      me_conv     = convNow;
      me_csmPrev  = me_csm;
      me_csm      = FalconEMA(me_csm, convNow, 3);
   }

   p.velocity        = me_vel;
   p.acceleration    = me_acc;
   p.convexity       = me_conv;
   p.convexitySmooth = me_csm;

   // efficiency over effLen window ending at last closed bar
   int eff = g_cfg.effLen;
   double mv = MathAbs(gClose[1]-gClose[1+eff]);
   double ps = 0.0;
   for(int i=1;i<=eff;i++) ps += MathAbs(gClose[i]-gClose[i+1]);
   p.efficiency   = (ps>0 ? mv/ps : 0.0);
   p.displacement = (gHigh[1]-gLow[1])/MathMax(atr,1e-10);
   p.momentum     = MathAbs(me_vel);

   double cth = atr*g_cfg.convMult;
   bool open_gt = (gClose[1]>gOpen[1]);
   bool open_lt = (gClose[1]<gOpen[1]);
   p.bullImpulse = (p.efficiency>g_cfg.effThresh && me_vel>me_velPrev && me_acc>0 && open_gt && p.displacement>g_cfg.dispThresh);
   p.bearImpulse = (p.efficiency>g_cfg.effThresh && me_vel<me_velPrev && me_acc<0 && open_lt && p.displacement>g_cfg.dispThresh);
   p.bullDecay   = (MathAbs(me_acc)<MathAbs(me_accPrev)*0.8 && me_vel>0);
   p.bearDecay   = (MathAbs(me_acc)<MathAbs(me_accPrev)*0.8 && me_vel<0);
   p.bullConvShift = (me_csm> cth && me_csmPrev<= cth);
   p.bearConvShift = (me_csm<-cth && me_csmPrev>=-cth);

   // energy / compression / expansion (LETRA scoring distilled)
   double expScore = FalconClamp((p.efficiency>g_cfg.effThresh ? p.efficiency*60.0 : p.efficiency*30.0)
                     + (p.displacement>g_cfg.dispThresh ? (p.displacement/MathMax(g_cfg.dispThresh,1e-10)-1.0)*20.0 : 0.0),0,100);
   p.expansion   = expScore;
   p.energy      = FalconClamp(expScore*0.5 + ((p.bullImpulse||p.bearImpulse)?30.0:0.0) + p.efficiency*20.0,0,100);
   p.compression = FalconClamp((1.0-MathMin(p.displacement/MathMax(g_cfg.dispThresh,1e-10),1.0))*60.0
                     + (1.0-MathMin(p.efficiency/MathMax(g_cfg.effThresh,1e-10),1.0))*40.0,0,100);
   p.volatility  = (p.atrSlow>0 ? p.atrFast/p.atrSlow : 1.0);

   g_state.physics = p;

   if(p.bullImpulse) FalconPublish(EVT_IMPULSE_BULL, gClose[1]);
   if(p.bearImpulse) FalconPublish(EVT_IMPULSE_BEAR, gClose[1]);
}

//==================================================================
// 2. STRUCTURE  (pivots, swings, HH/HL/LH/LL, BOS, CHoCH, trend)
//==================================================================
void ME_UpdateStructure()
{
   FalconStructure s;
   double atr = g_state.physics.atr;
   int pv = g_cfg.structLen;
   int center = pv+1;

   // detect a freshly-confirmed pivot at the center
   double eP=0; int eD=0;
   if(FalconIsPivotHigh(center,pv)) { eP=gHigh[center]; eD=1; }
   else if(FalconIsPivotLow(center,pv)) { eP=gLow[center]; eD=-1; }

   if(eD==1)
   {
      me_prSH = (me_curSH==0 ? gHigh[center] : me_curSH);
      me_curSH = gHigh[center];
   }
   else if(eD==-1)
   {
      me_prSL = (me_curSL==0 ? gLow[center] : me_curSL);
      me_curSL = gLow[center];
   }
   if(eD!=0)
   {
      me_prevP=me_lastP; me_prevD=me_lastD;
      me_lastP=eP;       me_lastD=eD;
   }

   double close1 = gClose[1];
   bool bullBOS = (me_prSH!=0 && close1>me_prSH);
   bool bearBOS = (me_prSL!=0 && close1<me_prSL);
   bool bullCH  = (me_prSH!=0 && close1>me_prSH + atr*g_cfg.chochBufferATR);
   bool bearCH  = (me_prSL!=0 && close1<me_prSL - atr*g_cfg.chochBufferATR);

   s.swingHigh     = me_curSH;
   s.swingLow      = me_curSL;
   s.prevSwingHigh = me_prSH;
   s.prevSwingLow  = me_prSL;
   s.hh = (me_curSH!=0 && me_prSH!=0 && me_curSH>me_prSH);
   s.lh = (me_curSH!=0 && me_prSH!=0 && me_curSH<me_prSH);
   s.hl = (me_curSL!=0 && me_prSL!=0 && me_curSL>me_prSL);
   s.ll = (me_curSL!=0 && me_prSL!=0 && me_curSL<me_prSL);
   s.bos   = bullBOS ? DIR_LONG : bearBOS ? DIR_SHORT : DIR_NONE;
   s.choch = bullCH  ? DIR_LONG : bearCH  ? DIR_SHORT : DIR_NONE;
   s.breakStrength = (atr>0 ? MathAbs(close1-(s.bos==DIR_LONG?me_prSH:me_prSL))/atr : 0.0);

   if(s.hh && s.hl) s.trend = DIR_LONG;
   else if(s.lh && s.ll) s.trend = DIR_SHORT;
   else if(bullBOS) s.trend = DIR_LONG;
   else if(bearBOS) s.trend = DIR_SHORT;
   else s.trend = g_state.structure.trend; // persist

   s.internalStruct = (close1>me_curSL && close1<me_curSH) ? s.trend : DIR_NONE;
   s.externalStruct = s.trend;

   g_state.structure = s;

   if(s.bos!=DIR_NONE)   FalconPublish(EVT_BOS, s.bos);
   if(s.choch!=DIR_NONE) FalconPublish(EVT_CHOCH, s.choch);
}

//==================================================================
// 3. LIQUIDITY  (pools from pivots, sweeps, density, heat, pressure)
//==================================================================
double me_liqLvl[256];
double me_liqWt[256];
int    me_liqAge[256];
int    me_liqCount=0;

void ME_UpdateLiquidity()
{
   FalconLiquidity lq;
   double atr = g_state.physics.atr;
   int pv = g_cfg.pivotLen;

   // push a new liquidity level when a pivot confirms
   bool ph = FalconIsPivotHigh(pv+1,pv);
   bool pl = FalconIsPivotLow(pv+1,pv);
   if(ph || pl)
   {
      double lvl = ph ? gHigh[pv+1] : gLow[pv+1];
      double swRng = (gHigh[pv+1]-gLow[pv+1])/MathMax(atr,1e-10);
      if(me_liqCount<256)
      {
         me_liqLvl[me_liqCount]=lvl;
         me_liqWt[me_liqCount]=MathMax(swRng,0.1);
         me_liqAge[me_liqCount]=g_barCounter;
         me_liqCount++;
      }
      else
      {
         for(int i=1;i<256;i++){ me_liqLvl[i-1]=me_liqLvl[i]; me_liqWt[i-1]=me_liqWt[i]; me_liqAge[i-1]=me_liqAge[i]; }
         me_liqLvl[255]=lvl; me_liqWt[255]=MathMax(swRng,0.1); me_liqAge[255]=g_barCounter;
      }
   }

   double close1=gClose[1];
   double radius = atr*g_cfg.liqRadius;
   double wide   = radius*3.0;
   double dens=0, densAbove=0, densBelow=0;
   for(int i=0;i<me_liqCount;i++)
   {
      int age = g_barCounter - me_liqAge[i];
      double dcy = MathPow(g_cfg.liqAgeDecay, age);
      double dist= MathAbs(close1-me_liqLvl[i]);
      if(dist<radius) dens += me_liqWt[i]*dcy;
      if(dist<wide)
      {
         if(me_liqLvl[i]>close1) densAbove += me_liqWt[i]*dcy*(1.0-dist/wide);
         else                    densBelow += me_liqWt[i]*dcy*(1.0-dist/wide);
      }
   }
   lq.clusterDensity = dens;
   lq.score          = FalconClamp(MathMin((densAbove+densBelow)/2.0,5.0)/5.0*100.0,0,100);
   lq.vacuum         = (dens<0.5);
   lq.pressure       = FalconClamp((densBelow-densAbove)/MathMax(densAbove+densBelow,1e-9)*100.0,-100,100);

   // sweeps relative to wave flip levels
   double swH = FalconHighest(1,g_cfg.liqSweepLookbk);
   double swL = FalconLowest(1,g_cfg.liqSweepLookbk);
   lq.sweepBull = (me_ft!=0 && swH>me_ft);
   lq.sweepBear = (me_fb!=0 && swL<me_fb);
   lq.sweepProbability = FalconClamp(lq.score*0.5 + (lq.vacuum?40.0:0.0),0,100);

   // copy active pools (most recent, capped)
   lq.poolCount=0;
   for(int i=me_liqCount-1;i>=0 && lq.poolCount<64;i--)
      lq.pools[lq.poolCount++]=me_liqLvl[i];

   lq.inducement  = (me_indOrig!=0);
   lq.falseChoch  = (me_recBrk>=2);
   lq.acceptance  = (close1>me_fb && close1<me_ft && me_ft!=0);

   g_state.liquidity = lq;

   if(lq.sweepBull || lq.sweepBear) FalconPublish(EVT_LIQ_SWEEP, lq.sweepBull?1:-1);
}

//==================================================================
// 3B. INDUCEMENT ENGINE  (LETRA f_findInducPrice — the lure level
//     inside the working range that price is induced to take before
//     the real move). Explicit engine writing the inducement zone.
//==================================================================
void ME_UpdateInducement()
{
   FalconLiquidity lq = g_state.liquidity;
   double atr   = g_state.physics.atr;
   double top   = me_ft, bot = me_fb;
   double close1= gClose[1];

   lq.inducePrice=0; lq.induceTop=0; lq.induceBot=0; lq.induceActive=false; lq.induceSwept=false;

   if(top!=0 && bot!=0 && top>bot)
   {
      // nearest interior bar fully inside the flip range -> its midpoint is the lure
      double best=0; int bestDist=-1;
      int lookback=g_cfg.inducLookback;
      int maxBars=FalconBars();
      for(int s=2;s<2+lookback && s<maxBars;s++)
      {
         if(gHigh[s]<top && gLow[s]>bot)
         {
            int dist=s;
            if(bestDist<0 || dist<bestDist){ bestDist=dist; best=(gHigh[s]+gLow[s])*0.5; }
         }
      }
      if(bestDist>=0)
      {
         lq.inducePrice=best;
         lq.induceTop=best+atr*g_cfg.inducZoneWidth;
         lq.induceBot=best-atr*g_cfg.inducZoneWidth;
         lq.induceActive=true;
         // swept when price has traded through the lure in the wave direction
         lq.induceSwept = (me_dir==1 ? gLow[1]<=lq.induceBot : me_dir==-1 ? gHigh[1]>=lq.induceTop : false);
      }
   }
   g_state.liquidity=lq;
}

//==================================================================
// 4. WAVE MACHINE  (verbatim port of f_se spawn + 0..14 phase FSM)
//==================================================================
void ME_UpdateWave()
{
   FalconWave w = g_state.wave;
   double atr = g_state.physics.atr;
   double close1=gClose[1];
   int prevPhase = me_pst;

   bool bullBOS=(g_state.structure.bos==DIR_LONG);
   bool bearBOS=(g_state.structure.bos==DIR_SHORT);
   bool bullCH =(g_state.structure.choch==DIR_LONG);
   bool bearCH =(g_state.structure.choch==DIR_SHORT);

   // impulse-driven reversal detection (pivot legs)
   bool pH = FalconIsPivotHigh(g_cfg.structLen+1,g_cfg.structLen);
   bool pL = FalconIsPivotLow (g_cfg.structLen+1,g_cfg.structLen);
   bool eLong  = (pH && me_prevD==-1 && (me_lastP-me_prevP)>atr*g_cfg.impulseAtrMult);
   bool eShort = (pL && me_prevD== 1 && (me_prevP-me_lastP)>atr*g_cfg.impulseAtrMult);

   bool hasCtx = (me_dir!=0 && me_ft!=0);
   bool flipDn = (me_dir==1  && bearCH);
   bool flipUp = (me_dir==-1 && bullCH);
   bool isRev  = (eLong && me_dir==-1) || (eShort && me_dir==1) || flipUp || flipDn;
   bool spawn  = (eLong || eShort || flipUp || flipDn) && (!hasCtx || isRev);

   if(spawn)
   {
      int nd = eLong?1: eShort?-1: flipUp?1:-1;
      double hi = MathMax(me_lastP,me_prevP);
      double lo = MathMin(me_lastP,me_prevP);
      me_dir = nd;
      me_ft  = hi;  me_fb = lo;
      me_p4h = hi;  me_p4l = lo;
      me_cycH= gHigh[1]; me_cycL=gLow[1];
      me_inv = (nd==1 ? lo : hi);
      double rng = (me_prSH!=0 && me_prSL!=0) ? MathAbs(me_prSH-me_prSL) : atr*5.0;
      me_tgt = (nd==1 ? hi+rng : lo-rng);
      me_waveSpawnBar = g_barCounter;
      me_entryCycle=0; me_waveDepth=0; me_isRecursive=false; me_recursiveComplete=false;
      me_recursiveFiredBar=-1; me_prevPstForCycle=0;
      FalconPublish(EVT_WAVE_SPAWN, nd);
   }
   if(me_dir==1)  me_cycH = (me_cycH==0?gHigh[1]:MathMax(me_cycH,gHigh[1]));
   if(me_dir==-1) me_cycL = (me_cycL==0?gLow[1]:MathMin(me_cycL,gLow[1]));

   // reset block on direction change
   bool reset = (me_dir!=me_lastDirSeen);
   me_lastDirSeen = me_dir;
   if(reset)
   {
      me_bos1=false; me_bos2=false; me_protSw=0; me_protSw2=0;
      me_indOrig=0; me_indExt=0; me_indBrk=false;
   }
   if(me_dir==1 && pL){ me_protSw2=me_protSw; me_protSw=gLow[g_cfg.structLen+1]; }
   if(me_dir==-1&& pH){ me_protSw2=me_protSw; me_protSw=gHigh[g_cfg.structLen+1]; }

   bool oppBOS = (me_dir==1 && me_protSw!=0 && close1<me_protSw) || (me_dir==-1 && me_protSw!=0 && close1>me_protSw);
   if(!me_bos1 && oppBOS){ me_bos1=true; me_indOrig=(me_dir==1?me_cycH:me_cycL); }
   if(me_bos1 && !me_bos2 && oppBOS && me_protSw2!=0 && (me_dir==1?close1<me_protSw2:close1>me_protSw2)) me_bos2=true;
   if(me_bos1 && me_dir==1)  me_indExt=(me_indExt==0?close1:MathMin(me_indExt,close1));
   if(me_bos1 && me_dir==-1) me_indExt=(me_indExt==0?close1:MathMax(me_indExt,close1));
   if(me_bos2 && me_indOrig!=0)
   {
      if(me_dir==1 && close1>me_indOrig)  me_indBrk=true;
      if(me_dir==-1&& close1<me_indOrig)  me_indBrk=true;
   }

   // physics-derived gating
   FalconPhysics ph2 = g_state.physics;
   double convScore = MathMin(MathAbs(me_csm)/MathMax(atr*g_cfg.convMult,1e-10)*50.0,100.0);
   double expScore  = MathMin(ph2.efficiency/MathMax(g_cfg.effThresh,1e-10)*50.0 + ph2.displacement/MathMax(g_cfg.dispThresh,1e-10)*50.0,100.0);
   double absScore  = (ph2.efficiency<g_cfg.effThresh*0.7 && MathAbs(me_vel)<MathAbs(me_velPrev)*0.6) ? 60.0+convScore*0.4 : convScore*0.3;
   bool momExpStrong= ph2.efficiency>g_cfg.effThresh*0.75 && (me_dir==1?me_vel>0:me_vel<0);
   bool momDecaying = (me_dir==1?ph2.bullDecay:ph2.bearDecay);
   bool momCounter  = (me_dir==1?ph2.bearImpulse:ph2.bullImpulse);
   bool momExhaust  = ph2.efficiency<g_cfg.effThresh*0.65 && absScore>40.0;
   bool physConvDev = convScore>35.0;
   bool physTransfer= convScore>48.0 || absScore>40.0;
   bool physCapLow  = absScore>45.0 || ph2.efficiency<g_cfg.effThresh*0.6;

   int wdir = (me_inv!=0 ? (close1>me_inv?1:close1<me_inv?-1:me_dir) : me_dir);
   bool atFlip   = (me_ft!=0 && me_fb!=0 && close1<=me_ft && close1>=me_fb);
   bool expanding= momExpStrong || eLong || eShort || (wdir==1?ph2.bullImpulse:ph2.bearImpulse);
   bool atExtreme= (wdir==1 ? gHigh[1]>=(me_cycH==0?gHigh[1]:me_cycH) : wdir==-1 ? gLow[1]<=(me_cycL==0?gLow[1]:me_cycL) : false);
   double extr   = (wdir==1?(me_cycH==0?close1:me_cycH):(me_cycL==0?close1:me_cycL));
   bool extended = (me_inv!=0 && MathAbs(extr-me_inv)>atr*1.5);
   double fzMid  = (me_ft!=0 && me_fb!=0)?(me_ft+me_fb)/2.0:0.0;
   double retrFrac=(fzMid!=0 && MathAbs(extr-fzMid)>1e-10)?MathAbs(extr-close1)/MathAbs(extr-fzMid):0.0;

   double compIdx = ph2.compression;

   // recursive transition counting
   bool phase2CH = (me_dir==1 && bearCH)||(me_dir==-1 && bullCH);
   if(reset || (atExtreme && extended)){ me_recBrk=0; me_recArm=true; }
   if((me_dir==1 && pH)||(me_dir==-1 && pL)) me_recArm=true;
   if((phase2CH||oppBOS) && me_recArm && !atExtreme){ me_recBrk++; me_recArm=false; }
   double recDom = MathMin(MathMax(me_recBrk*(30.0-compIdx*0.15), retrFrac*80.0),100.0);
   bool transferDone = recDom>=50.0;

   // single-latch phase FSM
   if(reset) me_pst=0;
   if(me_dir!=0 && !reset)
   {
      if(me_pst==0 && expanding) me_pst=1;
      if(me_pst==1 && !atExtreme && momDecaying && physConvDev) me_pst=2;
      if(me_pst==2 && !atExtreme && momCounter && physTransfer) me_pst=3;
      if(me_pst==3 && !atExtreme && (me_bos1||me_bos2||me_indBrk) && physTransfer) me_pst=4;
      if(me_pst>=1 && me_pst<=7 && atExtreme && extended) me_pst=5;
      if(me_pst==5 && !atExtreme && (me_recBrk>=1 || momExhaust)) me_pst=7;
      if(me_pst==7 && transferDone) me_pst=8;
      if(me_pst==8 && atFlip) me_pst=9;
      if(me_pst==9 && ((me_dir==1 && ph2.bullImpulse)||(me_dir==-1 && ph2.bearImpulse))) me_pst=10;
      if(me_pst==10 && (oppBOS || physCapLow)) me_pst=11;
      if(me_pst==11 && ((me_dir==1 && gLow[1]<me_fb)||(me_dir==-1 && gHigh[1]>me_ft))) me_pst=12;
      if(me_pst==12 && ((me_dir==1 && bullCH)||(me_dir==-1 && bearCH))) me_pst=13;
   }
   int phase = me_pst;
   if(phase==5 && me_dir==-1) phase=6;
   if(phase==13 && me_dir==-1) phase=14;

   // --- ENTRY-CYCLE / RECURSION DEPTH (F16 spawn-engine port) ---
   // Each completed terminal recursion (the return confirming after an
   // induction-liquidation sequence) is one Wyckoff "shift". Count them,
   // capped at 4 (spring/test/LPS1/LPS2). A fresh return that holds advances
   // the entry-cycle generation; compression decides how fast they stack.
   bool enteredReturn = ((me_pst==13) && me_prevPstForCycle!=13);
   bool freshFire = enteredReturn &&
                    (me_recursiveFiredBar<0 || (g_barCounter-me_recursiveFiredBar) > g_cfg.structLen);
   if(freshFire)
   {
      me_entryCycle = MathMin(me_entryCycle+1, 4);
      me_waveDepth  = me_entryCycle;
      me_isRecursive= (me_entryCycle>0);
      me_recursiveComplete = true;
      me_recursiveFiredBar = g_barCounter;
   }
   me_prevPstForCycle = me_pst;

   // wave progress mapping
   double wp = (me_pst==0?5.0:me_pst==1?15.0:me_pst==2?25.0:me_pst==3?33.0:me_pst==4?42.0:
                me_pst==5?55.0:me_pst==7?65.0:me_pst==8?75.0:me_pst==9?85.0:me_pst==10?90.0:
                me_pst==11?94.0:me_pst==12?97.0:100.0);
   double mf = MathMin(MathMax(expScore,MathMax(absScore,convScore))*0.70 + (me_dir!=0?30.0:0.0),100.0);

   w.phase            = phase;
   w.prevPhase        = prevPhase;
   w.direction        = wdir;
   w.strength         = mf;
   w.energy           = ph2.energy;
   w.age              = g_barCounter - me_waveSpawnBar;
   w.completion       = wp;
   w.confidence       = mf;
   w.origin           = me_inv;
   w.extreme          = extr;
   w.objective        = me_tgt;
   w.flipTop          = me_ft;
   w.flipBot          = me_fb;
   w.point4High       = me_p4h;
   w.point4Low        = me_p4l;
   w.cycleHigh        = me_cycH;
   w.cycleLow         = me_cycL;
   w.recursionBreaks  = me_recBrk;
   w.dominanceTransfer= recDom;
   w.recursiveComplete= me_recursiveComplete;
   w.entryCycle       = me_entryCycle;
   w.waveDepth        = me_waveDepth;

   // discrete sub-state scores (spec MarketState.Wave members) — derived from
   // the physics/geometry, peaking in their respective lifecycle windows.
   w.expansionScore    = FalconClamp(expScore,0,100);
   w.preConvexityScore = FalconClamp((ph2.bullDecay||ph2.bearDecay?50.0:0.0)+convScore*0.5,0,100);
   w.convexityScore    = FalconClamp(convScore,0,100);
   w.inductionScore    = FalconClamp((momCounter?45.0:0.0)+convScore*0.35,0,100);
   w.liquidationScore  = FalconClamp((physCapLow?40.0:0.0)+(oppBOS?30.0:0.0)+absScore*0.3,0,100);
   w.absorptionScore   = FalconClamp(absScore,0,100);
   w.retracementScore  = FalconClamp(retrFrac*100.0,0,100);

   // ---- FORECAST (planning layer) — what this wave expects next ------------
   double leg = MathAbs(w.extreme - w.origin);
   w.remainingCapacity = FalconClamp(100.0 - w.completion, 0, 100);
   if(w.completion < 60.0)
   {
      // still expanding -> a retracement is next; stage the return zone at the
      // 50% retrace of the current leg (the demand/supply price will pull back to)
      w.expectedNextPhase  = PH_RETRACEMENT;
      w.expectedReturnZone = (w.direction==DIR_LONG ? w.extreme - leg*0.5
                            : w.direction==DIR_SHORT ? w.extreme + leg*0.5 : 0.0);
      w.forecastProb       = FalconClamp(w.strength*0.5 + w.remainingCapacity*0.5, 0, 100);
   }
   else
   {
      // mature -> a return/continuation off the zone is next
      w.expectedNextPhase  = (w.direction==DIR_LONG ? PH_DEMAND_RETURN
                            : w.direction==DIR_SHORT ? PH_SUPPLY_RETURN : PH_TRANSITION);
      w.expectedReturnZone = (w.flipBot>0 && w.direction==DIR_LONG ? w.flipBot
                            : w.flipTop>0 && w.direction==DIR_SHORT ? w.flipTop
                            : (w.direction==DIR_LONG ? w.extreme - leg*0.382 : w.extreme + leg*0.382));
      w.forecastProb       = FalconClamp(w.confidence*0.5 + (100.0-w.completion)*0.5, 0, 100);
   }
   w.expectedBars = (w.completion>5.0 ? (int)MathMin(50.0, MathMax(1.0, w.age*(100.0-w.completion)/w.completion)) : 14);

   g_state.wave = w;

   if(phase != prevPhase) FalconPublish(EVT_PHASE_CHANGE, phase, FalconPhaseStr(phase));
}

//==================================================================
// 5. CONVEXITY / ARC  (Symphony ARC v2 + geometry capacity)
//==================================================================
void ME_UpdateConvexity()
{
   FalconConvexity c;
   double atr = g_state.physics.atr;
   c.arcLong=0; c.arcShort=0;

   if(me_dir==1 && me_inv!=0)
   {
      double impL = (me_p4h-me_p4l);
      if(impL>0)
      {
         double targetL = me_p4l + impL*g_cfg.arcExtMult;
         double t = FalconClamp((double)(g_barCounter-me_waveSpawnBar)/(double)g_cfg.arcHorizonBars,0,1);
         c.arcLong = me_p4l + (targetL-me_p4l)*MathPow(t,g_cfg.convPower);
      }
   }
   if(me_dir==-1 && me_inv!=0)
   {
      double impS = (me_p4h-me_p4l);
      if(impS>0)
      {
         double targetS = me_p4h - impS*g_cfg.arcExtMult;
         double t = FalconClamp((double)(g_barCounter-me_waveSpawnBar)/(double)g_cfg.arcHorizonBars,0,1);
         c.arcShort = me_p4h + (targetS-me_p4h)*MathPow(t,g_cfg.convPower);
      }
   }

   c.convexityWidth  = (me_ft!=0 && me_fb!=0)? (me_ft-me_fb):0.0;
   c.curvatureRadius = (MathAbs(me_csm)>1e-10)? 1.0/MathAbs(me_csm):0.0;
   double distToTarget = (me_tgt!=0)? MathAbs(me_tgt-gClose[1])/MathMax(atr,1e-10):0.0;
   c.geometryCapacity= FalconClamp(distToTarget/4.0*100.0,0,100);
   c.maturity        = FalconClamp(g_state.physics.compression*0.4 + g_state.wave.completion*0.6,0,100);

   g_state.convexity = c;
}

//==================================================================
// 6. FU CANDLE  (rejection / flip detector — port of f_fuPool)
//==================================================================
void ME_UpdateFU()
{
   FalconFU fu = g_state.fu;
   double atr = g_state.physics.atr;
   int lb = g_cfg.fuLookback;

   double rng = MathMax(gHigh[1]-gLow[1],1e-10);
   double pHi = FalconHighest(2,lb);
   double pLo = FalconLowest(2,lb);
   double uw  = (gHigh[1]-MathMax(gOpen[1],gClose[1]))/rng;
   double lw  = (MathMin(gOpen[1],gClose[1])-gLow[1])/rng;
   bool localTop = gHigh[1]>=FalconHighest(1,lb);
   bool localBot = gLow[1] <=FalconLowest(1,lb);
   bool bear = uw>=g_cfg.wickFrac && ((pHi!=0 && gHigh[1]>=pHi && gClose[1]<pHi)||(localTop && gClose[1]<gOpen[1]));
   bool bull = lw>=g_cfg.wickFrac && ((pLo!=0 && gLow[1] <=pLo && gClose[1]>pLo)||(localBot && gClose[1]>gOpen[1]));

   if(bear)
   {
      fu.dir=-1; fu.tip=gHigh[1];
      double bH=MathMax(gOpen[1],gClose[1]);
      fu.mid=bH+(fu.tip-bH)*0.5; fu.active=true; fu.lifecycle=0;
      fu.candle=gClose[1];
      fu.zoneTop=fu.tip; fu.zoneBot=bH;          // rejection band: body-top -> wick-tip
   }
   else if(bull)
   {
      fu.dir=1; fu.tip=gLow[1];
      double bL=MathMin(gOpen[1],gClose[1]);
      fu.mid=fu.tip+(bL-fu.tip)*0.5; fu.active=true; fu.lifecycle=0;
      fu.candle=gClose[1];
      fu.zoneTop=bL; fu.zoneBot=fu.tip;          // rejection band: wick-tip -> body-bottom
   }
   else if(fu.active) fu.lifecycle++;

   double wk = (fu.dir==-1 && fu.active)?(fu.tip-MathMax(gOpen[1],gClose[1]))/MathMax(atr,1e-10):
               (fu.dir== 1 && fu.active)?(MathMin(gOpen[1],gClose[1])-fu.tip)/MathMax(atr,1e-10):0.0;
   fu.confidence = FalconClamp(20.0+MathMin(25.0,wk*15.0)+(wk>1.0?15.0:0.0)+(wk>1.5?10.0:0.0),0,100);
   fu.strength   = FalconClamp(wk*40.0,0,100);

   g_state.fu = fu;
}

//==================================================================
// 7B. ORDER BLOCKS  (last opposing candle before an impulse leg)
//==================================================================
double me_obTop[FALCON_MAX_OB];
double me_obBot[FALCON_MAX_OB];
int    me_obDir[FALCON_MAX_OB];
int    me_obBirth[FALCON_MAX_OB];
double me_obStr[FALCON_MAX_OB];
int    me_obCount=0;

void ME_PushOB(const double top,const double bot,const int dir,const double strength)
{
   if(me_obCount>=FALCON_MAX_OB)
   {
      for(int i=1;i<FALCON_MAX_OB;i++)
      { me_obTop[i-1]=me_obTop[i]; me_obBot[i-1]=me_obBot[i]; me_obDir[i-1]=me_obDir[i];
        me_obBirth[i-1]=me_obBirth[i]; me_obStr[i-1]=me_obStr[i]; }
      me_obCount=FALCON_MAX_OB-1;
   }
   me_obTop[me_obCount]=top; me_obBot[me_obCount]=bot; me_obDir[me_obCount]=dir;
   me_obBirth[me_obCount]=g_barCounter; me_obStr[me_obCount]=strength; me_obCount++;
}

void ME_UpdateOrderBlocks()
{
   FalconOrderBlocks ob;
   double atr=g_state.physics.atr;
   FalconPhysics p=g_state.physics;

   // a new OB forms on the candle that flips into an impulse: the last
   // opposing-color candle body before the displacement leg.
   if(p.bullImpulse)
   {
      // last down candle before this up impulse
      for(int i=2;i<=8;i++){ if(gClose[i]<gOpen[i]){ ME_PushOB(gHigh[i],gLow[i],DIR_LONG, p.displacement*20.0); break; } }
   }
   if(p.bearImpulse)
   {
      for(int i=2;i<=8;i++){ if(gClose[i]>gOpen[i]){ ME_PushOB(gHigh[i],gLow[i],DIR_SHORT,p.displacement*20.0); break; } }
   }

   double close1=gClose[1];
   ob.count=0;
   double bestDist=DBL_MAX;
   ob.activeTop=0; ob.activeBot=0; ob.activeDir=DIR_NONE; ob.activeStrength=0;
   for(int i=0;i<me_obCount && ob.count<FALCON_MAX_OB;i++)
   {
      // invalidation: price closing fully through the block kills it
      bool valid=(me_obDir[i]==DIR_LONG ? close1>me_obBot[i] : close1<me_obTop[i]);
      ob.top[ob.count]=me_obTop[i]; ob.bot[ob.count]=me_obBot[i]; ob.dir[ob.count]=me_obDir[i];
      ob.birthBar[ob.count]=me_obBirth[i]; ob.valid[ob.count]=valid;
      ob.strength[ob.count]=FalconClamp(me_obStr[i] - (g_barCounter-me_obBirth[i])*0.2,0,100);
      if(valid)
      {
         double mid=(me_obTop[i]+me_obBot[i])*0.5;
         double d=MathAbs(close1-mid);
         if(d<bestDist){ bestDist=d; ob.activeTop=me_obTop[i]; ob.activeBot=me_obBot[i];
                         ob.activeDir=me_obDir[i]; ob.activeStrength=ob.strength[ob.count]; }
      }
      ob.count++;
   }
   g_state.orderBlocks=ob;
}

//==================================================================
// 7C. SUPPLY / DEMAND  (institutional zones from wave flip + OB)
//==================================================================
void ME_UpdateSupplyDemand()
{
   FalconSupplyDemand sd;
   double atr=g_state.physics.atr;
   double close1=gClose[1];
   FalconWave w=g_state.wave;
   FalconOrderBlocks ob=g_state.orderBlocks;

   // demand = working bullish OB or wave flip-bottom band; supply = bearish OB / flip-top band
   double demandMid = (ob.activeDir==DIR_LONG && ob.activeTop!=0) ? (ob.activeTop+ob.activeBot)*0.5
                      : (w.flipBot!=0 ? w.flipBot : 0.0);
   double supplyMid = (ob.activeDir==DIR_SHORT && ob.activeTop!=0)? (ob.activeTop+ob.activeBot)*0.5
                      : (w.flipTop!=0 ? w.flipTop : 0.0);

   sd.demandTop = (demandMid!=0? demandMid+atr*g_cfg.inducZoneWidth:0.0);
   sd.demandBot = (demandMid!=0? demandMid-atr*g_cfg.inducZoneWidth:0.0);
   sd.supplyTop = (supplyMid!=0? supplyMid+atr*g_cfg.inducZoneWidth:0.0);
   sd.supplyBot = (supplyMid!=0? supplyMid-atr*g_cfg.inducZoneWidth:0.0);

   sd.demandStrength = FalconClamp((ob.activeDir==DIR_LONG?ob.activeStrength:0.0)
                       + (g_state.liquidity.pressure>0?g_state.liquidity.pressure*0.5:0.0),0,100);
   sd.supplyStrength = FalconClamp((ob.activeDir==DIR_SHORT?ob.activeStrength:0.0)
                       + (g_state.liquidity.pressure<0?-g_state.liquidity.pressure*0.5:0.0),0,100);

   sd.inDemand = (demandMid!=0 && close1<=sd.demandTop && close1>=sd.demandBot);
   sd.inSupply = (supplyMid!=0 && close1<=sd.supplyTop && close1>=sd.supplyBot);
   sd.activeZone = sd.inDemand?DIR_LONG : sd.inSupply?DIR_SHORT : DIR_NONE;

   g_state.supplyDemand=sd;
}

//==================================================================
// 7. HTF STACK  (fixed M1·M5·M15·M30·H1·H4 + chart; fractal align)
//==================================================================
int ME_TFCurve(const ENUM_TIMEFRAMES tf, const int idx)
{
   int pv = g_cfg.structLen;
   int need = pv*2 + g_cfg.atrLen + 60;
   double h[],l[],c[],o[];
   ArraySetAsSeries(h,true); ArraySetAsSeries(l,true);
   ArraySetAsSeries(c,true); ArraySetAsSeries(o,true);
   if(CopyHigh(_Symbol,tf,0,need,h)<need) return(g_tfCurve[idx].oDir);
   if(CopyLow (_Symbol,tf,0,need,l)<need) return(g_tfCurve[idx].oDir);
   if(CopyClose(_Symbol,tf,0,need,c)<need) return(g_tfCurve[idx].oDir);
   if(CopyOpen (_Symbol,tf,0,need,o)<need) return(g_tfCurve[idx].oDir);

   // ATR proxy on this TF (mean true range over atrLen)
   double atr=0; for(int i=1;i<=g_cfg.atrLen;i++) atr+=(h[i]-l[i]); atr/=MathMax(g_cfg.atrLen,1); if(atr<=0) atr=1e-10;
   double close1=c[1];

   // physics EMA chain (advanced once per chart bar on this TF's last delta)
   double d = c[1]-c[2];
   if(!g_tfCurve[idx].init)
   { g_tfCurve[idx].vel=d; g_tfCurve[idx].velPrev=d; g_tfCurve[idx].acc=0; g_tfCurve[idx].accPrev=0; g_tfCurve[idx].csm=0; g_tfCurve[idx].csmPrev=0; g_tfCurve[idx].init=true; }
   else
   {
      g_tfCurve[idx].velPrev=g_tfCurve[idx].vel;
      g_tfCurve[idx].vel=FalconEMA(g_tfCurve[idx].vel,d,3);
      g_tfCurve[idx].accPrev=g_tfCurve[idx].acc;
      g_tfCurve[idx].acc=g_tfCurve[idx].vel-g_tfCurve[idx].velPrev;
      double cv=g_tfCurve[idx].acc-g_tfCurve[idx].accPrev;
      g_tfCurve[idx].csmPrev=g_tfCurve[idx].csm;
      g_tfCurve[idx].csm=FalconEMA(g_tfCurve[idx].csm,cv,3);
   }
   // efficiency / displacement on this TF
   int eff=g_cfg.effLen;
   double mv=MathAbs(c[1]-c[1+eff]); double ps=0; for(int i=1;i<=eff;i++) ps+=MathAbs(c[i]-c[i+1]);
   double efficiency=(ps>0?mv/ps:0.0);
   double disp=(h[1]-l[1])/atr;
   bool bullImp=(efficiency>g_cfg.effThresh && g_tfCurve[idx].vel>g_tfCurve[idx].velPrev && g_tfCurve[idx].acc>0 && c[1]>o[1] && disp>g_cfg.dispThresh);
   bool bearImp=(efficiency>g_cfg.effThresh && g_tfCurve[idx].vel<g_tfCurve[idx].velPrev && g_tfCurve[idx].acc<0 && c[1]<o[1] && disp>g_cfg.dispThresh);
   bool bullDec=(MathAbs(g_tfCurve[idx].acc)<MathAbs(g_tfCurve[idx].accPrev)*0.8 && g_tfCurve[idx].vel>0);
   bool bearDec=(MathAbs(g_tfCurve[idx].acc)<MathAbs(g_tfCurve[idx].accPrev)*0.8 && g_tfCurve[idx].vel<0);

   // pivots / structure at center
   int center=pv+1; double eP=0; int eD=0;
   bool isH=true,isL=true;
   for(int k=1;k<=pv;k++){ if(h[center]<=h[center+k]||h[center]<=h[center-k]) isH=false; if(l[center]>=l[center+k]||l[center]>=l[center-k]) isL=false; }
   if(isH){ eP=h[center]; eD=1; } else if(isL){ eP=l[center]; eD=-1; }
   if(eD==1){ g_tfCurve[idx].prSH=(g_tfCurve[idx].curSH==0?h[center]:g_tfCurve[idx].curSH); g_tfCurve[idx].curSH=h[center]; }
   else if(eD==-1){ g_tfCurve[idx].prSL=(g_tfCurve[idx].curSL==0?l[center]:g_tfCurve[idx].curSL); g_tfCurve[idx].curSL=l[center]; }
   if(eD!=0){ g_tfCurve[idx].prevP=g_tfCurve[idx].lastP; g_tfCurve[idx].prevD=g_tfCurve[idx].lastD; g_tfCurve[idx].lastP=eP; g_tfCurve[idx].lastD=eD; }

   bool bullCH=(g_tfCurve[idx].prSH!=0 && close1>g_tfCurve[idx].prSH+atr*g_cfg.chochBufferATR);
   bool bearCH=(g_tfCurve[idx].prSL!=0 && close1<g_tfCurve[idx].prSL-atr*g_cfg.chochBufferATR);
   bool eLong =(isH && g_tfCurve[idx].prevD==-1 && (g_tfCurve[idx].lastP-g_tfCurve[idx].prevP)>atr*g_cfg.impulseAtrMult);
   bool eShort=(isL && g_tfCurve[idx].prevD== 1 && (g_tfCurve[idx].prevP-g_tfCurve[idx].lastP)>atr*g_cfg.impulseAtrMult);

   bool hasCtx=(g_tfCurve[idx].dir!=0 && g_tfCurve[idx].ft!=0);
   bool flipUp=(g_tfCurve[idx].dir==-1 && bullCH);
   bool flipDn=(g_tfCurve[idx].dir==1  && bearCH);
   bool isRev =(eLong&&g_tfCurve[idx].dir==-1)||(eShort&&g_tfCurve[idx].dir==1)||flipUp||flipDn;
   bool spawn =(eLong||eShort||flipUp||flipDn)&&(!hasCtx||isRev);
   if(spawn)
   {
      int nd=eLong?1:eShort?-1:flipUp?1:-1;
      double hi=MathMax(g_tfCurve[idx].lastP,g_tfCurve[idx].prevP);
      double lo=MathMin(g_tfCurve[idx].lastP,g_tfCurve[idx].prevP);
      g_tfCurve[idx].dir=nd; g_tfCurve[idx].ft=hi; g_tfCurve[idx].fb=lo; g_tfCurve[idx].p4h=hi; g_tfCurve[idx].p4l=lo;
      g_tfCurve[idx].cycH=h[1]; g_tfCurve[idx].cycL=l[1]; g_tfCurve[idx].inv=(nd==1?lo:hi);
      double rng=(g_tfCurve[idx].prSH!=0&&g_tfCurve[idx].prSL!=0)?MathAbs(g_tfCurve[idx].prSH-g_tfCurve[idx].prSL):atr*5.0;
      g_tfCurve[idx].tgt=(nd==1?hi+rng:lo-rng); g_tfCurve[idx].spawnBar=g_barCounter;
   }
   if(g_tfCurve[idx].dir==1)  g_tfCurve[idx].cycH=(g_tfCurve[idx].cycH==0?h[1]:MathMax(g_tfCurve[idx].cycH,h[1]));
   if(g_tfCurve[idx].dir==-1) g_tfCurve[idx].cycL=(g_tfCurve[idx].cycL==0?l[1]:MathMin(g_tfCurve[idx].cycL,l[1]));

   bool reset=(g_tfCurve[idx].dir!=g_tfCurve[idx].lastDirSeen); g_tfCurve[idx].lastDirSeen=g_tfCurve[idx].dir;
   if(reset){ g_tfCurve[idx].bos1=false; g_tfCurve[idx].bos2=false; g_tfCurve[idx].protSw=0; g_tfCurve[idx].protSw2=0; }
   if(g_tfCurve[idx].dir==1 && isL){ g_tfCurve[idx].protSw2=g_tfCurve[idx].protSw; g_tfCurve[idx].protSw=l[center]; }
   if(g_tfCurve[idx].dir==-1&& isH){ g_tfCurve[idx].protSw2=g_tfCurve[idx].protSw; g_tfCurve[idx].protSw=h[center]; }
   bool oppBOS=(g_tfCurve[idx].dir==1 && g_tfCurve[idx].protSw!=0 && close1<g_tfCurve[idx].protSw)||(g_tfCurve[idx].dir==-1 && g_tfCurve[idx].protSw!=0 && close1>g_tfCurve[idx].protSw);
   if(!g_tfCurve[idx].bos1 && oppBOS) g_tfCurve[idx].bos1=true;

   int wdir=(g_tfCurve[idx].inv!=0?(close1>g_tfCurve[idx].inv?1:close1<g_tfCurve[idx].inv?-1:g_tfCurve[idx].dir):g_tfCurve[idx].dir);
   bool atFlip=(g_tfCurve[idx].ft!=0&&g_tfCurve[idx].fb!=0&&close1<=g_tfCurve[idx].ft&&close1>=g_tfCurve[idx].fb);
   bool atExtreme=(wdir==1?h[1]>=(g_tfCurve[idx].cycH==0?h[1]:g_tfCurve[idx].cycH):wdir==-1?l[1]<=(g_tfCurve[idx].cycL==0?l[1]:g_tfCurve[idx].cycL):false);
   double extr=(wdir==1?(g_tfCurve[idx].cycH==0?close1:g_tfCurve[idx].cycH):(g_tfCurve[idx].cycL==0?close1:g_tfCurve[idx].cycL));
   bool extended=(g_tfCurve[idx].inv!=0 && MathAbs(extr-g_tfCurve[idx].inv)>atr*1.5);
   bool expanding=eLong||eShort||(wdir==1?bullImp:bearImp);
   bool momDecaying=(g_tfCurve[idx].dir==1?bullDec:bearDec);
   bool momCounter =(g_tfCurve[idx].dir==1?bearImp:bullImp);
   double convScore=MathMin(MathAbs(g_tfCurve[idx].csm)/MathMax(atr*g_cfg.convMult,1e-10)*50.0,100.0);
   bool physConv=convScore>35.0, physTransfer=convScore>48.0;

   bool phase2CH=(g_tfCurve[idx].dir==1&&bearCH)||(g_tfCurve[idx].dir==-1&&bullCH);
   if(reset||(atExtreme&&extended)){ g_tfCurve[idx].recBrk=0; g_tfCurve[idx].recArm=true; }
   if((g_tfCurve[idx].dir==1&&isH)||(g_tfCurve[idx].dir==-1&&isL)) g_tfCurve[idx].recArm=true;
   if((phase2CH||oppBOS)&&g_tfCurve[idx].recArm&&!atExtreme){ g_tfCurve[idx].recBrk++; g_tfCurve[idx].recArm=false; }
   double compIdx=FalconClamp((1.0-MathMin(disp/MathMax(g_cfg.dispThresh,1e-10),1.0))*60.0+(1.0-MathMin(efficiency/MathMax(g_cfg.effThresh,1e-10),1.0))*40.0,0,100);
   double recDom=MathMin(MathMax(g_tfCurve[idx].recBrk*(30.0-compIdx*0.15),0.0),100.0);
   bool transferDone=recDom>=50.0;

   if(reset) g_tfCurve[idx].pst=0;
   if(g_tfCurve[idx].dir!=0 && !reset)
   {
      int pst=g_tfCurve[idx].pst;
      if(pst==0&&expanding) pst=1;
      if(pst==1&&!atExtreme&&momDecaying&&physConv) pst=2;
      if(pst==2&&!atExtreme&&momCounter&&physTransfer) pst=3;
      if(pst==3&&!atExtreme&&g_tfCurve[idx].bos1&&physTransfer) pst=4;
      if(pst>=1&&pst<=7&&atExtreme&&extended) pst=5;
      if(pst==5&&!atExtreme&&g_tfCurve[idx].recBrk>=1) pst=7;
      if(pst==7&&transferDone) pst=8;
      if(pst==8&&atFlip) pst=9;
      if(pst==9&&((g_tfCurve[idx].dir==1&&bullImp)||(g_tfCurve[idx].dir==-1&&bearImp))) pst=10;
      if(pst==10&&oppBOS) pst=11;
      if(pst==11&&((g_tfCurve[idx].dir==1&&l[1]<g_tfCurve[idx].fb)||(g_tfCurve[idx].dir==-1&&h[1]>g_tfCurve[idx].ft))) pst=12;
      if(pst==12&&((g_tfCurve[idx].dir==1&&bullCH)||(g_tfCurve[idx].dir==-1&&bearCH))) pst=13;
      g_tfCurve[idx].pst=pst;
   }
   int phase=g_tfCurve[idx].pst;
   if(phase==5 && g_tfCurve[idx].dir==-1) phase=6;
   if(phase==13&& g_tfCurve[idx].dir==-1) phase=14;
   double wp=(g_tfCurve[idx].pst==0?5.0:g_tfCurve[idx].pst==1?15.0:g_tfCurve[idx].pst==2?25.0:g_tfCurve[idx].pst==3?33.0:g_tfCurve[idx].pst==4?42.0:g_tfCurve[idx].pst==5?55.0:g_tfCurve[idx].pst==7?65.0:g_tfCurve[idx].pst==8?75.0:g_tfCurve[idx].pst==9?85.0:g_tfCurve[idx].pst==10?90.0:g_tfCurve[idx].pst==11?94.0:g_tfCurve[idx].pst==12?97.0:100.0);

   g_tfCurve[idx].oDir=wdir; g_tfCurve[idx].oPhase=phase; g_tfCurve[idx].oCompletion=wp;
   g_tfCurve[idx].oOrigin=g_tfCurve[idx].inv; g_tfCurve[idx].oExtreme=extr; g_tfCurve[idx].oObjective=g_tfCurve[idx].tgt;
   g_tfCurve[idx].oRecBrk=g_tfCurve[idx].recBrk; g_tfCurve[idx].oDom=recDom;
   me_htfDirState[idx]=wdir; me_htfOrigin[idx]=g_tfCurve[idx].inv;
   return(wdir);
}

void ME_UpdateHTF()
{
   FalconHTF h;
   int bull=0, bear=0;
   for(int i=0;i<7;i++)
   {
      int d;
      if(me_htfTF[i]==g_cfg.operatingTF)
      {
         // UNIFY (single source of truth): the rung that equals the OPERATING TF
         // REUSES the primary wave FSM (g_state.wave) instead of running a second
         // FSM. The chart TF no longer matters — the core runs on operatingTF and
         // this rung mirrors it, so the operating-scale phase exists exactly once.
         d = g_state.wave.direction;
         g_tfCurve[i].oDir       = d;
         g_tfCurve[i].oPhase     = g_state.wave.phase;
         g_tfCurve[i].oCompletion= g_state.wave.completion;
         g_tfCurve[i].oOrigin    = g_state.wave.origin;
         g_tfCurve[i].oExtreme   = g_state.wave.extreme;
         g_tfCurve[i].oObjective = g_state.wave.objective;
         g_tfCurve[i].oRecBrk    = g_state.wave.recursionBreaks;
         g_tfCurve[i].oDom       = g_state.wave.dominanceTransfer;
         me_htfDirState[i]=d; me_htfOrigin[i]=g_state.wave.origin;
      }
      else d = ME_TFCurve(me_htfTF[i], i);   // REAL per-TF wave engine (other rungs)
      h.dir[i]=d;
      h.beliefs[i]=d;
      h.prog[i]=g_tfCurve[i].oCompletion;
      if(d==1) bull++; else if(d==-1) bear++;
   }
   h.stackDir  = (bull>bear?DIR_LONG:bear>bull?DIR_SHORT:DIR_NONE);
   h.alignment = MathMax(bull,bear)/7.0*100.0;
   h.conflict  = 100.0 - h.alignment;
   h.fractalAgreement = (h.alignment>=66.0);
   // dominance / owner = highest timeframe whose own curve agrees with the stack
   h.dominance = 4; h.ownerTF=4;
   for(int i=6;i>=0;i--){ if(h.dir[i]==h.stackDir && h.stackDir!=0){ h.dominance=i; h.ownerTF=i; break; } }

   g_state.htf = h;
}

//==================================================================
// PER-TF ZONES — compute liquidity pools/sweeps, order block and
// supply/demand for ONE absolute rung from that TF's own bars.
//==================================================================
void ME_TFZones(const ENUM_TIMEFRAMES tf, const int idx)
{
   int pv   = g_cfg.structLen;
   int look = g_cfg.liqSweepLookbk;
   int need = pv*2 + g_cfg.atrLen + MathMax(look,10) + 20;
   double h[],l[],c[],o[];
   ArraySetAsSeries(h,true); ArraySetAsSeries(l,true);
   ArraySetAsSeries(c,true); ArraySetAsSeries(o,true);
   if(CopyHigh(_Symbol,tf,0,need,h)<need) { g_tfZones[idx].valid=false; return; }
   if(CopyLow (_Symbol,tf,0,need,l)<need) { g_tfZones[idx].valid=false; return; }
   if(CopyClose(_Symbol,tf,0,need,c)<need){ g_tfZones[idx].valid=false; return; }
   if(CopyOpen (_Symbol,tf,0,need,o)<need){ g_tfZones[idx].valid=false; return; }

   FalconTFZones z; ZeroMemory(z);
   double atr=0; for(int i=1;i<=g_cfg.atrLen;i++) atr+=(h[i]-l[i]); atr/=MathMax(g_cfg.atrLen,1);
   if(atr<=0) atr=1e-9;
   z.atr=atr;
   double close1=c[1];

   // swing hi/lo (pivot at center) — persist last known when no new pivot
   int center=pv+1; bool isH=true,isL=true;
   for(int k=1;k<=pv;k++){ if(h[center]<=h[center+k]||h[center]<=h[center-k]) isH=false;
                           if(l[center]>=l[center+k]||l[center]>=l[center-k]) isL=false; }
   z.swingHi=(isH? h[center] : g_tfZones[idx].swingHi);
   z.swingLo=(isL? l[center] : g_tfZones[idx].swingLo);

   // liquidity pools = recent extremes; sweep = pierced then closed back inside
   double poolHi=-DBL_MAX, poolLo=DBL_MAX;
   for(int i=2;i<2+look && i<need;i++){ if(h[i]>poolHi) poolHi=h[i]; if(l[i]<poolLo) poolLo=l[i]; }
   z.poolHi=(poolHi==-DBL_MAX?0:poolHi); z.poolLo=(poolLo==DBL_MAX?0:poolLo);
   z.sweptHi=(z.poolHi>0 && h[1]>z.poolHi && close1<z.poolHi);
   z.sweptLo=(z.poolLo>0 && l[1]<z.poolLo && close1>z.poolLo);

   // order block = last opposing candle before a displacement impulse
   double mv=MathAbs(c[1]-c[1+g_cfg.effLen]);
   bool bullImp=(c[1]>o[1] && mv>atr*g_cfg.impulseAtrMult);
   bool bearImp=(c[1]<o[1] && mv>atr*g_cfg.impulseAtrMult);
   z.obDir=DIR_NONE; z.obTop=0; z.obBot=0;
   if(bullImp){ for(int i=2;i<=8 && i<need;i++) if(c[i]<o[i]){ z.obTop=h[i]; z.obBot=l[i]; z.obDir=DIR_LONG; break; } }
   else if(bearImp){ for(int i=2;i<=8 && i<need;i++) if(c[i]>o[i]){ z.obTop=h[i]; z.obBot=l[i]; z.obDir=DIR_SHORT; break; } }

   // supply/demand = OB band, else the per-TF curve flip band, +- inducZoneWidth
   double fb=g_tfCurve[idx].fb, ft=g_tfCurve[idx].ft;
   double demMid=(z.obDir==DIR_LONG && z.obTop!=0)? (z.obTop+z.obBot)*0.5 : (fb!=0? fb : z.swingLo);
   double supMid=(z.obDir==DIR_SHORT&& z.obTop!=0)? (z.obTop+z.obBot)*0.5 : (ft!=0? ft : z.swingHi);
   double w=atr*g_cfg.inducZoneWidth;
   z.demTop=(demMid!=0? demMid+w:0); z.demBot=(demMid!=0? demMid-w:0);
   z.supTop=(supMid!=0? supMid+w:0); z.supBot=(supMid!=0? supMid-w:0);
   z.inDemand=(demMid!=0 && close1<=z.demTop && close1>=z.demBot);
   z.inSupply=(supMid!=0 && close1<=z.supTop && close1>=z.supBot);
   z.valid=true;
   g_tfZones[idx]=z;
}

//==================================================================
// Update per-TF zones for all 7 absolute rungs. The operating-TF rung
// mirrors the already-computed g_state zones (single source of truth).
//==================================================================
void ME_UpdateTFZones()
{
   for(int i=0;i<7;i++)
   {
      if(i==me_opTFIdx)
      {
         FalconTFZones z; ZeroMemory(z);
         z.atr=g_state.physics.atr;
         z.obTop=g_state.orderBlocks.activeTop; z.obBot=g_state.orderBlocks.activeBot; z.obDir=g_state.orderBlocks.activeDir;
         z.demTop=g_state.supplyDemand.demandTop; z.demBot=g_state.supplyDemand.demandBot;
         z.supTop=g_state.supplyDemand.supplyTop; z.supBot=g_state.supplyDemand.supplyBot;
         z.inDemand=g_state.supplyDemand.inDemand; z.inSupply=g_state.supplyDemand.inSupply;
         z.swingHi=g_state.structure.swingHigh;   z.swingLo=g_state.structure.swingLow;
         z.sweptHi=g_state.liquidity.sweepBear;    z.sweptLo=g_state.liquidity.sweepBull;
         z.valid=true;
         g_tfZones[i]=z;
      }
      else ME_TFZones(me_htfTF[i], i);
   }
}

//==================================================================
// MASTER ENTRY — Market Engine pipeline step
//==================================================================
void MarketEngineRun()
{
   if(FalconBars() < (2*g_cfg.structLen + 10)) return;
   ME_UpdatePhysics();
   ME_UpdateStructure();
   ME_UpdateLiquidity();
   ME_UpdateWave();
   ME_UpdateInducement();
   ME_UpdateConvexity();
   ME_UpdateFU();
   ME_UpdateOrderBlocks();
   ME_UpdateSupplyDemand();
   ME_UpdateHTF();
   ME_UpdateTFZones();   // per-TF liquidity/OB/S&D across the W1..M1 ladder
}

#endif // FALCON_MARKET_ENGINE_MQH
//+------------------------------------------------------------------+
