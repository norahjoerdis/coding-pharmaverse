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
