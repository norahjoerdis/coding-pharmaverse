# Analytical Data Science Programmer – Coding Assessment

Solutions to the Pharmaverse (R) and Python coding assessment.

> **Video walkthrough:** _TODO: add link_

## Repository structure

| Folder | Question | Main script(s) | Outputs |
|---|---|---|---|
| [`question_1_sdtm/`](question_1_sdtm/) | Q1 – SDTM DS domain with `{sdtm.oak}` | `01_create_ds_domain.R` | `output/ds.*`, `logs/*.log` |
| [`question_2_adam/`](question_2_adam/) | Q2 – ADaM ADSL with `{admiral}` | `create_adsl.R` | `output/adsl.*`, `logs/*.log` |
| [`question_3_tlg/`](question_3_tlg/) | Q3 – AE summary table and plots | `01_create_ae_summary_table.R`, `02_create_visualizations.R` | `output/ae_summary_table.html`, 2 × PNG, `logs/*.log` |
| [`question_4_python/`](question_4_python/) | Q4 (bonus) – GenAI Clinical Data Assistant | `clinical_trial_data_agent.py`, `test_agent.py` | `logs/*.log` |

Shared files:

- `install_packages.R` – installs the R packages used here.
- `run_all.R` – runs every R script and writes one log file per script to `<question>/logs/`. These logs show the code runs without errors.
- `docs/video_notes.md` – talking points for the 2-minute video.

## How to run

### R (Questions 1–3)

R ≥ 4.2.0. Run everything from the **repository root**, either in VS Code (below) or in a Posit Cloud project that clones this repo.

#### In VS Code

1. **File → Open Folder…** and open this repository folder itself. The scripts use paths relative to the repo root, and VS Code only reads `.vscode/` from the folder you open.
2. Install the recommended **R** extension (`REditorSupport.r`) if VS Code asks.
3. Install the packages once: **Terminal → Run Task… → R: install packages**. This also installs `languageserver`, which gives you autocomplete and linting.
4. Run code:
   - **Interactively:** open an R file and press `Cmd+Enter` to send a line or selection, or `Cmd+Shift+S` to source the whole file. This starts an R terminal in the repo root. Plots and data frames (`View(df)`) open in VS Code.
   - **As a script:** `Cmd+Shift+B` (task *R: run current file*), or the task *R: run all (write logs)* to create the log files.

```r
source("install_packages.R")   # once
source("run_all.R")            # runs all scripts and writes logs
```

To run one script and capture its log from a terminal:

```sh
Rscript question_1_sdtm/01_create_ds_domain.R > question_1_sdtm/logs/01_create_ds_domain.log 2>&1
```

### Python (Question 4)

See [`question_4_python/README.md`](question_4_python/README.md).


## Session info

R version 4.6.2
Python 3.14.9
