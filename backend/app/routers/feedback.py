"""Ideas & requests from boutiques (any language), plus the admin view for the app maker,
and the public app config (donation details)."""

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from ..config import settings
from ..database import get_db
from ..models import Feedback, User
from ..schemas import AppConfigOut, DonateOut, FeedbackIn, FeedbackOut, FeedbackUpdateIn
from ..security import current_user

router = APIRouter(tags=["Ideas & requests"])


def _out(f: Feedback, admin: bool = False) -> FeedbackOut:
    out = FeedbackOut(
        id=f.id, category=f.category, message=f.message, contact=f.contact, status=f.status,
        admin_reply=f.admin_reply, created_at=f.created_at, updated_at=f.updated_at,
    )
    if admin:
        out.username, out.boutique_name, out.boutique_phone = f.user.username, f.user.boutique_name, f.user.phone
    return out


def admin_user(user: User = Depends(current_user)) -> User:
    if not user.is_admin:
        raise HTTPException(403, "Only the app admin can see this")
    return user


@router.get("/app-config", response_model=AppConfigOut, tags=["Health"])
def app_config():
    """Public: what the donation pop-up shows (set in the server's .env / Render environment)."""
    return AppConfigOut(
        donate=DonateOut(
            upi_id=settings.donate_upi_id.strip() or None,
            name=settings.donate_name,
            url=settings.donate_url.strip() or None,
        )
    )


@router.post("/feedback", response_model=FeedbackOut)
def send_feedback(body: FeedbackIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    f = Feedback(user_id=user.id, category=body.category, message=body.message.strip(),
                 contact=(body.contact or "").strip() or None, status="new")
    db.add(f)
    db.commit()
    return _out(f)


@router.get("/feedback/mine", response_model=list[FeedbackOut])
def my_feedback(user: User = Depends(current_user), db: Session = Depends(get_db)):
    rows = db.scalars(select(Feedback).where(Feedback.user_id == user.id).order_by(Feedback.id.desc())).all()
    return [_out(f) for f in rows]


@router.get("/admin/feedback", response_model=list[FeedbackOut])
def all_feedback(status: str | None = None, _: User = Depends(admin_user), db: Session = Depends(get_db)):
    stmt = select(Feedback).options(joinedload(Feedback.user)).order_by(Feedback.id.desc())
    if status:
        stmt = stmt.where(Feedback.status == status)
    return [_out(f, admin=True) for f in db.scalars(stmt).all()]


@router.patch("/admin/feedback/{feedback_id}", response_model=FeedbackOut)
def update_feedback(feedback_id: int, body: FeedbackUpdateIn, _: User = Depends(admin_user), db: Session = Depends(get_db)):
    f = db.scalar(select(Feedback).options(joinedload(Feedback.user)).where(Feedback.id == feedback_id))
    if f is None:
        raise HTTPException(404, "Request not found")
    f.status = body.status
    f.admin_reply = (body.admin_reply or "").strip() or None
    f.updated_at = datetime.now().replace(microsecond=0)
    db.commit()
    return _out(f, admin=True)
