# Put Boutique Rentals on AWS (student / low-cost setup)

**What you'll build:** one small EC2 server that runs everything — the FastAPI backend, the SQLite
database file, the cloth photos and the browser app — with free automatic https.

```
 Phones (APK / browser) ──https──▶ EC2 t3.micro (Ubuntu, Mumbai)
                                    ├─ Caddy  (https, port 443)  → forwards to ↓
                                    └─ FastAPI app (port 8000, internal only)
                                        ├─ backend/database/rental_cloth.db  (SQLite)
                                        └─ backend/uploads/                  (photos)
```

**Cost:** new AWS accounts get the *Free Tier* (credits for the first months). This setup — one
`t3.micro`, 8 GB disk, one public IP — normally stays within those credits. After the free period
it costs roughly US $10/month while running, so **stop or terminate the instance when you're done
learning**. Prices change; check the AWS pricing pages and set the budget alert in step 1.

---

## Step 1 — AWS account + budget alert (do this first!)
1. Create an account at https://aws.amazon.com (needs a card for verification).
2. Top-right search box → **Billing and Cost Management → Budgets → Create budget →
   "Zero spend budget"** (or a $1 monthly budget) → enter your email.
   AWS will email you before anything costs money.
3. Top-right region selector → choose **Asia Pacific (Mumbai) ap-south-1** (closest to India).

## Step 2 — Launch the server (EC2)
Search **EC2** → **Launch instance**:

| Setting | Choose |
|---|---|
| Name | `rental-server` |
| OS image | **Ubuntu Server 24.04 LTS** (Free tier eligible) |
| Instance type | **t3.micro** (Free tier eligible) |
| Key pair | **Create new key pair** → name `rental-key`, type RSA, format **.pem** → it downloads `rental-key.pem`. Keep it safe, you can't download it again. |
| Network settings → Firewall | **Create security group**, tick: **Allow SSH from → My IP**, **Allow HTTPS from the internet**, **Allow HTTP from the internet** |
| Storage | 8 GiB gp3 (default) |

Click **Launch instance**.

## Step 3 — Give it a fixed IP (Elastic IP)
Without this, the server's IP (and so its web address) changes every time it restarts.
EC2 left menu → **Elastic IPs → Allocate Elastic IP address → Allocate**, then select it →
**Actions → Associate → Instance: rental-server → Associate**.
Note the IP, e.g. `13.233.10.20`.

> Release the Elastic IP when you delete the server (an unattached Elastic IP is billed).

## Step 4 — Prepare the files on your PC
1. Move the key somewhere simple, e.g. `F:\rental_cloth_management\deploy\rental-key.pem`
   (it's ignored by git — **never share or commit it**).
2. Lock its permissions (Windows' SSH refuses keys others can read). In **cmd** in `deploy\`:
   ```
   icacls rental-key.pem /inheritance:r
   icacls rental-key.pem /grant:r "%USERNAME%:R"
   ```
3. Double-click **`mobile\run_web.bat`** (builds the browser app), then **`deploy\make_package.bat`**.
   You get `rental_app.tar.gz` (code) and `rental_data.tar.gz` (your database + photos).

## Step 5 — Upload to the server
In **cmd** in `deploy\` (replace `13.233.10.20` with your Elastic IP):
```
scp -i rental-key.pem rental_app.tar.gz rental_data.tar.gz setup_server.sh ubuntu@13.233.10.20:~
```
Type `yes` the first time it asks about the fingerprint.

## Step 6 — Run the setup (one command)
```
ssh -i rental-key.pem ubuntu@13.233.10.20
```
You're now "inside" the server. Run:
```
bash setup_server.sh
```
After 2–4 minutes it prints your links, e.g.:
```
Browser app (any phone, anywhere):  https://13-233-10-20.sslip.io/app/
Server address for the APK:         https://13-233-10-20.sslip.io
```
Type `exit` to leave the server. **Your PC can now be switched off — the app keeps running.**

## Step 7 — Use it
- Any phone, any network: open `https://13-233-10-20.sslip.io/app/`
- Android APK: ⚙ on the login screen → `https://13-233-10-20.sslip.io` → Test & Save
- Or ask Claude to build an APK with this address built in, so users don't type anything.

---

## Updating after you change code
1. `mobile\run_web.bat` (if the app changed) → `deploy\make_package.bat`
2. `scp -i rental-key.pem rental_app.tar.gz setup_server.sh ubuntu@IP:~`
3. `ssh -i rental-key.pem ubuntu@IP` → `bash setup_server.sh`

Your server's database, photos and `.env` are kept.

## Useful server commands (after `ssh`)
| What | Command |
|---|---|
| Is the API running? | `sudo systemctl status rental` |
| See API errors | `sudo journalctl -u rental -n 50` |
| Restart the API | `sudo systemctl restart rental` |
| Https/Caddy errors | `sudo journalctl -u caddy -n 50` |
| Back up the database to your PC (run on PC) | `scp -i rental-key.pem ubuntu@IP:/opt/rental/backend/database/rental_cloth.db .` |

## When you're finished learning (avoid charges)
EC2 → Instances → select → **Instance state → Terminate**, then **Elastic IPs → Release**.
(Stopping instead of terminating keeps the disk, which costs a little each month.)
