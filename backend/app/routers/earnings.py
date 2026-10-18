"""Earnings dashboard: money per day/month and per cloth, for bookings starting in a period."""

from collections import defaultdict
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from ..database import get_db
from ..models import Cloth, Rental, User
from ..schemas import EarningsByCloth, EarningsByDate, EarningsOut, EarningsTotals
from ..security import current_user
from ..serializers import image_url

router = APIRouter(tags=["Earnings"])


def _periods(start: datetime, end: datetime, group: str) -> list[str]:
    """Every day / month in the range, so the chart has no gaps."""
    keys, d = [], start
    while d < end:
        key = d.strftime("%Y-%m-%d" if group == "day" else "%Y-%m")
        if not keys or keys[-1] != key:
            keys.append(key)
        d += timedelta(days=1)
    return keys


@router.get("/earnings", response_model=EarningsOut)
def earnings(
    start: datetime,
    end: datetime,
    group: str = Query("auto", pattern="^(auto|day|month)$"),
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    """Bookings that start between start and end (end not included).
    group=auto gives days for up to ~2 months, months for longer ranges."""
    start, end = start.replace(tzinfo=None), end.replace(tzinfo=None)
    if group == "auto":
        group = "day" if (end - start).days <= 62 else "month"
    fmt = "%Y-%m-%d" if group == "day" else "%Y-%m"

    cloths = db.scalars(select(Cloth).where(Cloth.owner_id == user.id)).all()
    rentals = db.scalars(
        select(Rental)
        .join(Cloth)
        .options(joinedload(Rental.cloth))
        .where(Cloth.owner_id == user.id, Rental.start_at >= start, Rental.start_at < end)
    ).unique().all()

    by_date = {k: EarningsByDate(period=k, bookings=0, rent=0, collected=0, deposit_kept=0) for k in _periods(start, end, group)}
    by_cloth = {
        c.id: EarningsByCloth(
            cloth_id=c.id, cloth_code=c.cloth_code, cloth_name=c.name, cloth_image=image_url(c),
            bookings=0, days_rented=0, rent=0, collected=0, deposit_kept=0,
        )
        for c in cloths
    }
    totals = defaultdict(float)
    for r in rentals:
        rent, paid, kept = float(r.rent_amount or 0), float(r.advance_paid or 0), r.deposit_kept
        days = max((r.end_at - r.start_at).total_seconds() / 86400, 0)
        for row in (by_date.get(r.start_at.strftime(fmt)), by_cloth.get(r.cloth_id)):
            if row is None:
                continue
            row.bookings += 1
            row.rent += rent
            row.collected += paid
            row.deposit_kept += kept
        by_cloth[r.cloth_id].days_rented += days
        totals["rent"] += rent
        totals["paid"] += paid
        totals["kept"] += kept

    # Deposits you're holding right now (any booking, not just this period).
    held = db.scalars(
        select(Rental).join(Cloth).where(Cloth.owner_id == user.id, Rental.deposit_returned.is_(None), Rental.deposit_amount > 0)
    ).all()

    for row in by_cloth.values():
        row.days_rented = round(row.days_rented, 1)
    return EarningsOut(
        start=start,
        end=end,
        group=group,
        totals=EarningsTotals(
            bookings=len(rentals),
            rent_total=totals["rent"],
            rent_collected=totals["paid"],
            rent_pending=max(totals["rent"] - totals["paid"], 0),
            deposit_kept=totals["kept"],
            income=totals["rent"] + totals["kept"],
            deposits_held_now=sum(float(r.deposit_amount or 0) for r in held),
        ),
        by_date=list(by_date.values()),
        # Best earners first; clothes not rented in this period at the end.
        by_cloth=sorted(by_cloth.values(), key=lambda c: (-(c.rent + c.deposit_kept), -c.bookings, c.cloth_code)),
    )
