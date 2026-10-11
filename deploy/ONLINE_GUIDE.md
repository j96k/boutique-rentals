# Put Boutique Rentals online for free (Neon + Render) — no card, PC can be off

```
 Phones (APK / browser) ──https──▶ Render (free web service, Singapore)
                                    └─ FastAPI app + browser app at /app/
                                         │
                                         ▼
                                    Neon (free PostgreSQL)
                                    └─ users, cloths, rentals, photos
```

| Free plan limit | What it means for you |
|---|---|
| Render sleeps after 15 min with no visitors | The next visitor waits 30–60 s while it wakes up, then it's fast |
| Neon: 0.5 GB storage | Thousands of rentals and a few thousand cloth photos |
| Render: 750 free hours / month | Enough for one service running all month |

Your PC setup (SQLite, `run_server.bat`) keeps working separately — it has its own data.

---

## Step 1 — Online database (Neon)
1. Go to https://neon.tech → **Sign up** (with Google or GitHub — no card needed).
2. Create a project: name `boutique-rentals`, Postgres version: default,
   region: **AWS Asia Pacific (Singapore)** (same region as Render = faster).
3. On the project dashboard click **Connect**. Copy the **connection string**; it looks like
   `postgresql://neondb_owner:xxxx@ep-xxxx.ap-southeast-1.aws.neon.tech/neondb?sslmode=require`
4. Keep it secret (it contains the database password). You'll paste it into Render in step 3.

The tables are created automatically the first time the server starts.

## Step 2 — Code on GitHub (private repository)
Render takes the code from GitHub. Only the clean **`live`** folder is uploaded — it has no
passwords, databases, photos, keys or SDKs (`deploy\make_live.bat` creates/refreshes it).

1. On https://github.com → **New repository** → name e.g. `boutique-rentals` → **Private** →
   don't add a README → **Create repository**.
2. In **cmd** (replace `YOUR-NAME` with your GitHub username):
   ```
   cd /d F:\rental_cloth_management\live
   git init -b main
   git add .
   git commit -m "Boutique Rentals"
   git remote add origin https://github.com/YOUR-NAME/boutique-rentals.git
   git push -u origin main
   ```
   The first push opens a browser window to log in to GitHub.

**Later updates:** run `deploy\prepare_online.bat` (if app screens changed) → `deploy\make_live.bat`
→ in `live\`: `git add .` → `git commit -m "update"` → `git push`.

## Step 3 — Run it on Render
1. Go to https://render.com → **Get Started** → sign up **with GitHub** (no card for the free plan).
2. **New → Blueprint** → choose your repository → Render finds `render.yaml`.
3. It asks for **DATABASE_URL** → paste the Neon connection string from step 1 → **Apply**.
4. Wait 3–5 minutes for the first build. When it says **Live**, your address is shown at the top,
   e.g. `https://boutique-rentals.onrender.com` (Render may add letters if the name is taken).

## Step 4 — Test
- Health check: `https://boutique-rentals.onrender.com/` → `{"status":"ok",...}`
- **Browser app (any phone, anywhere):** `https://boutique-rentals.onrender.com/app/`
- **API test page:** `https://boutique-rentals.onrender.com/docs`
- **Android APK:** ⚙ on the login screen → `https://boutique-rentals.onrender.com` → Test & Save.
  If it says it can't reach the server, open the browser link first to wake the server, then retry.
- Create a new boutique account (the online database starts empty), add a cloth with a photo,
  rent it out, then restart the service in Render (Manual Deploy → Restart) and check the
  photo and rental are still there.

## Updating later
1. Changed app screens? Run `deploy\prepare_online.bat` (needs Flutter installed).
2. Commit and `git push`. Render rebuilds and redeploys automatically (2–4 minutes).

## Seeing your online data
- **Neon website** → your project → **Tables** (browse/edit rows), or
- **Beekeeper Studio** → New connection → **PostgreSQL** → paste the Neon connection string
  (enable SSL).
