"""GenAI Clinical Data Assistant.

Translates free-text questions about the AE dataset into structured pandas
queries:

    user question -> Prompt (with schema) -> LLM -> Parse (structured JSON) -> Execute (pandas)

The LLM maps the question to a dataset variable (e.g. "severity" -> AESEV).
There are no hard-coded keyword rules. If no API key is available, a mock LLM
returns a JSON response, and the Prompt -> Parse -> Execute flow stays the same.
"""

from __future__ import annotations

import json
import os
from dataclasses import dataclass, field
from pathlib import Path

import pandas as pd
from pydantic import BaseModel, Field, field_validator

DATA_PATH = Path(__file__).parent / "data" / "adae.csv"

# -----------------------------------------------------------------------------
# 1. Schema definition
# -----------------------------------------------------------------------------
# Keep this to fields that can answer common clinical questions. Administrative
# identifiers, dates, and MedDRA codes are omitted until the agent supports them.
SCHEMA: dict[str, str] = {
    "AESEV": (
        "Adverse-event severity or intensity. Synonyms: severity, intensity, "
        "grade. Values in this dataset: MILD, MODERATE, SEVERE."
    ),
    "AETERM": (
        "Reported adverse-event term or symptom, as entered for the event. "
        "Synonyms: event, symptom, reported term. Examples: FATIGUE, DIARRHOEA."
    ),
    "AEDECOD": (
        "Standardized coded preferred term for the adverse event. "
        "Synonyms: coded term, preferred term. Examples: FATIGUE, DIARRHOEA."
    ),
    "AESOC": (
        "System Organ Class (SOC), the broad body system category for the event. "
        "Synonyms: body system, organ class. Examples: CARDIAC DISORDERS, "
        "GASTROINTESTINAL DISORDERS."
    ),
    "AESER": (
        "Whether the adverse event is classified as serious. "
        "Synonyms: serious, seriousness. Values: Y (yes), N (no)."
    ),
    "AEREL": (
        "Assessed relationship of the event to study treatment. "
        "Synonyms: treatment-related, related to drug/treatment, causality. "
        "Observed values: PROBABLE, POSSIBLE, REMOTE, NONE; some records are missing."
    ),
    "AEOUT": (
        "Outcome or resolution status of the adverse event. "
        "Synonyms: outcome, resolved, recovered. Examples: RECOVERED/RESOLVED, "
        "NOT RECOVERED/NOT RESOLVED, FATAL."
    ),
    "AESCAN": (
        "Whether the event involved cancer. Values: Y (yes), N (no)."
    ),
    "AESDISAB": (
        "Whether the event resulted in persistent or significant disability. "
        "Values: Y (yes), N (no)."
    ),
    "AESDTH": (
        "Whether the event resulted in death. Values: Y (yes), N (no)."
    ),
    "AESHOSP": (
        "Whether the event required or prolonged hospitalization. "
        "Values: Y (yes), N (no)."
    ),
    "AESLIFE": (
        "Whether the event was life-threatening. Values: Y (yes), N (no)."
    ),
}


# -----------------------------------------------------------------------------
# 2. Structured output model
# -----------------------------------------------------------------------------
class QueryPlan(BaseModel):
    """Structured JSON the LLM must return."""

    target_column: str = Field(description="Dataset column to filter on")
    filter_value: str = Field(
        min_length=1,
        description="Non-empty value to search for, taken from the question",
    )

    @field_validator("target_column")
    @classmethod
    def target_column_must_be_in_schema(cls, value: str) -> str:
        if value not in SCHEMA:
            allowed = ", ".join(SCHEMA)
            raise ValueError(f"target_column must be one of: {allowed}")
        return value

    @field_validator("filter_value")
    @classmethod
    def filter_value_must_not_be_blank(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("filter_value must not be blank")
        return value


@dataclass
class QueryResult:
    question: str
    plan: QueryPlan
    n_subjects: int
    subject_ids: list[str] = field(default_factory=list)


# -----------------------------------------------------------------------------
# 3. Agent
# -----------------------------------------------------------------------------
class ClinicalTrialDataAgent:
    """Maps natural-language questions to pandas filters on the AE dataset."""

    def __init__(self, df: pd.DataFrame, use_mock: bool | None = None, model: str = "gpt-4o-mini"):
        self.df = df
        # Use the mock automatically when no API key is set
        self.use_mock = use_mock if use_mock is not None else not os.getenv("OPENAI_API_KEY")
        self.model = model
        self._llm = None if self.use_mock else self._build_llm()

    # ---- Prompt --------------------------------------------------------------
    def build_prompt(self, question: str) -> str:
        """Create the prompt that describes the schema and the task to the LLM."""
        schema_text = "\n".join(f"- {col}: {desc}" for col, desc in SCHEMA.items())
        return (
            "You are a clinical data assistant working with an adverse events (AE) dataset.\n"
            "Available columns:\n"
            f"{schema_text}\n\n"
            "Pick the single column that best answers the question and extract the value "
            "to filter on. Only pick from the available columns. Respond only with JSON: "
            '{"target_column": "...", "filter_value": "..."}\n\n'
            "Keep the filter value exactly as it appears in the question, including case and punctuation. \n"
            "If the question is ambiguous, ask the user for clarification.\n"
            "If no column matches the question, inform the user.\n\n"
            f"Question: {question}"
        )

    # ---- LLM -----------------------------------------------------------------
    def _build_llm(self):
        """Create the LangChain chat model with structured output."""
        from langchain_openai import ChatOpenAI  # imported lazily so mock mode needs no LangChain

        return ChatOpenAI(model=self.model, temperature=0).with_structured_output(QueryPlan)

    def _mock_llm(self, prompt: str) -> str:
        """Return a mocked raw JSON string as if an LLM produced it.

        The mock supports the example questions in test_agent.py.
        """
        question = prompt.rsplit("Question:", maxsplit=1)[-1].strip().casefold()
        responses = {
            "give me the subjects who had adverse events of moderate severity.": {
                "target_column": "AESEV",
                "filter_value": "MODERATE",
            },
            "which patients reported a headache?": {
                "target_column": "AETERM",
                "filter_value": "HEADACHE",
            },
            "how many patients had an ae involving cancer?": {
                "target_column": "AESCAN",
                "filter_value": "Y",
            },
            "how many patients had aes which were probably linked to the study drug?": {
                "target_column": "AEREL",
                "filter_value": "PROBABLE",
            },
        }

        if question not in responses:
            raise ValueError(
                f"The mock LLM has no canned response for question: {question!r}"
            )
        return json.dumps(responses[question])

    # ---- Parse ---------------------------------------------------------------
    def parse_question(self, question: str) -> QueryPlan:
        """Prompt -> LLM -> QueryPlan."""
        prompt = self.build_prompt(question)
        if self.use_mock:
            raw = self._mock_llm(prompt)
            plan = QueryPlan(**json.loads(raw))
        else:
            plan = self._llm.invoke(prompt)
        return plan

    # ---- Execute -------------------------------------------------------------
    def execute(self, plan: QueryPlan) -> tuple[int, list[str]]:
        """Apply the pandas filter from the plan.

        Returns the count of unique USUBJID values and the sorted list of IDs.

        Matching is a case-insensitive literal substring search. Missing values
        in the target column and missing subject IDs are ignored.
        """
        if plan.target_column not in self.df.columns:
            raise ValueError(
                f"Query column {plan.target_column!r} is not present in the dataset."
            )
        if "USUBJID" not in self.df.columns:
            raise ValueError("Dataset is missing the required USUBJID column.")

        matches = self.df[plan.target_column].astype("string").str.contains(
            plan.filter_value,
            case=False,
            regex=False,
            na=False,
        )
        subject_ids = sorted(
            self.df.loc[matches, "USUBJID"].dropna().astype(str).unique().tolist()
        )
        return len(subject_ids), subject_ids

    # ---- End-to-end ----------------------------------------------------------
    def ask(self, question: str) -> QueryResult:
        plan = self.parse_question(question)
        n, ids = self.execute(plan)
        return QueryResult(question=question, plan=plan, n_subjects=n, subject_ids=ids)


def load_ae(path: Path = DATA_PATH) -> pd.DataFrame:
    """Load the AE dataset (export it first with export_adae.R)."""
    return pd.read_csv(path)
