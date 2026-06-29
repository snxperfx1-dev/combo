//+------------------------------------------------------------------+
//|  FALCON OS — MODULE 1: CORE MARKET ENGINE                       |
//|  Source: LETRA + Symphony physics.                              |
//|  Pure market model — NO execution, NO dashboards.               |
//|  Physics · Structure (fixed-TF f_se) · Liquidity · Wave physics |
//|  · FU pools · HTF · Fractal stack. Each value computed ONCE.    |
//+------------------------------------------------------------------+
#ifndef FALCON_COREMARKET_MQH
#define FALCON_COREMARKET_MQH
#include "Kernel.mqh"

//==================================================================
// PER-TF PERSISTENT STRUCTURE-ENGINE STATE  (f_se `var` locals)
//==================================================================
struct CM_SEState
  {
   bool     init;
   datetime lastBar;
   // physics continuity
   double   velPrev, accPrev, csmPrev;
   // swings
   double   curSH, curSL, prSH, prSL;
   // pivot memory
   double   lastP, prevP; int lastD, prevD;
   // wave context
   int      dir;
   double   ft, fb, p4h, p4l, inv, tgt, cycH, cycL;
   // lifecycle internals
   bool     bos1, bos2;
   double   protSw, protSw2, indOrig, indExt;
   bool     indBrk;
   int      lastDirSeen;
   int      recBrk; bool recArm;
   int      pst;            // monotonic phase state 0..13
  };
CM_SEState g_se[FAL_TF_COUNT];

// ATR handles per TF (created once).
int g_atrHandle[FAL_TF_COUNT];

//==================================================================
// PIVOT DETECTION on a series array (index 0 = newest)
//==================================================================
bool CM_IsPivotHigh(const double &h[], int center, int len, int size)
  {
   if(center-len < 0 || center+len >= size) return(false);
   double v = h[center];
   for(int k=1;k<=len;k++)
     {
      if(v <= h[center-k]) return(false);
      if(v <= h[center+k]) return(false);
     }
   return(true);
  }
bool CM_IsPivotLow(const double &l[], int center, int len, int size)
  {
   if(center-len < 0 || center+len >= size) return(false);
   double v = l[center];
   for(int k=1;k<=len;k++)
     {
      if(v >= l[center-k]) return(false);
      if(v >= l[center+k]) return(false);
     }
   return(true);
  }

//==================================================================
// PROCESS ONE FIXED-TF STRUCTURE ENGINE  (verbatim f_se port)
//==================================================================
// Advances the persistent state machine by one closed bar and writes
// the result into g_state.structure.tf[idx].
void CM_ProcessTF(int idx, CM_SEState &s)
  {
   ENUM_TIMEFRAMES tf = FAL_TF[idx];
   datetime t0 = iTime(_Symbol, tf, 0);
   if(t0 == 0) return;

   bool newBar = (!s.init) || (t0 != s.lastBar);
   if(!newBar)
      return;                 // process only on a fresh bar of this TF
   s.lastBar = t0;

   int need = MathMax(300, g_cfg.structLen*4 + g_cfg.pivotLen*4 + 60);
   double cl[], hi[], lo[], op[];
   ArraySetAsSeries(cl,true); ArraySetAsSeries(hi,true);
   ArraySetAsSeries(lo,true); ArraySetAsSeries(op,true);
   if(CopyClose(_Symbol,tf,0,need,cl)<=0) return;
   if(CopyHigh (_Symbol,tf,0,need,hi)<=0) return;
   if(CopyLow  (_Symbol,tf,0,need,lo)<=0) return;
   if(CopyOpen (_Symbol,tf,0,need,op)<=0) return;
   int sz = ArraySize(cl);
   if(sz < 60) return;

   int c = 1;                 // last CLOSED bar
   double close = cl[c], open = op[c], high = hi[c], low = lo[c];

   // ATR for this TF
   double atr = 0.0;
   if(g_atrHandle[idx] != INVALID_HANDLE)
     {
      double ab[]; ArraySetAsSeries(ab,true);
      if(CopyBuffer(g_atrHandle[idx],0,c,1,ab)>0) atr = ab[0];
     }
   if(atr<=0) atr = (high-low);
   if(atr<=0) atr = _Point*10;

   // ── PHYSICS (this tf) ─────────────────────────────────────────
   double diff = cl[c]-cl[c+1];
   if(!s.init){ s.velPrev=0; s.accPrev=0; s.csmPrev=0; }
   double prevVel=s.velPrev, prevAcc=s.accPrev, prevCsm=s.csmPrev;
   double vel = FAL_EmaStep(prevVel, diff, 3);
   double acc = vel - prevVel;
   double cvx = acc - prevAcc;
   double csm = FAL_EmaStep(prevCsm, cvx, 3);
   s.velPrev = vel; s.accPrev = acc; s.csmPrev = csm;

   int    effL = g_cfg.effLen;
   double mv = MathAbs(cl[c]-cl[c+effL]);
   double ps = 0; for(int i=0;i<effL;i++) ps += MathAbs(cl[c+i]-cl[c+i+1]);
   double eff = ps>0 ? mv/ps : 0.0;
   double disp = (high-low)/MathMax(atr,1e-10);

   double effT=g_cfg.effThresh, dispT=g_cfg.dispThresh, convM=g_cfg.convMult;
   bool bullImp = eff>effT && vel>0 && acc>0 && close>open && disp>dispT;
   bool bearImp = eff>effT && vel<0 && acc<0 && close<open && disp>dispT;
   bool bullDec = MathAbs(acc) < MathAbs(prevAcc)*0.8 && vel>0;
   bool bearDec = MathAbs(acc) < MathAbs(prevAcc)*0.8 && vel<0;

   // ── SWINGS (pivot at confirmation center) ─────────────────────
   int center = 1 + g_cfg.pivotLen;
   double pH = CM_IsPivotHigh(hi, center, g_cfg.pivotLen, sz) ? hi[center] : EMPTY_VALUE;
   double pL = CM_IsPivotLow (lo, center, g_cfg.pivotLen, sz) ? lo[center] : EMPTY_VALUE;
   bool hasPH = (pH != EMPTY_VALUE);
   bool hasPL = (pL != EMPTY_VALUE);

   if(!s.init)
     {
      s.curSH=s.curSL=s.prSH=s.prSL=EMPTY_VALUE;
      s.lastP=s.prevP=EMPTY_VALUE; s.lastD=s.prevD=0;
      s.dir=0; s.ft=s.fb=s.p4h=s.p4l=s.inv=s.tgt=s.cycH=s.cycL=EMPTY_VALUE;
      s.bos1=s.bos2=false; s.protSw=s.protSw2=s.indOrig=s.indExt=EMPTY_VALUE;
      s.indBrk=false; s.lastDirSeen=0; s.recBrk=0; s.recArm=true; s.pst=0;
      s.init=true;
     }

   if(hasPH){ s.prSH = (s.curSH==EMPTY_VALUE)?pH:s.curSH; s.curSH=pH; }
   if(hasPL){ s.prSL = (s.curSL==EMPTY_VALUE)?pL:s.curSL; s.curSL=pL; }

   // pivot memory
   double eP=EMPTY_VALUE; int eD=0;
   if(hasPH){ eP=pH; eD=1; } else if(hasPL){ eP=pL; eD=-1; }
   if(eD!=0){ s.prevP=s.lastP; s.prevD=s.lastD; s.lastP=eP; s.lastD=eD; }

   bool bullBOS = (s.prSH!=EMPTY_VALUE) && close>s.prSH;
   bool bearBOS = (s.prSL!=EMPTY_VALUE) && close<s.prSL;
   double chBuf = g_cfg.chochBufferATR;
   bool bullCH  = (s.prSH!=EMPTY_VALUE) && close>s.prSH+atr*chBuf;
   bool bearCH  = (s.prSL!=EMPTY_VALUE) && close<s.prSL-atr*chBuf;

   double impM = g_cfg.impulseAtrMult;
   bool eLong  = hasPH && s.prevD==-1 && (pH-s.prevP)>atr*impM;
   bool eShort = hasPL && s.prevD== 1 && (s.prevP-pL)>atr*impM;

   // ── DIRECTION / SPAWN ─────────────────────────────────────────
   bool hasCtx = s.dir!=0 && s.ft!=EMPTY_VALUE;
   bool flipDn = s.dir==1  && bearCH;
   bool flipUp = s.dir==-1 && bullCH;
   bool isRev  = (eLong && s.dir==-1) || (eShort && s.dir==1) || flipUp || flipDn;
   bool spawn  = (eLong||eShort||flipUp||flipDn) && (!hasCtx || isRev);
   if(spawn)
     {
      int nd = eLong?1:(eShort?-1:(flipUp?1:-1));
      double phi = MathMax(s.lastP, s.prevP);
      double plo = MathMin(s.lastP, s.prevP);
      s.dir=nd; s.ft=phi; s.fb=plo; s.p4h=phi; s.p4l=plo;
      s.cycH=high; s.cycL=low;
      s.inv = (nd==1)?plo:phi;
      double rng = (s.prSH!=EMPTY_VALUE && s.prSL!=EMPTY_VALUE)?MathAbs(s.prSH-s.prSL):atr*5.0;
      s.tgt = (nd==1)? (s.ft+rng) : (s.fb-rng);
     }
   if(s.dir==1)  s.cycH = (s.cycH==EMPTY_VALUE)?high:MathMax(s.cycH,high);
   if(s.dir==-1) s.cycL = (s.cycL==EMPTY_VALUE)?low :MathMin(s.cycL,low);

   int bosOut = bullBOS?1:(bearBOS?-1:0);
   int chOut  = bullCH ?1:(bearCH ?-1:0);

   // ── LIFECYCLE INTERNALS ───────────────────────────────────────
   bool reset = (s.dir != s.lastDirSeen);
   s.lastDirSeen = s.dir;
   if(reset){ s.bos1=false; s.bos2=false; s.protSw=EMPTY_VALUE; s.protSw2=EMPTY_VALUE;
              s.indOrig=EMPTY_VALUE; s.indExt=EMPTY_VALUE; s.indBrk=false; }
   if(s.dir==1  && hasPL){ s.protSw2=s.protSw; s.protSw=pL; }
   if(s.dir==-1 && hasPH){ s.protSw2=s.protSw; s.protSw=pH; }
   bool oppBOS = (s.dir==1 && s.protSw!=EMPTY_VALUE && close<s.protSw) ||
                 (s.dir==-1&& s.protSw!=EMPTY_VALUE && close>s.protSw);
   if(!s.bos1 && oppBOS){ s.bos1=true; s.indOrig=(s.dir==1)?( s.cycH==EMPTY_VALUE?high:s.cycH):( s.cycL==EMPTY_VALUE?low:s.cycL); }
   if(s.bos1 && !s.bos2 && oppBOS && s.protSw2!=EMPTY_VALUE && (s.dir==1?close<s.protSw2:close>s.protSw2)) s.bos2=true;
   if(s.bos1 && s.dir==1)  s.indExt=(s.indExt==EMPTY_VALUE)?close:MathMin(s.indExt,close);
   if(s.bos1 && s.dir==-1) s.indExt=(s.indExt==EMPTY_VALUE)?close:MathMax(s.indExt,close);
   if(s.bos2 && s.indOrig!=EMPTY_VALUE)
     {
      if(s.dir==1 && close>s.indOrig)  s.indBrk=true;
      if(s.dir==-1&& close<s.indOrig)  s.indBrk=true;
     }

   double convScore = FAL_Clamp(MathAbs(csm)/MathMax(atr*convM,1e-10)*50.0,0,100);
   double expScore  = FAL_Clamp(eff/MathMax(effT,1e-10)*50.0 + disp/MathMax(dispT,1e-10)*50.0,0,100);
   double absScore  = (eff<effT*0.7 && MathAbs(vel)<MathAbs(prevVel)*0.6) ? 60.0+convScore*0.4 : convScore*0.3;
   bool momExpStrong = eff>effT*0.75 && (s.dir==1?vel>0:vel<0);
   bool momDecaying  = (s.dir==1)?bullDec:bearDec;
   bool momCounter   = (s.dir==1)?bearImp:bullImp;
   bool momExhaust   = eff<effT*0.65 && absScore>40.0;
   bool physConvex   = convScore>35.0;
   bool physTransfer = convScore>48.0 || absScore>40.0;
   bool physCapLow   = absScore>45.0 || eff<effT*0.6;

   int wdir = (s.inv!=EMPTY_VALUE)?(close>s.inv?1:(close<s.inv?-1:s.dir)):s.dir;
   bool atFlip = (s.ft!=EMPTY_VALUE && s.fb!=EMPTY_VALUE && close<=s.ft && close>=s.fb);
   bool expanding = momExpStrong || eLong || eShort || (wdir==1?bullImp:bearImp);
   bool atExtreme = (wdir==1)?(high>=(s.cycH==EMPTY_VALUE?high:s.cycH)):(wdir==-1?(low<=(s.cycL==EMPTY_VALUE?low:s.cycL)):false);
   double extr = (wdir==1)?(s.cycH==EMPTY_VALUE?close:s.cycH):(s.cycL==EMPTY_VALUE?close:s.cycL);
   bool extended = (s.inv!=EMPTY_VALUE) && MathAbs(extr-s.inv)>atr*1.5;
   double fzMid = (s.ft!=EMPTY_VALUE && s.fb!=EMPTY_VALUE)?(s.ft+s.fb)/2.0:EMPTY_VALUE;
   double retrFrac = (fzMid!=EMPTY_VALUE && MathAbs(extr-fzMid)>1e-10)?MathAbs(extr-close)/MathAbs(extr-fzMid):0.0;
   double compIdx = FAL_Clamp((1.0-MathMin(disp/MathMax(dispT,1e-10),1.0))*60.0 +
                               (1.0-MathMin(eff /MathMax(effT,1e-10),1.0))*40.0,0,100);

   // recursive transition
   bool phase2CH = (s.dir==1 && bearCH) || (s.dir==-1 && bullCH);
   if(reset || (atExtreme && extended)){ s.recBrk=0; s.recArm=true; }
   if((s.dir==1 && hasPH) || (s.dir==-1 && hasPL)) s.recArm=true;
   if((phase2CH||oppBOS) && s.recArm && !atExtreme){ s.recBrk++; s.recArm=false; }
   double recDom = FAL_Clamp(MathMax(s.recBrk*(30.0-compIdx*0.15), retrFrac*80.0),0,100);
   bool transferDone = recDom>=50.0;

   // ── PHASE STATE MACHINE (single-latch 0..13) ──────────────────
   if(reset) s.pst=0;
   if(s.dir!=0 && !reset)
     {
      if(s.pst==0 && expanding) s.pst=1;
      if(s.pst==1 && !atExtreme && momDecaying && physConvex) s.pst=2;
      if(s.pst==2 && !atExtreme && momCounter && physTransfer) s.pst=3;
      if(s.pst==3 && !atExtreme && (s.bos1||s.bos2||s.indBrk) && physTransfer) s.pst=4;
      if(s.pst>=1 && s.pst<=7 && atExtreme && extended) s.pst=5;
      if(s.pst==5 && !atExtreme && (s.recBrk>=1 || momExhaust)) s.pst=7;
      if(s.pst==7 && transferDone) s.pst=8;
      if(s.pst==8 && atFlip) s.pst=9;
      if(s.pst==9 && ((s.dir==1&&bullImp)||(s.dir==-1&&bearImp))) s.pst=10;
      if(s.pst==10 && (oppBOS||physCapLow)) s.pst=11;
      if(s.pst==11 && ((s.dir==1&&low<s.fb)||(s.dir==-1&&high>s.ft))) s.pst=12;
      if(s.pst==12 && ((s.dir==1&&bullCH)||(s.dir==-1&&bearCH))) s.pst=13;
     }
   int phase = s.pst;
   if(phase==5 && s.dir==-1) phase=6;
   if(phase==13 && s.dir==-1) phase=14;

   double wp = (s.pst==0)?5.0:(s.pst==1)?15.0:(s.pst==2)?25.0:(s.pst==3)?33.0:
               (s.pst==4)?42.0:(s.pst==5)?55.0:(s.pst==7)?65.0:(s.pst==8)?75.0:
               (s.pst==9)?85.0:(s.pst==10)?90.0:(s.pst==11)?94.0:(s.pst==12)?97.0:100.0;
   double cm = MathMin(convScore,100.0);
   double mf = FAL_Clamp(MathMax(expScore,MathMax(absScore,convScore))*0.70 + (s.dir!=0?30.0:0.0),0,100);
   double frzS = FAL_Clamp((eLong||eShort?50.0:0.0)+expScore*0.30+convScore*0.20,0,100);

   // ── WRITE TF RESULT ───────────────────────────────────────────
   FAL_TFStruct r;
   r.dir=wdir; r.phase=phase;
   r.swingHigh=s.curSH; r.swingLow=s.curSL; r.prevSwingHigh=s.prSH; r.prevSwingLow=s.prSL;
   r.bos=bosOut; r.choch=chOut; r.p4High=s.p4h; r.p4Low=s.p4l;
   r.invalidation=s.inv; r.target=s.tgt; r.flipTop=s.ft; r.flipBot=s.fb;
   r.frzScore=frzS; r.waveProgress=wp; r.convMaturity=cm; r.modelFit=mf;
   r.compression=compIdx; r.recBreaks=s.recBrk; r.dominance=recDom; r.barTime=t0;
   g_state.structure.tf[idx] = r;

   // L0 (M5) physics feeds the shared physics block (computed once).
   if(idx==FAL_L0)
     {
      FAL_Physics p;
      p.atr=atr; p.velocity=vel; p.acceleration=acc; p.convexity=cvx; p.convSmooth=csm;
      p.efficiency=eff; p.displacement=disp; p.momentum=vel-prevVel; p.compression=compIdx;
      p.expansion=expScore; p.bullImpulse=bullImp; p.bearImpulse=bearImp;
      p.bullDecay=bullDec; p.bearDecay=bearDec;
      p.bullConvShift=(csm>atr*convM && prevCsm<=atr*convM);
      p.bearConvShift=(csm<-atr*convM && prevCsm>=-atr*convM);
      p.velDecay70=MathAbs(vel)<MathAbs(prevVel)*0.7;
      p.velDecay50=MathAbs(vel)<MathAbs(prevVel)*0.5;
      // volatility regime
      double aS[]; ArraySetAsSeries(aS,true);
      double atrSma=atr;
      if(g_atrHandle[idx]!=INVALID_HANDLE && CopyBuffer(g_atrHandle[idx],0,1,20,aS)>0)
        { double sum=0; for(int i=0;i<20;i++) sum+=aS[i]; atrSma=sum/20.0; }
      p.volRatio = atr/MathMax(atrSma,1e-10);
      // physics observation layer
      double velScore = FAL_Clamp(MathAbs(vel)/MathMax(atr*0.1,1e-10)*50.0,0,100);
      double convexityScore = FAL_Clamp(MathAbs(csm)/MathMax(atr*convM,1e-10)*25.0,0,100);
      p.obsExpansion = FAL_Clamp((eff>effT?eff*60.0:eff*30.0) +
                       (disp>dispT?(disp/MathMax(dispT,1e-10)-1.0)*20.0:0.0) +
                       ((vel>0&&acc>0)||(vel<0&&acc<0)?velScore*0.2:0.0),0,100);
      p.obsDecay = FAL_Clamp((bullDec||bearDec?40.0:0.0)+(convexityScore>30?convexityScore*0.5:0.0)+(p.velDecay70?30.0:0.0),0,100);
      p.obsCurvature = convexityScore;
      p.obsAbsorption = FAL_Clamp((eff<effT*0.7?(1.0-eff/MathMax(effT,1e-10))*50.0:0.0)+(p.velDecay50?30.0:0.0)+(disp<dispT*0.5?20.0:0.0),0,100);
      p.obsLiquidity = FAL_Clamp(p.obsDecay*0.4+p.obsCurvature*0.4+(disp>dispT*1.2&&(bullDec||bearDec)?20.0:0.0),0,100);
      p.energy = FAL_Clamp(p.obsExpansion*0.5+(bullImp||bearImp?30.0:0.0)+eff*20.0,0,100);
      double pmax=MathMax(p.obsExpansion,MathMax(p.obsDecay,MathMax(p.obsAbsorption,p.obsLiquidity)));
      double pmin=MathMin(p.obsExpansion,MathMin(p.obsDecay,MathMin(p.obsAbsorption,p.obsLiquidity)));
      p.physicsConsensus=MathMax(0.0,100.0-(pmax-pmin));
      g_state.physics = p;
     }
  }

//==================================================================
// FRACTAL STACK ALIGNMENT
//==================================================================
void CM_FractalStack()
  {
   int sb=0, sr=0;
   for(int i=0;i<FAL_TF_COUNT;i++)
     {
      int d = g_state.structure.tf[i].dir;
      if(d==1) sb++; else if(d==-1) sr++;
     }
   g_state.structure.stackBull=sb;
   g_state.structure.stackBear=sr;
   g_state.structure.fractalStackDir = sb>sr?1:(sr>sb?-1:0);
   g_state.structure.fractalStackScore = MathMax(sb,sr)/(double)FAL_TF_COUNT*100.0;

   // M5-derived strict structure bias + BOS/CHoCH
   FAL_TFStruct m5 = g_state.structure.tf[FAL_L0];
   bool isHH = (m5.swingHigh!=EMPTY_VALUE && m5.prevSwingHigh!=EMPTY_VALUE && m5.swingHigh>m5.prevSwingHigh);
   bool isLH = (m5.swingHigh!=EMPTY_VALUE && m5.prevSwingHigh!=EMPTY_VALUE && m5.swingHigh<m5.prevSwingHigh);
   bool isHL = (m5.swingLow !=EMPTY_VALUE && m5.prevSwingLow !=EMPTY_VALUE && m5.swingLow >m5.prevSwingLow);
   bool isLL = (m5.swingLow !=EMPTY_VALUE && m5.prevSwingLow !=EMPTY_VALUE && m5.swingLow <m5.prevSwingLow);
   g_state.structure.isHH=isHH; g_state.structure.isHL=isHL;
   g_state.structure.isLH=isLH; g_state.structure.isLL=isLL;
   g_state.structure.bullBOS=(m5.bos==1); g_state.structure.bearBOS=(m5.bos==-1);
   g_state.structure.bullCHoCH=(m5.choch==1); g_state.structure.bearCHoCH=(m5.choch==-1);
   static int sbias=0;
   if(g_cfg.useStrictStructure){ if(isHH&&isHL) sbias=1; if(isLH&&isLL) sbias=-1; }
   else { if(m5.bos==1) sbias=1; if(m5.bos==-1) sbias=-1; }
   g_state.structure.structBias=sbias;
  }

//==================================================================
// LIQUIDITY HEATMAP  (chart-TF)
//==================================================================
double g_liqLevels[160]; double g_liqWeights[160]; datetime g_liqAges[160]; int g_liqN=0;
void CM_Liquidity()
  {
   double atr=g_state.physics.atr; if(atr<=0) return;
   double cl[],hi[],lo[]; long vol[];
   ArraySetAsSeries(cl,true);ArraySetAsSeries(hi,true);ArraySetAsSeries(lo,true);ArraySetAsSeries(vol,true);
   int need=MathMax(60,g_cfg.liqSweepLookback+g_cfg.pivotLen*2+5);
   if(CopyClose(_Symbol,_Period,0,need,cl)<=0) return;
   if(CopyHigh (_Symbol,_Period,0,need,hi)<=0) return;
   if(CopyLow  (_Symbol,_Period,0,need,lo)<=0) return;
   CopyTickVolume(_Symbol,_Period,0,need,vol);
   double close=cl[1];

   // register new pivot as a liquidity level
   int center=1+g_cfg.pivotLen; int sz=ArraySize(hi);
   double volAvg=0; for(int i=1;i<=20 && i<ArraySize(vol);i++) volAvg+=(double)vol[i]; volAvg/=20.0;
   double normVol = volAvg>0 ? (double)vol[center]/volAvg : 1.0;
   bool nH=CM_IsPivotHigh(hi,center,g_cfg.pivotLen,sz);
   bool nL=CM_IsPivotLow (lo,center,g_cfg.pivotLen,sz);
   if(nH||nL)
     {
      double lvl = nH?hi[center]:lo[center];
      double swRng=(hi[center]-lo[center])/MathMax(atr,1e-10);
      if(g_liqN<160){ g_liqLevels[g_liqN]=lvl; g_liqWeights[g_liqN]=normVol*swRng; g_liqAges[g_liqN]=iTime(_Symbol,_Period,center); g_liqN++; }
      else { for(int i=0;i<159;i++){ g_liqLevels[i]=g_liqLevels[i+1]; g_liqWeights[i]=g_liqWeights[i+1]; g_liqAges[i]=g_liqAges[i+1]; }
             g_liqLevels[159]=lvl; g_liqWeights[159]=normVol*swRng; g_liqAges[159]=iTime(_Symbol,_Period,center); }
     }

   double rP=atr*g_cfg.liqRadius, rW=atr*g_cfg.liqRadius*3.0;
   double wD=0,wA=0,wB=0;
   int barsPerNode=1;
   for(int i=0;i<g_liqN;i++)
     {
      double lvl=g_liqLevels[i], wt=g_liqWeights[i];
      int age=(int)((iTime(_Symbol,_Period,0)-g_liqAges[i])/MathMax(PeriodSeconds(_Period),1));
      double dcy=MathPow(g_cfg.liqAgDecay,(double)MathMax(age,0));
      double dist=MathAbs(close-lvl);
      if(dist<rP) wD+=wt*dcy;
      if(dist<rW){ if(lvl>close) wA+=wt*dcy*(1.0-dist/rW); else wB+=wt*dcy*(1.0-dist/rW); }
     }
   double liqHeat = FAL_Clamp(MathMin((wA+wB)/2.0,5.0)/5.0*100.0,0,100);
   g_state.liquidity.liqHeat=liqHeat;
   g_state.liquidity.wDensity=wD;
   g_state.liquidity.liqVacuum=(wD<0.5);
   g_state.liquidity.zone = liqHeat<30?"Open space":(liqHeat<70?"Active":"Congested");

   double swH=lo[1],swL=hi[1];
   double maxH=hi[1],minL=lo[1];
   for(int i=1;i<=g_cfg.liqSweepLookback && i<sz;i++){ if(hi[i]>maxH)maxH=hi[i]; if(lo[i]<minL)minL=lo[i]; }
   double ftop=g_state.wave.flipTop, fbot=g_state.wave.flipBot;
   g_state.liquidity.sweepBull = (ftop!=EMPTY_VALUE && ftop!=0 && maxH>ftop);
   g_state.liquidity.sweepBear = (fbot!=EMPTY_VALUE && fbot!=0 && minL<fbot);
   int wdir=g_state.wave.direction;
   g_state.liquidity.sweepOK = (!g_cfg.requireLiqSweep) ||
        (wdir==1 && (g_state.liquidity.sweepBull||g_state.liquidity.liqVacuum)) ||
        (wdir==-1&& (g_state.liquidity.sweepBear||g_state.liquidity.liqVacuum));
  }

//==================================================================
// HTF + TIME INTELLIGENCE  (bias from H1/H4 structure + cycle stack)
//==================================================================
void CM_HTF()
  {
   g_state.htf.biasH1 = g_state.structure.tf[4].dir;
   g_state.htf.biasH4 = g_state.structure.tf[5].dir;
   g_state.htf.align  = (g_state.htf.biasH1!=0 && g_state.htf.biasH1==g_state.htf.biasH4)?g_state.htf.biasH1:0;

   // 5-cycle time stack: bias = close vs cycle open
   ENUM_TIMEFRAMES cyc[5]={PERIOD_MN1,PERIOD_W1,PERIOD_D1,PERIOD_H4,PERIOD_H1};
   double close=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   int bull=0,bear=0;
   for(int i=0;i<5;i++)
     {
      double o=iOpen(_Symbol,cyc[i],0);
      if(o>0){ if(close>o) bull++; else if(close<o) bear++; }
     }
   g_state.htf.timeDir = bull>bear?1:(bear>bull?-1:0);
   double tot=bull+bear;
   g_state.htf.timeAlign = tot>0?MathMax(bull,bear)/tot*100.0:50.0;
   g_state.htf.timeConflict = 100.0-g_state.htf.timeAlign;
   // H1 timing from prior-bar sweep
   double h1h=iHigh(_Symbol,PERIOD_H1,0), h1l=iLow(_Symbol,PERIOD_H1,0);
   double h1ph=iHigh(_Symbol,PERIOD_H1,1), h1pl=iLow(_Symbol,PERIOD_H1,1);
   bool ht=h1h>h1ph, lt=h1l<h1pl;
   g_state.htf.h1Timing = (ht&&lt)?"COMPLETION":(lt&&!ht)?"LOW FIRST":(ht&&!lt)?"HIGH FIRST":"BALANCED";
  }

//==================================================================
// FU POOLS (multi-TF validated FU left-pool magnets)
//==================================================================
struct CM_FUState { datetime lastBar; double tip,bH,bL; int dir; bool valid; double score; };
CM_FUState g_fu[FAL_TF_COUNT];
void CM_ProcessFU(int idx, CM_FUState &f)
  {
   ENUM_TIMEFRAMES tf=FAL_TF[idx];
   datetime t0=iTime(_Symbol,tf,0); if(t0==0) return;
   if(t0==f.lastBar)
     {
      // still update validation against forming price
     }
   double hi[],lo[],op[],cl[]; ArraySetAsSeries(hi,true);ArraySetAsSeries(lo,true);ArraySetAsSeries(op,true);ArraySetAsSeries(cl,true);
   int lb=g_cfg.fuLookback;
   int need=lb+6;
   if(CopyHigh(_Symbol,tf,0,need,hi)<=0)return; if(CopyLow(_Symbol,tf,0,need,lo)<=0)return;
   if(CopyOpen(_Symbol,tf,0,need,op)<=0)return; if(CopyClose(_Symbol,tf,0,need,cl)<=0)return;
   int c=1;
   double rng=MathMax(hi[c]-lo[c],1e-10);
   double priorHi=hi[c+1],priorLo=lo[c+1];
   for(int i=1;i<=lb;i++){ if(hi[c+i]>priorHi)priorHi=hi[c+i]; if(lo[c+i]<priorLo)priorLo=lo[c+i]; }
   double uw=(hi[c]-MathMax(op[c],cl[c]))/rng;
   double lw=(MathMin(op[c],cl[c])-lo[c])/rng;
   double wf=g_cfg.fuWickFrac;
   bool bear = uw>=wf && hi[c]>priorHi && cl[c]<priorHi;
   bool bull = lw>=wf && lo[c]<priorLo && cl[c]>priorLo;
   if(t0!=f.lastBar)
     {
      f.lastBar=t0;
      if(bear){ f.dir=-1; f.tip=hi[c]; f.bH=MathMax(op[c],cl[c]); f.bL=MathMin(op[c],cl[c]); f.valid=true; }
      else if(bull){ f.dir=1; f.tip=lo[c]; f.bH=MathMax(op[c],cl[c]); f.bL=MathMin(op[c],cl[c]); f.valid=true; }
      if(f.valid)
        {
         double atr=g_state.physics.atr; if(atr<=0)atr=rng;
         double wk = (f.dir==-1)?(f.tip-f.bH)/MathMax(atr,1e-10):(f.bL-f.tip)/MathMax(atr,1e-10);
         f.score = 20.0+MathMin(25.0,wk*15.0)+15.0+(wk>1.0?15.0:0.0)+(wk>1.5?10.0:0.0);
        }
     }
   g_state.fu.tip[idx]   = f.valid?f.tip:EMPTY_VALUE;
   g_state.fu.dir[idx]   = f.dir;
   g_state.fu.score[idx] = f.score;
   g_state.fu.valid[idx] = f.valid;
  }
void CM_FUResolve()
  {
   double close=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   int active=0; double win=EMPTY_VALUE; int winIdx=-1;
   // highest-TF validated FU on bias side becomes the magnet
   for(int i=FAL_TF_COUNT-1;i>=0;i--)
     {
      if(g_state.fu.valid[i]){ active++; if(winIdx<0) winIdx=i; }
     }
   if(winIdx>=0) win=g_state.fu.tip[winIdx];
   g_state.fu.activeCount=active;
   g_state.fu.recursiveAlign=active/(double)FAL_TF_COUNT*100.0;
   g_state.fu.winTarget=win;
   g_state.fu.winBand = win;
  }

//==================================================================
// MODULE 1 INIT + RUN
//==================================================================
void CM_Init()
  {
   for(int i=0;i<FAL_TF_COUNT;i++)
     {
      g_se[i].init=false;
      g_fu[i].lastBar=0; g_fu[i].valid=false; g_fu[i].dir=0; g_fu[i].score=0;
      g_atrHandle[i]=iATR(_Symbol,FAL_TF[i],g_cfg.atrLen);
     }
   g_liqN=0;
   FAL_SetModuleStatus(0,"ready");
  }

// Deterministic step 1: physics + structure (all rungs) -> stack -> FU -> HTF.
// (Liquidity runs LATER, after the wave-spawn engine sets the current flip zone.)
void CM_StepStructure()
  {
   g_state.spot = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   for(int i=0;i<FAL_TF_COUNT;i++) CM_ProcessTF(i,g_se[i]);
   CM_FractalStack();
   for(int i=0;i<FAL_TF_COUNT;i++) CM_ProcessFU(i,g_fu[i]);
   CM_FUResolve();
   CM_HTF();
   FAL_Publish("CORE_UPDATED");
   if(g_state.physics.bullImpulse) FAL_Publish("IMPULSE_BULL");
   if(g_state.physics.bearImpulse) FAL_Publish("IMPULSE_BEAR");
   FAL_SetModuleStatus(0,"ok");
  }
// Deterministic step 2: liquidity heatmap (consumes the just-set flip zone).
void CM_StepLiquidity(){ CM_Liquidity(); }

#endif // FALCON_COREMARKET_MQH
