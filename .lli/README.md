# LLI Nextcloud Container

This container uses Nginx as a webserver and PHP Fast Process Manager (FPM) as the PHP executor upstream.

The filesystem layout is:

```
/ncloud
  /server              Nextcloud server and plugins.
  /data                Mounted storage volume.
  /php-fpm.sock        Socket file for FPM (Nginx upstream target).
/etc/php/<version>/fpm
  /php-fpm.conf        Global FPM configuration.
  /pool.d/www.conf     FPM pool configuration.
/etc/nginx/nginx.conf  Nginx config.
```

[TODO: Expand doc.]
