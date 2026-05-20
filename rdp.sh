#!/bin/bash
# ============================================
# Script: windows11-docker-tunnel.sh
# ============================================

set -e

# Cek root
if [ "$EUID" -ne 0 ]; then
  echo "Jalankan dengan: sudo bash $0"
  exit 1
fi

# Update & install dependencies
apt update -y
apt install -y docker-compose wget curl qemu-kvm libvirt-daemon-system

# Setup KVM permissions
adduser $(who am i | awk '{print $1}') kvm

# Buat direktori kerja
mkdir -p /root/dockercom
cd /root/dockercom

# Buat docker-compose.yml
cat > docker-compose.yml <<'EOF'
version: "3.8"
services:
  windows:
    image: dockurr/windows:latest
    container_name: windows11
    environment:
      VERSION: "11"
      USERNAME: "user"
      PASSWORD: "Pass@123"
      RAM_SIZE: "4G"
      CPU_CORES: "2"
      DISK_SIZE: "64G"
    devices:
      - /dev/kvm
    cap_add:
      - NET_ADMIN
      - SYS_NICE
    ports:
      - "8006:8006"
      - "3389:3389"
    volumes:
      - ./windows-data:/storage
    restart: unless-stopped
EOF

# Jalankan container
docker-compose up -d

# Install cloudflared
if ! command -v cloudflared &> /dev/null; then
  wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
  chmod +x cloudflared-linux-amd64
  mv cloudflared-linux-amd64 /usr/local/bin/cloudflared
fi

# Jalankan tunnel (perbaikan untuk TCP)
nohup cloudflared tunnel --url http://localhost:8006 > /tmp/cf-web.log 2>&1 &
sleep 3
nohup cloudflared tunnel --url tcp://localhost:3389 > /tmp/cf-rdp.log 2>&1 &

echo "=== Selesai ==="
echo "Tunggu 1-2 menit hingga tunnel aktif"
echo "Cek log: tail -f /tmp/cf-*.log"
