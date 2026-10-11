import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from sqlalchemy import or_, select
from sqlalchemy.orm import Session, selectinload

from ..config import settings
from ..database import get_db
from ..models import Cloth, StoredImage, User
from ..schemas import ClothDetailOut, ClothOut
from ..security import current_user
from ..serializers import cloth_out, image_content_type

router = APIRouter(prefix="/cloths", tags=["Cloths"])

ALLOWED_EXT = {".jpg", ".jpeg", ".png", ".webp", ".heic"}
MAX_IMAGE_BYTES = 10 * 1024 * 1024


def _get_owned(db: Session, user: User, cloth_id: int) -> Cloth:
    cloth = db.scalar(
        select(Cloth)
        .options(selectinload(Cloth.rentals))
        .where(Cloth.id == cloth_id, Cloth.owner_id == user.id)
    )
    if cloth is None:
        raise HTTPException(404, "Cloth not found")
    return cloth


async def _save_image(image: UploadFile, db: Session) -> str:
    ext = ("." + image.filename.rsplit(".", 1)[-1].lower()) if image.filename and "." in image.filename else ".jpg"
    if ext not in ALLOWED_EXT:
        raise HTTPException(400, "Only JPG, PNG, WEBP or HEIC images are allowed")
    data = await image.read()
    if len(data) > MAX_IMAGE_BYTES:
        raise HTTPException(400, "Image is too large (max 10 MB)")
    name = f"{uuid.uuid4().hex}{ext}"
    if settings.images_in_db:
        db.add(StoredImage(name=name, content_type=image_content_type(name), data=data))
    else:
        settings.upload_dir.mkdir(parents=True, exist_ok=True)
        (settings.upload_dir / name).write_bytes(data)
    return name


def _delete_image(name: str | None, db: Session) -> None:
    """Removes the photo; the caller commits."""
    if not name:
        return
    (settings.upload_dir / name).unlink(missing_ok=True)
    stored = db.get(StoredImage, name)
    if stored is not None:
        db.delete(stored)


@router.get("", response_model=list[ClothOut])
def list_cloths(
    q: str | None = None,
    status: str | None = None,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    """List all cloths. `q` searches cloth ID, name, category and description."""
    stmt = select(Cloth).options(selectinload(Cloth.rentals)).where(Cloth.owner_id == user.id)
    if q:
        like = f"%{q.strip()}%"
        stmt = stmt.where(
            or_(Cloth.cloth_code.ilike(like), Cloth.name.ilike(like), Cloth.category.ilike(like), Cloth.description.ilike(like))
        )
    now = datetime.now()
    items = [cloth_out(c, now) for c in db.scalars(stmt.order_by(Cloth.cloth_code)).all()]
    if status:
        items = [c for c in items if c.status == status]
    return items


@router.get("/code/{cloth_code}", response_model=ClothDetailOut)
def get_by_code(cloth_code: str, user: User = Depends(current_user), db: Session = Depends(get_db)):
    """Search by exact Cloth ID (what is written on the tag / QR code)."""
    cloth = db.scalar(
        select(Cloth)
        .options(selectinload(Cloth.rentals))
        .where(Cloth.owner_id == user.id, Cloth.cloth_code == cloth_code.strip().upper())
    )
    if cloth is None:
        raise HTTPException(404, f"No cloth with ID '{cloth_code}'")
    return cloth_out(cloth, datetime.now(), detail=True)


@router.get("/{cloth_id}", response_model=ClothDetailOut)
def get_cloth(cloth_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    return cloth_out(_get_owned(db, user, cloth_id), datetime.now(), detail=True)


@router.post("", response_model=ClothDetailOut)
async def create_cloth(
    cloth_code: str = Form(...),
    name: str = Form(...),
    description: str = Form(""),
    category: str | None = Form(None),
    size: str | None = Form(None),
    rent_price: float = Form(0),
    image: UploadFile | None = File(None),
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    code = cloth_code.strip().upper()
    if not code:
        raise HTTPException(400, "Cloth ID is required")
    if db.scalar(select(Cloth).where(Cloth.owner_id == user.id, Cloth.cloth_code == code)):
        raise HTTPException(400, f"Cloth ID '{code}' already exists")
    cloth = Cloth(
        owner_id=user.id,
        cloth_code=code,
        name=name.strip(),
        description=description.strip(),
        category=(category or "").strip() or None,
        size=(size or "").strip() or None,
        rent_price=rent_price,
    )
    if image is not None and image.filename:
        cloth.image_path = await _save_image(image, db)
    db.add(cloth)
    db.commit()
    return cloth_out(_get_owned(db, user, cloth.id), datetime.now(), detail=True)


@router.put("/{cloth_id}", response_model=ClothDetailOut)
async def update_cloth(
    cloth_id: int,
    cloth_code: str = Form(...),
    name: str = Form(...),
    description: str = Form(""),
    category: str | None = Form(None),
    size: str | None = Form(None),
    rent_price: float = Form(0),
    image: UploadFile | None = File(None),
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    cloth = _get_owned(db, user, cloth_id)
    code = cloth_code.strip().upper()
    clash = db.scalar(select(Cloth).where(Cloth.owner_id == user.id, Cloth.cloth_code == code, Cloth.id != cloth_id))
    if clash:
        raise HTTPException(400, f"Cloth ID '{code}' already exists")
    cloth.cloth_code = code
    cloth.name = name.strip()
    cloth.description = description.strip()
    cloth.category = (category or "").strip() or None
    cloth.size = (size or "").strip() or None
    cloth.rent_price = rent_price
    if image is not None and image.filename:
        old = cloth.image_path
        cloth.image_path = await _save_image(image, db)
        _delete_image(old, db)
    db.commit()
    return cloth_out(_get_owned(db, user, cloth.id), datetime.now(), detail=True)


@router.delete("/{cloth_id}")
def delete_cloth(cloth_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    cloth = _get_owned(db, user, cloth_id)
    image = cloth.image_path
    db.delete(cloth)
    _delete_image(image, db)
    db.commit()
    return {"ok": True}
