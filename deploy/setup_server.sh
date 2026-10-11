#!/usr/bin/env bash
# Sets up (or updates) the Rental Cloth app on an AWS EC2 Ubuntu 24.04 server.
#
#   bash setup_server.sh
#
# Expects in the home folder (uploaded with scp from deploy\):
#   rental_app.tar.gz    - the code + browser app        (required)
#   rental_data.tar.gz   - your local database + photos  (optional, used only on first setup)
#
# Safe to run again after uploading a new rental_app.tar.gz: it keeps .env, the database and photos.
set -euo pipefail

APP_DIR=/opt/rental
PKG="$HOME/rental_app.tar.gz"
DATA_PKG="$HOME/rental_data.tar.gz"

[ -f "$PKG" ] || { echo "Missing $PKG - upload it first (see deploy/AWS_GUIDE.md)"; exit 1; }

echo "== 1/6 Installing system packages (Python, Caddy web server)"
sudo apt-get update -y -q
sudo apt-get install -y -q python3-venv python3-pip caddy curl

echo "== 2/6 Unpacking the app into $APP_DIR"
sudo mkdir -p "$APP_DIR"
sudo chown -R "$USER:$USER" "$APP_DIR"
tar -xzf "$PKG" -C "$APP_DIR"
mkdir -p "$APP_DIR/backend/database" "$APP_DIR/backend/uploads"
if [ -f "$DATA_PKG" ] && [ ! -f "$APP_DIR/backend/database/rental_cloth.db" ]; then
  echo "   First setup: copying your local database and photos"
  tar -xzf "$DATA_PKG" -C "$APP_DIR"
fi

echo "== 3/6 Installing Python packages"
cd "$APP_DIR/backend"
python3 -m venv .venv
.venv/bin/pip install -q --upgrade pip
.venv/bin/pip install -q -r requirements.txt

if [ ! -f .env ]; then
  echo "   Creating .env (SQLite + a new random login secret)"
  cat > .env <<EOF
DB_TYPE=sqlite
JWT_SECRET=$(python3 -c 'import secrets; print(secrets.token_urlsafe(48))')
JWT_EXPIRE_DAYS=30
EOF
  chmod 600 .env
fi

echo "== 4/6 Running the API as a service (starts automatically on reboot)"
sudo tee /etc/systemd/system/rental.service >/dev/null <<EOF
[Unit]
Description=Rental Cloth API
After=network.target

[Service]
User=$USER
WorkingDirectory=$APP_DIR/backend
ExecStart=$APP_DIR/backend/.venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000
Restart=always

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable -q rental
sudo systemctl restart rental

echo "== 5/6 Setting up https with Caddy"
if [ -z "${DOMAIN:-}" ]; then
  # Free hostname that points at this server's public IP: 1.2.3.4 -> 1-2-3-4.sslip.io
  TOKEN=$(curl -s -X PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
  IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)
  DOMAIN="${IP//./-}.sslip.io"
fi
sudo tee /etc/caddy/Caddyfile >/dev/null <<EOF
$DOMAIN {
    encode gzip
    reverse_proxy 127.0.0.1:8000
}
EOF
sudo systemctl reload caddy || sudo systemctl restart caddy

echo "== 6/6 Checking"
sleep 3
if curl -s http://127.0.0.1:8000/ | grep -q '"ok"'; then echo "   API: running"; else
  echo "   API is NOT running. See errors with:  sudo journalctl -u rental -n 50"; fi

cat <<EOF

=====================================================================
 Done! (the https certificate can take up to a minute the first time)

   Browser app (any phone, anywhere):  https://$DOMAIN/app/
   API test page:                      https://$DOMAIN/docs
   Server address for the APK:         https://$DOMAIN
=====================================================================
EOF
