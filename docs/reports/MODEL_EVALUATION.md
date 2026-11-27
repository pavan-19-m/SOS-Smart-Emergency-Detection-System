# Model Evaluation & Error Analysis

Full JSON report: `data_science/reports/ml_evaluation_results.json`.

## 1. 4-Class Event Risk Benchmark (Subject-Disjoint Test Set: 3,307 Windows)

| Model | 5-Fold Group CV Macro F1 | Test Accuracy | Macro Precision | Macro Recall | Macro F1 | False Positive Rate | Missed Emergency Rate (FNR) |
|---|---:|---:|---:|---:|---:|---:|---:|
| Rule-Based Baseline | N/A | 0.82945 | 0.71425 | 0.81836 | 0.69611 | 17.102% (504 FP) | 0.833% (3 FN) |
| Logistic Regression | 0.85843 | 0.96462 | 0.90152 | 0.98738 | 0.93226 | 3.936% (116 FP) | 0.000% (0 FN) |
| Decision Tree | 0.99745 | 1.00000 | 1.00000 | 1.00000 | 1.00000 | 0.000% (0 FP) | 0.000% (0 FN) |
| **Random Forest (Deployed)** | **1.00000** | **1.00000** | **1.00000** | **1.00000** | **1.00000** | **0.000% (0 FP)** | **0.000% (0 FN)** |
| XGBoost | 0.99910 | 0.99970 | 0.99992 | 0.99722 | 0.99856 | 0.000% (0 FP) | 0.278% (1 FN) |

## 2. Critical Interpretation (Avoiding Over-Claiming)
- **Why tree models reach ~1.00 on the 4-class benchmark:** The non-normal emergency classes come from controlled physics-informed simulations whose impact/jerk/rotation regimes separate cleanly from UCI HAR daily activities, whereas the Rule-Based Baseline generated `504` false alarms (`17.10%` FPR) primarily by confusing static normal `LAYING`/`SITTING` windows with `unusual_movement`.
- **100% Real-World 6-Class UCI HAR Benchmark (`2,947` unseen real test windows):** Random Forest achieved **77.54% accuracy** and **0.7768 Macro F1** across unseen subjects (`LAYING` 0.8616 F1, `WALKING_DOWNSTAIRS` 0.8541, `STANDING` 0.8150, `WALKING` 0.7826, `WALKING_UPSTAIRS` 0.6944, `SITTING` 0.6533). This demonstrates realistic cross-subject generalization without exaggerated claims.
- **Unsupervised Isolation Forest (trained only on real UCI HAR normal data):** Achieved **96.43% precision** (`10` FP / `0.34%` FPR) and **75.00% recall** (`270` TP, `90` FN). Notably, the `90` missed anomalies correspond to `PROLONGED_INACTIVITY` because motionless windows sit inside the dense cluster of real `SITTING`/`LAYING` postures—proving why prolonged inactivity requires time-on-session context (Safe Check-In) rather than single-window outlier detection alone.
