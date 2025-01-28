#!/bin/bash
set -e

# Boot script. Installs, launches, and configures Nextcloud.

# ---- App configuration.
disable_apps=(
    "dashboard"
    "user_status"
    "files_reminders"
)
enable_apps=(
    # Default.
    "comments"
    "admin_audit"
    "files_external"
    # Third-party.
    "activity"
    "comments"
    "announcementcenter"
    "comments"
    "notifications"
    "group_everyone"
    "files_downloadactivity"
    "logreader"
    "user_retention"
    "password_policy"
    "privacy"
    # First-party.
    "cdsp"
    "user_saml"
)

data_directory=/ncloud/data
ncloud_version="29.0.8.1"
# ----

exec_occ() {
    sudo -u www-data php occ "$@"
}

conf_occ_sys() {
    exec_occ config:system:set $1 --value="$2"
}

conf_occ_app() {
    exec_occ config:app:set $1 $2 --value="$3"
}

service_url=http://localhost
postgres_conn_str=postgresql://$POSTGRES_USER:$POSTGRES_PW@$POSTGRES_HOST/$POSTGRES_DB
if [[ $LLI_ENV != "local" ]]; then
    service_url=https://$NCLOUD_INTERNAL_HOST
fi

echo "Chowning data mount..."
chown -R www-data:www-data /ncloud/data

echo "Configuring Nginx..."
cat nginx.template.conf | \
sed -E s/__NCLOUD_INTERNAL_HOST/$NCLOUD_INTERNAL_HOST/ | \
sed -E s/__NCLOUD_EXTERNAL_HOST/$NCLOUD_EXTERNAL_HOST/ | \
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

# TODO: I don't think there's a way to remove this duplication, but worth
# investigating...
echo "Checking install state..."
is_installed=0
table_present=$(cat << EOF | psql -tA $postgres_conn_str
SELECT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'oc_users'
);
EOF
)
if [[ $table_present == "t" ]]; then
    existing_user=$(cat << EOF | psql -tA $postgres_conn_str
SELECT uid FROM oc_users LIMIT 1;
EOF
)
    if [[ $existing_user != "" ]]; then
        echo "Existing install detected."
        is_installed=1
    fi
fi

if [[ $NCLOUD_INSTALL == "1" ]] && ! (( $is_installed )); then
    echo "Triggering install..."
    curl \
        -sS \
        -X POST \
        -H "Content-Type: multipart/form-data" \
        -F install=true \
        -F adminlogin=$NCLOUD_INSTALL_ADMIN_USER \
        -F adminpass=$NCLOUD_INSTALL_ADMIN_PW \
        -F directory=$data_directory \
        -F dbtype=pgsql \
        -F dbuser=$POSTGRES_USER \
        -F dbpass=$POSTGRES_PW \
        -F dbpass-clone=$POSTGRES_PW \
        -F dbname=$POSTGRES_DB \
        -F dbhost=$POSTGRES_HOST \
        http://localhost
else
    echo "Marking existing install..."
    cat << EOF > server/config/config.php
<?php
\$CONFIG = [
'version' => '$ncloud_version',
'installed' => true,
'updater.release.channel' => 'git',
'datadirectory' => '$data_directory',
'dbtype' => 'pgsql',
'dbuser' => '$POSTGRES_USER',
'dbpassword' => '$POSTGRES_PW',
'dbhost' => '$POSTGRES_HOST',
'dbname' => '$POSTGRES_DB',
];
EOF
chown www-data:www-data server/config/config.php
fi

cd server

echo "Configuring system..."
# ---- System configuration.
# Can't use helper function for these directly below because sub-arrays.
exec_occ config:system:set redis host --value="$REDIS_HOST"
exec_occ config:system:set redis port --value="$REDIS_PORT"
exec_occ config:system:set trusted_domains 0 --value="localhost"
exec_occ config:system:set trusted_domains 1 --value="$NCLOUD_INTERNAL_HOST"
exec_occ config:system:set trusted_domains 2 --value="$NCLOUD_EXTERNAL_HOST"

conf_occ_sys debug                 $NCLOUD_DEBUG
conf_occ_sys instanceid            $NCLOUD_INSTANCE_ID
conf_occ_sys secret                $NCLOUD_SECRET
conf_occ_sys passwordsalt          $NCLOUD_SALT

conf_occ_sys log_type              file
conf_occ_sys logfile               /ncloud/ncloud.log
conf_occ_sys loglevel              "0" # TODO: Inject config.

conf_occ_sys datadirectory         $data_directory

conf_occ_sys dbtype                pgsql
conf_occ_sys dbhost                $POSTGRES_HOST
conf_occ_sys dbname                $POSTGRES_DB
conf_occ_sys dbuser                $POSTGRES_USER
conf_occ_sys dbpassword            $POSTGRES_PW
conf_occ_sys dbtableprefix         oc_

conf_occ_sys memcache.local        "\OC\Memcache\Redis"
conf_occ_sys memcache.distributed  "\OC\Memcache\Redis"
conf_occ_sys memcache.locking      "\OC\Memcache\Redis"

conf_occ_sys overwriteprotocol     https
conf_occ_sys overwritewebroot      $NCLOUD_PATH_PREFIX
conf_occ_sys overwritehost         $NCLOUD_HOST
conf_occ_sys overwrite.cli.url     $service_url

conf_occ_sys projects.enabled      "true"

conf_occ_sys mail_from_address     $MAIL_FROM_ADDRESS
conf_occ_sys mail_smtpmode         smtp
conf_occ_sys mail_sendmailmode     smtp
conf_occ_sys mail_domain           $MAIL_DOMAIN
conf_occ_sys mail_smtphost         $MAIL_SMTP_HOST
conf_occ_sys mail_smtpport         $MAIL_SMTP_PORT
if [[ $MAIL_SMTP_USER != "" ]]; then
    conf_occ_sys mail_smtpauth     "1"
    conf_occ_sys mail_smtpsecure   "tls"
    conf_occ_sys mail_smptauthtype "LOGIN"
    conf_occ_sys mail_smtpname     $MAIL_SMTP_USER
    conf_occ_sys mail_smtppassword $MAIL_SMTP_PW
fi

conf_occ_sys installed             "true"

echo "Configuring enabled apps..."
conf_occ_sys theme                 cdsp-theme

printf "%s\n" "${disable_apps[@]}" | xargs -I {} sudo -u www-data php occ app:disable {}
printf "%s\n" "${enable_apps[@]}" | xargs -I {} sudo -u www-data php occ app:enable --force {}
# ----

# ---- App configuration.
echo "Configuring apps..."
conf_occ_app user_saml general-allow_multiple_user_back_ends    "1"
conf_occ_app user_saml type                                     "saml"

conf_occ_app cdsp restrictedgroups     $CDSP_RESTRICTED_GROUPS
conf_occ_app cdsp unassignedgroups     $CDSP_UNASSIGNED_GROUPS
conf_occ_app cdsp admingroups          $CDSP_ADMIN_GROUPS

conf_occ_app cdsp awsforceurl          $AWS_FORCE_URL
conf_occ_app cdsp awsaccesskey         $AWS_ACCESS_KEY_ID
conf_occ_app cdsp awssecretkey         $AWS_SECRET_ACCESS_KEY
conf_occ_app cdsp awsbucket            $AWS_BUCKET
conf_occ_app cdsp awsregion            ca-central-1

saml_internal_conf_json="$(echo "$SAML_INTERNAL_CONF_B64" | base64 -d)"
saml_external_conf_json="$(echo "$SAML_EXTERNAL_CONF_B64" | base64 -d)"
cat <<EOF | psql $postgres_conn_str
DELETE FROM oc_user_saml_configurations;

INSERT INTO oc_user_saml_configurations (id, name, configuration)
VALUES
(1, 'Internal IdP', '$saml_internal_conf_json'),
(2, 'External IdP', '$saml_external_conf_json');
EOF
# ----

echo "Up."
tail -f /ncloud/ncloud.log
