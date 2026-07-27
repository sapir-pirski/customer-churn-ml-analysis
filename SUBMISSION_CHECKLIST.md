# Submission checklist

Use this checklist immediately before packaging the project. Checked items have
already been verified in the current workspace; unchecked items require final
team or lecturer confirmation.

## Required project files

- [x] `final_project.ipynb`
- [x] `data/churn.csv`
- [x] `README.md`
- [x] `requirements.txt`
- [x] `pyproject.toml`
- [x] `uv.lock`
- [x] `run-full-project.sh`
- [x] `run-full-project.ps1`
- [x] `scripts/validate_project.py`
- [x] `CONTRIBUTORS.md`
- [x] `LICENSE`
- [x] `final_project_presentation.pptx`
- [ ] Replace the two presentation contributor-name placeholders with final names.

## Notebook execution and reproducibility

- [x] The notebook uses Python 3.12 metadata.
- [x] Direct and transitive dependencies are locked with package hashes.
- [x] Launchers skip dependency synchronization when the lock fingerprint and
      existing Python 3.12 environment match.
- [x] Every code cell has been executed in order.
- [x] No notebook output contains an error, traceback, or warning.
- [x] The train/test split is stratified and reproducible.
- [x] Preprocessing is fitted inside each model pipeline.
- [x] Hyperparameters are selected from training folds only.
- [x] The final test set remains untouched until model selection is complete.
- [x] The launcher validates the dataset, execution counts, saved outputs,
      required sections, plots, and algorithm artifacts after execution.
- [ ] Run `./run-full-project.sh --no-open` once immediately before submission.

## Problem and data description

- [x] The prediction target is explained.
- [x] Available input data is explained.
- [x] Motivation and possible applications are described.
- [x] Total, training, and test example counts are reported.
- [x] Original and modeled feature counts are reported.
- [x] Label distribution is reported.
- [x] Missing and blank values are investigated.

## Six required EDA plots

- [x] Churn-label distribution
- [x] Churn rate by contract
- [x] Tenure distribution by churn
- [x] Monthly-charge distribution by churn
- [x] Churn rate by internet service
- [x] Churn rate by payment method

## Data engineering

- [x] Removed features are identified and justified.
- [x] Candidate engineered features are identified and justified.
- [x] Engineered features are evaluated through ablation.
- [x] Missing-value handling is explained.
- [x] Leakage prevention is explained.

## Required algorithms

- [x] KNN is evaluated with multiple `k` values.
- [x] Decision trees are evaluated with multiple maximum depths.
- [x] Random forests are evaluated with multiple maximum depths.
- [x] Random forests are evaluated with multiple estimator counts.
- [x] A majority-class baseline contextualizes model performance.

## Algorithm artifacts and final comparison

- [x] Shallow, selected, and unrestricted decision trees are inspected.
- [x] Random-forest impurity feature importance is plotted.
- [x] Permutation importance on unseen test data is plotted.
- [x] Best train and test accuracy is compared for every required algorithm.
- [x] Confusion matrices and supporting classification metrics are included.
- [x] Error patterns are inspected by customer segment.
- [x] Conclusions and limitations are stated.

## Contributors and final packaging

- [x] All lecturer-required team names are present in the submitted materials.
- [x] README links and embedded plots resolve to project files.
- [x] `.DS_Store`, notebook checkpoints, environments, and caches are ignored.
- [ ] Confirm no temporary or unrelated files are included in the submission
      archive.
- [ ] Open the packaged notebook on another computer and confirm that all saved
      outputs render correctly.
- [ ] Confirm every numeric result in the README matches the final notebook run.
