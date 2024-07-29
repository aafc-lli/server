# Local Quickstart

You must have the following dependencies installed and in your `PATH`:
* Docker
* Git + Git Bash
* JQ

First, ensure the `lli-infra` repo is cloned next to our NextCloud `server` repo:

```
<any directory>
  lli-infra/
  server/
```

Always use Git Bash when working with this NextCloud setup. In VSCode, you can open a Git Bash terminal by:
- Press Ctrl + ~ to open the terminal panel
- Click the caret next to the "+" icon at the top of the terminal panel
- Select "Git Bash"

All scripts should be run from this directory:

```bash
cd ncloud/docker/modern
```

To start NextCloud locally, run:

```bash
./local.sh up then-init
```

This builds and starts a Docker Compose of NextCloud and supporting services, then automatically initializes the database and triggers the NextCloud install.

NextCloud will now be installed and running at http://localhost. The default administrator credentials are:

```bash
Username: admin
Password: admin
```

After making a code change in your local repos, run the following to apply the changes to the deployment.

```bash
./local.sh update
```

If the change involves Vue or other built JS code, add the `rebuild-js` flag:

```bash
./local.sh update rebuild-js
```

To shut the deployment down, run:

```bash
./local.sh down
```

Or, if you want to retain all the data for next time:

```bash
./local.sh down save-vols
```

This will shut down and destroy all containers, but leave volumes in place. If you shut down this way, you do not need to re-initialize the next time you run NextCloud, so start it with simply:

```bash
./local.sh up
```

# Container

This container uses Nginx as a webserver and PHP Fast Process Manager (FPM) as the PHP executor upstream.

The filesystem layout is:

```
/ncloud
  /server              NextCloud server and plugins.
  /data                Mounted storage volume.
  /php-fpm.sock        Socket file for FPM (Nginx upstream target).
/etc/php/<version>/fpm
  /php-fpm.conf        Global FPM configuration.
  /pool.d/www.conf     FPM pool configuration.
/etc/nginx/nginx.conf  Nginx config.
```

The required runtime environment variables are:

```
NGINX_PORT               The port number Nginx should listen on.
NGINX_INTERNAL_HOST      The internal URL on which the site is hosted, without the protocol.
NGINX_EXTERNAL_HOST      The external URL on which the site is hosted, without the protocol.
NGINX_PATH_PREFIX        The URL prefix NextCloud lives on, on the hostname.
CDSP_UNASSIGNED_GROUPS   A comma-separated list of groups new users are assigned to.
CDSP_RESTRICTED_GROUPS   A comma-separated list of groups whose members logins are restricted by realm.
CDSP_ADMIN_GROUPS        A comma-separated list of groups whose members are considered administrators.
AWS_ACCESS_KEY_ID        Access Key for the AWS credential.
AWS_SECRET_ACCESS_KEY    Secret Key for the AWS credential.
AWS_BUCKET               AWS Bucket name.
```
