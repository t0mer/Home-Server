#!/usr/bin/env bash
set -e

NODE_EXPORTER_VERSION="1.8.2"
ARCH="$(uname -m)"

case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  armv7l) ARCH="armv7" ;;
  *)
    echo "Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

USER="node_exporter"
BIN="/usr/local/bin/node_exporter"

echo "▶ Installing Node Exporter v${NODE_EXPORTER_VERSION} for ${ARCH}"

# Create user
if ! id "$USER" &>/dev/null; then
  useradd --system --no-create-home --shell /usr/sbin/nologin "$USER"
fi

# Download
cd /tmp
curl -LO https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}.tar.gz

tar xzf node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}.tar.gz
cp node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}/node_exporter $BIN
chmod 755 $BIN
chown $USER:$USER $BIN

# Systemd service
cat >/etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Prometheus Node Exporter
After=network-online.target
Wants=network-online.target

[Service]
User=${USER}
Group=${USER}
Type=simple
ExecStart=${BIN}
Restart=always
RestartSec=5

# Hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

# Start service
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now node_exporter

echo "✅ Node Exporter installed and running"
echo "   Metrics: http://localhost:9100/metrics"
