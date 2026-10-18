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
    rent_amount: float | None = Field(default=None, ge=0)  # empty = the cloth's rent price
    advance_paid: float = Field(default=0, ge=0)  # rent paid so far
    deposit_amount: float = Field(default=0, ge=0)  # security deposit taken
    notes: str | None = None

    @model_validator(mode="after")
    def check_dates(self):
        if self.end_at <= self.start_at:
            raise ValueError("Return date/time must be after the rent-out date/time")
        if self.rent_amount is not None and self.advance_paid > self.rent_amount:
            raise ValueError("Paid amount can't be more than the rent amount")
        return self


class ReturnIn(BaseModel):
    """Sent with "Mark returned". All optional, so older app versions still work."""

    collect_balance: bool = True  # the remaining rent was paid now
    deposit_returned: float | None = Field(default=None, ge=0)  # None = decide later
    deposit_note: str | None = Field(default=None, max_length=500)


class DepositIn(BaseModel):
    deposit_returned: float = Field(ge=0)
    deposit_note: str | None = Field(default=None, max_length=500)


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
    rent_amount: float
    advance_paid: float  # rent paid so far
    balance_due: float
    deposit_amount: float
    deposit_returned: float | None
    deposit_kept: float
    deposit_status: str  # none | held | refunded | part_kept
    deposit_note: str | None
    deposit_settled_at: datetime | None
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


# ---------- Inquiries (waitlist) ----------
class InquiryIn(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    phone: str | None = Field(default=None, max_length=20)
    email: str | None = Field(default=None, max_length=120)
    instagram: str | None = Field(default=None, max_length=60)
    offered_amount: float = Field(default=0, ge=0)
    wanted_from: datetime | None = None
    wanted_to: datetime | None = None
    notes: str | None = Field(default=None, max_length=1000)

    @model_validator(mode="after")
    def check(self):
        for f in ("phone", "email", "instagram", "notes"):
            v = getattr(self, f)
            setattr(self, f, v.strip() if v and v.strip() else None)
        if self.instagram:
            self.instagram = self.instagram.lstrip("@")
        if not (self.phone or self.email or self.instagram):
            raise ValueError("Add at least one way to contact them: phone, Gmail or Instagram")
        if (self.wanted_from is None) != (self.wanted_to is None):
            raise ValueError("Choose both the 'from' and 'to' dates, or neither")
        if self.wanted_from and self.wanted_to and self.wanted_to <= self.wanted_from:
            raise ValueError("The 'to' date must be after the 'from' date")
        return self


class InquiryStatusIn(BaseModel):
    status: str = Field(pattern=r"^(waiting|contacted|booked|not_interested)$")


class InquiryOut(BaseModel):
    id: int
    cloth_id: int
    cloth_code: str
    cloth_name: str
    cloth_image: str | None
    name: str
    phone: str | None
    email: str | None
    instagram: str | None
    offered_amount: float
    wanted_from: datetime | None
    wanted_to: datetime | None
    notes: str | None
    status: str
    source: str
    created_at: datetime


# ---------- Dashboard ----------
class DashboardOut(BaseModel):
    total_cloths: int
    available: int
    on_rent: int
    overdue: int
    going_out_today: list[RentalOut]
    returning_today: list[RentalOut]
    overdue_list: list[RentalOut]
    waitlist_ready: list[InquiryOut]  # people waiting for clothes that are free for their dates


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


# ---------- Earnings ----------
class EarningsTotals(BaseModel):
    bookings: int
    rent_total: float  # agreed rent of bookings in the period
    rent_collected: float
    rent_pending: float
    deposit_kept: float  # kept from deposits (damage etc.) — extra income
    income: float  # rent_total + deposit_kept
    deposits_held_now: float  # deposits you're holding right now (to give back) — not period-based


class EarningsByDate(BaseModel):
    period: str  # "2026-10-18" (day) or "2026-10" (month)
    bookings: int
    rent: float
    collected: float
    deposit_kept: float


class EarningsByCloth(BaseModel):
    cloth_id: int
    cloth_code: str
    cloth_name: str
    cloth_image: str | None
    bookings: int
    days_rented: float
    rent: float
    collected: float
    deposit_kept: float


class EarningsOut(BaseModel):
    start: datetime
    end: datetime
    group: str  # day | month
    totals: EarningsTotals
    by_date: list[EarningsByDate]
    by_cloth: list[EarningsByCloth]


# ---------- Customers ----------
class CustomerSummary(BaseModel):
    key: str  # "p:9812345678" (by phone) or "n:priya shah" (no phone)
    name: str
    phone: str | None
    bookings: int
    last_booking_at: datetime | None
    rent_total: float
    rent_paid: float
    balance_due: float
    deposits_held: float  # still to give back to this customer
    deposits_returned: float
    deposits_kept: float
    inquiries: int


class CustomerDetail(CustomerSummary):
    other_names: list[str]  # if the same phone was booked under different names
    rentals: list[RentalOut]  # newest first
    waitlist: list[InquiryOut]
