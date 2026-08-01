# Cross-System Data Drift & Trust Monitoring Platform
## README — Theoretical Foundations

This document explains the *theory* behind each component of the platform:
why each technique was chosen, what problem it solves, and the math or
logic underneath it. It complements (not replaces) a usage/setup README —
see `DATABRICKS_SETUP_GUIDE.md` for run instructions.

---

## 1. The Core Problem: Why "Drift" and "Trust" Are Different Things

Two systems can look fine independently and still be silently wrong
*relative to each other*. Two related but distinct failure modes matter here:

- **Drift** — a system's own data changes shape over time in ways that
  weren't expected (a schema changes, volume spikes, a distribution
  shifts). Drift is a **temporal** comparison: *today vs. a reference point*.
- **Trust erosion** — systems disagree *with each other right now* (a
  customer exists in CRM but never appears in Billing; Billing and
  Analytics report different totals for the same customer). This is a
  **cross-sectional** comparison: *system A vs. system B, same moment*.

A monitoring platform that only does one of these is incomplete: drift
detection alone can't tell you Billing and Analytics disagree today if
they've *always* disagreed; cross-system comparison alone can't tell you
a system's data quality is degrading over time. This platform implements
both, and a third component — a **Trust Score** — that fuses them into a
single interpretable number.

---

## 2. Architectural Theory: Why Medallion (Bronze/Silver/Gold)

The Medallion architecture is a layered data-quality theory, not just a
folder convention:

| Layer | Theoretical Purpose | What Would Break Without It |
|---|---|---|
| **Bronze** | Preserve the *original* signal, unmodified. This is your ground truth for reproducing any downstream result and for diffing "what actually arrived" vs. "what we processed." | Without Bronze, cleaning bugs are unrecoverable — you can't tell whether "no drift detected" means data is stable or means the cleaning step silently discarded the drifted rows. |
| **Silver** | Normalize representation (types, casing, whitespace, duplicates) so that comparisons in the next layer are apples-to-apples. | Without standardization, a false "mismatch" can be nothing more than `"ACTIVE"` vs `"active"` or a trailing space in a customer ID — noise masquerading as a real data-quality signal. |
| **Gold** | Persist *decisions*, not just data — the outcome of comparison, drift, and scoring logic, in a form BI tools and humans can consume directly. | Without Gold, every consumer of "is our data trustworthy?" has to re-run the entire pipeline's logic themselves. |

The layering also gives you a natural **replay boundary**: if the scoring
formula changes, you re-run Silver→Gold without re-ingesting Bronze; if the
cleaning logic changes, you re-run from Bronze without re-fetching from
source systems.

---

## 3. Comparison Logic: Set Theory Applied to Data Quality

All three comparison checks reduce to operations on sets of keys:

### 3.1 Missing Records Detection
*"Which CRM customers have no billing activity?"*
This is a **relative complement** (set difference): `CRM_keys − BILLING_keys`.
In Spark this is a `left_anti` join — return rows from the left table with
no matching key on the right. Interpreted as trust theory: this measures
**referential completeness** — does every entity that *should* generate
downstream activity actually do so?

### 3.2 Extra Records Detection
*"Which billing transactions reference a customer we've never heard of?"*
This is the same set operation with the operands reversed:
`BILLING_keys − CRM_keys`. Interpreted as trust theory: this measures
**referential integrity** — orphan records are evidence of upstream
sync failures, deleted-but-not-cascaded records, or (in adversarial
settings) fraudulent activity using fabricated customer IDs.

### 3.3 Aggregation Mismatch
*"Do two systems' independently-computed totals for the same entity agree?"*
Unlike the two checks above (existence-based), this is **magnitude-based**:
for each key present in both systems, compute
```
pct_diff = |billing_total − analytics_total| / |billing_total|
```
and flag anything exceeding a tolerance `τ` (this project uses `τ = 2%`).
A nonzero tolerance is theoretically necessary, not a shortcut — floating
point aggregation, rounding at different points in each pipeline, and
timing differences (a transaction landing in Billing at 11:59pm vs.
Analytics' next-day batch) all produce small legitimate disagreement that
isn't a real trust problem. The tolerance separates *noise* from *signal*.

> **Requires a shared grain.** This check only works if both systems can
> be aggregated to the same entity/key (e.g. both per-customer, or both
> per-day). If one system reports per-customer totals and the other
> reports daily aggregates, they must first be re-aggregated to a common
> grain (e.g. sum Billing by day) before comparison — comparing
> different grains directly produces meaningless results.

---

## 4. Drift Detection Theory

### 4.1 Schema Drift
Theoretically the simplest and most severe: a **type-level** contract
violation. Comparing `{column_name: type}` between baseline and current
catches three sub-cases:
- **Added columns** — usually benign (new field), but changes cardinality assumptions downstream.
- **Removed columns** — usually breaking (any code referencing that column fails).
- **Type-changed columns** — the most dangerous silently, e.g. a
  numeric ID reinterpreted as a string will still "work" but silently
  break numeric joins/aggregations.

### 4.2 Volume Drift
A simple relative change in record count:
```
pct_change = (current_count − baseline_count) / baseline_count
```
Theoretically, this is a **proxy metric** — it doesn't diagnose *why*
volume changed, only *that* it changed beyond what's plausible for normal
day-to-day variation. The threshold (this project uses 15%) should be
calibrated from the system's own historical variance, not chosen
arbitrarily — a system with naturally volatile daily volume (e.g. a
flash-sale retailer) needs a wider threshold than a stable B2B system.

### 4.3 Distribution Drift — Population Stability Index (PSI)
Volume drift catches "how many"; distribution drift catches "what kind."
Two datasets can have identical record counts and completely different
underlying distributions (e.g. transaction amounts quietly shifting from
averaging $40 to averaging $55).

**PSI theory:** bucket both the baseline and current values into the same
bins, and measure how much probability mass moved between bins:
```
PSI = Σ (current_pct_i − baseline_pct_i) × ln(current_pct_i / baseline_pct_i)
```
for each bucket `i`. This is closely related to the **Kullback-Leibler
divergence** (PSI is, in fact, a symmetrized approximation of KL
divergence between the two distributions) — both measure "how surprised
would you be to see the current distribution if you expected the baseline
distribution?"

**Why PSI over a simpler mean/stddev comparison:** mean and standard
deviation are summary statistics that can stay constant while the
underlying shape changes completely (e.g. a distribution that splits into
two clusters can keep the same mean). PSI is shape-sensitive because it
compares the full binned distribution, not just its first two moments.

**Interpreting PSI** (industry-standard thresholds, used here):
| PSI range | Interpretation |
|---|---|
| < 0.10 | No significant shift |
| 0.10 – 0.25 | Moderate shift — worth investigating |
| > 0.25 | Major shift — likely a real behavioral or pipeline change |

---

## 5. Data Trust Scoring: Composite Metric Theory

A single "is this trustworthy" score is a **weighted linear composite** of
independently-meaningful sub-scores — a common pattern in data-quality and
credit-scoring theory alike, where no single signal is sufficient but
several partial signals combined are informative.

```
trust_score = w1·completeness + w2·consistency + w3·volume_stability
            + w4·schema_stability + w5·distribution_stability
```

**Why weighted rather than a simple average or a hard pass/fail gate:**
- A simple average treats all failure modes as equally important, which
  they usually aren't (a schema change is typically more urgent than a
  1% volume wobble).
- A hard gate (fail if *any* check fails) is too brittle for a monitoring
  tool — a single moderate PSI shift shouldn't make an otherwise-healthy
  dataset register as "0% trustworthy." A continuous score lets you rank
  severity and set warning vs. critical thresholds independently.

**Weight design in this project** (`completeness=0.30, consistency=0.30,
volume=0.15, schema=0.15, distribution=0.10`): completeness and
consistency get the highest weight because they're **directly
observable data-quality facts** (a null is a null, a mismatch is a
mismatch), whereas the three drift components are **directional risk
signals** — real, but a step further removed from a definitive quality
judgment (volume can legitimately spike for good business reasons). This
is a design choice, not a law — the weights should be revisited against
what actually matters for a given organization's downstream use of the data.

**Component definitions:**
- *Completeness* — % of records with no nulls in business-critical columns.
- *Consistency* — how well cross-system comparison checks agree (blend of
  referential coverage and aggregation agreement, §3 above).
- *Stability (volume / schema / distribution)* — binary-derived: 100 if
  that check found no drift, 0 if it did, then averaged across all checks
  of that type.

---

## 6. Alerting Theory: Why Thresholds, Not Anomaly Detection (Yet)

This platform uses **fixed, configurable thresholds** rather than
statistical anomaly detection (e.g. z-scores, isolation forests). This is
a deliberate, theory-grounded choice for a v1 monitoring system:

- **Interpretability** — a threshold-based alert ("volume changed +28%,
  threshold is 15%") is immediately explainable to a non-technical
  stakeholder. A statistical anomaly score is not, without additional
  translation.
- **Stability with sparse history** — anomaly detection models need
  enough historical baselines to learn "normal" variance; a new
  monitoring platform doesn't have that history yet. Thresholds work from
  day one.
- **Auditability** — for compliance-sensitive domains (the proposal cites
  banking and e-commerce), a fixed, documented threshold is easier to
  justify to an auditor than "the model decided this was anomalous."

Statistical/ML-based anomaly detection is explicitly named as **future
scope**, not a missing requirement — it's a natural v2 once enough
historical Gold-layer data accumulates to train a baseline of "normal"
variance per source.

**Severity tiering** follows a common two-threshold pattern (WARNING vs.
CRITICAL) rather than a single alert level, because it lets downstream
routing differ — e.g. WARNING → a dashboard/Slack channel for awareness,
CRITICAL → paging an on-call engineer — without every alert being
treated as equally urgent.

---

## 7. Summary: How the Pieces Compose

```
Bronze (raw truth)
   │
   ▼
Silver (standardized, comparable)
   │
   ├──► Comparison Logic ──► completeness/consistency inputs ─┐
   │                                                           │
   ├──► Drift Detection ───► stability inputs ─────────────────┼──► Trust Score ──► Alerts ──► Gold
   │                                                           │
   └───────────────────────────────────────────────────────────┘
```

Every downstream number traces back to Bronze — which is the entire point
of the layered design: if a trust score looks wrong, you can walk it back
through Silver's cleaning logic to Bronze's raw records and find exactly
where the number came from, rather than treating the score as a black box.

---

