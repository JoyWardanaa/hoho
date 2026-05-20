#!/bin/bash
# windows-rdp-codespaces.sh - WORKING solution for GitHub Codespaces
# Menjalankan Windows 11 via Docker DOCKER (emulated, tanpa KVM)

set -e

echo "=============================================="
echo "  Windows 11 RDP via Docker di Codespaces"
echo "=============================================="

# Cek environment
if [ ! -f /workspaces/.codespaces ]; then
    echo "⚠️ Bukan di GitHub Codespaces, tapi tetap bisa jalan"
fi

echo ""
echo "=== Step 1: Install Docker ==="
sudo apt update -y
sudo apt install -y docker.io docker-compose
sudo service docker start
sudo usermod -aG docker $USER

echo ""
echo "=== Step 2: Buat direktori ==="
mkdir -p ~/windows-docker
cd ~/windows-docker

echo ""
echo "=== Step 3: Buat docker-compose.yml (tanpa KVM) ==="
cat > docker-compose.yml <<'EOF'
version: "3.8"
services:
  windows:
    image: dockurr/windows:latest
    container_name: windows11
    environment:
      VERSION: "11"
      USERNAME: "Codespaces"
      PASSWORD: "Pass123"
      RAM_SIZE: "3G"
      CPU_CORES: "2"
      DISK_SIZE: "32G"
      KVM: "N"
    ports:
      - "8006:8006"
      - "3389:3389"
    volumes:
      - ./storage:/storage
    restart: unless-stopped
EOF

echo ""
echo "=== Step 4: Jalankan container ==="
sudo docker-compose up -d

echo ""
echo "=== Step 5: Tunggu download image (3-5 menit) ==="
echo "Progress:"
sudo docker logs -f windows11 &
LOG_PID=$!
sleep 30
kill $LOG_PID 2>/dev/null

echo ""
echo "=== Step 6: Install Cloudflare Tunnel ==="
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
chmod +x cloudflared-linux-amd64
sudo mv cloudflared-linux-amd64 /usr/local/bin/cloudflared

echo ""
echo "=== Step 7: Buat tunnel web (NoVNC) ==="
pkill cloudflared 2>/dev/null
nohup cloudflared tunnel --url http://localhost:8006 > ~/cf-web.log 2>&1 &

echo ""
echo "=== Step 8: Buat tunnel RDP ==="
nohup cloudflared tunnel --url tcp://localhost:3389 > ~/cf-rdp.log 2>&1 &

sleep 8

echo ""
echo "=============================================="
echo "  ✅ INSTALLASI SELESAI"
echo "=============================================="

echo ""
echo "🌐 LINK WEB (NoVNC):"
CF_WEB=$(grep -o "https://[a-zA-Z0-9.-]*\.trycloudflare\.com" ~/cf-web.log | head -1)
if [ -n "$CF_WEB" ]; then
    echo "   $CF_WEB"
else
    echo "   ⏳ Tunggu 1-2 menit, lalu jalankan:"
    echo "   grep 'trycloudflare' ~/cf-web.log"
fi

echo ""
echo "🖥️ LINK RDP:"
CF_RDP=$(grep -o "tcp://[a-zA-Z0-9.-]*\.trycloudflare\.com:[0-9]*" ~/cf-rdp.log | head -1)
if [ -n "$CF_RDP" ]; then
    echo "   $CF_RDP"
else
    echo "   ⏳ Tunggu 1-2 menit, lalu jalankan:"
    echo "   grep 'trycloudflare' ~/cf-rdp.log"
fi

echo ""
echo "🔑 LOGIN:"
echo "   Username: Codespaces"
echo "   Password: Pass123"

echo ""
echo "📋 PERINTAH MONITORING:"
echo "   Lihat log:        docker logs -f windows11"
echo "   Cek status:       docker ps"
echo "   Stop container:   docker stop windows11"
echo "   Start container:  docker start windows11"
echo "   Hapus container:  docker rm -f windows11"

echo ""
echo "⚠️ CATATAN:"
echo "   - Boot pertama butuh 10-30 menit (download + install Windows)"
echo "   - Performa lambat karena emulasi tanpa KVM"
echo "   - Jika tunnel tidak muncul, tunggu 3-5 menit lalu jalankan ulang tunnel:"
echo "     pkill cloudflared; nohup cloudflared tunnel --url http://localhost:8006 > ~/cf-web.log 2>&1 &"

echo ""
echo "=============================================="
