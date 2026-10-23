"""Public, printable invoice page for one booking. Opened from the link sent on WhatsApp / Gmail.
Only someone with the secret link can see it (the token is random and unguessable)."""

from datetime import datetime
from html import escape

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import HTMLResponse
from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from ..database import get_db
from ..models import Cloth, Rental

router = APIRouter(tags=["Invoice (customer link)"])


def _money(v: float) -> str:
    """₹1,23,456 (Indian grouping)."""
    n = int(round(v or 0))
    s = str(abs(n))
    if len(s) > 3:
        head, tail = s[:-3], s[-3:]
        groups = []
        while len(head) > 2:
            groups.insert(0, head[-2:])
            head = head[:-2]
        if head:
            groups.insert(0, head)
        s = ",".join(groups) + "," + tail
    return ("-" if n < 0 else "") + "₹" + s


def _dt(d: datetime | None) -> str:
    return d.strftime("%a, %d %b %Y · %I:%M %p") if d else "—"


@router.get("/invoice/{token}", response_class=HTMLResponse)
def invoice_page(token: str, db: Session = Depends(get_db)):
    r = db.scalar(
        select(Rental).options(joinedload(Rental.cloth).joinedload(Cloth.owner)).where(Rental.invoice_token == token)
    )
    if r is None or len(token) < 16:
        raise HTTPException(404, "Invoice not found")
    shop = r.cloth.owner
    rent, paid = float(r.rent_amount or 0), float(r.advance_paid or 0)
    deposit = float(r.deposit_amount or 0)

    if r.returned_at:
        status = f"Returned on {_dt(r.returned_at)}"
    elif datetime.now() < r.start_at:
        status = "Booked"
    elif datetime.now() > r.end_at:
        status = "Not returned yet (overdue)"
    else:
        status = "With customer"

    if not deposit:
        dep_rows = ""
    elif r.deposit_returned is None:
        dep_rows = f"<tr><td>Security deposit (refundable)</td><td>{_money(deposit)}</td></tr>" \
                   "<tr><td colspan=2 class=note>Deposit will be returned when the outfit comes back.</td></tr>"
    else:
        kept = r.deposit_kept
        dep_rows = (
            f"<tr><td>Security deposit taken</td><td>{_money(deposit)}</td></tr>"
            f"<tr><td>Deposit returned{' on ' + escape(_dt(r.deposit_settled_at)) if r.deposit_settled_at else ''}</td>"
            f"<td>{_money(float(r.deposit_returned))}</td></tr>"
        )
        if kept:
            reason = f" ({escape(r.deposit_note)})" if r.deposit_note else ""
            dep_rows += f"<tr><td>Deposit kept{reason}</td><td>{_money(kept)}</td></tr>"

    contact = " · ".join(escape(x) for x in [shop.phone] if x)
    html = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Invoice INV-{r.id:05d} · {escape(shop.boutique_name)}</title>
<style>
  :root {{ --plum:#3D1F4E; --gold:#C9A45C; --ink:#1F1724; --muted:#7C7083; --line:#E9E1EC; --bg:#FBF7F2; }}
  * {{ box-sizing:border-box; }}
  body {{ margin:0; background:var(--bg); color:var(--ink); font:15px/1.5 system-ui,-apple-system,Segoe UI,Roboto,sans-serif; }}
  .page {{ max-width:640px; margin:24px auto; background:#fff; border:1px solid var(--line); border-radius:18px; overflow:hidden; }}
  header {{ background:var(--plum); color:#fff; padding:22px 24px; }}
  header h1 {{ margin:0; font-size:22px; }} header p {{ margin:2px 0 0; color:#F3E6C8; font-size:13px; }}
  .meta {{ display:flex; justify-content:space-between; gap:12px; flex-wrap:wrap; padding:18px 24px 0; color:var(--muted); font-size:13px; }}
  .meta b {{ color:var(--ink); }}
  section {{ padding:16px 24px; }}
  h2 {{ font-size:12px; letter-spacing:1.4px; text-transform:uppercase; color:var(--muted); margin:0 0 8px; }}
  table {{ width:100%; border-collapse:collapse; }}
  td {{ padding:8px 0; border-bottom:1px solid var(--line); vertical-align:top; }}
  td:last-child {{ text-align:right; white-space:nowrap; font-weight:600; }}
  tr.total td {{ border-bottom:none; font-size:17px; font-weight:800; }}
  .note {{ color:var(--muted); font-size:13px; text-align:left !important; font-weight:400 !important; }}
  .status {{ display:inline-block; background:#F3E6C8; color:var(--plum); border-radius:20px; padding:3px 10px; font-weight:700; font-size:13px; }}
  footer {{ padding:16px 24px 22px; color:var(--muted); font-size:13px; border-top:1px solid var(--line); }}
  button {{ background:var(--plum); color:#fff; border:0; border-radius:12px; padding:12px 18px; font-size:15px; font-weight:700; cursor:pointer; }}
  @media print {{ body {{ background:#fff; }} .page {{ margin:0; border:0; }} .noprint {{ display:none; }} }}
  @media (max-width:520px) {{ .page {{ margin:0; border-radius:0; border:0; }} }}
</style></head><body>
<div class="page">
  <header><h1>{escape(shop.boutique_name)}</h1><p>Rental invoice{(' · ' + contact) if contact else ''}</p></header>
  <div class="meta">
    <div>Invoice <b>INV-{r.id:05d}</b><br>Date <b>{datetime.now().strftime('%d %b %Y')}</b></div>
    <div style="text-align:right">Customer <b>{escape(r.customer_name)}</b>{('<br>' + escape(r.customer_phone)) if r.customer_phone else ''}</div>
  </div>
  <section>
    <h2>Outfit</h2>
    <table>
      <tr><td><b>{escape(r.cloth.cloth_code)}</b> · {escape(r.cloth.name)}</td><td></td></tr>
      <tr><td>Rent out</td><td>{_dt(r.start_at)}</td></tr>
      <tr><td>Return by</td><td>{_dt(r.end_at)}</td></tr>
      <tr><td>Status</td><td><span class="status">{escape(status)}</span></td></tr>
    </table>
  </section>
  <section>
    <h2>Payment</h2>
    <table>
      <tr><td>Rent</td><td>{_money(rent)}</td></tr>
      <tr><td>Paid</td><td>{_money(paid)}</td></tr>
      <tr class="total"><td>Balance due</td><td>{_money(max(rent - paid, 0))}</td></tr>
    </table>
  </section>
  {f'<section><h2>Security deposit</h2><table>{dep_rows}</table></section>' if dep_rows else ''}
  <footer>
    Thank you for choosing {escape(shop.boutique_name)}! We hope you loved our service.
    <p class="noprint" style="margin-top:14px"><button onclick="window.print()">Print / Save as PDF</button></p>
  </footer>
</div>
</body></html>"""
    return HTMLResponse(html)
