from sqlalchemy import create_engine, event, inspect, text
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


# Columns added after the first version. create_all() only makes missing *tables*,
# so existing databases (your PC's SQLite, Neon online) get these added here.
_NEW_COLUMNS = {
    "rentals": [
        ("rent_amount", "NUMERIC(10,2) DEFAULT 0"),
        ("deposit_amount", "NUMERIC(10,2) DEFAULT 0"),
        ("deposit_returned", "NUMERIC(10,2)"),
        ("deposit_note", "TEXT"),
        ("deposit_settled_at", "TIMESTAMP"),
        ("invoice_token", "VARCHAR(40)"),
        ("customer_email", "VARCHAR(120)"),
        ("customer_instagram", "VARCHAR(60)"),
    ],
}


def upgrade_schema() -> None:
    insp = inspect(engine)
    with engine.begin() as conn:
        for table, columns in _NEW_COLUMNS.items():
            existing = {c["name"] for c in insp.get_columns(table)}
            for name, ddl in columns:
                if name in existing:
                    continue
                conn.execute(text(f"ALTER TABLE {table} ADD COLUMN {name} {ddl}"))
                if (table, name) == ("rentals", "rent_amount"):
                    # Old bookings had no rent amount: use the cloth's price.
                    conn.execute(text(
                        "UPDATE rentals SET rent_amount = "
                        "(SELECT rent_price FROM cloths WHERE cloths.id = rentals.cloth_id)"
                    ))
        # Rent can't be less than what was already paid (old bookings with a ₹0 cloth price).
        conn.execute(text("UPDATE rentals SET rent_amount = advance_paid WHERE rent_amount < advance_paid"))
        # Deposits settled before the date was recorded: use the day the cloth came back.
        conn.execute(text(
            "UPDATE rentals SET deposit_settled_at = returned_at "
            "WHERE deposit_returned IS NOT NULL AND deposit_settled_at IS NULL"
        ))
