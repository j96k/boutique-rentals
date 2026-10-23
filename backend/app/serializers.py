"""Convert database rows into API response objects."""

from datetime import datetime

from .models import Cloth, Inquiry, Rental
from .schemas import ClothDetailOut, ClothOut, InquiryOut, RentalOut


_CONTENT_TYPES = {".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".png": "image/png", ".webp": "image/webp", ".heic": "image/heic"}


def image_content_type(name: str) -> str:
    return _CONTENT_TYPES.get("." + name.rsplit(".", 1)[-1].lower(), "application/octet-stream")


def image_url(cloth: Cloth) -> str | None:
    # Relative URL; the app prefixes it with the server address.
    return f"/uploads/{cloth.image_path}" if cloth.image_path else None


def rental_out(r: Rental, now: datetime) -> RentalOut:
    return RentalOut(
        id=r.id,
        cloth_id=r.cloth_id,
        cloth_code=r.cloth.cloth_code,
        cloth_name=r.cloth.name,
        cloth_image=image_url(r.cloth),
        customer_name=r.customer_name,
        customer_phone=r.customer_phone,
        customer_email=r.customer_email,
        customer_instagram=r.customer_instagram,
        start_at=r.start_at,
        end_at=r.end_at,
        returned_at=r.returned_at,
        rent_amount=float(r.rent_amount or 0),
        advance_paid=float(r.advance_paid or 0),
        balance_due=r.balance_due,
        deposit_amount=float(r.deposit_amount or 0),
        deposit_returned=None if r.deposit_returned is None else float(r.deposit_returned),
        deposit_kept=r.deposit_kept,
        deposit_status=r.deposit_status,
        deposit_note=r.deposit_note,
        deposit_settled_at=r.deposit_settled_at,
        notes=r.notes,
        status=r.status(now),
    )


def cloth_out(c: Cloth, now: datetime, detail: bool = False) -> ClothOut:
    active = [r for r in c.rentals if r.returned_at is None]
    current = next((r for r in active if r.start_at <= now), None)
    upcoming = sorted((r for r in active if r.start_at > now), key=lambda r: r.start_at)
    status = current.status(now) if current else "available"

    data = dict(
        id=c.id,
        cloth_code=c.cloth_code,
        name=c.name,
        description=c.description or "",
        category=c.category,
        size=c.size,
        rent_price=float(c.rent_price or 0),
        image_url=image_url(c),
        status=status,
        current_rental=rental_out(current, now) if current else None,
        next_booking=rental_out(upcoming[0], now) if upcoming else None,
    )
    if detail:
        return ClothDetailOut(**data, rentals=[rental_out(r, now) for r in c.rentals])
    return ClothOut(**data)


def inquiry_out(i: Inquiry) -> InquiryOut:
    return InquiryOut(
        id=i.id,
        cloth_id=i.cloth_id,
        cloth_code=i.cloth.cloth_code,
        cloth_name=i.cloth.name,
        cloth_image=image_url(i.cloth),
        name=i.name,
        phone=i.phone,
        email=i.email,
        instagram=i.instagram,
        offered_amount=float(i.offered_amount or 0),
        wanted_from=i.wanted_from,
        wanted_to=i.wanted_to,
        notes=i.notes,
        status=i.status,
        source=i.source,
        created_at=i.created_at,
    )
