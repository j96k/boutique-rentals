from datetime import datetime, time, timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import and_, select
from sqlalchemy.orm import Session, joinedload, selectinload

from ..database import get_db
from ..models import Cloth, Rental, User
from ..schemas import DashboardOut, RentalIn, RentalOut
from ..security import current_user
from ..serializers import cloth_out, rental_out
from .cloths import _get_owned

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


@router.post("/cloths/{cloth_id}/rentals", response_model=RentalOut)
def create_rental(cloth_id: int, body: RentalIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    cloth = _get_owned(db, user, cloth_id)
    start, end = body.start_at.replace(tzinfo=None), body.end_at.replace(tzinfo=None)
    _check_overlap(db, cloth.id, start, end)
    rental = Rental(cloth_id=cloth.id, **body.model_dump(exclude={"start_at", "end_at"}), start_at=start, end_at=end)
    db.add(rental)
    db.commit()
    return rental_out(_owned_rental(db, user, rental.id), datetime.now())


@router.put("/rentals/{rental_id}", response_model=RentalOut)
def update_rental(rental_id: int, body: RentalIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    rental = _owned_rental(db, user, rental_id)
    start, end = body.start_at.replace(tzinfo=None), body.end_at.replace(tzinfo=None)
    if rental.returned_at is None:
        _check_overlap(db, rental.cloth_id, start, end, ignore_id=rental.id)
    for k, v in body.model_dump(exclude={"start_at", "end_at"}).items():
        setattr(rental, k, v)
    rental.start_at, rental.end_at = start, end
    db.commit()
    return rental_out(rental, datetime.now())


@router.post("/rentals/{rental_id}/return", response_model=RentalOut)
def mark_returned(rental_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    rental = _owned_rental(db, user, rental_id)
    rental.returned_at = datetime.now().replace(microsecond=0)
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
    )
