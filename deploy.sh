#!/bin/bash
set -e

echo "=== CholoKolkata Auto-Deployment Script ==="
cd "$(dirname "$0")"

echo "[1/4] Pulling latest changes from GitHub..."
git pull origin main || true

echo "[2/4] Locating Python..."
if command -v python3 &>/dev/null; then
    PY="python3"
elif [ -f "/opt/cpanel/ea-python311/bin/python3" ]; then
    PY="/opt/cpanel/ea-python311/bin/python3"
elif [ -f "/opt/cpanel/ea-python310/bin/python3" ]; then
    PY="/opt/cpanel/ea-python310/bin/python3"
elif [ -f "/usr/bin/python3" ]; then
    PY="/usr/bin/python3"
else
    echo "Python binary not found. Please activate your cPanel virtual environment."
    exit 1
fi

echo "[3/4] Installing / Updating Python dependencies..."
$PY -m pip install -r requirements.txt || pip install -r requirements.txt || true

echo "[4/4] Triggering Phusion Passenger Application Restart..."
mkdir -p tmp
touch tmp/restart.txt

echo "=== Deployment Finished Successfully! ==="
echo "Visit http://cholokolkata.online/import-db?action=run to initialize the database."

