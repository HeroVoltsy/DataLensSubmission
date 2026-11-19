from pathlib import Path
import pandas as pd

ROOT = Path("data/external_data/daphnia/raw")

recovery = pd.read_csv(
    ROOT / "resultats_manip_final.txt",
    sep=r"\s+",
    decimal=",",
    encoding="utf-8-sig",
    engine="python"
)

tdt = pd.read_csv(
    ROOT / "results_TDT.txt",
    sep=r"\s+",
    decimal=",",
    encoding="utf-16",
    engine="python"
)

for filename in [
    "resultats_manip_final.txt",
    "results_TDT.txt"
]:
    path = ROOT / filename

    with open(path, "rb") as f:
        raw = f.read(16)

    print(filename, raw, raw.hex(" "))

print("Recovery:", recovery.shape)
print(recovery.head())

print("TDT:", tdt.shape)
print(tdt.head())

# ============================================================
# DAPHNIA EXTERNAL DATASET: EXPERIMENTAL STRUCTURE
# ============================================================

print("\n" + "=" * 65)
print("1. WAVE DISTRIBUTION")
print("=" * 65)
print(recovery["Wave"].value_counts().sort_index().to_string())

print("\n" + "=" * 65)
print("2. RECOVERY PERIODS")
print("=" * 65)
print(recovery["Recup"].value_counts().sort_index().to_string())

print("\n" + "=" * 65)
print("3. TREATMENT COMBINATIONS")
print("=" * 65)

treatment_structure = (
    recovery.groupby(
        ["Wave", "Recup", "Temp", "Food"],
        observed=True
    )
    .agg(
        n=("Num", "size"),
        unique_individuals=("Num", "nunique")
    )
    .reset_index()
)

print(treatment_structure.to_string(index=False))

print("\n" + "=" * 65)
print("4. INDIVIDUAL IDENTITY ACROSS WAVES")
print("=" * 65)

identity = (
    recovery.groupby("Num")
    .agg(
        n_waves=("Wave", "nunique"),
        waves=("Wave", lambda x: tuple(sorted(x.unique()))),
        n_records=("Wave", "size")
    )
)

print(identity["n_waves"].value_counts().sort_index().to_string())

print("\nIndividuals appearing in multiple waves:")
print(identity[identity["n_waves"] > 1].head(20).to_string())

print("\n" + "=" * 65)
print("5. DUPLICATE INDIVIDUAL-WAVE RECORDS")
print("=" * 65)

duplicates = (
    recovery.groupby(["Wave", "Num"])
    .size()
    .loc[lambda x: x > 1]
)

print(duplicates.to_string() if not duplicates.empty else "None")

print("\n" + "=" * 65)
print("6. THERMAL TOLERANCE DISTRIBUTION")
print("=" * 65)
print(recovery["Timm"].describe().to_string())

print("\n" + "=" * 65)
print("7. MISSING VALUES")
print("=" * 65)
print(recovery.isna().sum().to_string())