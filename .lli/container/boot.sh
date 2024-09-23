#!/bin/bash
set -e

# Boot script. Installs, launches, and configures NextCloud.

# ---- App configuration.
disable_apps=(
    "dashboard"
    "user_status"
    "files_reminders"
    "comments"
)
enable_apps=(
    # Default.
    "admin_audit"
    "files_external"
    # Third-party.
    "activity"
    "auto_groups"
    "announcementcenter"
    "notifications"
    "user_saml"
    # First-party.
    "cdsp"
)
# ----

protocol=http
service_url=http://localhost
postgres_conn_str=postgresql://$POSTGRES_USER:$POSTGRES_PW@$POSTGRES_HOST/$POSTGRES_DB
if [[ $LLI_ENV != "local" ]]; then
    protocol=https
    service_url=https://$NCLOUD_HOST
fi

echo "Chowning data mount..."
chown -R www-data:www-data /ncloud/data

echo "Configuring Nginx..."
cat nginx.template.conf | \
sed -E s/__NCLOUD_HOST/$NCLOUD_HOST/ | \
sed -E s/__LISTEN_PORT/$NGINX_PORT/ \
> /etc/nginx/nginx.conf

echo "Booting..."
nginx &
nginx_pid=$!
/usr/sbin/php-fpm8.1 -R

# On local, Postgres needs to be initialized before we can continue.
echo "Awaiting Postgres..."
postgres_up=0
while ! psql $postgres_conn_str -c '\q' > /dev/null 2>&1; do
    printf "."
    sleep 2
done
echo

echo "Triggering install..."
curl \
    -sS \
    -X POST \
    -H "Content-Type: multipart/form-data" \
    -F install=true \
    -F adminlogin=$ADMIN_USER \
    -F adminpass=$ADMIN_PW \
    -F directory=/ncloud/data \
    -F dbtype=pgsql \
    -F dbuser=$POSTGRES_USER \
    -F dbpass=$POSTGRES_PW \
    -F dbpass-clone=$POSTGRES_PW \
    -F dbname=$POSTGRES_DB \
    -F dbhost=$POSTGRES_HOST \
    $service_url

echo "Configuring enabled apps..."
cd server

exec_occ() {
    sudo -u www-data php occ "$@"
}

printf "%s\n" "${disable_apps[@]}" | xargs -I {} sudo -u www-data php occ app:disable {}
printf "%s\n" "${enable_apps[@]}" | xargs -I {} sudo -u www-data php occ app:enable --force {}

echo "Applying configuration..."
if [[ $NCLOUD_DEBUG == "1" ]]; then
    exec_occ config:system:set debug --value="true"
fi

exec_occ config:system:set log_type --value="file"
exec_occ config:system:set logfile --value="/ncloud/ncloud.log"
exec_occ config:system:set loglevel --value="0" # TODO: Inject config.

exec_occ config:system:set redis host --value="$REDIS_HOST"
exec_occ config:system:set redis port --value="$REDIS_PORT"

exec_occ config:system:set memcache.local --value="\OC\Memcache\Redis"
exec_occ config:system:set memcache.distributed --value="\OC\Memcache\Redis"
exec_occ config:system:set memcache.locking --value="\OC\Memcache\Redis"

exec_occ config:system:set trusted_domains 1 --value="$NCLOUD_HOST"
exec_occ config:system:set overwriteprotocol --value="$protocol"
exec_occ config:system:set overwritewebroot --value="$NCLOUD_PATH_PREFIX"
exec_occ config:system:set overwritehost --value="$NCLOUD_HOST"
exec_occ config:system:set overwrite.cli.url --value="$service_url"
exec_occ config:system:set theme --value="cdsp-theme"

exec_occ config:app:set user_saml general-allow_multiple_user_back_ends --value="1" # todo rm this
exec_occ config:app:set user_saml type --value "saml"

saml_conf_json="$(echo "$SAML_CONF_B64" | base64 -d)"
cat <<EOF___ | psql $postgres_conn_str
DELETE FROM oc_user_saml_configurations;

INSERT INTO oc_user_saml_configurations (id, name, configuration)
VALUES (1, 'Primary IdP', '$saml_conf_json');
EOF___

exec_occ config:app:set cdsp restrictedgroups --value="$CDSP_RESTRICTED_GROUPS"
exec_occ config:app:set cdsp unassignedgroups --value="$CDSP_UNASSIGNED_GROUPS"
exec_occ config:app:set cdsp admingroups --value="$CDSP_ADMIN_GROUPS"

exec_occ config:app:set cdsp awsaccesskey --value="$AWS_ACCESS_KEY_ID"
exec_occ config:app:set cdsp awssecretkey --value="$AWS_SECRET_ACCESS_KEY"
exec_occ config:app:set cdsp awsbucket --value="$AWS_BUCKET"
exec_occ config:app:set cdsp awsregion --value="ca-central-1"

echo "Up."
tail -f /ncloud/ncloud.log
