"""Tests for the Python auth.verify capability (pure logic)."""
import pytest
from src.domain.auth import check_password, hash_password, mint_token, verify_token


def test_verify_valid():
    tok = mint_token("user-1", "field_agent", "secret")
    claims = verify_token(tok, "secret")
    assert claims.user_id == "user-1"
    assert claims.role == "field_agent"


def test_verify_wrong_secret():
    tok = mint_token("user-1", "field_agent", "secret")
    with pytest.raises(ValueError):
        verify_token(tok, "wrong")


def test_hash_and_check():
    h = hash_password("s3cret!")
    assert check_password("s3cret!", h)
    assert not check_password("wrong", h)


def test_hash_salted():
    assert hash_password("same") != hash_password("same")
