"""Customer-facing endpoints: no login, and no other customers' personal details are shown."""

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from ..database import get_db
from ..models import Cloth, User
from ..schemas import BusyRange, PublicClothOut
from ..serializers import image_url

router = APIRouter(prefix="/public", tags=["Customer (no login)"])


@router.get("/{boutique}/cloths/{cloth_code}", response_model=PublicClothOut)
def check_availability(boutique: str, cloth_code: str, db: Session = Depends(get_db)):
    owner = db.scalar(select(User).where(User.username == boutique.lower().strip()))
    if owner is None:
        raise HTTPException(404, "Boutique not found")
    cloth = db.scalar(
        select(Cloth)
        .options(selectinload(Cloth.rentals))
        .where(Cloth.owner_id == owner.id, Cloth.cloth_code == cloth_code.strip().upper())
    )
    if cloth is None:
        raise HTTPException(404, f"No cloth with ID '{cloth_code}'")

    now = datetime.now()
    # Every rental not yet returned blocks the cloth (upcoming, current or overdue).
    busy = sorted((r for r in cloth.rentals if r.returned_at is None), key=lambda r: r.start_at)
    return PublicClothOut(
        boutique_name=owner.boutique_name,
        cloth_code=cloth.cloth_code,
        name=cloth.name,
        description=cloth.description or "",
        category=cloth.category,
        size=cloth.size,
        rent_price=float(cloth.rent_price or 0),
        image_url=image_url(cloth),
        available_now=not any(r.start_at <= now for r in busy),
        busy=[BusyRange(start_at=r.start_at, end_at=r.end_at) for r in busy],
    )
