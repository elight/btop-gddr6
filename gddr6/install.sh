#!/usr/bin/env bash
# Build btop-gddr6 and install it, plus the root feed that supplies VRAM temperatures.
# Needs: gddr6 at /usr/local/bin/gddr6, nvidia-smi, and a C++23 compiler (g++-14 on Ubuntu 24.04).
set -euo pipefail
cd "$(dirname "$0")/.."

CXX="${CXX:-g++-14}"
make -j"$(nproc)" CXX="$CXX" GPU_SUPPORT=true

sudo install -m 755 bin/btop /usr/local/bin/btop
sudo install -m 755 gddr6/gddr6-feed /usr/local/bin/gddr6-feed
sudo install -m 644 gddr6/gddr6-feed.service /etc/systemd/system/gddr6-feed.service
sudo systemctl daemon-reload
sudo systemctl enable --now gddr6-feed
sudo systemctl restart gddr6-feed

sleep 3
echo "btop: $(command -v btop) ($(btop --version | head -1))"
for f in /run/gddr6/gpu*; do echo "$f: $(cat "$f")°C"; done
