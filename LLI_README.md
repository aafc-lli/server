# LLI NextCloud Fork

This is a fork of the NextCloud repo to which customizations are applied to meet LLI requirements.

We use Git Submodules to manage additional repositories involved in our NextCloud deployment. This includes:
- Our theme, `cdsp-theme`
- Our app, `cdsp`
- Several apps from the NextCloud ecosystem

To clone this repo, run:

```bash
git clone --recurse-submodules <repo url>
```

Clone this repo in the same directory as the `lli-infra` repo to allow the scripts in that repo to function properly:

```
/
    lli-infra/
    server/
```

# LLI Container

The `.lli` directory contains build configuration for a NextCloud container which uses Nginx as a webserver and PHP Fast Process Manager (FPM) as the PHP executor upstream.

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

Run the following in __Bash__ to build the container:

```bash
cd .lli
./build.sh <desired tag>
```

*Document incomplete*
