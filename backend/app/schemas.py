from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, model_validator


# ---------- Auth ----------
class RegisterIn(BaseModel):
    username: str = Field(min_length=3, max_length=50, pattern=r"^[a-zA-Z0-9_.]+$")
    password: str = Field(min_length=6, max_length=72)
    boutique_name: str = Field(min_length=2, max_length=120)
    phone: str | None = Field(default=None, max_length=20)


class LoginIn(BaseModel):
    username: str
    password: str


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    username: str
    boutique_name: str
    phone: str | None


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut


# ---------- Rentals ----------
class RentalIn(BaseModel):
    customer_name: str = Field(min_length=1, max_length=120)
    customer_phone: str | None = Field(default=None, max_length=20)
    start_at: datetime
    end_at: datetime
    advance_paid: float = 0
    notes: str | None = None

    @model_validator(mode="after")
    def check_dates(self):
        if self.end_at <= self.start_at:
            raise ValueError("Return date/time must be after the rent-out date/time")
        return self


class RentalOut(BaseModel):
    id: int
    cloth_id: int
    cloth_code: str
    cloth_name: str
    cloth_image: str | None
    customer_name: str
    customer_phone: str | None
    start_at: datetime
    end_at: datetime
    returned_at: datetime | None
    advance_paid: float
    notes: str | None
    status: str  # booked | on_rent | overdue | returned


# ---------- Cloths ----------
class ClothOut(BaseModel):
    id: int
    cloth_code: str
    name: str
    description: str
    category: str | None
    size: str | None
    rent_price: float
    image_url: str | None
    status: str  # available | on_rent | overdue
    current_rental: RentalOut | None
    next_booking: RentalOut | None


class ClothDetailOut(ClothOut):
    rentals: list[RentalOut]


# ---------- Dashboard ----------
class DashboardOut(BaseModel):
    total_cloths: int
    available: int
    on_rent: int
    overdue: int
    going_out_today: list[RentalOut]
    returning_today: list[RentalOut]
    overdue_list: list[RentalOut]


# ---------- Public (customer) ----------
class BusyRange(BaseModel):
    start_at: datetime
    end_at: datetime


class PublicClothOut(BaseModel):
    boutique_name: str
    cloth_code: str
    name: str
    description: str
    category: str | None
    size: str | None
    rent_price: float
    image_url: str | None
    available_now: bool
    busy: list[BusyRange]
