# Analytical Data Science Programmer – Coding Assessment

Solutions to the Pharmaverse (R) and Python coding assessment.

## Repository structure

| Folder | Question | Main script(s) | Outputs |
|---|---|---|---|
| [`question_1_sdtm/`](question_1_sdtm/) | Q1 – SDTM DS domain with `{sdtm.oak}` | `01_create_ds_domain.R` | `output/ds.*`, `logs/*.log` |
| [`question_2_adam/`](question_2_adam/) | Q2 – ADaM ADSL with `{admiral}` | `create_adsl.R` | `output/adsl.*`, `logs/*.log` |
| [`question_3_tlg/`](question_3_tlg/) | Q3 – AE summary table and plots | `01_create_ae_summary_table.R`, `02_create_visualizations.R` | `output/ae_summary_table.html`, 2 × PNG, `logs/*.log` |
| [`question_4_python/`](question_4_python/) | Q4 (bonus) – GenAI Clinical Data Assistant | `clinical_trial_data_agent.py`, `test_agent.py` | `logs/*.log` |

Shared files:

- `install_packages.R` – installs the R packages used here.

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

# Question 4 (Bonus) – GenAI Clinical Data Assistant

**Objective:** Translate free-text safety questions into structured pandas queries on the AE dataset. An LLM (OpenAI through LangChain) maps the user's intent to the right column, with no hard-coded rules.

## Files
| Path | Description |
|---|---|
| `export_adae.R` | Exports `pharmaversesdtm::ae` to `data/adae.csv` |
| `clinical_trial_data_agent.py` | Schema, `ClinicalTrialDataAgent`, and the parse/execute logic |
| `test_agent.py` | Runs 3 example queries and prints the results |
| `requirements.txt` | Python dependencies |
| `.env.example` | Template for `OPENAI_API_KEY` |
| `logs/test_agent.log` | Output of the test script |

## Flow
```
question ──► prompt (schema + task) ──► LLM ──► JSON {target_column, filter_value}
         ──► pandas filter on AE df ──► unique USUBJID count + list
```

Example mappings: "severity"/"intensity" → `AESEV`, "Headache" → `AETERM`, "Cardiac"/"Skin" → `AESOC`.

## Schema design
`SCHEMA` describes the dataset columns the LLM is allowed to choose, using a
plain-language meaning, common synonyms, and observed values/examples. It
focuses on clinically meaningful event questions (term, severity, body system,
seriousness, relationship, outcome, and serious-event criteria) rather than
exposing every technical code or date column. The schema was checked against
`pharmaversesdtm::ae` (1,191 records, 35 columns). Fields with no useful
variation in this dataset snapshot are omitted: `AEACN` is entirely missing,
while `AESCONG` and `AESOD` contain only `N`.

## Setup and run
```sh
# 1. Create the input data (from the repo root, in R / Posit Cloud)
Rscript question_4_python/export_adae.R

# 2. Python environment (from question_4_python/)
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env               # optional: add OPENAI_API_KEY

# 3. Run the test script and save a log
python test_agent.py > logs/test_agent.log 2>&1
python test_agent.py --mock        # offline, mocked LLM
```

## Design decisions
- Matching rule: case-insensitive literal substring, so `Cardiac` matches
  `CARDIAC DISORDERS`; missing event values and missing subject IDs are ignored.
- Validation of the LLM output: `QueryPlan` only accepts columns in `SCHEMA`
  and rejects an empty or whitespace-only filter value.
- Mock strategy: returns canned structured responses for the example
  questions in `test_agent.py`; other questions raise an explicit error.


## Session info

R version 4.6.2
Python 3.14.9
