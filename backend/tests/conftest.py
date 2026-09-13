import os
from pathlib import Path

os.environ.setdefault("DATABASE_URL", "sqlite:///" + str(Path(__file__).parent / "test.db"))
os.environ.setdefault("SKIP_SEED", "1")

import pytest
from fastapi.testclient import TestClient

from app.db import Base, engine
from app.main import app


@pytest.fixture(autouse=True)
def _db():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture
def client() -> TestClient:
    return TestClient(app)


@pytest.fixture
def sample_rsc() -> str:
    path = Path(__file__).parent / "fixtures" / "sample.rsc"
    return path.read_text(encoding="utf-8")
