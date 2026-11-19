
# Biological Recovery Prediction — Scientific Assessment 1

**DataLens.Tools Student Talent Programme 2026**

## Overview

This project investigates machine learning approaches for predicting biological recovery using the LUMA-1 dataset. It evaluates conventional classification algorithms and a custom weighted ensemble, the **Jump Process Explainability Ensemble (JPEE)**.

An independent *Daphnia* dataset is additionally used to assess model behavior on an external biological dataset through a shared-feature benchmark.

## Objectives

- Develop predictive models for binary biological recovery outcomes.
- Compare conventional machine learning classifiers against JPEE.
- Evaluate generalization using cross-validation and held-out test sets.
- Examine predictive feature contributions using permutation importance.
- Assess performance on an external dataset while documenting differences in endpoint definitions and feature availability.

## Datasets

### LUMA-1

The primary dataset contains 240 observations from 30 experimental chambers, with eight individuals per chamber.

- **Target:** `recovered_48h`
- **Task:** Binary classification.
- **Experimental unit:** Chamber.
- **Validation:** Repeated stratified group cross-validation, using chamber identifiers to prevent individuals from the same chamber appearing in both training and validation folds.

### External Daphnia Dataset

Source: [Zenodo — Record 16810636](https://zenodo.org/records/16810636)

The processed dataset contains 321 observations with engineered recovery-related features.

- **Target:** Binary proxy derived from `recovery_state`.
- **Class 0:** 155 observations.
- **Class 1:** 166 observations.
- **Validation:** Repeated stratified cross-validation and a stratified held-out test set.
- **Shared predictors:** Treatment group, recovery temperature, and body mass.

The Daphnia endpoint is not equivalent to LUMA-1's 48-hour recovery outcome. Consequently, this experiment is treated as an external-dataset benchmark, not a direct test of the frozen LUMA-1 classifiers.

## Models

Seven classification approaches were evaluated:

1. Logistic Regression
2. Extra Trees Classifier
3. Random Forest Classifier
4. XGBoost Classifier
5. LightGBM Classifier
6. CatBoost Classifier
7. Jump Process Explainability Ensemble (JPEE)

### JPEE Architecture

JPEE combines the predicted probabilities of multiple fitted classifiers through normalized weighted averaging:

\[
\hat{P}(Y=1\mid X)
=
\sum_{m=1}^{M} w_m\hat{P}_m(Y=1\mid X)
\]

subject to:

\[
w_m\geq 0,\qquad \sum_{m=1}^{M}w_m=1
\]

When weights are not specified, equal weighting is used. The default classification threshold is 0.5.

JPEE also provides permutation-based feature importance to estimate how much predictive performance decreases when individual features are shuffled.

**Important:** Permutation importance measures predictive reliance, not causal effects. The ensemble implementation performs probability aggregation and explainability; it does not independently estimate temporal jump processes.

## Evaluation

The models were evaluated using:

- ROC-AUC
- PR-AUC
- Balanced Accuracy
- Accuracy
- Precision
- Recall
- F1-score
- Brier Score

Cross-validation results are reported as mean and standard deviation.

LUMA-1 validation uses chamber-grouped folds to account for the experimental structure. Daphnia validation uses stratified folds because no documented experimental-unit grouping identifier was available.

## External Validation Results

On the Daphnia held-out test set:

| Model | ROC-AUC | PR-AUC |
|---|---:|---:|
| Logistic Regression | 0.8022 | 0.8249 |
| Extra Trees | 0.8809 | 0.8986 |
| Random Forest | 0.8743 | 0.8860 |
| XGBoost | 0.8610 | 0.8811 |
| LightGBM | 0.8676 | 0.8830 |
| CatBoost | 0.8847 | 0.9003 |
| JPEE | 0.8762 | 0.8953 |

CatBoost achieved the highest held-out ROC-AUC and PR-AUC among the evaluated models.

JPEE's Daphnia permutation importance results:

| Feature | Mean Importance | SD |
|---|---:|---:|
| Treatment group | 0.2029 | 0.0369 |
| Recovery temperature | 0.1346 | 0.0385 |
| Body mass | 0.0717 | 0.0318 |

Treatment group contributes the most to predictive discrimination. However, it is also involved in the construction of the Daphnia endpoint, which introduces potential target-construction dependence.

## Limitations

- LUMA-1 has a relatively small sample size and only 30 experimental chambers.
- The Daphnia endpoint is a proxy and is not directly equivalent to LUMA-1's recovery outcome.
- Only three predictors were shared between the datasets.
- The Daphnia dataset does not provide a documented experimental-unit identifier for grouped validation.
- Treatment-group information contributes to the construction of the Daphnia target.
- Predictive feature importance should not be interpreted as causal evidence.
- Performance differences should not be interpreted as statistically significant without appropriate inferential testing.

## Reproducibility

The analysis was implemented in Python using machine learning and data-processing libraries, including:

- pandas
- NumPy
- scikit-learn
- imbalanced-learn
- XGBoost
- LightGBM
- CatBoost

Random seeds were fixed where applicable to support reproducibility.

## Conclusion

The assessment compares conventional classifiers and JPEE for biological recovery prediction, evaluates their behavior across two biological datasets, and investigates predictive feature contributions.

The external benchmark demonstrates promising discrimination across the evaluated models. However, differences in endpoint construction, feature availability, and experimental metadata limit direct claims of cross-dataset transportability.

---

**Project:** Scientific Assessment 1  
**Programme:** DataLens.Tools Student Talent Programme 2026
