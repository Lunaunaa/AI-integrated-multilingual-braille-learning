import sys
import unittest
from pathlib import Path
from unittest.mock import patch

import requests
from pydantic import ValidationError

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import main
from adaptive_ml import FEATURE_NAMES, predict_probability
from train_adaptive_demo import generate_synthetic_examples, train_and_evaluate
from recommendation_service import recommend_from_progress
from verified_braille import verified_single_letter, verified_uncontracted_word


class ApiTests(unittest.TestCase):
    def test_rule_baseline_selects_a_due_skill_before_future_review(self):
        from datetime import datetime, timedelta, timezone

        now = datetime.now(timezone.utc)
        result = recommend_from_progress([
            {"skill_id": "future", "attempts": 2, "mastery": 0.2, "next_review_at": now + timedelta(days=1)},
            {"skill_id": "due", "attempts": 3, "mastery": 0.6, "next_review_at": now - timedelta(days=1)},
        ])
        self.assertEqual(result["skill_id"], "due")
        self.assertEqual(result["source"], "rule_baseline")

    def test_rule_baseline_handles_new_learners_without_history(self):
        self.assertEqual(recommend_from_progress([]), {
            "skill_id": None,
            "reason": "no_practice_history",
            "source": "rule_baseline",
        })

    def test_application_health_is_independent_of_services(self):
        self.assertEqual(main.application_health(), {"status": "ok"})

    def test_tutor_uses_bounded_timeout_and_returns_local_answer(self):
        class Response:
            def raise_for_status(self):
                pass

            def json(self):
                return {"message": {"content": "Try the example in your lesson."}}

        def fake_post(url, json, timeout):
            self.assertEqual(timeout, (3, 20))
            return Response()

        with patch.object(main.requests, "post", side_effect=fake_post):
            response = main.ask_tutor(main.TutorQuestion(question="Give me a hint"))

        self.assertEqual(response["answer"], "Try the example in your lesson.")
        self.assertEqual(response["source"], "ollama")

    def test_tutor_filters_model_generated_dot_pattern_claims(self):
        class Response:
            def raise_for_status(self):
                pass
            def json(self):
                return {"message": {"content": "The letter uses dot 4."}}

        with patch.object(main.requests, "post", return_value=Response()):
            response = main.ask_tutor(main.TutorQuestion(question="Explain my lesson"))
        self.assertEqual(response["source"], "safe_fallback")
        self.assertNotIn("dot 4", response["answer"])

    def test_braille_pattern_question_uses_verified_engine_without_calling_ollama(self):
        data = main.TutorQuestion(
            question="What is the Braille pattern for a?",
            verified_examples=[{"text": "a", "cells": [1]}],
        )
        with patch.object(main.requests, "post", side_effect=AssertionError("LLM must not encode")):
            response = main.ask_tutor(data)
        self.assertEqual(response["source"], "verified_engine")
        self.assertEqual(response["verified_examples"], [{"text": "a", "cells": [1]}])
        self.assertTrue(response["sources"])

    def test_uppercase_a_answer_explains_letter_dots_and_capital_sign(self):
        with patch.object(main.requests, "post", side_effect=AssertionError("LLM must not encode")):
            response = main.ask_tutor(main.TutorQuestion(
                question="What is the Braille pattern for A?",
            ))

        self.assertEqual(response["source"], "verified_engine")
        self.assertIn("The letter A uses dot 1 only", response["answer"])
        self.assertIn("top-left", response["answer"])
        self.assertIn("capital sign (dot 6)", response["answer"])
        # Six-bit masks: 32 is dot 6 (capital sign), 1 is dot 1 (A cell).
        self.assertEqual(response["verified_examples"], [{"text": "A", "cells": [32, 1]}])
        self.assertTrue(any("iceb.org" in source["url"] for source in response["sources"]))

    def test_braille_word_answer_is_deterministic_and_includes_verified_cells(self):
        with patch.object(
            main.requests,
            "post",
            side_effect=AssertionError("word encodings must not rely on Ollama"),
        ) as request:
            response = main.ask_tutor(main.TutorQuestion(
                question="How do I write the word cat in Braille?",
            ))

        self.assertEqual(response["source"], "verified_engine")
        self.assertTrue(response["answer"].startswith("Let's look at cat one letter at a time."))
        self.assertIn("uses 3 cells", response["answer"])
        self.assertIn("c: dot 1 at top-left and dot 4 at top-right", response["answer"])
        self.assertIn("a: dot 1 at top-left", response["answer"])
        self.assertIn("t: dot 2 at middle-left, dot 3 at bottom-left, dot 4 at top-right, and dot 5 at middle-right", response["answer"])
        self.assertIn("without contractions", response["answer"])
        self.assertEqual(response["verified_examples"], [{"text": "cat", "cells": [9, 1, 30]}])
        self.assertEqual([item["letter"] for item in response["letter_examples"]], ["c", "a", "t"])
        self.assertFalse(request.called)
        self.assertTrue(any("iceb.org" in source["url"] for source in response["sources"]))

    def test_mixed_case_word_includes_capital_sign_and_unsupported_word_is_refused(self):
        class Response:
            def raise_for_status(self):
                pass
            def json(self):
                return {"message": {"content": "Let's look at each letter in order."}}

        with patch.object(main.requests, "post", return_value=Response()):
            mixed_case = main.ask_tutor(main.TutorQuestion(
                question="Encode Cat in Braille",
            ))
            unsupported = main.ask_tutor(main.TutorQuestion(
                question="Write can't in Braille",
            ))

        self.assertEqual(mixed_case["verified_examples"], [{"text": "Cat", "cells": [32, 9, 1, 30]}])
        self.assertIn("Each uppercase letter has a capital sign, dot 6", mixed_case["answer"])
        self.assertEqual(unsupported["source"], "unsupported_example")

    def test_uppercase_word_uses_the_verified_engine_capital_word_indicator(self):
        self.assertEqual(
            verified_uncontracted_word("CAT"),
            {"text": "CAT", "cells": [32, 32, 9, 1, 30]},
        )
        class Response:
            def raise_for_status(self):
                pass
            def json(self):
                return {"message": {"content": "We'll explore this word together."}}

        with patch.object(main.requests, "post", return_value=Response()):
            response = main.ask_tutor(main.TutorQuestion(
                question="How do I write CAT in Braille?",
            ))
        self.assertEqual(response["verified_examples"][0]["cells"], [32, 32, 9, 1, 30])
        self.assertIn("capital-word indicator first: dot 6 twice", response["answer"])

    def test_supported_word_question_forms_resolve_target_word(self):
        from verified_braille import requested_english_word
        examples = {
            "What dots make up the word DOG?": "DOG",
            "How do I read the Braille word SUN?": "SUN",
            "Can you teach me to write BAT?": "BAT",
            "Why is CAT written using these Braille cells?": "CAT",
        }
        for question, expected in examples.items():
            with self.subTest(question=question):
                self.assertEqual(requested_english_word(question), expected)

    def test_short_word_followup_keeps_the_verified_word_context(self):
        class Response:
            def raise_for_status(self):
                pass
            def json(self):
                return {"message": {"content": "Each cell represents one letter in this beginner spelling."}}

        with patch.object(main.requests, "post", return_value=Response()):
            response = main.ask_tutor(main.TutorQuestion(
                question="Why?",
                history=[{"role": "user", "content": "How do I write CAT in Braille?"}],
            ))
        self.assertIn("capital-word indicator", response["answer"])
        self.assertEqual(response["verified_examples"][0]["cells"], [32, 32, 9, 1, 30])
        self.assertEqual([item["letter"] for item in response["letter_examples"]], ["C", "A", "T"])

    def test_word_answers_use_verified_cells_without_calling_ollama(self):
        with patch.object(
            main.requests,
            "post",
            side_effect=requests.Timeout("local model timed out"),
        ):
            response = main.ask_tutor(main.TutorQuestion(
                question="What dots make up the word DOG?",
            ))
        self.assertEqual(response["source"], "verified_engine")
        self.assertEqual(response["verified_examples"][0]["cells"], [32, 32, 25, 21, 27])
        self.assertIn("D: dot 1 at top-left", response["answer"])
        self.assertEqual(len(response["letter_examples"]), 3)

    def test_server_verifies_requested_pattern_and_rejects_unsupported_letter(self):
        with patch.object(main.requests, "post", side_effect=AssertionError("unsupported mapping must not call LLM")):
            unsupported = main.ask_tutor(main.TutorQuestion(question="What is the pattern for Hindi अ?"))
            corrected = main.ask_tutor(main.TutorQuestion(
                question="What is the Braille pattern for a?",
                verified_examples=[{"text": "a", "cells": [2]}],
            ))
        self.assertEqual(unsupported["source"], "unsupported_example")
        self.assertEqual(corrected["source"], "verified_engine")
        self.assertEqual(corrected["verified_examples"], [{"text": "a", "cells": [1]}])

    def test_retrieval_evidence_and_followup_are_used_for_conceptual_answers(self):
        class Response:
            def raise_for_status(self):
                pass
            def json(self):
                return {"message": {"content": "The cell has two columns and three positions."}}

        captured = {}
        def fake_post(url, json, timeout):
            captured.update(json)
            return Response()

        data = main.TutorQuestion(
            question="Why?",
            history=[{"role": "user", "content": "Explain the six-dot Braille cell layout"}],
        )
        with patch.object(main.requests, "post", side_effect=fake_post):
            response = main.ask_tutor(data)
        self.assertEqual(response["source"], "ollama_rag")
        self.assertTrue(any("english-six-dot-cell" in message["content"] for message in captured["messages"]))
        self.assertTrue(response["sources"])

    def test_tutor_rejects_unvalidated_voice_language_and_limits_history(self):
        with self.assertRaises(ValidationError):
            main.TutorQuestion(question="Explain Braille", language="Hindi")
        with self.assertRaises(ValidationError):
            main.TutorQuestion(question="Explain Braille", history=[
                {"role": "user", "content": "past"} for _ in range(9)
            ])

    def test_deterministic_verifier_matches_lowercase_and_capital_cells(self):
        self.assertEqual(verified_single_letter("a"), {"text": "a", "cells": [1]})
        self.assertEqual(verified_single_letter("A"), {"text": "A", "cells": [32, 1]})
        self.assertIsNone(verified_single_letter("ā"))

    def test_tutor_timeout_returns_safe_fallback(self):
        with patch.object(
            main.requests,
            "post",
            side_effect=requests.Timeout("local model timed out"),
        ):
            response = main.ask_tutor(main.TutorQuestion(question="Explain this"))

        self.assertEqual(response["source"], "fallback")
        self.assertIn("verified English", response["answer"])

    def test_conceptual_question_gets_retrieved_teaching_when_ollama_is_unavailable(self):
        with patch.object(
            main.requests,
            "post",
            side_effect=requests.ConnectionError("local model is stopped"),
        ):
            response = main.ask_tutor(main.TutorQuestion(
                question="Explain the six-dot Braille cell layout",
            ))

        self.assertEqual(response["source"], "verified_knowledge_fallback")
        self.assertIn("two columns", response["answer"])
        self.assertTrue(response["sources"])

    def test_tutor_rejects_empty_question(self):
        with self.assertRaises(ValidationError):
            main.TutorQuestion(question="")

    def test_ml_loader_falls_back_when_artifact_is_missing(self):
        result = predict_probability({}, 0.37, Path("missing-model.joblib"))
        self.assertEqual(result["source"], "rule_based")
        self.assertEqual(result["probability"], 0.37)

    def test_synthetic_demo_model_loads_with_bounded_probability(self):
        artifact = Path(__file__).resolve().parents[1] / "artifacts" / "adaptive_v1.joblib"
        features = {
            "recent_accuracy": 0.6,
            "attempt_count": 4,
            "average_response_seconds": 25,
            "hint_rate": 0.2,
            "days_since_practice": 2,
            "mastery_estimate": 0.55,
            "exercise_difficulty": 0.4,
        }
        result = predict_probability(features, 0.5, artifact)
        self.assertEqual(result["source"], "model")
        self.assertGreaterEqual(result["probability"], 0)
        self.assertLessEqual(result["probability"], 1)

    def test_synthetic_ml_training_uses_grouped_held_out_learners(self):
        rows, targets, groups = generate_synthetic_examples(
            learner_count=40,
            skills_per_learner=3,
            attempts=5,
            seed=42,
        )
        model, metrics = train_and_evaluate(rows, targets, groups, seed=42)

        self.assertEqual(len(rows[0]), len(FEATURE_NAMES))
        self.assertEqual(metrics["train_learners"] + metrics["test_learners"], 40)
        self.assertTrue(0 <= metrics["brier_score_model"] <= 1)
        self.assertTrue(0 <= metrics["log_loss_model"])
        self.assertEqual(len(model.classes_), 2)


class RegistrationServiceTests(unittest.TestCase):
    """Unit tests for registration_service.py — no database required."""

    def test_generate_code_is_six_digits(self):
        import registration_service
        code = registration_service._generate_code()
        self.assertRegex(code, r"^\d{6}$")

    def test_hash_code_is_stable_sha256(self):
        import hashlib
        import registration_service
        code = "123456"
        expected = hashlib.sha256(code.encode()).hexdigest()
        self.assertEqual(registration_service._hash_code(code), expected)

    def test_different_codes_produce_different_hashes(self):
        import registration_service
        h1 = registration_service._hash_code("000001")
        h2 = registration_service._hash_code("000002")
        self.assertNotEqual(h1, h2)


class LearnerRegisterEndpointTests(unittest.TestCase):
    """Tests for POST /learners/register without a real database."""

    def _make_valid_payload(self, **overrides):
        payload = {
            "name": "Priya",
            "phone": "9876543210",
            "preferred_language": "English",
            "consent": True,
        }
        payload.update(overrides)
        return payload

    def test_register_requires_at_least_phone_or_email(self):
        data = main.LearnerRegisterRequest(
            name="Test", consent=True,
        )
        # Remove both phone and email
        with self.assertRaises(Exception) as ctx:
            main.learner_register(data)
        # Should raise HTTPException with 422
        from fastapi import HTTPException
        self.assertIsInstance(ctx.exception, HTTPException)
        self.assertEqual(ctx.exception.status_code, 422)

    def test_register_requires_consent(self):
        from fastapi import HTTPException
        data = main.LearnerRegisterRequest(
            name="Test", phone="9876543210", consent=False,
        )
        with self.assertRaises(HTTPException) as ctx:
            main.learner_register(data)
        self.assertEqual(ctx.exception.status_code, 422)

    def test_pydantic_rejects_non_digit_phone(self):
        from pydantic import ValidationError
        with self.assertRaises(ValidationError):
            main.LearnerRegisterRequest(
                name="Test",
                phone="not-a-number",
                consent=True,
            )

    def test_pydantic_rejects_too_short_phone(self):
        from pydantic import ValidationError
        with self.assertRaises(ValidationError):
            main.LearnerRegisterRequest(
                name="Test",
                phone="123",   # fewer than 7 digits
                consent=True,
            )

    def test_register_calls_registration_service_and_returns_code(self):
        import registration_service
        sentinel = {
            "learner_id": "uuid-abc",
            "learner_code": "042817",
            "name": "Priya",
            "phone": "9876543210",
            "email": None,
            "batch": None,
            "preferred_language": "English",
            "consent_at": None,
            "created_at": None,
        }
        with patch.object(registration_service, "register_learner", return_value=sentinel) as mock_reg:
            data = main.LearnerRegisterRequest(
                name="Priya", phone="9876543210", consent=True,
            )
            result = main.learner_register(data)
        mock_reg.assert_called_once()
        self.assertEqual(result["learner_code"], "042817")

    def test_register_propagates_db_error_as_500(self):
        import registration_service
        from fastapi import HTTPException
        with patch.object(registration_service, "register_learner", side_effect=RuntimeError("db down")):
            data = main.LearnerRegisterRequest(
                name="Priya", phone="9876543210", consent=True,
            )
            with self.assertRaises(HTTPException) as ctx:
                main.learner_register(data)
        self.assertEqual(ctx.exception.status_code, 500)


class LearnerRestoreEndpointTests(unittest.TestCase):
    """Tests for POST /learners/restore without a real database."""

    def test_restore_returns_404_on_mismatch(self):
        import registration_service
        from fastapi import HTTPException
        with patch.object(registration_service, "restore_learner", return_value=None):
            data = main.LearnerRestoreRequest(
                phone_or_email="9876543210", code="000000",
            )
            with self.assertRaises(HTTPException) as ctx:
                main.learner_restore(data)
        self.assertEqual(ctx.exception.status_code, 404)

    def test_restore_returns_learner_on_match(self):
        import registration_service
        sentinel = {
            "learner_id": "uuid-abc",
            "name": "Priya",
            "phone": "9876543210",
            "email": None,
            "batch": None,
            "preferred_language": "English",
            "created_at": None,
        }
        with patch.object(registration_service, "restore_learner", return_value=sentinel):
            data = main.LearnerRestoreRequest(
                phone_or_email="9876543210", code="042817",
            )
            result = main.learner_restore(data)
        self.assertEqual(result["learner_id"], "uuid-abc")

    def test_pydantic_rejects_non_six_digit_code(self):
        from pydantic import ValidationError
        with self.assertRaises(ValidationError):
            main.LearnerRestoreRequest(
                phone_or_email="9876543210", code="12345",  # 5 digits
            )

    def test_pydantic_rejects_alpha_code(self):
        from pydantic import ValidationError
        with self.assertRaises(ValidationError):
            main.LearnerRestoreRequest(
                phone_or_email="9876543210", code="abc123",
            )

    def test_restore_propagates_db_error_as_500(self):
        import registration_service
        from fastapi import HTTPException
        with patch.object(registration_service, "restore_learner", side_effect=RuntimeError("db down")):
            data = main.LearnerRestoreRequest(
                phone_or_email="9876543210", code="042817",
            )
            with self.assertRaises(HTTPException) as ctx:
                main.learner_restore(data)
        self.assertEqual(ctx.exception.status_code, 500)


if __name__ == "__main__":
    unittest.main()
