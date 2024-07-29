#!/bin/bash
set -e

# Boot script for ncloud container.

# Check for existing config.php.
chown -R www-data:www-data /ncloud/conf
if [[ -f /ncloud/conf/config.php ]]; then
    echo "Pulling existing config.php..."
    cp /ncloud/conf/config.php /ncloud/server/config/config.php
fi

# De-template Nginx config.
cat nginx.conf.template | \
    sed -E s/__INTERNAL_HOST/$NGINX_INTERNAL_HOST/ | \
    sed -E s/__EXTERNAL_HOST/$NGINX_EXTERNAL_HOST/ | \
    sed -E s/__LISTEN_PORT/$NGINX_PORT/ | \
    sed -E s#__PATH_PREFIX#$NGINX_PATH_PREFIX# \
> /etc/nginx/nginx.conf
rm nginx.conf.template

# Update data directory ownership. Performed on boot since this is a volume.
chown -R www-data:www-data /ncloud/data

# Boot.
echo "Booting..."
nginx & /usr/sbin/php-fpm8.1 -F -R
