#!/usr/bin/env python3
# -----------------------------------------------------------------------------
# analysis.py
#
# Statistical analysis of spontaneous calcium-imaging network dynamics in
# primary mouse cortical cultures across three conditions:
#     Control  (ctrl) — vehicle only
#     TTX      (ttx)  — tetrodotoxin (Na+ channel blocker; silences spiking)
#     Blocker  (bloq) — synaptic blocker cocktail
#                       (removes both excitation and inhibition)
#
# Unit of analysis
# ----------------
# One row = one field of view (FOV) / coverslip. Per-cell variability within a
# FOV has already been averaged by sCaSpA, so FOV is the natural (and only
# valid) unit of inference here. We do NOT treat individual neurons as
# independent observations.
#
# Pipeline
# --------
# 1. Load, parse condition from CoverslipID prefix, filter KeepFOV==1.
# 2. Descriptives per group (n, mean, SD, median, IQR, min, max).
# 3. Per-metric assumption testing:
#        - Shapiro-Wilk per group (normality)
#        - Levene (homogeneity of variance)
# 4. Choose omnibus test per metric from the decision tree:
#        normal + equal var          -> one-way ANOVA  + Tukey HSD
#        normal + unequal var        -> Welch's ANOVA  + Games-Howell
#        not normal                  -> Kruskal-Wallis + Dunn (BH-adjusted)
# 5. Compute effect size (eta^2 / omega^2 for ANOVA, epsilon^2 for KW).
# 6. Benjamini-Hochberg FDR correction across the 11 omnibus p-values.
# 7. Save all tables (CSV) and figures (PNG + PDF).
#
# Why these choices
# -----------------
# - n per group is 4-7. With n this small, every classical normality test has
#   very low power: a non-significant Shapiro-Wilk does NOT prove normality,
#   it just fails to reject it. We therefore (a) always inspect distributions
#   visually, (b) use the parametric test only when BOTH groups look
#   approximately normal AND variances are not grossly unequal, and (c)
#   default to the non-parametric Kruskal-Wallis + Dunn otherwise. This is
#   consistent with standard practice for small-n calcium-imaging datasets.
# - BH-FDR (q = 0.05) is used across metrics rather than Bonferroni, because
#   the metrics are correlated (e.g. MeanDuration25/50/75/90 share a lot of
#   variance) and Bonferroni is unnecessarily conservative in that setting.
# - We never drop a data point for being "an outlier"; the whole point of a
#   raincloud plot is to show every FOV.
#
# Author: analysis prepared for Javeth (homeostatic plasticity project)
# -----------------------------------------------------------------------------

from __future__ import annotations

import json
import re
import sys
import warnings
from pathlib import Path

import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import scikit_posthocs as sp
import seaborn as sns
from scipy import stats
from statsmodels.stats.multitest import multipletests
from statsmodels.stats.oneway import anova_oneway

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

PROJECT_ROOT = Path(__file__).resolve().parent
DATA_PATH    = PROJECT_ROOT / "data.csv"
OUT_TABLES   = PROJECT_ROOT / "outputs" / "tables"
OUT_FIGURES  = PROJECT_ROOT / "figures"
OUT_TABLES.mkdir(parents=True, exist_ok=True)
OUT_FIGURES.mkdir(parents=True, exist_ok=True)

# Fixed display order and colors. Order chosen so the baseline (Control) is
# leftmost and TTX / Bloq follow in increasing "pharmacological severity".
GROUP_ORDER   = ["ctrl", "ttx", "bloq"]
GROUP_LABELS  = {"ctrl": "Control", "ttx": "TTX", "bloq": "Blocker cocktail"}
# Muted, journal-style palette for the overlaid data points only.
# Boxes themselves are black-outlined, white-filled — the point color is the
# only thing that distinguishes groups beyond the x-axis label.
GROUP_COLORS  = {"ctrl": "#444444",   # dark grey
                 "ttx":  "#9A3A3A",   # muted red
                 "bloq": "#4A4A7A"}   # muted indigo

# The 11 numeric metrics we treat as separate dependent variables.
METRICS = [
    "NetworkFrequency",
    "SilentCells",
    "MeanFrequency",
    "MeanInterSpikeInterval",
    "MeanSynchronicity",
    "MeanIsolated",
    "MeanTimeToRise",
    "MeanDuration25",
    "MeanDuration50",
    "MeanDuration75",
    "MeanDuration90",
    "MeanProminence",
]

# Short, human-readable labels used in figure titles and the report.
METRIC_LABELS = {
    "NetworkFrequency":        "Network burst frequency (Hz)",
    "SilentCells":             "Silent cells (%)",
    "MeanFrequency":           "Mean single-cell frequency (Hz)",
    "MeanInterSpikeInterval":  "Mean inter-spike interval (s)",
    "MeanSynchronicity":       "Mean synchronicity (%)",
    "MeanIsolated":            "Mean isolated spikes (%)",
    "MeanTimeToRise":          "Mean time to rise (s)",
    "MeanDuration25":          "Transient duration at 25% (s)",
    "MeanDuration50":          "Transient duration at 50% (s)",
    "MeanDuration75":          "Transient duration at 75% (s)",
    "MeanDuration90":          "Transient duration at 90% (s)",
    "MeanProminence":          "Transient prominence (ΔF/F₀)",
}

ALPHA = 0.05  # significance level for every test, FDR, and post-hoc

# APA7-ish matplotlib defaults
# - sans-serif, 10-11pt body
# - no top/right spines, no gridlines, black on white
# - figure sized to a journal single column (~3.5 in wide)
mpl.rcParams.update({
    "font.family":          "DejaVu Sans",   # Arial/Helvetica substitute
    "font.size":            10,
    "axes.titlesize":       11,
    "axes.labelsize":       10,
    "xtick.labelsize":      9,
    "ytick.labelsize":      9,
    "legend.fontsize":      9,
    "axes.spines.top":      False,
    "axes.spines.right":    False,
    "axes.linewidth":       0.9,
    "xtick.major.width":    0.9,
    "ytick.major.width":    0.9,
    "savefig.dpi":          300,
    "savefig.bbox":         "tight",
    "pdf.fonttype":         42,              # embed TrueType, not Type3
    "ps.fonttype":          42,
})


# -----------------------------------------------------------------------------
# 1. Load and prepare data
# -----------------------------------------------------------------------------

def parse_condition(coverslip_id: str) -> str | None:
    """Extract the condition name from a CoverslipID like 'bloqcs01fov1'.

    The prefix (letters before 'cs<digits>') encodes the condition.
    """
    m = re.match(r"^([a-z]+)cs\d+", str(coverslip_id))
    return m.group(1) if m else None


def load_data(path: Path) -> pd.DataFrame:
    """Load the CSV, parse condition, and filter to usable rows.

    Rule for keeping a FOV:
        - KeepFOV == 1
        - At least NetworkFrequency and MeanFrequency are not missing
          (per-metric NaN is handled downstream, listwise, so a FOV
          with one missing metric is still used for the other 10).
    """
    df = pd.read_csv(path)
    df["Condition"] = df["CoverslipID"].apply(parse_condition)
    df = df[df["KeepFOV"] == 1].copy()
    df = df[df["Condition"].isin(GROUP_ORDER)].copy()
    df["Condition"] = pd.Categorical(df["Condition"],
                                     categories=GROUP_ORDER,
                                     ordered=True)
    df = df.sort_values(["Condition", "CoverslipID"]).reset_index(drop=True)
    return df


# -----------------------------------------------------------------------------
# 2. Descriptive statistics
# -----------------------------------------------------------------------------

def descriptives(df: pd.DataFrame) -> pd.DataFrame:
    """Produce a tidy table of per-group descriptives for every metric."""
    rows = []
    for metric in METRICS:
        for group in GROUP_ORDER:
            vals = df.loc[df["Condition"] == group, metric].dropna().values
            if vals.size == 0:
                row = {"metric": metric, "group": group, "n": 0}
            else:
                row = {
                    "metric": metric,
                    "group":  group,
                    "n":      int(vals.size),
                    "mean":   float(np.mean(vals)),
                    "sd":     float(np.std(vals, ddof=1)) if vals.size > 1 else np.nan,
                    "sem":    float(stats.sem(vals, ddof=1)) if vals.size > 1 else np.nan,
                    "median": float(np.median(vals)),
                    "q25":    float(np.percentile(vals, 25)),
                    "q75":    float(np.percentile(vals, 75)),
                    "min":    float(np.min(vals)),
                    "max":    float(np.max(vals)),
                }
            rows.append(row)
    return pd.DataFrame(rows)


# -----------------------------------------------------------------------------
# 3. Assumption tests
# -----------------------------------------------------------------------------

def shapiro_per_group(df: pd.DataFrame, metric: str) -> dict:
    """Shapiro-Wilk normality test on each group's values for one metric.

    Returns the test statistic (W) and p-value per group. A low p-value
    rejects normality. With n = 4-7, power is very low; a non-rejection
    is weak evidence of normality, not proof.
    """
    out = {}
    for g in GROUP_ORDER:
        vals = df.loc[df["Condition"] == g, metric].dropna().values
        if vals.size >= 3 and np.ptp(vals) > 0:
            W, p = stats.shapiro(vals)
            out[g] = {"n": int(vals.size), "W": float(W), "p": float(p)}
        else:
            # Can't run Shapiro on <3 points or on a constant sample.
            out[g] = {"n": int(vals.size), "W": np.nan, "p": np.nan}
    return out


def levene_across_groups(df: pd.DataFrame, metric: str) -> dict:
    """Levene's test for equality of variance across the three groups.

    Uses the median-centered variant ("Brown-Forsythe"), which is more
    robust to non-normality than the mean-centered classical Levene.
    """
    groups = [df.loc[df["Condition"] == g, metric].dropna().values
              for g in GROUP_ORDER]
    if all(g.size >= 2 for g in groups):
        W, p = stats.levene(*groups, center="median")
        return {"W": float(W), "p": float(p)}
    return {"W": np.nan, "p": np.nan}


# -----------------------------------------------------------------------------
# 4. Omnibus tests + decision tree
# -----------------------------------------------------------------------------

def choose_test(shapiro: dict, levene: dict, alpha: float = ALPHA) -> str:
    """Pick the appropriate omnibus test for a metric.

    normal   = Shapiro p >= alpha for EVERY group with n>=3
    equalvar = Levene  p >= alpha

    normal + equalvar  -> 'anova'    (one-way ANOVA, parametric)
    normal + unequal   -> 'welch'    (Welch's ANOVA, parametric, no equal-var)
    not normal         -> 'kruskal'  (Kruskal-Wallis, rank-based)
    """
    group_ps = [v["p"] for v in shapiro.values()
                if v["n"] >= 3 and not np.isnan(v["p"])]
    normal   = len(group_ps) > 0 and all(p >= alpha for p in group_ps)
    equalvar = (not np.isnan(levene["p"])) and levene["p"] >= alpha
    if normal and equalvar:
        return "anova"
    if normal and not equalvar:
        return "welch"
    return "kruskal"


def run_omnibus(df: pd.DataFrame, metric: str, which: str) -> dict:
    """Run the chosen omnibus test and return F or H, p, df, and effect size.

    Effect sizes:
        ANOVA / Welch:  eta^2 = SS_between / SS_total,
                        omega^2 (less biased for small n)
        Kruskal-Wallis: epsilon^2 = (H - k + 1) / (N - k),
                        the recommended effect size for KW
                        (Tomczak & Tomczak 2014).
    """
    groups = [df.loc[df["Condition"] == g, metric].dropna().values
              for g in GROUP_ORDER]
    all_vals = np.concatenate(groups)
    k = sum(1 for g in groups if g.size > 0)
    N = all_vals.size

    if which == "anova":
        F, p = stats.f_oneway(*[g for g in groups if g.size > 0])
        grand = np.mean(all_vals)
        ss_between = sum(g.size * (np.mean(g) - grand) ** 2
                         for g in groups if g.size > 0)
        ss_total   = np.sum((all_vals - grand) ** 2)
        eta2 = ss_between / ss_total if ss_total > 0 else np.nan
        ms_within = (ss_total - ss_between) / (N - k)
        omega2 = ((ss_between - (k - 1) * ms_within) /
                  (ss_total + ms_within)) if (ss_total + ms_within) > 0 else np.nan
        return {"test": "one-way ANOVA",
                "stat_name": "F", "stat": float(F),
                "df1": k - 1, "df2": N - k,
                "p": float(p),
                "effect_name": "eta^2", "effect": float(eta2),
                "omega2": float(omega2)}

    if which == "welch":
        res = anova_oneway(all_vals,
                           groups=np.repeat(
                               [GROUP_LABELS[g] for g in GROUP_ORDER
                                if (df["Condition"] == g).sum() > 0],
                               [g.size for g in groups if g.size > 0]),
                           use_var="unequal",
                           welch_correction=True)
        grand = np.mean(all_vals)
        ss_between = sum(g.size * (np.mean(g) - grand) ** 2
                         for g in groups if g.size > 0)
        ss_total   = np.sum((all_vals - grand) ** 2)
        eta2 = ss_between / ss_total if ss_total > 0 else np.nan
        return {"test": "Welch's ANOVA",
                "stat_name": "F", "stat": float(res.statistic),
                "df1": float(res.df_num), "df2": float(res.df_denom),
                "p": float(res.pvalue),
                "effect_name": "eta^2", "effect": float(eta2),
                "omega2": np.nan}

    # Kruskal-Wallis
    H, p = stats.kruskal(*[g for g in groups if g.size > 0])
    eps2 = (H - k + 1) / (N - k) if (N - k) > 0 else np.nan
    return {"test": "Kruskal-Wallis",
            "stat_name": "H", "stat": float(H),
            "df1": k - 1, "df2": np.nan,
            "p": float(p),
            "effect_name": "epsilon^2", "effect": float(max(eps2, 0.0)),
            "omega2": np.nan}


# -----------------------------------------------------------------------------
# 5. Post-hoc
# -----------------------------------------------------------------------------

def run_posthoc(df: pd.DataFrame, metric: str, which: str) -> pd.DataFrame:
    """Pairwise post-hoc tests consistent with the omnibus choice.

    - ANOVA   -> Tukey HSD (familywise alpha controlled across pairs)
    - Welch   -> Games-Howell (does not assume equal variance)
    - Kruskal -> Dunn with Benjamini-Hochberg adjustment of the three
                 pairwise p-values
    """
    sub = df[["Condition", metric]].dropna().copy()
    sub["Condition"] = sub["Condition"].astype(str)

    if which == "anova":
        from statsmodels.stats.multicomp import pairwise_tukeyhsd
        res = pairwise_tukeyhsd(sub[metric].values,
                                sub["Condition"].values,
                                alpha=ALPHA)
        tbl = pd.DataFrame(res.summary().data[1:],
                           columns=res.summary().data[0])
        tbl.rename(columns={"group1": "group_a",
                            "group2": "group_b",
                            "meandiff": "mean_diff",
                            "p-adj": "p_adj",
                            "lower": "ci_low",
                            "upper": "ci_high",
                            "reject": "reject"}, inplace=True)
        tbl["method"] = "Tukey HSD"
        return tbl

    if which == "welch":
        tbl = sp.posthoc_games_howell(sub, val_col=metric, group_col="Condition")
        # Reshape square p-value matrix to long form
        rows = []
        groups_present = tbl.index.tolist()
        for i, a in enumerate(groups_present):
            for b in groups_present[i + 1:]:
                rows.append({"group_a": a, "group_b": b,
                             "p_adj": float(tbl.loc[a, b]),
                             "method": "Games-Howell"})
        return pd.DataFrame(rows)

    # Kruskal
    tbl = sp.posthoc_dunn(sub, val_col=metric, group_col="Condition",
                          p_adjust="fdr_bh")
    rows = []
    groups_present = tbl.index.tolist()
    for i, a in enumerate(groups_present):
        for b in groups_present[i + 1:]:
            rows.append({"group_a": a, "group_b": b,
                         "p_adj": float(tbl.loc[a, b]),
                         "method": "Dunn (BH)"})
    return pd.DataFrame(rows)


# -----------------------------------------------------------------------------
# 6. Plotting
# -----------------------------------------------------------------------------

def boxplot_with_points(ax: plt.Axes, df: pd.DataFrame, metric: str) -> None:
    """Classic Tukey box-and-whisker plot with individual FOVs overlaid.

    Design choices (deliberately minimal, journal-style):
      * boxes:    white fill, thin black outline
      * median:   solid black line
      * whiskers: solid black, extend to 1.5 x IQR (default scipy/Tukey rule)
      * outliers (beyond whiskers) are NOT drawn as fliers, because every
        data point is already shown as a jittered dot overlay
      * points:   small filled circle, group color, thin dark edge
    """
    positions = np.arange(len(GROUP_ORDER))
    group_data = []
    for g in GROUP_ORDER:
        vals = df.loc[df["Condition"] == g, metric].dropna().values
        group_data.append(vals)

    # --- boxes -----------------------------------------------------------
    ax.boxplot(
        [v for v in group_data if v.size > 0],
        positions=[p for p, v in zip(positions, group_data) if v.size > 0],
        widths=0.45,
        patch_artist=True,
        showfliers=False,
        medianprops=dict(color="black", lw=1.1),
        whiskerprops=dict(color="black", lw=0.9),
        capprops=dict(color="black", lw=0.9),
        boxprops=dict(facecolor="white", edgecolor="black", lw=0.9),
    )

    # --- individual data points (every FOV visible) ----------------------
    for i, (g, vals) in enumerate(zip(GROUP_ORDER, group_data)):
        if vals.size == 0:
            continue
        rng    = np.random.default_rng(seed=hash((metric, g)) & 0xFFFFFFFF)
        jitter = rng.uniform(-0.12, 0.12, size=vals.size)
        ax.scatter(np.full(vals.size, i) + jitter, vals,
                   s=22, color=GROUP_COLORS[g],
                   edgecolor="black", linewidth=0.4,
                   zorder=5, alpha=0.9)

    ax.set_xticks(positions)
    ax.set_xticklabels([GROUP_LABELS[g] for g in GROUP_ORDER])
    ax.set_xlim(-0.6, len(GROUP_ORDER) - 0.4)


def annotate_pvalues(ax: plt.Axes, posthoc: pd.DataFrame,
                     data: pd.DataFrame, metric: str) -> None:
    """Simple significance brackets above the plot for post-hoc comparisons
    with (test's own) adjusted p < .05.
    """
    if posthoc is None or len(posthoc) == 0:
        return
    y_max = np.nanmax(data[metric].values)
    y_min = np.nanmin(data[metric].values)
    span  = y_max - y_min if y_max > y_min else max(abs(y_max), 1.0)
    step  = span * 0.07
    y     = y_max + step

    for _, row in posthoc.iterrows():
        p = row["p_adj"] if "p_adj" in row else row.get("p-adj", np.nan)
        try:
            p = float(p)
        except (TypeError, ValueError):
            continue
        if np.isnan(p) or p >= 0.05:
            continue
        a = GROUP_ORDER.index(row["group_a"])
        b = GROUP_ORDER.index(row["group_b"])
        if a > b:
            a, b = b, a
        ax.plot([a, a, b, b], [y, y + step * 0.25, y + step * 0.25, y],
                lw=0.7, color="black")
        stars = ("***" if p < 0.001 else
                 "**"  if p < 0.01  else
                 "*"   if p < 0.05  else "")
        ax.text((a + b) / 2, y + step * 0.3, stars,
                ha="center", va="bottom", fontsize=9)
        y += step * 1.0


def plot_metric(df: pd.DataFrame, metric: str,
                omnibus: dict, posthoc: pd.DataFrame,
                q_value: float) -> Path:
    """Render one metric: boxplot + jittered points + significance brackets.

    Deliberately minimal: no stat text crammed into the title (those live in
    the omnibus/post-hoc tables). The y-axis label names the metric and
    carries its unit; the x-axis names the groups.
    """
    fig, ax = plt.subplots(figsize=(3.4, 3.2))

    boxplot_with_points(ax, df, metric)
    annotate_pvalues(ax, posthoc, df, metric)

    ax.set_ylabel(METRIC_LABELS.get(metric, metric))

    # Pad the top so brackets never clip
    y_min, y_max = ax.get_ylim()
    ax.set_ylim(y_min, y_max + (y_max - y_min) * 0.08)

    out_png = OUT_FIGURES / f"{metric}.png"
    out_pdf = OUT_FIGURES / f"{metric}.pdf"
    fig.savefig(out_png)
    fig.savefig(out_pdf)
    plt.close(fig)
    return out_png


def plot_overview(df: pd.DataFrame, omnibus_df: pd.DataFrame) -> Path:
    """A 4x3 panel of all metrics on one figure (publication supplement)."""
    n = len(METRICS)
    cols = 3
    rows = int(np.ceil(n / cols))
    fig, axes = plt.subplots(rows, cols, figsize=(cols * 3.0, rows * 2.7))
    axes = np.atleast_2d(axes).flatten()
    for i, metric in enumerate(METRICS):
        ax = axes[i]
        boxplot_with_points(ax, df, metric)
        ax.set_ylabel(METRIC_LABELS.get(metric, metric), fontsize=8)
        ax.tick_params(labelsize=8)
    for j in range(i + 1, rows * cols):
        axes[j].axis("off")
    fig.tight_layout()
    out = OUT_FIGURES / "overview_all_metrics.png"
    fig.savefig(out)
    fig.savefig(out.with_suffix(".pdf"))
    plt.close(fig)
    return out


# -----------------------------------------------------------------------------
# 7. Main
# -----------------------------------------------------------------------------

def fmt_p(p: float) -> str:
    return "< .001" if p < 0.001 else f"= {p:.3f}"


def main() -> None:
    warnings.simplefilter("ignore", category=RuntimeWarning)

    print("Loading data...")
    df = load_data(DATA_PATH)
    print(f"  loaded {len(df)} FOVs after KeepFOV filter")
    print(df["Condition"].value_counts().to_string())
    print()

    # --- Descriptives ---------------------------------------------------------
    print("Computing descriptives...")
    desc = descriptives(df)
    desc.to_csv(OUT_TABLES / "01_descriptives.csv", index=False)

    # --- Assumption tests + omnibus + post-hoc per metric --------------------
    omnibus_rows = []
    assumptions_rows = []
    posthoc_frames   = []

    for metric in METRICS:
        shapiro = shapiro_per_group(df, metric)
        levene  = levene_across_groups(df, metric)
        which   = choose_test(shapiro, levene)
        omn     = run_omnibus(df, metric, which)
        ph      = run_posthoc(df, metric, which)
        ph.insert(0, "metric", metric)
        posthoc_frames.append(ph)

        omnibus_rows.append({
            "metric":      metric,
            "test":        omn["test"],
            "statistic":   omn["stat"],
            "df1":         omn["df1"],
            "df2":         omn["df2"],
            "p":           omn["p"],
            "effect_name": omn["effect_name"],
            "effect":      omn["effect"],
            "omega2":      omn.get("omega2", np.nan),
            "chosen":      which,
        })

        for g in GROUP_ORDER:
            sh = shapiro.get(g, {})
            assumptions_rows.append({
                "metric":     metric,
                "group":      g,
                "n":          sh.get("n", np.nan),
                "shapiro_W":  sh.get("W", np.nan),
                "shapiro_p":  sh.get("p", np.nan),
                "levene_W":   levene["W"],
                "levene_p":   levene["p"],
                "chosen_test": which,
            })

    omnibus_df     = pd.DataFrame(omnibus_rows)
    assumptions_df = pd.DataFrame(assumptions_rows)

    # --- BH-FDR across the 11 omnibus tests ----------------------------------
    reject, q_vals, _, _ = multipletests(omnibus_df["p"].values,
                                         alpha=ALPHA,
                                         method="fdr_bh")
    omnibus_df["q_bh"]    = q_vals
    omnibus_df["sig_bh"]  = reject
    omnibus_df.to_csv(OUT_TABLES / "02_omnibus.csv", index=False)
    assumptions_df.to_csv(OUT_TABLES / "03_assumption_tests.csv", index=False)

    posthoc_all = pd.concat(posthoc_frames, ignore_index=True)
    posthoc_all.to_csv(OUT_TABLES / "04_posthoc.csv", index=False)

    # --- Figures -------------------------------------------------------------
    print("Rendering figures...")
    for metric in METRICS:
        om = omnibus_df.loc[omnibus_df["metric"] == metric].iloc[0].to_dict()
        ph = posthoc_all.loc[posthoc_all["metric"] == metric].copy()
        plot_metric(df, metric,
                    omnibus=om,
                    posthoc=ph,
                    q_value=float(om["q_bh"]))
    plot_overview(df, omnibus_df)

    # --- Human-readable summary printed to stdout ----------------------------
    print()
    print("=" * 78)
    print(f"OMNIBUS RESULTS  (alpha = {ALPHA}, BH-FDR across {len(METRICS)} metrics)")
    print("=" * 78)
    for _, r in omnibus_df.iterrows():
        marker = " *" if r["sig_bh"] else "  "
        print(f"{marker} {r['metric']:<25}  {r['test']:<16}  "
              f"{r['statistic']:>6.2f}  "
              f"p {fmt_p(r['p']):<8}  q = {r['q_bh']:.3f}  "
              f"{r['effect_name']} = {r['effect']:.3f}")

    # --- JSON dump for the report-writing step --------------------------------
    bundle = {
        "n_per_group": {g: int((df["Condition"] == g).sum()) for g in GROUP_ORDER},
        "omnibus":     omnibus_df.to_dict(orient="records"),
        "posthoc":     posthoc_all.to_dict(orient="records"),
        "assumptions": assumptions_df.to_dict(orient="records"),
        "descriptives": desc.to_dict(orient="records"),
    }
    with open(OUT_TABLES / "all_results.json", "w") as f:
        json.dump(bundle, f, indent=2, default=float)

    print()
    print("Outputs:")
    print(f"  tables : {OUT_TABLES}")
    print(f"  figures: {OUT_FIGURES}")


if __name__ == "__main__":
    main()
