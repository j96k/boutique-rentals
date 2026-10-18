"""Customers: search by name or phone and see their whole history (bookings, payments, deposits).
There is no separate customer table — a customer is everyone booked with the same phone number
(or, without a phone, the same name)."""

import re
from collections import defaultdict
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from ..database import get_db
from ..models import Cloth, Inquiry, Rental, User
from ..schemas import CustomerDetail, CustomerSummary
from ..security import current_user
from ..serializers import inquiry_out, rental_out

router = APIRouter(prefix="/customers", tags=["Customers"])


def phone_digits(phone: str | None) -> str:
    """'+91 98123-45678' -> '9812345678' (last 10 digits, so country codes don't matter)."""
    digits = re.sub(r"\D", "", phone or "")
    return digits[-10:]


def customer_key(name: str, phone: str | None) -> str:
    digits = phone_digits(phone)
    return f"p:{digits}" if len(digits) >= 6 else f"n:{' '.join(name.lower().split())}"


def _load(db: Session, user: User):
    rentals = db.scalars(
        select(Rental).join(Cloth).options(joinedload(Rental.cloth)).where(Cloth.owner_id == user.id)
    ).unique().all()
    inquiries = db.scalars(
        select(Inquiry).join(Cloth).options(joinedload(Inquiry.cloth)).where(Cloth.owner_id == user.id)
    ).unique().all()
    groups: dict[str, dict] = defaultdict(lambda: {"rentals": [], "inquiries": []})
    for r in rentals:
        groups[customer_key(r.customer_name, r.customer_phone)]["rentals"].append(r)
    for i in inquiries:
        # Waitlist people only join a customer found by phone (names alone are too loose).
        if phone_digits(i.phone):
            groups[f"p:{phone_digits(i.phone)}"]["inquiries"].append(i)
    return groups


def _summary(key: str, g: dict) -> dict:
    rentals: list[Rental] = sorted(g["rentals"], key=lambda r: r.start_at, reverse=True)
    inquiries: list[Inquiry] = g["inquiries"]
    latest = rentals[0] if rentals else None
    name = latest.customer_name if latest else inquiries[0].name
    phone = (latest.customer_phone if latest and latest.customer_phone else None) or next(
        (i.phone for i in inquiries if i.phone), None
    )
    return dict(
        key=key,
        name=name,
        phone=phone,
        bookings=len(rentals),
        last_booking_at=latest.start_at if latest else None,
        rent_total=sum(float(r.rent_amount or 0) for r in rentals),
        rent_paid=sum(float(r.advance_paid or 0) for r in rentals),
        balance_due=sum(r.balance_due for r in rentals),
        deposits_held=sum(float(r.deposit_amount or 0) for r in rentals if r.deposit_status == "held"),
        deposits_returned=sum(float(r.deposit_returned or 0) for r in rentals if r.deposit_returned is not None),
        deposits_kept=sum(r.deposit_kept for r in rentals),
        inquiries=len(inquiries),
    )


@router.get("", response_model=list[CustomerSummary])
def search_customers(q: str = "", user: User = Depends(current_user), db: Session = Depends(get_db)):
    """Search by name or phone. Empty search = most recent customers.
    People still owed a deposit are listed first."""
    groups = _load(db, user)
    q = q.strip().lower()
    digits = re.sub(r"\D", "", q)
    if len(digits) > 10:
        digits = digits[-10:]  # "+91 98123 45678" matches a number saved as "9812345678"
    found = []
    for key, g in groups.items():
        s = _summary(key, g)
        if q:
            names = {r.customer_name.lower() for r in g["rentals"]} | {i.name.lower() for i in g["inquiries"]}
            by_phone = len(digits) >= 3 and digits in phone_digits(s["phone"])
            by_name = any(q in n for n in names)
            if not (by_phone or by_name):
                continue
        found.append(s)
    found.sort(key=lambda s: (s["deposits_held"] <= 0, -(s["last_booking_at"] or datetime.min).timestamp()))
    return found[:100]


@router.get("/detail", response_model=CustomerDetail)
def customer_detail(key: str, user: User = Depends(current_user), db: Session = Depends(get_db)):
    g = _load(db, user).get(key)
    if g is None:
        raise HTTPException(404, "Customer not found")
    now = datetime.now()
    rentals = sorted(g["rentals"], key=lambda r: r.start_at, reverse=True)
    s = _summary(key, g)
    return CustomerDetail(
        **s,
        other_names=sorted({r.customer_name for r in rentals} - {s["name"]}),
        rentals=[rental_out(r, now) for r in rentals],
        waitlist=[inquiry_out(i) for i in sorted(g["inquiries"], key=lambda i: i.created_at or now, reverse=True)],
    )
