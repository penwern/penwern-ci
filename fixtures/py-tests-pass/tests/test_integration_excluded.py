import pytest


@pytest.mark.integration
def test_would_fail_if_run():
    # Proves `pytest -m "not integration"` excludes this; if it ran, the suite would fail.
    assert False
