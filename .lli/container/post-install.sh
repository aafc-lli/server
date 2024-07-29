#!/bin/bash
set -e

# Post-install script. Executed on container boot for cloud and during init for local.

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
    # 3rdparty.
    "activity"
    "announcementcenter"
    "notifications"
    # 1stparty.
    "cdsp"
)
protocol=http
cli_url=http://localhost

if [[ $LLI_ENV != "local" ]]; then
    protocol=https
    cli_url=https://$NGINX_INTERNAL_HOST

    enable_apps+=("user_saml")
fi

cd server

echo "Configuring apps..."
printf "%s\n" "${disable_apps[@]}" | xargs -I {} php occ app:disable {}
printf "%s\n" "${enable_apps[@]}" | xargs -I {} php occ app:enable --force {}

echo "Finalizing config..."
php occ config:system:set log_type --value="file"
php occ config:system:set logfile --value="/proc/self/fd/2"
php occ config:system:set loglevel --value="0" # TODO: Inject config.

php occ config:system:set redis host --value="$REDIS_HOST"
php occ config:system:set redis port --value="$REDIS_PORT"

php occ config:system:set memcache.local --value="\OC\Memcache\Redis"
php occ config:system:set memcache.distributed --value="\OC\Memcache\Redis"
php occ config:system:set memcache.locking --value="\OC\Memcache\Redis"

php occ config:system:set overwriteprotocol --value="$protocol"
php occ config:system:set overwrite.cli.url --value="$cli_url"
php occ config:system:set theme --value="cdsp-theme"

php occ config:app:set cdsp restrictedgroups --value="$CDSP_RESTRICTED_GROUPS"
php occ config:app:set cdsp unassignedgroups --value="$CDSP_UNASSIGNED_GROUPS"
php occ config:app:set cdsp admingroups --value="$CDSP_ADMIN_GROUPS"

php occ config:app:set cdsp awsaccesskey --value="$AWS_ACCESS_KEY_ID"
php occ config:app:set cdsp awssecretkey --value="$AWS_SECRET_ACCESS_KEY"
php occ config:app:set cdsp awsbucket --value="$AWS_BUCKET"
php occ config:app:set cdsp awsregion --value="ca-central-1"

# Push config.php to volume.
cp /ncloud/server/config/config.php /ncloud/conf/config.php
