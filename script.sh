#!/bin/bash
if [ "$EUID" -ne 0 ]; then
    echo "Pliz executé ce script avec sudo ou les droits root."
    exit 1
fi

echo "Installasion du serveur web Apache2..."
apt install -y apache2

echo "Installasion des paquets PHP et du serveur SQL..."
apt install -y php php-mysql mariadb-server unzip wget

echo "Démarage et activation d'Apache et MariaDB..."
systemctl enable apache2 mariadb
systemctl start apache2 mariadb

echo "Configuration de MariaDB..."
mysql_secure_installation <<EOF

n
y
y
y
y
EOF

echo "Création des bases de donnés pour Nextcloud et Dolibarr..."
mysql -u root <<MYSQL_SCRIPT
CREATE DATABASE nextcloud;
CREATE USER 'nc'@'localhost' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON nextcloud.* TO 'nc'@'localhost';

CREATE DATABASE dolibarr;
CREATE USER 'doli'@'localhost' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON dolibarr.* TO 'doli'@'localhost';

FLUSH PRIVILEGES;
MYSQL_SCRIPT

echo "Installation de Nextcloud..."
wget -q https://download.nextcloud.com/server/releases/latest.zip -O nextcloud.zip
unzip -q nextcloud.zip -d /var/www/
mv /var/www/nextcloud /var/www/nextcloud
chown -R www-data:www-data /var/www/nextcloud
chmod -R 755 /var/www/nextcloud

echo "Installation de Dolibarr..."
wget -q https://sourceforge.net/projects/dolibarr/files/Dolibarr%20ERP-CRM/20.0.2/dolibarr-20.0.2.zip/download -O dolibarr.zip
unzip -q dolibarr.zip -d /var/www/
mv /var/www/dolibarr-20.0.2 /var/www/dolibarr
chown -R www-data:www-data /var/www/dolibarr
chmod -R 755 /var/www/dolibarr

echo "Konfiguration des Virtual Hosts pour Apache..."

cat <<EOL > /etc/apache2/sites-available/001-nextcloud.conf
<VirtualHost *:80>
    ServerName nc.classe.lab
    DocumentRoot /var/www/nextcloud
    ErrorLog \${APACHE_LOG_DIR}/nextcloud_error.log
    CustomLog \${APACHE_LOG_DIR}/nextcloud_access.log combined
</VirtualHost>
EOL

cat <<EOL > /etc/apache2/sites-available/002-dolibarr.conf
<VirtualHost *:80>
    ServerName doli.classe.lab
    DocumentRoot /var/www/dolibarr
    ErrorLog \${APACHE_LOG_DIR}/dolibarr_error.log
    CustomLog \${APACHE_LOG_DIR}/dolibarr_access.log combined
</VirtualHost>
EOL

echo "Activation des VirtualHosts et modules..."
a2ensite 001-nextcloud.conf
a2ensite 002-dolibarr.conf
a2enmod rewrite
systemctl reload apache2

echo "Ajout des noms de domène dans /etc/hosts..."
echo "127.0.0.1 nc.classe.lab" >> /etc/hosts
echo "127.0.0.1 doli.classe.lab" >> /etc/hosts

echo "Installasion terminé avec succés! Accédez à vos applis via:"
echo " - Nextcloud: http://nc.classe.lab"
echo " - Dolibarr: http://doli.classe.lab"
