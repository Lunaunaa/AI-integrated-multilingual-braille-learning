import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from knowledge_base import retrieve_evidence


class RetrievalEvaluationTests(unittest.TestCase):
    """Small deterministic retrieval set; this does not evaluate an LLM."""

    def test_reference_queries_retrieve_expected_scope_only(self):
        cases = [
            ("Explain the six-dot Braille cell layout", "english-six-dot-cell"),
            ("Why does letter B use that pattern?", "english-letter-b"),
            ("What does UEB say about contractions?", "resonant-english-scope"),
            ("Can you teach Hindi Bharati Braille?", "resonant-language-scope"),
            ("Explain the Braille pattern for C", "english-letter-c"),
        ]
        for question, expected in cases:
            with self.subTest(question=question):
                result = retrieve_evidence(question)
                self.assertEqual([item["id"] for item in result], [expected])

    def test_short_followup_resolves_from_immediately_available_user_history(self):
        result = retrieve_evidence(
            "Why?", history=[{"role": "user", "content": "Explain the six-dot Braille cell layout"}]
        )
        self.assertEqual([item["id"] for item in result], ["english-six-dot-cell"])

    def test_unrepresented_topic_does_not_get_invented_retrieval(self):
        result = retrieve_evidence("Explain music notation")
        self.assertEqual(result, [])


if __name__ == "__main__":
    unittest.main()
