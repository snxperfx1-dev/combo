#!/usr/bin/env bash
# Regenerate the single-file FALCON OS build by concatenating kernel + engines.
# Strips per-file #include and #property lines; emits one #property block + Trade include.
set -euo pipefail
cd "$(dirname "$0")"
SRC=FALCON_OS
OUT=FalconOS_AllInOne.mq5
VER="${1:-3.28}"

ORDER=(
  "Kernel/FalconConfig.mqh"
  "Kernel/FalconState.mqh"
  "Kernel/FalconSeries.mqh"
  "Kernel/FalconEventBus.mqh"
  "Kernel/FalconLog.mqh"
  "Kernel/FalconPersistence.mqh"
  "Engines/MarketEngine.mqh"
  "Engines/MemoryEngine.mqh"
  "Engines/CurveTree.mqh"
  "Engines/TimeEngine.mqh"
  "Engines/CurveLocator.mqh"
  "Engines/WaveCycleIntel.mqh"
  "Engines/IntelligenceEngine.mqh"
  "Engines/DecisionEngine.mqh"
  "Engines/ExecutionEngine.mqh"
  "Engines/ThermalRiskEngine.mqh"
  "Engines/MoneyManager.mqh"
  "Engines/TradePlan.mqh"
  "Engines/TradeJournal.mqh"
  "Engines/Adaptive.mqh"
  "Engines/SelfAwareness.mqh"
  "Engines/MissTrade.mqh"
  "Engines/SymphonyEngine.mqh"
  "Engines/Visualization.mqh"
  "FalconOS.mq5"
)

{
  cat <<EOF
//+------------------------------------------------------------------+
//|                                            FalconOS_AllInOne.mq5 |
//|   FALCON OS — Unified Trading Intelligence Platform               |
//|   SINGLE-FILE BUILD (all kernel + engines concatenated)          |
//|   Risk: PYRO thermal + TALON curve-convergent structural grip.   |
//+------------------------------------------------------------------+
#property copyright "FALCON OS"
#property version   "${VER}"
#property strict

#include <Trade\\Trade.mqh>

EOF
  for f in "${ORDER[@]}"; do
    echo ""
    echo "//  ===== ${f} ====="
    # strip #include lines and #property lines (kept once in the header above)
    grep -vE '^[[:space:]]*#include' "$SRC/$f" | grep -vE '^[[:space:]]*#property'
  done
} > "$OUT"

echo "WROTE $OUT  (version $VER)"
wc -l "$OUT"
