from sqlalchemy import create_engine, event
from sqlalchemy.orm import DeclarativeBase, sessionmaker

from .config import settings


def ensure_database_exists() -> None:
    """Create the database if it is missing, so beginners don't have to."""
    if settings.is_sqlite:
        settings.sqlite_path.parent.mkdir(parents=True, exist_ok=True)
        return
    if settings.is_postgres:
        return  # the online database (Neon) is created in its website

    import pymysql

    conn = pymysql.connect(
        host=settings.db_host,
        port=settings.db_port,
        user=settings.db_user,
        password=settings.db_password,
    )
    try:
        with conn.cursor() as cur:
            cur.execute(
                f"CREATE DATABASE IF NOT EXISTS `{settings.db_name}` "
                "CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
            )
        conn.commit()
    finally:
        conn.close()


ensure_database_exists()

if settings.is_sqlite:
    # check_same_thread=False: FastAPI serves requests from several threads.
    engine = create_engine(settings.database_url, connect_args={"check_same_thread": False})

    @event.listens_for(engine, "connect")
    def _sqlite_pragmas(dbapi_conn, _):
        # SQLite ignores foreign keys (and so ON DELETE CASCADE) unless switched on.
        dbapi_conn.execute("PRAGMA foreign_keys=ON")
elif settings.is_postgres:
    # Neon closes idle connections, so check them before use and recycle often.
    engine = create_engine(settings.database_url, pool_pre_ping=True, pool_recycle=300)
else:
    engine = create_engine(settings.database_url, pool_pre_ping=True, pool_recycle=3600)

SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
