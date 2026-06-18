"""Runtime configuration, sourced from environment variables.

The Helm chart (helm/backend) injects DB_* from the postgres-credentials Secret
and OTEL_* from its values. Sensible localhost defaults keep `uvicorn app.main:app`
working for local dev without any env wiring.
"""
from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # --- App ---
    app_name: str = "platform-obs-backend"
    environment: str = "dev"
    log_level: str = "info"

    # --- Postgres ---
    db_host: str = "localhost"
    db_port: int = 5432
    db_name: str = "appdb"
    db_user: str = "appuser"
    db_password: str = "appsecret"

    # Pool sizing — kept small; observability workloads care more about
    # predictable latency than raw throughput here.
    db_pool_min: int = 1
    db_pool_max: int = 5

    @property
    def db_conninfo(self) -> str:
        return (
            f"host={self.db_host} port={self.db_port} dbname={self.db_name} "
            f"user={self.db_user} password={self.db_password} "
            f"connect_timeout=5 application_name={self.app_name}"
        )


@lru_cache
def get_settings() -> Settings:
    return Settings()
