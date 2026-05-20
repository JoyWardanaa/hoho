#!/bin/bash
# fix-rdp-codespaces.sh
set -e

echo "=== Install Docker & Docker Compose ==="
sudo apt update
sudo apt install -y docker.io docker-compose
sudo service docker start

echo "=== Buat direktori kerja ==="
mkdir -p ~/windows-docker
cd ~/windows-docker

echo "=== Buat docker-compose.yml (tanpa KVM) ==="
cat > docker-compose.yml <<'EOF'
version: "3.8"
services:
  windows:
    image: dockurr/windows:latest
    container_name: windows11
    environment:
      VERSION: "11"
      USERNAME: "admin"
      PASSWORD: "Admin123"
      RAM_SIZE: "4G"
      CPU_CORES: "2"
      DISK_SIZE: "32G"
      # Nonaktifkan KVM
      KVM: "N"
    ports:
      - "8006:8006"
      - "3389:3389"
    volumes:
      - ./storage:/storage
    restart: unless-stopped
EOF

echo "=== Jalankan container ==="
sudo docker-compose up -d

echo "=== Install Cloudflare Tunnel ==="
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
chmod +x cloudflared-linux-amd64
sudo mv cloudflared-linux-amd64 /usr/local/bin/cloudflared

echo "=== Jalankan tunnel untuk web (NoVNC) ==="
nohup cloudflared tunnel --url http://localhost:8006 > ~/cf-web.log 2>&1 &

sleep 5
echo ""
echo "=== 🔗 Ambil link dari log ==="
grep -o "https://[a-zA-Z0-9.-]*\.trycloudflare\.com" ~/cf-web.log | head -1
echo ""
echo "Username: admin"
echo "Password: Admin123"
echo "Tunggu 3-5 menit sampai Windows booting"
