import numpy as np
import pandas as pd
from pathlib import Path


ROOT = Path("data/external_data/daphnia/raw")
OUT = Path("data/processed/external/daphnia")

OUT.mkdir(parents=True, exist_ok=True)

raw = pd.read_csv(
    ROOT / "resultats_manip_final.txt",
    sep=r"\s+",
    decimal=",",
    encoding="utf-8",
    engine="python"
)

# Canonical feature schema
canonical = pd.DataFrame({
    "study_id": "daphnia_recovery_2026",
    "organism": "Daphnia",
    "record_id": (
        raw["Wave"].astype(str) + "_" +
        raw["Recup"].astype(str) + "_" +
        raw["Temp"].astype(str) + "_" +
        raw["Food"].astype(str) + "_" +
        raw["Num"].astype(str) + "_" +
        raw["Pos"].astype(str) + "_" +
        raw["Box"].astype(str)
    ),
    "wave": raw["Wave"],
    "recovery_duration_h": raw["Recup"],
    "recovery_temperature_c": raw["Temp"],
    "treatment_group": raw["Food"],
    "replicate_code": raw["Num"],
    "position": raw["Pos"],
    "box": raw["Box"],
    "body_mass": raw["Weight"],
    "body_length": raw["Length"],
    "thermal_tolerance_min": raw["Timm"],
    "empty_container_mass": raw["Pvide"],
    "filled_container_mass": raw["Pplein"]
})

canonical["body_mass"] = pd.to_numeric(
    canonical["body_mass"], errors="coerce"
)

canonical["body_length"] = pd.to_numeric(
    canonical["body_length"], errors="coerce"
)

canonical["thermal_tolerance_min"] = pd.to_numeric(
    canonical["thermal_tolerance_min"], errors="coerce"
)

canonical.to_csv(
    OUT / "daphnia_canonical_raw.csv",
    index=False
)

# Exclude baseline observations from recovery outcomes.
recovery_features = canonical.loc[
    canonical["recovery_duration_h"] > 0
].copy()

# Food-specific baseline thermal tolerance references.
BASELINE_TDT = {
    "CY": 165.71,
    "S": 147.13
}

recovery_features["baseline_tolerance_min"] = (
    recovery_features["treatment_group"]
    .map(BASELINE_TDT)
)

if recovery_features["baseline_tolerance_min"].isna().any():
    raise ValueError("Unknown food treatment encountered.")

# Difference from the 90-minute lower reference threshold.
recovery_features["tolerance_excess_min"] = (
    recovery_features["thermal_tolerance_min"]
    - (recovery_features["baseline_tolerance_min"] - 90)
)

# Recovery state: normalized relative to baseline.
recovery_features["recovery_state"] = (
    recovery_features["tolerance_excess_min"] / 90
) * 100

# Recovery rate: normalized tolerance change per recovery minute.
recovery_features["recovery_rate"] = (
    recovery_features["tolerance_excess_min"]
    / (recovery_features["recovery_duration_h"] * 60)
).round(4)

# Preserve original variable names for comparison with R.
recovery_features["rapport"] = recovery_features["recovery_state"]
recovery_features["time_win"] = recovery_features["recovery_rate"]

# Save engineered dataset.
recovery_features.to_csv(
    OUT / "daphnia_recovery_engineered.csv",
    index=False
)

print("\nRECOVERY FEATURE ENGINEERING")
print("Shape:", recovery_features.shape)
print("\nOutcome summaries:")
print(
    recovery_features[
        [
            "recovery_state",
            "recovery_rate"
        ]
    ].describe().round(4).to_string()
)

print("\nSaved:", OUT / "daphnia_recovery_engineered.csv")
