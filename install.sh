#!/usr/bin/env bash
set -euo pipefail

# Home-Server remote installer
# Runs scripts directly from GitHub using curl (no local downloads)

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root (sudo)."
  exit 1
fi

BASE_URL="https://raw.githubusercontent.com/t0mer/Home-Server/main"

run_remote_script() {
  local script="$1"
  local url="${BASE_URL}/${script}"

  echo "▶ Running ${script} from ${url}"

  curl -fsSL "${url}" | bash

  echo "✅ Finished ${script}"
  echo
}


curl -fsSL https://get.docker.com | sh
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

run_remote_script "dependencies.sh"
run_remote_script "cftunnel.sh"

echo "🎉 Home-Server setup completed successfully"
