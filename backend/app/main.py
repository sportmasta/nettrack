from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import router
from app.config import settings
from app.db import SessionLocal, init_db
from app.services import seed_default


@asynccontextmanager
async def lifespan(_app: FastAPI):
    init_db()
    if not settings.skip_seed:
        db = SessionLocal()
        try:
            seed_default(db, settings.default_rsc_path)
        finally:
            db.close()
    yield


app = FastAPI(title="NetTrack", lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(router)
