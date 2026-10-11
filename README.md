# Boutique Rentals — Rental Cloth Management

A mobile app (Android + iOS) for boutiques that rent out clothes.

- **Owner login** with username & password
- **Wardrobe**: every cloth has a **Cloth ID** (e.g. `LH001`), a photo, a description, size, category, price
- **Search by Cloth ID** (type it or **scan the QR tag**) → instantly see:
  - when it **went out on rent** (date + time) and who has it
  - when it **comes back** (date + time) with a live countdown ("Comes back in 1d 2h" / "Late by 5h")
  - a **colour calendar** of all its bookings
- **Book in advance** — the server blocks double-booking the same cloth
- **Today** screen: overdue items, pickups today, returns today
- **Calendar** tab: any day → what goes out, what comes back, what is with customers
- **Call / WhatsApp reminder** to the customer in one tap
- **QR tag** for each cloth — print it, stick it on the hanger, scan to find
- **Customer mode** (no login): a customer enters the Boutique code + Cloth ID and sees if the dress is free on their date (other customers' details are never shown)

```
rental_cloth_management/
├── backend/          ← Python FastAPI server (talks to MySQL)
│   ├── app/          ← the API code
│   ├── uploads/      ← cloth photos are saved here
│   ├── .env          ← YOUR settings (MySQL password) — edit this
│   └── run_server.bat← double-click to start the server
└── mobile/           ← Flutter app (Android + iOS)
    └── lib/          ← the app code
```

---

## How it works (big picture)

```
 [Phone app (Flutter)]  --Wi-Fi / internet-->  [FastAPI server on your PC]  -->  [MySQL database]
                                                    saves photos in backend/uploads
```

1. The **app** only shows screens. It never touches the database directly.
2. The **FastAPI server** checks the login, stores data in **MySQL**, and saves photos.
3. The phone and the PC must be able to reach each other (same Wi-Fi for testing).

The tables (`users`, `cloths`, `rentals`) and the database `rental_cloth_db` are **created automatically** the first time the server starts.

---

## Step 1 — Start the backend (API server)

Python 3.10 is installed and all Python packages are inside `backend\.venv` (only in this folder — nothing global).

**Database:** by default the app uses **SQLite** — a single file, `backend\database\rental_cloth.db`. There's no database server to install or start. To look at the data, open that file in **Beekeeper Studio** (New connection → SQLite → choose the file); you'll see the `users`, `cloths` and `rentals` tables. To use a MySQL server instead, set `DB_TYPE=mysql` plus the `DB_*` values in `backend\.env`.

1. Double-click `backend\run_server.bat`
   (or in a terminal: `cd backend` then `.venv\Scripts\uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload`)
2. It prints your PC's IP address — note it down (e.g. `192.168.1.5`). Keep that window open.
3. Open **http://localhost:8000/docs** in your browser. This is a test page where you can try every API:
   - `POST /auth/register` → *Try it out* → create an account
   - copy the `access_token`, click **Authorize** (top right) and paste it
   - now try `POST /cloths`, `GET /cloths/code/{cloth_code}`, etc.

> **Windows Firewall**: the first time, Windows may ask to allow Python on the network — click **Allow** (Private networks). Otherwise a real phone can't connect.

---

## Step 2 — Run the app

Flutter is already installed (`F:\UPI_App\flutter`). Flutter packages are kept **inside this project** in `rental_cloth_management\.pub-cache` (on this PC the default `C:\...\AppData\Local\Pub\Cache` folder is blocked). So before any `flutter` command in a new terminal (cmd), run this once in `mobile\`:

```bash
set PUB_CACHE=F:\rental_cloth_management\.pub-cache
```
```bash
flutter pub get
```
(`run_web.bat` does this for you.)

### Option A — Quickest: run in your browser (to try screens)
Double-click **`mobile\run_web.bat`**. It builds the app and opens **http://localhost:8080** in your default browser (Chrome, Edge or Chromium all work). Next time, to skip rebuilding: `run_web.bat skipbuild`.

(`flutter run -d chrome` also works but is very slow on this PC in debug mode.)

Server address in the app: `http://localhost:8000` (already the default on web). Camera/QR scan may not work in a desktop browser — use a phone for that.

### Option B — Android emulator
Start an emulator from Android Studio (Device Manager), then:
```bash
flutter run
```
Server address: `http://10.0.2.2:8000` (already the default on Android — `10.0.2.2` means "my PC" inside the emulator).

### Option C — Your real Android phone (best test)
1. Phone: *Settings → About phone →* tap **Build number** 7 times → *Developer options →* turn on **USB debugging**.
2. Connect with USB, allow the prompt on the phone, check it shows up: `flutter devices`
3. `flutter run`
4. In the app login screen tap the **⚙ gear** (top right) → enter `http://<your PC IP>:8000` (e.g. `http://192.168.1.5:8000`) → **Test & Save**.
   Phone and PC must be on the **same Wi-Fi**.

Or install the ready APK without a cable: build it with
```bash
flutter build apk --release
```
and copy `mobile\build\app\outputs\flutter-apk\app-release.apk` to the phone and open it (allow "install unknown apps").

### Option D — iPhone
Building for iOS **requires a Mac with Xcode** (Apple's rule — not possible on Windows). The iOS project is already set up (`mobile/ios`, camera/photo permissions included). On a Mac: `cd mobile && flutter pub get && cd ios && pod install && cd .. && flutter run`.

---

## Step 3 — Test checklist (do these in order)

| # | Do this | You should see |
|---|---------|----------------|
| 1 | Login screen → **New boutique? Create account** | lands on **Today** screen |
| 2 | **Wardrobe → Add cloth**, photo, ID `LH001`, name, price | card appears with green **Available** |
| 3 | Try adding `lh001` again | error "already exists" (IDs are unique, case-insensitive) |
| 4 | Open LH001 → **Give on rent / Book** → out = now, return = +2 days | orange **On Rent**, "Comes back in 2d" |
| 5 | Book LH001 again overlapping those dates | red error "Already booked by … from … to …" |
| 6 | Book LH001 for next week | shows under **Upcoming bookings**, blue on calendar |
| 7 | **Today** → type `LH001` in the big search box → Enter | opens the cloth with out/return date & time |
| 8 | Open LH001 → **QR icon** → scan it from another phone's app (Today → scan button) | opens the cloth |
| 9 | Create a rental with a return time in the past | appears under **Overdue** in red; WhatsApp reminder button |
| 10 | Tap **Mark returned** | cloth goes back to **Available**, rental moves to **History** |
| 11 | **Calendar** tab → tap a day | lists what goes out / comes back that day |
| 12 | Profile → note your **Boutique code** → logout → **I'm a customer** → enter code + `LH001` | photo, price, "free from …", red booked days; no customer names |

---

## Phone compatibility

| | Minimum | Covers |
|---|---|---|
| Android | **7.0 (API 24)** | ~98% of Android phones in use |
| iOS | **15.0** | iPhone 6s and newer |

This is the lowest that current Flutter supports — older phones can't run any modern Flutter app. The layout adapts to small & large screens and tablets, and font size is kept readable even if the user has large text turned on.

---

## Going live (later, for real customers)

For testing, the server runs on your PC. For daily use from anywhere you'd:
1. Put the `backend` folder on a cloud server (any VPS with Python + MySQL), run it behind **HTTPS** (e.g. Nginx + Let's Encrypt).
2. Change `JWT_SECRET` in `.env` to a new random value, use a non-root MySQL user.
3. In the app, set the server address to `https://your-domain.com`.
4. Publish: Android → Google Play Console; iOS → App Store Connect (needs Mac + Apple developer account).

---

## API reference (short)

| Method | Path | What |
|---|---|---|
| POST | `/auth/register`, `/auth/login` | get a login token |
| GET | `/cloths?q=&status=` | list / search cloths |
| GET | `/cloths/code/{ID}` | find cloth by Cloth ID (with all rentals) |
| POST/PUT/DELETE | `/cloths`, `/cloths/{id}` | add (with photo) / edit / delete |
| POST | `/cloths/{id}/rentals` | give on rent / book (overlap is blocked) |
| PUT/DELETE | `/rentals/{id}` | change / cancel |
| POST | `/rentals/{id}/return` | mark returned |
| GET | `/rentals?start=&end=` | for the calendar |
| GET | `/dashboard` | today's summary |
| GET | `/public/{boutique_code}/cloths/{ID}` | customer availability (no login) |

Full interactive docs: **http://localhost:8000/docs**
