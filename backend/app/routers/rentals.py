from datetime import datetime, time, timedelta

from fastapi import APIRouter, Body, Depends, HTTPException
from sqlalchemy import and_, select
from sqlalchemy.orm import Session, joinedload, selectinload

from ..database import get_db
from ..models import Cloth, Rental, User
from ..schemas import DashboardOut, DepositIn, RentalIn, RentalOut, ReturnIn
from ..security import current_user
from ..serializers import cloth_out, inquiry_out, rental_out
from .cloths import _get_owned
from .inquiries import waitlist_ready

router = APIRouter(tags=["Rentals"])


def _owned_rental(db: Session, user: User, rental_id: int) -> Rental:
    rental = db.scalar(
        select(Rental)
        .join(Cloth)
        .options(joinedload(Rental.cloth))
        .where(Rental.id == rental_id, Cloth.owner_id == user.id)
    )
    if rental is None:
        raise HTTPException(404, "Rental not found")
    return rental


def _check_overlap(db: Session, cloth_id: int, start: datetime, end: datetime, ignore_id: int | None = None):
    """A cloth cannot be given to two customers at the same time."""
    stmt = select(Rental).where(
        Rental.cloth_id == cloth_id,
        Rental.returned_at.is_(None),
        Rental.start_at < end,
        Rental.end_at > start,
    )
    if ignore_id:
        stmt = stmt.where(Rental.id != ignore_id)
    clash = db.scalar(stmt)
    if clash:
        raise HTTPException(
            409,
            f"Already booked by {clash.customer_name} from "
            f"{clash.start_at:%d %b %Y %I:%M %p} to {clash.end_at:%d %b %Y %I:%M %p}",
        )


def _apply_rental(rental: Rental, body: RentalIn, cloth: Cloth) -> None:
    for k, v in body.model_dump(exclude={"start_at", "end_at", "rent_amount"}).items():
        setattr(rental, k, v)
    rental.start_at, rental.end_at = body.start_at.replace(tzinfo=None), body.end_at.replace(tzinfo=None)
    # Older app versions don't send a rent amount: keep the current one, or use the cloth's price.
    if body.rent_amount is not None:
        rental.rent_amount = body.rent_amount
    elif not rental.rent_amount:
        rental.rent_amount = cloth.rent_price or 0
    if float(rental.advance_paid or 0) > float(rental.rent_amount or 0):
        raise HTTPException(422, "Paid amount can't be more than the rent amount")
    if rental.deposit_returned is not None and float(rental.deposit_returned) > float(rental.deposit_amount or 0):
        raise HTTPException(422, "The deposit already given back is more than the new deposit amount")


@router.post("/cloths/{cloth_id}/rentals", response_model=RentalOut)
def create_rental(cloth_id: int, body: RentalIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    cloth = _get_owned(db, user, cloth_id)
    rental = Rental(cloth_id=cloth.id)
    _apply_rental(rental, body, cloth)
    _check_overlap(db, cloth.id, rental.start_at, rental.end_at)
    db.add(rental)
    db.commit()
    return rental_out(_owned_rental(db, user, rental.id), datetime.now())


@router.put("/rentals/{rental_id}", response_model=RentalOut)
def update_rental(rental_id: int, body: RentalIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    rental = _owned_rental(db, user, rental_id)
    if rental.returned_at is None:
        _check_overlap(db, rental.cloth_id, body.start_at.replace(tzinfo=None), body.end_at.replace(tzinfo=None),
                       ignore_id=rental.id)
    _apply_rental(rental, body, rental.cloth)
    db.commit()
    return rental_out(rental, datetime.now())


def _settle_deposit(rental: Rental, returned: float, note: str | None) -> None:
    if returned > float(rental.deposit_amount or 0):
        raise HTTPException(422, f"Can't give back more than the deposit ({float(rental.deposit_amount or 0):.0f})")
    rental.deposit_returned = returned
    rental.deposit_note = (note or "").strip() or None


@router.post("/rentals/{rental_id}/return", response_model=RentalOut)
def mark_returned(
    rental_id: int,
    body: ReturnIn | None = Body(default=None),
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    """The cloth came back. Optionally records the rent balance and the deposit given back."""
    rental = _owned_rental(db, user, rental_id)
    body = body or ReturnIn()
    rental.returned_at = datetime.now().replace(microsecond=0)
    if body.collect_balance:
        rental.advance_paid = rental.rent_amount
    if body.deposit_returned is not None:
        _settle_deposit(rental, body.deposit_returned, body.deposit_note)
    db.commit()
    return rental_out(rental, datetime.now())


@router.post("/rentals/{rental_id}/deposit", response_model=RentalOut)
def settle_deposit(rental_id: int, body: DepositIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    """Give the deposit back later (full, or keep part of it for damage)."""
    rental = _owned_rental(db, user, rental_id)
    _settle_deposit(rental, body.deposit_returned, body.deposit_note)
    db.commit()
    return rental_out(rental, datetime.now())


@router.delete("/rentals/{rental_id}")
def delete_rental(rental_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    db.delete(_owned_rental(db, user, rental_id))
    db.commit()
    return {"ok": True}


@router.get("/rentals", response_model=list[RentalOut])
def list_rentals(
    start: datetime,
    end: datetime,
    cloth_id: int | None = None,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    """All rentals touching the [start, end] window — used by the calendar."""
    stmt = (
        select(Rental)
        .join(Cloth)
        .options(joinedload(Rental.cloth))
        .where(Cloth.owner_id == user.id, and_(Rental.start_at <= end, Rental.end_at >= start))
        .order_by(Rental.start_at)
    )
    if cloth_id:
        stmt = stmt.where(Rental.cloth_id == cloth_id)
    now = datetime.now()
    return [rental_out(r, now) for r in db.scalars(stmt).unique().all()]


@router.get("/dashboard", response_model=DashboardOut)
def dashboard(user: User = Depends(current_user), db: Session = Depends(get_db)):
    now = datetime.now()
    day_start = datetime.combine(now.date(), time.min)
    day_end = day_start + timedelta(days=1)

    cloths = db.scalars(select(Cloth).options(selectinload(Cloth.rentals)).where(Cloth.owner_id == user.id)).all()
    statuses = [cloth_out(c, now).status for c in cloths]

    active = db.scalars(
        select(Rental)
        .join(Cloth)
        .options(joinedload(Rental.cloth))
        .where(Cloth.owner_id == user.id, Rental.returned_at.is_(None))
        .order_by(Rental.start_at)
    ).unique().all()

    return DashboardOut(
        total_cloths=len(cloths),
        available=statuses.count("available"),
        on_rent=statuses.count("on_rent"),
        overdue=statuses.count("overdue"),
        going_out_today=[rental_out(r, now) for r in active if day_start <= r.start_at < day_end],
        returning_today=[rental_out(r, now) for r in active if day_start <= r.end_at < day_end],
        overdue_list=[rental_out(r, now) for r in active if r.end_at < now],
        waitlist_ready=[inquiry_out(i) for i in waitlist_ready(db, user, now)],
    )
