#!/bin/bash

# Warna ANSI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner ASCII untuk Nginx
NGINX_BANNER=$(cat << 'EOF'
${GREEN}
  _  _      _       __  __
 | \| |__ _(_)_ _   \ \/ /
 | .` / _` | | ' \   >  < 
 |_|\_\__, |_|_||_| /_/\_\
      |___/               
  WordPress with Nginx
${NC}
EOF
)

# Banner ASCII untuk Apache2
APACHE2_BANNER=$(cat << 'EOF'
${GREEN}
    _                 _        ___ 
   /_\  _ __  __ _ __| |_  ___|_  )
  / _ \| '_ \/ _` / _| ' \/ -_)/ / 
 /_/ \_\ .__/\__,_\__|_||_\___/___|
       |_|                         
  WordPress with Apache2
${NC}
EOF
)

# Periksa apakah pengguna memiliki hak akses root
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}Skrip ini harus dijalankan sebagai root. Gunakan sudo atau login sebagai root.${NC}"
    exit 1
fi

# Periksa jumlah argumen
if [ "$#" -ne 3 ] || [ "$1" != "wordpress" ] || [ "$3" != "nginx" ] && [ "$3" != "apache2" ]; then
    echo -e "${RED}Penggunaan: $0 wordpress <domain> <nginx|apache2>${NC}"
    echo -e "${RED}Contoh: $0 wordpress hondavario.id nginx${NC}"
    exit 1
fi

DOMAIN=$2
WEBSERVER=$3
DB_NAME="wordpress"
DB_USER="wpuser"
DB_PASS=$(openssl rand -base64 12) # Generate password acak
WP_ADMIN_USER="admin"
WP_ADMIN_PASS=$(openssl rand -base64 12) # Generate password acak
WP_ADMIN_EMAIL="admin@$DOMAIN"
WP_TITLE="My WordPress Site"
CRED_FILE="/root/.inicv.txt"

# Tampilkan banner berdasarkan web server
if [ "$WEBSERVER" == "nginx" ]; then
    echo -e "$NGINX_BANNER"
elif [ "$WEBSERVER" == "apache2" ]; then
    echo -e "$APACHE2_BANNER"
fi

# Deteksi OS
echo -e "${BLUE}Mendeteksi sistem operasi...${NC}"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VERSION=$VERSION_ID
else
    echo -e "${RED}Tidak dapat mendeteksi sistem operasi!${NC}"
    exit 1
fi
echo -e "${GREEN}Sistem operasi terdeteksi: $OS $VERSION${NC}"

# Fungsi untuk instalasi Nginx
install_nginx() {
    echo -e "${YELLOW}Menginstal Nginx dan dependensi...${NC}"
    apt-get update
    apt-get install -y nginx php-fpm php-mysql php-curl php-gd php-intl php-mbstring php-soap php-xml php-xmlrpc php-zip mariadb-server mariadb-client curl unzip

    # Mulai dan aktifkan layanan
    systemctl start nginx
    systemctl enable nginx
    systemctl start mariadb
    systemctl enable mariadb
    systemctl start php${PHP_VERSION}-fpm
    systemctl enable php${PHP_VERSION}-fpm
    echo -e "${GREEN}Nginx dan dependensi berhasil diinstal!${NC}"
}

# Fungsi untuk instalasi Apache2
install_apache2() {
    echo -e "${YELLOW}Menginstal Apache2 dan dependensi...${NC}"
    apt-get update
    apt-get install -y apache2 php libapache2-mod-php php-mysql php-curl php-gd php-intl php-mbstring php-soap php-xml php-xmlrpc php-zip mariadb-server mariadb-client curl unzip

    # Mulai dan aktifkan layanan
    systemctl start apache2
    systemctl enable apache2
    systemctl start mariadb
    systemctl enable mariadb
    echo -e "${GREEN}Apache2 dan dependensi berhasil diinstal!${NC}"
}

# Tentukan versi PHP berdasarkan OS
if [[ "$OS" == *"Ubuntu"* ]]; then
    if [[ "$VERSION" == "20.04" ]]; then
        PHP_VERSION="7.4"
    elif [[ "$VERSION" == "22.04" ]]; then
        PHP_VERSION="8.1"
    elif [[ "$VERSION" == "24.04" ]]; then
        PHP_VERSION="8.3"
    else
        PHP_VERSION="8.1" # Default untuk Ubuntu lainnya
    fi
elif [[ "$OS" == *"Debian"* ]]; then
    if [[ "$VERSION" == "10" ]]; then
        PHP_VERSION="7.3"
    elif [[ "$VERSION" == "11" ]]; then
        PHP_VERSION="7.4"
    elif [[ "$VERSION" == "12" ]]; then
        PHP_VERSION="8.2"
    else
        PHP_VERSION="7.4" # Default untuk Debian lainnya
    fi
else
    echo -e "${RED}OS tidak didukung!${NC}"
    exit 1
fi
echo -e "${BLUE}Versi PHP yang digunakan: $PHP_VERSION${NC}"

# Instal dependensi berdasarkan web server yang dipilih
if [ "$WEBSERVER" == "nginx" ]; then
    install_nginx
elif [ "$WEBSERVER" == "apache2" ]; then
    install_apache2
fi

# Konfigurasi database
echo -e "${YELLOW}Mengatur database MariaDB...${NC}"
mysql -u root -e "CREATE DATABASE $DB_NAME;"
mysql -u root -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -u root -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
mysql -u root -e "FLUSH PRIVILEGES;"
echo -e "${GREEN}Database berhasil dikonfigurasi!${NC}"

# Instal WP-CLI
echo -e "${YELLOW}Menginstal WP-CLI...${NC}"
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp
echo -e "${GREEN}WP-CLI berhasil diinstal!${NC}"

# Unduh dan ekstrak WordPress
echo -e "${YELLOW}Mengunduh dan mengkonfigurasi WordPress...${NC}"
cd /var/www
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
mv wordpress $DOMAIN
chown -R www-data:www-data /var/www/$DOMAIN
chmod -R 755 /var/www/$DOMAIN
rm latest.tar.gz
echo -e "${GREEN}WordPress berhasil diunduh dan dikonfigurasi!${NC}"

# Konfigurasi wp-config.php
echo -e "${YELLOW}Mengkonfigurasi wp-config.php...${NC}"
cd /var/www/$DOMAIN
cp wp-config-sample.php wp-config.php
sed -i "s/database_name_here/$DB_NAME/" wp-config.php
sed -i "s/username_here/$DB_USER/" wp-config.php
sed -i "s/password_here/$DB_PASS/" wp-config.php
echo -e "${GREEN}wp-config.php berhasil dikonfigurasi!${NC}"

# Instal WordPress menggunakan WP-CLI
echo -e "${YELLOW}Menginstal WordPress dengan WP-CLI...${NC}"
wp core install --url=https://$DOMAIN --title="$WP_TITLE" --admin_user=$WP_ADMIN_USER --admin_password=$WP_ADMIN_PASS --admin_email=$WP_ADMIN_EMAIL --allow-root
echo -e "${GREEN}WordPress berhasil diinstal!${NC}"

# Instal Certbot untuk SSL
echo -e "${YELLOW}Menginstal Certbot untuk SSL...${NC}"
apt-get install -y certbot python3-certbot-$WEBSERVER
echo -e "${GREEN}Certbot berhasil diinstal!${NC}"

# Konfigurasi web server
if [ "$WEBSERVER" == "nginx" ]; then
    echo -e "${YELLOW}Mengkonfigurasi Nginx untuk $DOMAIN...${NC}"
    cat > /etc/nginx/sites-available/$DOMAIN <<EOL
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN www.$DOMAIN;
    root /var/www/$DOMAIN;
    index index.php index.html index.htm;
    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }
    location ~ \\.php\$ {
        include fastcgi_params;
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
}
EOL
    ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    nginx -t && systemctl reload nginx
    echo -e "${GREEN}Nginx berhasil dikonfigurasi!${NC}"

    # Instal SSL dengan Certbot
    echo -e "${YELLOW}Mengatur SSL dengan Certbot...${NC}"
    certbot --nginx --agree-tos --redirect --email admin@$DOMAIN -d $DOMAIN -d www.$DOMAIN
    echo -e "${GREEN}SSL berhasil diaktifkan untuk $DOMAIN!${NC}"
elif [ "$WEBSERVER" == "apache2" ]; then
    echo -e "${YELLOW}Mengkonfigurasi Apache2 untuk $DOMAIN...${NC}"
    cat > /etc/apache2/sites-available/$DOMAIN.conf <<EOL
<VirtualHost *:80>
    ServerName $DOMAIN
    ServerAlias www.$DOMAIN
    DocumentRoot /var/www/$DOMAIN
    <Directory /var/www/$DOMAIN>
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog \${APACHE_LOG_DIR}/$DOMAIN-error.log
    CustomLog \${APACHE_LOG_DIR}/$DOMAIN-access.log combined
</VirtualHost>
EOL
    a2enmod rewrite
    a2ensite $DOMAIN
    a2dissite 000-default
    apache2ctl configtest && systemctl restart apache2
    echo -e "${GREEN}Apache2 berhasil dikonfigurasi!${NC}"

    # Instal SSL dengan Certbot
    echo -e "${YELLOW}Mengatur SSL dengan Certbot...${NC}"
    certbot --apache --agree-tos --redirect --email admin@$DOMAIN -d $DOMAIN -d www.$DOMAIN
    echo -e "${GREEN}SSL berhasil diaktifkan untuk $DOMAIN!${NC}"
fi

# Setel izin akhir
echo -e "${YELLOW}Mengatur izin file...${NC}"
find /var/www/$DOMAIN/ -type d -exec chmod 755 {} \;
find /var/www/$DOMAIN/ -type f -exec chmod 644 {} \;
echo -e "${GREEN}Izin file berhasil diatur!${NC}"

# Simpan kredensial ke file .inicv.txt
echo -e "${YELLOW}Menyimpan kredensial ke $CRED_FILE...${NC}"
cat > $CRED_FILE <<EOL
[WordPress]
URL=https://$DOMAIN
Admin_URL=https://$DOMAIN/wp-admin
Username=$WP_ADMIN_USER
Password=$WP_ADMIN_PASS
Email=$WP_ADMIN_EMAIL

[Database]
Name=$DB_NAME
User=$DB_USER
Password=$DB_PASS
EOL
chmod 600 $CRED_FILE
echo -e "${GREEN}Kredensial berhasil disimpan di $CRED_FILE!${NC}"

# Tampilkan informasi instalasi
echo -e "${BLUE}============================================${NC}"
echo -e "${GREEN}Instalasi WordPress selesai!${NC}"
echo -e "${BLUE}============================================${NC}"
echo -e "${YELLOW}URL:${NC} https://$DOMAIN"
echo -e "${YELLOW}Admin URL:${NC} https://$DOMAIN/wp-admin"
echo -e "${YELLOW}Username:${NC} $WP_ADMIN_USER"
echo -e "${YELLOW}Password:${NC} $WP_ADMIN_PASS"
echo -e "${YELLOW}Email:${NC} $WP_ADMIN_EMAIL"
echo -e "${YELLOW}Database Name:${NC} $DB_NAME"
echo -e "${YELLOW}Database User:${NC} $DB_USER"
echo -e "${YELLOW}Database Password:${NC} $DB_PASS"
echo -e "${RED}Kredensial telah disimpan di $CRED_FILE${NC}"
echo -e "${RED}Simpan informasi ini di tempat yang aman!${NC}"
echo -e "${BLUE}============================================${NC}"
