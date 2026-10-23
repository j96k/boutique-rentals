from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, Response
from fastapi.staticfiles import StaticFiles
from sqlalchemy.orm import Session

from . import models  # noqa: F401  (registers tables)
from .config import BASE_DIR, settings
from .database import Base, engine, get_db, upgrade_schema
from .models import StoredImage
from .routers import auth, cloths, customers, earnings, inquiries, invoice, public, rentals

Base.metadata.create_all(bind=engine)  # creates tables on first run
upgrade_schema()  # adds columns introduced later (keeps existing data)
settings.upload_dir.mkdir(parents=True, exist_ok=True)

app = FastAPI(title="Rental Cloth Management API", version="1.0.0")

app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

app.include_router(auth.router)
app.include_router(cloths.router)
app.include_router(rentals.router)
app.include_router(inquiries.router)
app.include_router(earnings.router)
app.include_router(customers.router)
app.include_router(public.router)
app.include_router(invoice.router)


@app.get("/uploads/{name}", tags=["Photos"])
def get_photo(name: str, db: Session = Depends(get_db)):
    """A cloth photo: from backend/uploads/ on disk, or from the database when it's online."""
    if "/" in name or "\\" in name or name.startswith("."):
        raise HTTPException(404)
    path = settings.upload_dir / name
    if path.is_file():
        return FileResponse(path)
    stored = db.get(StoredImage, name)
    if stored is None:
        raise HTTPException(404, "Photo not found")
    # Photo names are random and never reused, so phones may cache them for long.
    return Response(stored.data, media_type=stored.content_type, headers={"Cache-Control": "public, max-age=31536000"})


# The browser version of the app, served at /app/ so one address works for the app and the API.
# backend/webapp/ is the copy used by online hosting (see deploy/prepare_online.bat);
# mobile/build/web/ is where mobile/run_web.bat builds it on this PC.
for web_dir in (BASE_DIR / "webapp", BASE_DIR.parent / "mobile" / "build" / "web"):
    if (web_dir / "index.html").exists():
        app.mount("/app", StaticFiles(directory=web_dir, html=True), name="web")
        break


@app.get("/", tags=["Health"])
def health():
    return {"status": "ok", "message": "Rental Cloth API is running. Open /docs to try it."}
