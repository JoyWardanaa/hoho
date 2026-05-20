#!/bin/bash
# pterodactyl-install.sh - Auto install Pterodactyl Panel di VPS
# Berjalan di GitHub Codespaces sebagai orchestrator

set -e

echo "=============================================="
echo "  Pterodactyl Panel Auto Installer"
echo "  Mode: Deploy ke VPS remote"
echo "=============================================="

# Warna
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Masukkan informasi VPS target:${NC}"
read -p "IP VPS: " VPS_IP
read -p "Username (biasanya root): " VPS_USER
read -p "Password: " VPS_PASS
read -p "Domain/subdomain untuk panel (contoh: panel.domain.com): " DOMAIN

echo ""
echo -e "${GREEN}Menginstall sshpass...${NC}"
sudo apt update -y
sudo apt install -y sshpass

echo ""
echo -e "${GREEN}Membuat script install di VPS...${NC}"

cat > /tmp/pterodactyl-install.sh <<'EOF'
#!/bin/bash
set -e

# Warna
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}=== Update system ===${NC}"
apt update -y && apt upgrade -y
apt install -y software-properties-common curl git nginx mariadb-server \
    redis-server certbot python3-certbot-nginx unzip tar

echo -e "${GREEN}=== Install Docker ===${NC}"
curl -fsSL https://get.docker.com | sh
systemctl enable docker
systemctl start docker

echo -e "${GREEN}=== Install Wings (daemon Pterodactyl) ===${NC}"
mkdir -p /etc/pterodactyl
curl -L -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
chmod u+x /usr/local/bin/wings

echo -e "${GREEN}=== Install Panel ===${NC}"
cd /var/www
curl -L -o panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
tar -xzvf panel.tar.gz
mv panel-* pterodactyl
cd pterodactyl

cp .env.example .env
curl -sS https://getcomposer.org/installer | php
php composer.phar install --no-dev --optimize-autoloader

php artisan key:generate --force

echo -e "${GREEN}=== Setup environment ===${NC}"
read -p "Database password: " DB_PASS
php artisan p:environment:setup --no-interaction \
    --url=http://DOMAIN_PLACEHOLDER \
    --timezone=Asia/Jakarta \
    --cache=redis \
    --session=redis \
    --queue=redis \
    --redis-host=localhost

php artisan p:environment:database \
    --host=127.0.0.1 \
    --port=3306 \
    --database=pterodactyl \
    --username=pterodactyl \
    --password=$DB_PASS

mysql -u root -e "CREATE DATABASE IF NOT EXISTS pterodactyl;"
mysql -u root -e "CREATE USER IF NOT EXISTS 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '$DB_PASS';"
mysql -u root -e "GRANT ALL PRIVILEGES ON pterodactyl.* TO 'pterodactyl'@'127.0.0.1' WITH GRANT OPTION;"
mysql -u root -e "FLUSH PRIVILEGES;"

php artisan migrate --force
php artisan p:user:make

echo -e "${GREEN}=== Setup Nginx ===${NC}"
cat > /etc/nginx/sites-available/pterodactyl <<'NGINX'
server {
    listen 80;
    server_name DOMAIN_PLACEHOLDER;
    root /var/www/pterodactyl/public;
    index index.php;
    
    location / {
        try_files $uri $uri/ /index.php?$args;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
    }
}
NGINX

ln -s /etc/nginx/sites-available/pterodactyl /etc/nginx/sites-enabled/
systemctl restart nginx

echo -e "${GREEN}=== Install SSL ===${NC}"
certbot --nginx -d DOMAIN_PLACEHOLDER --non-interactive --agree-tos --email admin@DOMAIN_PLACEHOLDER

echo -e "${GREEN}=== Setup queue worker ===${NC}"
echo "[Unit]
Description=Pterodactyl Queue Worker
[Service]
User=www-data
Group=www-data
WorkingDirectory=/var/www/pterodactyl
ExecStart=/usr/bin/php artisan queue:work --sleep=3 --tries=3
Restart=always
[Install]
WantedBy=multi-user.target" > /etc/systemd/system/pterodactyl-worker.service

systemctl enable pterodactyl-worker
systemctl start pterodactyl-worker

echo -e "${GREEN}=== Selesai! ===${NC}"
echo "Panel: https://DOMAIN_PLACEHOLDER"
echo "Login dengan akun yang dibuat tadi"
EOF

# Replace placeholder dengan domain asli
sed -i "s/DOMAIN_PLACEHOLDER/$DOMAIN/g" /tmp/pterodactyl-install.sh

echo ""
echo -e "${GREEN}Upload script ke VPS...${NC}"
sshpass -p "$VPS_PASS" scp -o StrictHostKeyChecking=no /tmp/pterodactyl-install.sh $VPS_USER@$VPS_IP:/root/

echo ""
echo -e "${GREEN}Jalankan script di VPS...${NC}"
sshpass -p "$VPS_PASS" ssh -o StrictHostKeyChecking=no $VPS_USER@$VPS_IP "bash /root/pterodactyl-install.sh"

echo ""
echo -e "${GREEN}=============================================="
echo -e "✅ INSTALLASI SELESAI"
echo -e "=============================================="
echo -e "Panel: ${YELLOW}https://$DOMAIN${NC}"
echo -e "Wings API Key: ${YELLOW}Lihat di panel → Admin → Nodes${NC}"
echo -e "=============================================="
