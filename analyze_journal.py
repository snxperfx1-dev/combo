#!/usr/bin/env python3
"""
FALCON OS — Trade Journal analyzer.

Reads the CSV written by the TradeJournal module (FALCON_Journal_<sym>_<tf>.csv,
in <MT5 DataFolder>/MQL5/Files/  — the COMMON files dir) and reports win-rate +
expectancy (avg R) bucketed by each panel setting, so you can pick thresholds on
EVIDENCE (e.g. "only trade when confidence >= 70").

It auto-detects the ENTRY ENGINE from the trade tag (LETRA / F16 / SYMPHONY) and
prints the full breakdown PER ENGINE, plus a stop/target fit from the MFE/MAE
distribution — i.e. "which settings work best for each engine".

Usage:
    python3 analyze_journal.py FALCON_Journal_XAUUSD_5.csv
    python3 analyze_journal.py FALCON_Journal_XAUUSD_5.csv --min-trades 8
    python3 analyze_journal.py FALCON_Journal_XAUUSD_5.csv --overall-only

resultR = profit / risked-cash (R-multiple). Expectancy = avg R per trade:
> 0 means the bucket makes money over time.
"""
import csv, sys, argparse
from collections import defaultdict


def load(path):
    rows = []
    with open(path, newline="") as f:
        for r in csv.DictReader(f):
            try:
                for k in ("conf", "execProb", "threat", "conflict", "opp",
                          "mcScore", "completion", "geomCap", "ownerCtrl",
                          "htfAlign", "resultR", "profit", "mfeR", "maeR"):
                    r[k] = float(r[k])
                r["win"] = int(r["win"])
            except (ValueError, KeyError):
                continue
            # derive entry engine + phase kind from the tag ("LETRA P3 Long")
            parts = str(r.get("tag", "")).split()
            r["engine"] = parts[0].upper() if parts else "?"
            r["pkind"] = next((p.upper() for p in parts
                               if p.upper() in ("P1", "P2", "P3", "P4")), "?")
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


def print_overall(rows, label="OVERALL"):
    s = summarize(rows)
    print("=" * 74)
    print(f"{label}  trades={s['n']}  win%={s['wr']:.1f}  "
          f"expectancy={s['expR']:+.3f}R  totalR={s['totR']:+.1f}  "
          f"netP={s['totP']:+.2f}  PF={s['pf']:.2f}")
    print(f"         avg MFE={s['avgMfe']:.2f}R   avg MAE={s['avgMae']:.2f}R")
    print("=" * 74)


def bucket_threshold(rows, key, edges, min_trades, direction=">="):
    print(f"\n[{key}]  filter {direction} threshold  "
          f"(does tightening the gate improve expectancy?)")
    print(f"  {'thresh':>7} | {'kept':>5} | {'win%':>6} | {'expR':>7} | "
          f"{'totR':>7} | {'PF':>5}")
    print("  " + "-" * 56)
    for e in edges:
        sub = ([r for r in rows if r[key] >= e] if direction == ">="
               else [r for r in rows if r[key] <= e])
        if len(sub) < min_trades:
            print(f"  {e:>7.2f} | {len(sub):>5} |   (too few)")
            continue
        s = summarize(sub)
        print(f"  {e:>7.2f} | {s['n']:>5} | {s['wr']:>5.1f}% | "
              f"{s['expR']:>+6.3f} | {s['totR']:>+6.1f} | {s['pf']:>5.2f}")


def bucket_bins(rows, key, bins, min_trades):
    print(f"\n[{key}]  per-range (which band is actually profitable?)")
    print(f"  {'range':>13} | {'n':>4} | {'win%':>6} | {'expR':>7} | {'totR':>7}")
    print("  " + "-" * 52)
    for lo, hi in zip(bins[:-1], bins[1:]):
        sub = [r for r in rows if lo <= r[key] < hi]
        if len(sub) < min_trades:
            print(f"  {lo:>5.1f}-{hi:<6.1f} | {len(sub):>4} |   (too few)")
            continue
        s = summarize(sub)
        print(f"  {lo:>5.1f}-{hi:<6.1f} | {s['n']:>4} | {s['wr']:>5.1f}% | "
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


def _pct(sorted_arr, p):
    if not sorted_arr:
        return 0.0
    return sorted_arr[int(p * (len(sorted_arr) - 1))]


def recommend_stop_target(rows, label=""):
    """Use the MFE/MAE distribution to suggest target & stop (in R = x current stop)."""
    wins = [r for r in rows if r["win"] == 1]
    if len(rows) < 5:
        return
    mfes = sorted(r["mfeR"] for r in rows)
    mae_win = sorted(r["maeR"] for r in wins) if wins else [0.0]
    print(f"\n[STOP/TARGET FIT {label}]  (R = multiples of the CURRENT stop distance)")
    print(f"  MFE        p50={_pct(mfes,.5):.2f}R  p75={_pct(mfes,.75):.2f}R  "
          f"p90={_pct(mfes,.9):.2f}R   <- how far price runs your way")
    print(f"  winner MAE p50={_pct(mae_win,.5):.2f}R  p75={_pct(mae_win,.75):.2f}R  "
          f"p90={_pct(mae_win,.9):.2f}R   <- how far WINNERS dip before working")
    tgt = _pct(mfes, .75)
    print(f"  hint: set RawTgtATR so the target sits near MFE p75 ({tgt:.1f}x stop); "
          f"if winner-MAE p90 > ~0.9R your stop is too tight (clipping winners).")


def full_report(rows, mt, label):
    print_overall(rows, label)
    bucket_threshold(rows, "conf",       [40, 45, 50, 55, 60, 65, 70, 75, 80], mt)
    bucket_threshold(rows, "execProb",   [.20, .30, .40, .50, .60, .70, .80], mt)
    bucket_threshold(rows, "ownerCtrl",  [40, 50, 60, 70, 80], mt)
    bucket_threshold(rows, "htfAlign",   [40, 50, 60, 70, 80], mt)
    bucket_threshold(rows, "completion", [90, 85, 80, 70, 60], mt, "<=")
    bucket_bins(rows, "conf",     [0, 40, 50, 55, 60, 70, 80, 101], mt)
    bucket_bins(rows, "geomCap",  [0, 20, 40, 60, 80, 101], mt)
    bucket_categorical(rows, "pkind", mt)
    bucket_categorical(rows, "dir", mt)
    bucket_categorical(rows, "phase", mt)
    recommend_stop_target(rows, label)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("csv")
    ap.add_argument("--min-trades", type=int, default=6,
                    help="ignore buckets with fewer trades than this")
    ap.add_argument("--overall-only", action="store_true",
                    help="skip the per-engine breakdown")
    a = ap.parse_args()

    rows = load(a.csv)
    if not rows:
        print("No usable rows found in", a.csv)
        sys.exit(1)

    mt = a.min_trades

    # which engines are present?
    engines = sorted({r["engine"] for r in rows})
    print(f"\nEngines in this journal: {', '.join(engines)}   (total trades {len(rows)})")

    # 1) overall (all engines combined)
    full_report(rows, mt, "OVERALL (all engines)")

    # 2) per-engine breakdown — the "which settings work best for EACH" answer
    if not a.overall_only and len(engines) > 1:
        for eng in engines:
            sub = [r for r in rows if r["engine"] == eng]
            if len(sub) < mt:
                continue
            print("\n\n" + "#" * 74)
            print(f"# ENGINE: {eng}")
            print("#" * 74)
            full_report(sub, mt, f"ENGINE {eng}")

    print("\nRead expectancy (expR) as $ won per $1 risked, per trade. For each "
          "engine pick the lowest threshold where expR stays solidly positive\n"
          "AND kept-trade count is still meaningful — that is its gate. Then set "
          "the matching input (InpMinConf / InpExecProbArm / InpCycleRawTgtATR ...).")


if __name__ == "__main__":
    main()
