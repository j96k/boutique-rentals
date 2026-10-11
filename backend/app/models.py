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


class Rental(Base):
    __tablename__ = "rentals"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    cloth_id: Mapped[int] = mapped_column(ForeignKey("cloths.id", ondelete="CASCADE"), index=True)
    customer_name: Mapped[str] = mapped_column(String(120))
    customer_phone: Mapped[str | None] = mapped_column(String(20), nullable=True)
    start_at: Mapped[datetime] = mapped_column(DateTime, index=True)  # goes out on rent
    end_at: Mapped[datetime] = mapped_column(DateTime, index=True)  # promised return
    returned_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)  # actually came back
    advance_paid: Mapped[float] = mapped_column(Numeric(10, 2), default=0)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    cloth: Mapped[Cloth] = relationship(back_populates="rentals")

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
