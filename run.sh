#!/bin/bash
set -e

apt-get update

apt-get install -y \
  postgresql16-server \
  zabbix-server-pgsql \
  fping \
  apache2 \
  apache2-mod_php8.2 \
  php8.2 \
  php8.2-mbstring \
  php8.2-sockets \
  php8.2-gd \
  php8.2-xmlreader \
  php8.2-pgsql \
  php8.2-ldap \
  php8.2-openssl \
  zabbix-phpfrontend-apache2 \
  zabbix-phpfrontend-php8.2 \
  zabbix-agent

/etc/init.d/postgresql initdb || true
systemctl enable --now postgresql.service

su - postgres -s /bin/sh -c 'createuser --no-superuser --no-createdb --no-createrole --encrypted --pwprompt zabbix'
su - postgres -s /bin/sh -c 'createdb -O zabbix zabbix'

for sql_file in schema.sql images.sql data.sql; do
  su - postgres -s /bin/sh -c "psql -U zabbix -d zabbix -f /usr/share/doc/zabbix-common-database-pgsql-7.0.12/$sql_file"
done

PHP_CONF="/etc/php/8.2/apache2-mod_php/php.ini"
sed -i 's/^max_execution_time.*/max_execution_time = 600/' "$PHP_CONF"
sed -i 's/^max_input_time.*/max_input_time = 600/' "$PHP_CONF"
sed -i 's/^memory_limit.*/memory_limit = 256M/' "$PHP_CONF"
sed -i 's/^post_max_size.*/post_max_size = 32M/' "$PHP_CONF"
sed -i 's|^;*date.timezone.*|date.timezone = Europe/Moscow|' "$PHP_CONF"
grep -q "always_populate_raw_post_data" "$PHP_CONF" || echo "always_populate_raw_post_data = -1" >> "$PHP_CONF"

systemctl restart httpd2.service

ZBX_CONF="/etc/zabbix/zabbix_server.conf"

sed -i 's|^#*DBHost=.*|DBHost=localhost|' "$ZBX_CONF"
sed -i 's|^#*DBName=.*|DBName=zabbix|' "$ZBX_CONF"
sed -i 's|^#*DBUser=.*|DBUser=zabbix|' "$ZBX_CONF"
sed -i 's|^#*DBPassword=.*|DBPassword=toor|' "$ZBX_CONF"

systemctl enable --now zabbix_pgsql.service

ln -sf /etc/httpd2/conf/addon.d/A.zabbix.conf /etc/httpd2/conf/extra-enabled/

systemctl restart httpd2.service

chown apache2:apache2 /var/www/webapps/zabbix/ui/conf

systemctl enable --now zabbix_agentd.service
