"""Test script: run 3 example queries through ClinicalTrialDataAgent and print the results.

Usage (from question_4_python/):
    python test_agent.py            # real LLM if OPENAI_API_KEY is set, otherwise mock
    python test_agent.py --mock     # always use the mock LLM
"""

import sys

from clinical_trial_data_agent import ClinicalTrialDataAgent, load_ae

try:
    from dotenv import load_dotenv

    load_dotenv()
except ImportError:
    pass

QUESTIONS = [
    "Give me the subjects who had Adverse events of Moderate severity.",
    "Which patients reported a headache?",
    "How many patients had an AE involving cancer?",
    "How many patients had AES which were probably linked to the study drug?",
]


def main() -> None:
    use_mock = True if "--mock" in sys.argv else None
    agent = ClinicalTrialDataAgent(load_ae(), use_mock=use_mock)
    print(f"LLM mode: {'mock' if agent.use_mock else agent.model}\n")

    for q in QUESTIONS:
        result = agent.ask(q)
        print(f"Q: {result.question}")
        print(f"   Plan     : {result.plan.model_dump_json()}")
        print(f"   Subjects : {result.n_subjects}")
        print(f"   IDs      : {result.subject_ids}\n")


if __name__ == "__main__":
    main()
