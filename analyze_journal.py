#!/usr/bin/env python3
"""
FALCON OS — Trade Journal analyzer.

Reads the CSV written by the TradeJournal module (FALCON_Journal_<sym>_<tf>.csv,
found in <MT5 DataFolder>/MQL5/Files/  — it is written to the COMMON files dir)
and reports win-rate + expectancy (avg R) bucketed by each panel setting, so you
can pick thresholds on EVIDENCE (e.g. "only trade when confidence >= 70").

Usage:
    python3 analyze_journal.py FALCON_Journal_XAUUSD_15.csv
    python3 analyze_journal.py FALCON_Journal_XAUUSD_15.csv --min-trades 8

The key column is `resultR` (profit / risked-cash = R-multiple). Expectancy is
the average R per trade: > 0 means the bucket makes money over time.
"""
import csv, sys, argparse
from collections import defaultdict


def load(path):
    rows = []
    with open(path, newline="") as f:
        for r in csv.DictReader(f):
            try:
                r["conf"] = float(r["conf"])
                r["execProb"] = float(r["execProb"])
                r["threat"] = float(r["threat"])
                r["conflict"] = float(r["conflict"])
                r["opp"] = float(r["opp"])
                r["mcScore"] = float(r["mcScore"])
                r["completion"] = float(r["completion"])
                r["geomCap"] = float(r["geomCap"])
                r["ownerCtrl"] = float(r["ownerCtrl"])
                r["htfAlign"] = float(r["htfAlign"])
                r["resultR"] = float(r["resultR"])
                r["profit"] = float(r["profit"])
                r["mfeR"] = float(r["mfeR"])
                r["maeR"] = float(r["maeR"])
                r["win"] = int(r["win"])
            except (ValueError, KeyError):
                continue
            rows.append(r)
    return rows


def summarize(rows):
    n = len(rows)
    if n == 0:
        return None
    wins = sum(r["win"] for r in rows)
    totR = sum(r["resultR"] for r in rows)
    totP = sum(r["profit"] for r in rows)
    gains = sum(r["profit"] for r in rows if r["profit"] > 0)
    losses = -sum(r["profit"] for r in rows if r["profit"] < 0)
    pf = (gains / losses) if losses > 0 else float("inf")
    return dict(n=n, wr=100.0 * wins / n, expR=totR / n, totR=totR,
                totP=totP, pf=pf, avgMfe=sum(r["mfeR"] for r in rows) / n,
                avgMae=sum(r["maeR"] for r in rows) / n)


def print_overall(rows):
    s = summarize(rows)
    print("=" * 74)
    print(f"OVERALL  trades={s['n']}  win%={s['wr']:.1f}  "
          f"expectancy={s['expR']:+.3f}R  totalR={s['totR']:+.1f}  "
          f"netP={s['totP']:+.2f}  PF={s['pf']:.2f}")
    print(f"         avg MFE={s['avgMfe']:.2f}R   avg MAE={s['avgMae']:.2f}R")
    print("=" * 74)


def bucket_threshold(rows, key, edges, min_trades, direction=">="):
    """For each edge, summarise trades that pass key >= edge (or <= edge)."""
    print(f"\n[{key}]  filter {direction} threshold  "
          f"(does tightening the gate improve expectancy?)")
    print(f"  {'thresh':>7} | {'kept':>5} | {'win%':>6} | {'expR':>7} | "
          f"{'totR':>7} | {'PF':>5}")
    print("  " + "-" * 56)
    for e in edges:
        if direction == ">=":
            sub = [r for r in rows if r[key] >= e]
        else:
            sub = [r for r in rows if r[key] <= e]
        if len(sub) < min_trades:
            print(f"  {e:>7.2f} | {len(sub):>5} |   (too few)")
            continue
        s = summarize(sub)
        print(f"  {e:>7.2f} | {s['n']:>5} | {s['wr']:>5.1f}% | "
              f"{s['expR']:>+6.3f} | {s['totR']:>+6.1f} | {s['pf']:>5.2f}")


def bucket_bins(rows, key, bins, min_trades):
    """Non-cumulative bins: which RANGE of the value is best?"""
    print(f"\n[{key}]  per-range (which band is actually profitable?)")
    print(f"  {'range':>13} | {'n':>4} | {'win%':>6} | {'expR':>7} | {'totR':>7}")
    print("  " + "-" * 52)
    for lo, hi in zip(bins[:-1], bins[1:]):
        sub = [r for r in rows if lo <= r[key] < hi]
        if len(sub) < min_trades:
            print(f"  {lo:>5.1f}–{hi:<6.1f} | {len(sub):>4} |   (too few)")
            continue
        s = summarize(sub)
        print(f"  {lo:>5.1f}–{hi:<6.1f} | {s['n']:>4} | {s['wr']:>5.1f}% | "
              f"{s['expR']:>+6.3f} | {s['totR']:>+6.1f}")


def bucket_categorical(rows, key, min_trades):
    print(f"\n[{key}]  by category")
    print(f"  {'value':>12} | {'n':>4} | {'win%':>6} | {'expR':>7} | {'totR':>7}")
    print("  " + "-" * 50)
    groups = defaultdict(list)
    for r in rows:
        groups[r.get(key, "?")].append(r)
    for v, sub in sorted(groups.items(), key=lambda kv: -summarize(kv[1])["totR"]):
        if len(sub) < min_trades:
            continue
        s = summarize(sub)
        print(f"  {str(v):>12} | {s['n']:>4} | {s['wr']:>5.1f}% | "
              f"{s['expR']:>+6.3f} | {s['totR']:>+6.1f}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("csv")
    ap.add_argument("--min-trades", type=int, default=6,
                    help="ignore buckets with fewer trades than this")
    a = ap.parse_args()

    rows = load(a.csv)
    if not rows:
        print("No usable rows found in", a.csv)
        sys.exit(1)

    print_overall(rows)
    mt = a.min_trades

    # Cumulative threshold sweeps — the question "trade only when X >= t?"
    bucket_threshold(rows, "conf",     [40, 45, 50, 55, 60, 65, 70, 75, 80], mt)
    bucket_threshold(rows, "execProb", [.20, .30, .40, .50, .60, .70, .80], mt)
    bucket_threshold(rows, "mcScore",  [40, 50, 55, 60, 65, 70, 75], mt)
    bucket_threshold(rows, "ownerCtrl",[40, 50, 60, 70, 80], mt)
    bucket_threshold(rows, "htfAlign", [40, 50, 60, 70, 80], mt)
    bucket_threshold(rows, "threat",   [70, 60, 50, 45, 40, 30], mt, "<=")
    bucket_threshold(rows, "conflict", [70, 60, 50, 40, 30], mt, "<=")
    bucket_threshold(rows, "completion",[90, 85, 80, 70, 60], mt, "<=")

    # Per-range bins — the question "which BAND is best?"
    bucket_bins(rows, "conf",     [0, 40, 50, 55, 60, 70, 80, 101], mt)
    bucket_bins(rows, "execProb", [0, .2, .3, .4, .5, .6, .7, 1.01], mt)
    bucket_bins(rows, "geomCap",  [0, 20, 40, 60, 80, 101], mt)

    # Categorical
    bucket_categorical(rows, "tag", mt)
    bucket_categorical(rows, "dir", mt)
    bucket_categorical(rows, "oppGrade", mt)
    bucket_categorical(rows, "mcConfirm", mt)
    bucket_categorical(rows, "phase", mt)
    bucket_categorical(rows, "intent", mt)
    bucket_categorical(rows, "timing", mt)

    print("\nRead expectancy (expR) as $ won per $1 risked, per trade. Pick the "
          "lowest threshold where expR stays solidly positive AND kept-trade\n"
          "count is still meaningful — that is your gate. Then set the matching "
          "input (InpMinConf / InpExecProbArm / InpMaxThreat ...).")


if __name__ == "__main__":
    main()
