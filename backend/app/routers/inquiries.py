"""Inquiries = the waitlist: people who want a cloth, contacted when it frees up."""

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload, selectinload

from ..database import get_db
from ..models import ACTIVE_INQUIRY_STATUSES, Cloth, Inquiry, User
from ..schemas import InquiryIn, InquiryOut, InquiryStatusIn
from ..security import current_user
from ..serializers import inquiry_out
from .cloths import _get_owned

router = APIRouter(tags=["Inquiries (waitlist)"])


def _naive(d: datetime | None) -> datetime | None:
    return d.replace(tzinfo=None) if d else None


def apply_inquiry(inq: Inquiry, body: InquiryIn) -> None:
    for k, v in body.model_dump(exclude={"wanted_from", "wanted_to"}).items():
        setattr(inq, k, v)
    inq.wanted_from, inq.wanted_to = _naive(body.wanted_from), _naive(body.wanted_to)


def _best_first(items: list[Inquiry]) -> list[Inquiry]:
    """Open inquiries first, highest offer first, then oldest first."""
    return sorted(
        items,
        key=lambda i: (i.status not in ACTIVE_INQUIRY_STATUSES, -float(i.offered_amount or 0), i.created_at or datetime.min),
    )


def _owned_inquiry(db: Session, user: User, inquiry_id: int) -> Inquiry:
    inq = db.scalar(
        select(Inquiry).join(Cloth).options(joinedload(Inquiry.cloth)).where(Inquiry.id == inquiry_id, Cloth.owner_id == user.id)
    )
    if inq is None:
        raise HTTPException(404, "Inquiry not found")
    return inq


def _is_free(cloth: Cloth, start: datetime, end: datetime, now: datetime) -> bool:
    """No rental blocks start..end. An overdue cloth counts as still out until today."""
    for r in cloth.rentals:
        if r.returned_at is not None:
            continue
        busy_until = max(r.end_at, now)
        if r.start_at < end and busy_until > start:
            return False
    return True


def waitlist_ready(db: Session, user: User, now: datetime) -> list[Inquiry]:
    """Open inquiries whose cloth is free for the dates they want (or free right now if no dates)."""
    rows = db.scalars(
        select(Inquiry)
        .join(Cloth)
        .options(joinedload(Inquiry.cloth).selectinload(Cloth.rentals))
        .where(Cloth.owner_id == user.id, Inquiry.status.in_(ACTIVE_INQUIRY_STATUSES))
    ).unique().all()
    ready = []
    for i in rows:
        if i.wanted_from and i.wanted_to:
            if i.wanted_to < now:
                continue  # their dates have passed
            if _is_free(i.cloth, i.wanted_from, i.wanted_to, now):
                ready.append(i)
        elif not any(r.returned_at is None and r.start_at <= now for r in i.cloth.rentals):
            ready.append(i)  # no dates given: ready when the cloth is in the boutique now
    return _best_first(ready)


@router.get("/cloths/{cloth_id}/inquiries", response_model=list[InquiryOut])
def list_inquiries(cloth_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    cloth = _get_owned(db, user, cloth_id)
    items = db.scalars(select(Inquiry).options(joinedload(Inquiry.cloth)).where(Inquiry.cloth_id == cloth.id)).all()
    return [inquiry_out(i) for i in _best_first(list(items))]


@router.post("/cloths/{cloth_id}/inquiries", response_model=InquiryOut)
def create_inquiry(cloth_id: int, body: InquiryIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    cloth = _get_owned(db, user, cloth_id)
    inq = Inquiry(cloth_id=cloth.id, source="owner", status="waiting")
    apply_inquiry(inq, body)
    db.add(inq)
    db.commit()
    return inquiry_out(_owned_inquiry(db, user, inq.id))


@router.put("/inquiries/{inquiry_id}", response_model=InquiryOut)
def update_inquiry(inquiry_id: int, body: InquiryIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    inq = _owned_inquiry(db, user, inquiry_id)
    apply_inquiry(inq, body)
    db.commit()
    return inquiry_out(inq)


@router.patch("/inquiries/{inquiry_id}/status", response_model=InquiryOut)
def set_status(inquiry_id: int, body: InquiryStatusIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    inq = _owned_inquiry(db, user, inquiry_id)
    inq.status = body.status
    db.commit()
    return inquiry_out(inq)


@router.delete("/inquiries/{inquiry_id}")
def delete_inquiry(inquiry_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    db.delete(_owned_inquiry(db, user, inquiry_id))
    db.commit()
    return {"ok": True}


@router.get("/inquiries/matching", response_model=list[InquiryOut])
def matching(
    cloth_id: int,
    start: datetime,
    end: datetime,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    """Who to call when cloth_id becomes free for start..end (after a cancellation or early return)."""
    cloth = _get_owned(db, user, cloth_id)  # loads its rentals
    start, end = _naive(start), _naive(end)
    now = datetime.now()
    items = db.scalars(
        select(Inquiry)
        .options(joinedload(Inquiry.cloth))
        .where(Inquiry.cloth_id == cloth.id, Inquiry.status.in_(ACTIVE_INQUIRY_STATUSES))
    ).all()
    # Skip people whose dates got booked meanwhile (e.g. by someone else on this list).
    fits = [i for i in items if i.wants(start, end) and (not i.wanted_from or _is_free(cloth, i.wanted_from, i.wanted_to, now))]
    return [inquiry_out(i) for i in _best_first(fits)]


@router.get("/inquiries/ready", response_model=list[InquiryOut])
def ready(user: User = Depends(current_user), db: Session = Depends(get_db)):
    return [inquiry_out(i) for i in waitlist_ready(db, user, datetime.now())]
