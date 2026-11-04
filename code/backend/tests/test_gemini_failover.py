"""Tests for multi-key and multi-model Gemini failover mechanism."""
import pytest
from unittest.mock import MagicMock, patch

from app.config import Settings
from app.services.vision_service import (
    generate_gemini_content,
    get_candidate_models,
    reset_gemini_clients,
)


def test_gemini_keys_parsing():
    # 1. Comma-separated in GEMINI_API_KEY
    s1 = Settings(GEMINI_API_KEY="key1, key2, key3")
    assert s1.gemini_api_keys == ["key1", "key2", "key3"]
    assert s1.GEMINI_API_KEY == "key1"

    # 2. Plural GEMINI_API_KEYS
    s2 = Settings(GEMINI_API_KEY="", GEMINI_API_KEYS="keyA,keyB,keyC")
    assert s2.gemini_api_keys == ["keyA", "keyB", "keyC"]
    assert s2.GEMINI_API_KEY == "keyA"

    # 3. Numbered env vars
    with patch.dict("os.environ", {"GEMINI_API_KEY_1": "numKey1", "GEMINI_API_KEY_2": "numKey2"}):
        s3 = Settings(GEMINI_API_KEY=None, GEMINI_API_KEYS=None)
        assert "numKey1" in s3.gemini_api_keys
        assert "numKey2" in s3.gemini_api_keys


def test_failover_shifts_to_next_key_when_all_models_fail():
    """Verify that if Client 1 fails across all candidate models, execution shifts to Client 2."""
    models = ["model-primary", "model-fallback"]

    # Mock Client 1: Fails on all models with 429 RESOURCE_EXHAUSTED
    client_1 = MagicMock()
    client_1.models.generate_content.side_effect = Exception("429 RESOURCE_EXHAUSTED free tier exceeded")

    # Mock Client 2: Succeeds on fallback model
    client_2 = MagicMock()
    success_resp = MagicMock()
    success_resp.text = '{"status": "ok"}'

    def client_2_generate(model, contents, config=None):
        if model == "model-primary":
            raise Exception("503 UNAVAILABLE spike in demand")
        return success_resp

    client_2.models.generate_content.side_effect = client_2_generate

    mock_clients = [("Key-1", client_1), ("Key-2", client_2)]

    with patch("app.services.vision_service.get_gemini_clients", return_value=mock_clients):
        resp, used_model = generate_gemini_content(
            contents="test prompt",
            preferred_models=models,
        )

    # Client 1 was called for each model
    assert client_1.models.generate_content.call_count == len(models)

    # Client 2 was called and succeeded on model-fallback
    assert resp == success_resp
    assert used_model == "model-fallback"


def test_failover_returns_none_when_all_keys_and_models_exhausted():
    """Verify graceful fallback when all keys and candidate models fail."""
    client_1 = MagicMock()
    client_1.models.generate_content.side_effect = Exception("429 RESOURCE_EXHAUSTED")
    client_2 = MagicMock()
    client_2.models.generate_content.side_effect = Exception("503 UNAVAILABLE")

    mock_clients = [("Key-1", client_1), ("Key-2", client_2)]

    with patch("app.services.vision_service.get_gemini_clients", return_value=mock_clients):
        resp, used_model = generate_gemini_content(
            contents="test prompt",
            preferred_models=["model-a"],
        )

    assert resp is None
    assert used_model is None
