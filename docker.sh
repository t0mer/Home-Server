#!/usr/bin/env bash
set -euo pipefail

# Docker + Docker Compose (plugin) install for Ubuntu
# - Uses official Docker repository + GPG key
# - Installs: docker-ce, docker-ce-cli, containerd.io, buildx, compose plugin
# - Adds current user to docker group (no hello-world)

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root (sudo)."
  exit 1
fi

echo "[1/7] Installing prerequisites..."
apt-get update -y
apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release

echo "[2/7] Setting up Docker GPG key..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "[3/7] Adding Docker apt repository..."
ARCH="$(dpkg --print-architecture)"
CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"

echo \
  "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${CODENAME} stable" \
  > /etc/apt/sources.list.d/docker.list

echo "[4/7] Installing Docker Engine + plugins..."
apt-get update -y
apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

echo "[5/7] Enabling and starting Docker service..."
systemctl enable docker
systemctl start docker

# Add invoking user to docker group (only if called via sudo)
if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
  echo "[6/7] Adding user '${SUDO_USER}' to docker group..."
  groupadd -f docker
  usermod -aG docker "${SUDO_USER}"
  echo "NOTE: User must log out and log back in (or reboot) for group changes to apply."
else
  echo "[6/7] Skipping docker group usermod (no SUDO_USER detected)."
fi

echo "[7/7] Verifying installation (no hello-world)..."
docker --version
docker compose version

echo "Done ✅"
