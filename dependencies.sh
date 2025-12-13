#!/usr/bin/env bash
set -euo pipefail

# Common utilities installation script
# Tested on Ubuntu 20.04 / 22.04 / 24.04

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root (sudo)."
  exit 1
fi

echo "[1/3] Updating package index..."
apt-get update -y

echo "[2/3] Installing packages..."
apt-get install -y \
  ffmpeg \
  zip \
  unzip \
  python3-pip \
  git

echo "[3/3] Verifying installation..."
ffmpeg -version | head -n 1
zip -v | head -n 1
unzip -v | head -n 1
pip3 --version
git --version

echo "Done ✅"
