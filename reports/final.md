# Tabular ML Report — 2026-05-02

## Executive summary

We analyzed **7,043 rows** to predict **`Churn`** (binary classification). Best model: **logistic_regression** with **roc_auc = 0.8416**.

## What we tried

| run_id | model | metric | value | status | seconds |
|---|---|---|---|---|---|
| `2026-05-02T12-19_lgbm_01` | lightgbm | roc_auc | — | failed | 0.0 |
| `2026-05-02T12-19_lr_01` | logistic_regression | roc_auc | 0.8416 | ok | 0.03 |
| `2026-05-02T12-19_xgb_01` | xgboost | roc_auc | 0.8354 | ok | 0.32 |
| `2026-05-02T12-19_lgbm_01` | lightgbm | roc_auc | — | failed | 0.0 |

## Caveats

- small dataset (7,043 rows) — single-fold evaluation
