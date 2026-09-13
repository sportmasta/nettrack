from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

ROOT = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=str(ROOT / ".env"), extra="ignore")

    database_url: str = "postgresql+psycopg2://nettrack:nettrack@localhost:5432/nettrack"
    default_rsc_path: str = str(ROOT / "config" / "ccr2004.rsc")
    skip_seed: bool = False


settings = Settings()
