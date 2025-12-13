#!/usr/bin/env bash
set -euo pipefail

# Cloudflared installation script
# Uses official Cloudflare APT repository + GPG key

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root (sudo)."
  exit 1
fi

echo "[1/4] Creating keyrings directory..."
install -m 0755 -d /usr/share/keyrings

echo "[2/4] Adding Cloudflare GPG key..."
curl -fsSL https://pkg.cloudflare.com/cloudflare-public-v2.gpg \
  | tee /usr/share/keyrings/cloudflare-public-v2.gpg >/dev/null

echo "[3/4] Adding Cloudflared APT repository..."
cat <<EOF > /etc/apt/sources.list.d/cloudflared.list
deb [signed-by=/usr/share/keyrings/cloudflare-public-v2.gpg] https://pkg.cloudflare.com/cloudflared any main
EOF

echo "[4/4] Installing cloudflared..."
apt-get update -y
apt-get install -y cloudflared

echo "Verifying installation..."
cloudflared --version

echo "Done ✅"
