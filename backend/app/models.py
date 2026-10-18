from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, LargeBinary, Numeric, String, Text, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .database import Base


class User(Base):
    """A boutique owner account."""

    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    username: Mapped[str] = mapped_column(String(50), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    boutique_name: Mapped[str] = mapped_column(String(120))
    phone: Mapped[str | None] = mapped_column(String(20), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    cloths: Mapped[list["Cloth"]] = relationship(back_populates="owner", cascade="all, delete-orphan")


class Cloth(Base):
    __tablename__ = "cloths"
    __table_args__ = (UniqueConstraint("owner_id", "cloth_code", name="uq_owner_cloth_code"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    owner_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    cloth_code: Mapped[str] = mapped_column(String(40), index=True)  # the "Cloth ID" printed on the tag
    name: Mapped[str] = mapped_column(String(120))
    description: Mapped[str] = mapped_column(Text, default="")
    category: Mapped[str | None] = mapped_column(String(60), nullable=True)
    size: Mapped[str | None] = mapped_column(String(20), nullable=True)
    rent_price: Mapped[float] = mapped_column(Numeric(10, 2), default=0)
    image_path: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    owner: Mapped[User] = relationship(back_populates="cloths")
    rentals: Mapped[list["Rental"]] = relationship(
        back_populates="cloth", cascade="all, delete-orphan", order_by="Rental.start_at.desc()"
    )
    inquiries: Mapped[list["Inquiry"]] = relationship(back_populates="cloth", cascade="all, delete-orphan")


class Rental(Base):
    __tablename__ = "rentals"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    cloth_id: Mapped[int] = mapped_column(ForeignKey("cloths.id", ondelete="CASCADE"), index=True)
    customer_name: Mapped[str] = mapped_column(String(120))
    customer_phone: Mapped[str | None] = mapped_column(String(20), nullable=True)
    start_at: Mapped[datetime] = mapped_column(DateTime, index=True)  # goes out on rent
    end_at: Mapped[datetime] = mapped_column(DateTime, index=True)  # promised return
    returned_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)  # actually came back
    # --- money ---
    rent_amount: Mapped[float] = mapped_column(Numeric(10, 2), default=0)  # agreed rent for this booking
    advance_paid: Mapped[float] = mapped_column(Numeric(10, 2), default=0)  # rent paid so far
    deposit_amount: Mapped[float] = mapped_column(Numeric(10, 2), default=0)  # security deposit taken
    deposit_returned: Mapped[float | None] = mapped_column(Numeric(10, 2), nullable=True)  # None = not settled yet
    deposit_note: Mapped[str | None] = mapped_column(Text, nullable=True)  # e.g. why part was kept
    deposit_settled_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)  # when it was given back
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    cloth: Mapped[Cloth] = relationship(back_populates="rentals")

    @property
    def balance_due(self) -> float:
        return max(float(self.rent_amount or 0) - float(self.advance_paid or 0), 0.0)

    @property
    def deposit_kept(self) -> float:
        """Part of the deposit kept (e.g. for damage) — extra income."""
        if self.deposit_returned is None:
            return 0.0
        return max(float(self.deposit_amount or 0) - float(self.deposit_returned), 0.0)

    @property
    def deposit_status(self) -> str:
        if not self.deposit_amount:
            return "none"
        if self.deposit_returned is None:
            return "held"
        return "refunded" if self.deposit_kept == 0 else "part_kept"

    def status(self, now: datetime) -> str:
        if self.returned_at is not None:
            return "returned"
        if now < self.start_at:
            return "booked"
        if now > self.end_at:
            return "overdue"
        return "on_rent"


class StoredImage(Base):
    """A cloth photo kept inside the database (used with an online database,
    because free hosting disks are wiped on restart)."""

    __tablename__ = "images"

    name: Mapped[str] = mapped_column(String(64), primary_key=True)  # same as Cloth.image_path
    content_type: Mapped[str] = mapped_column(String(40))
    data: Mapped[bytes] = mapped_column(LargeBinary)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())


INQUIRY_STATUSES = ("waiting", "contacted", "booked", "not_interested")
ACTIVE_INQUIRY_STATUSES = ("waiting", "contacted")


class Inquiry(Base):
    """Someone who wants a cloth (the waitlist). Contacted when the cloth frees up."""

    __tablename__ = "inquiries"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    cloth_id: Mapped[int] = mapped_column(ForeignKey("cloths.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String(120))
    phone: Mapped[str | None] = mapped_column(String(20), nullable=True)
    email: Mapped[str | None] = mapped_column(String(120), nullable=True)
    instagram: Mapped[str | None] = mapped_column(String(60), nullable=True)
    offered_amount: Mapped[float] = mapped_column(Numeric(10, 2), default=0)  # what they're ready to pay
    wanted_from: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)  # empty = any dates
    wanted_to: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="waiting")  # see INQUIRY_STATUSES
    source: Mapped[str] = mapped_column(String(10), default="owner")  # owner | customer
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    cloth: Mapped[Cloth] = relationship(back_populates="inquiries")

    def wants(self, start: datetime, end: datetime) -> bool:
        """True if this person would take the cloth for (part of) start..end."""
        if self.wanted_from is None or self.wanted_to is None:
            return True
        return self.wanted_from < end and self.wanted_to > start
