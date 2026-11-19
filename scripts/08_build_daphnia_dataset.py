
from pathlib import Path
import numpy as np
import pandas as pd

ROOT = Path("/home/voltsy/Projects/DataLensSubmission")

SOURCE = (
    ROOT / "data/processed/external/daphnia/"
    "daphnia_recovery_engineered.csv"
)

OUT = ROOT / "data/processed/external/daphnia"
OUT.mkdir(parents=True, exist_ok=True)

LUMA_FEATURES = [
    "treatment_group",
    "recovery_temperature_c",
    "humidity_pct",
    "body_mass",
    "baseline_activity",
    "baseline_feeding",
    "activity_24h",
    "feeding_24h",
    "response_latency",
    "oxygen_rate",
    "molecular_signal_A",
    "molecular_signal_B",
    "fluorescence_signal",
    "sensor_variability",
    "processing_delay",
    "measurement_order",
]

IDENTIFIERS = [
    "study_id",
    "organism",
    "record_id",
    "experimental_unit_id",
]

DAPHNIA_EXTENSIONS = [
    "body_length",
    "recovery_duration_h",
    "wave",
    "position",
]

TARGET = "recovery_state_binary"


def build_dataset():
    source = pd.read_csv(SOURCE)

    data = pd.DataFrame(index=source.index)

    # Canonical metadata
    data["study_id"] = "frizot_2026"
    data["organism"] = "Daphnia"
    data["record_id"] = source["record_id"].astype(str)

    # No verified experimental-unit identifier.
    data["experimental_unit_id"] = np.nan

    # Directly compatible features
    data["treatment_group"] = source["treatment_group"]
    data["recovery_temperature_c"] = source[
        "recovery_temperature_c"
    ]
    data["body_mass"] = source["body_mass"]

    # Preserve the complete LUMA feature schema.
    for feature in LUMA_FEATURES:
        if feature not in data.columns:
            data[feature] = np.nan

    # Daphnia-specific extensions; not substituted into LUMA features.
    for feature in DAPHNIA_EXTENSIONS:
        data[feature] = source[feature]

    # Binary target based on the original food-specific reference.
    data[TARGET] = (
        pd.to_numeric(source["recovery_state"], errors="coerce") > 0
    ).astype("Int64")

    # Exclude records without a valid target.
    data = data.dropna(subset=[TARGET]).copy()
    data[TARGET] = data[TARGET].astype(int)

    # Feature availability audit
    availability = pd.DataFrame({
        "feature": LUMA_FEATURES,
        "available": [
            data[c].notna().any() for c in LUMA_FEATURES
        ],
        "missing_pct": [
            data[c].isna().mean() * 100 for c in LUMA_FEATURES
        ],
        "unique_values": [
            data[c].nunique(dropna=True) for c in LUMA_FEATURES
        ],
    })

    # Only directly observed, nonconstant shared predictors.
    usable_features = [
        c for c in LUMA_FEATURES
        if data[c].notna().any() and data[c].nunique(dropna=True) > 1
    ]

    data.to_csv(OUT / "daphnia_luma_schema.csv", index=False)
    availability.to_csv(
        OUT / "daphnia_feature_availability.csv", index=False
    )

    print("=" * 75)
    print("DAPHNIA CANONICAL DATASET")
    print("=" * 75)
    print("Shape:", data.shape)
    print("\nTarget distribution:")
    print(data[TARGET].value_counts().sort_index().to_string())

    print("\nLUMA schema feature availability:")
    print(availability.to_string(index=False))

    print("\nUsable shared predictors:")
    print(usable_features)

    print("\nExcluded unavailable predictors:")
    print([
        c for c in LUMA_FEATURES if c not in usable_features
    ])

    print("\nSaved:")
    print(OUT / "daphnia_luma_schema.csv")
    print(OUT / "daphnia_feature_availability.csv")

    return data, usable_features


if __name__ == "__main__":
    build_dataset()
