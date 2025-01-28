# "base" or "node_base" to have NodeJS installed.
ARG SERVICE_BASE_IMAGE=base

## Base stage. ######################################################
FROM ubuntu:jammy AS base

WORKDIR /ncloud

ENV PHP_VER_NUM 8.1
ENV PHP_VER php$PHP_VER_NUM
ENV DEBIAN_FRONTEND noninteractive

# Install base dependencies and add PHP PPA.
RUN echo rev1 && \
    apt-get update && \
    apt-get install -y software-properties-common jq && \
    add-apt-repository ppa:ondrej/php && \
    apt-get update

# Install PHP and required extensions listed in composer config.
COPY context/composer.json .

RUN echo $PHP_VER | xargs apt-get install -y

RUN cat composer.json | \
    jq -r '.require | keys[]' | \
    # Not all ext-* requires have a separate installation candidate.
    sed -E 's/ext-(libxml|session|zlib|json|openssl)//g' | \
    sed -E 's/php//g' | \
    sed s/ext/$PHP_VER/g | \
    tr '\n' ' ' | \
    xargs apt-get install -y


## Node base stage. #################################################
FROM base AS node_base

ENV NODE_VERSION 22.0.0
ENV NVM_DIR /ncloud/nvm

# Install Node.
RUN apt-get install -y curl

RUN mkdir $NVM_DIR && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash && \
    . $NVM_DIR/nvm.sh && \
    nvm install $NODE_VERSION

ENV PATH $NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH


## Build stage. #####################################################
FROM node_base AS build

ENV COMPOSER_ALLOW_SUPERUSER 1

RUN apt-get install -y git

# Install Composer.
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Composer init.
COPY context/composer.lock .

RUN composer install --no-dev && \
    composer dump-autoload --optimize

# Unpack server.
COPY context/server.tar .

RUN mkdir server && \
    cd server && \
    tar -xf ../server.tar && \
    cd .. && \
    rm server.tar


## Build run stage. #################################################
FROM build AS build_run

# Frontend builds where required (some apps don't ship their built JS,
# including ours).
COPY container/build-frontend.sh build-frontend.sh

RUN ./build-frontend.sh
RUN ./build-frontend.sh announcementcenter


## Service stage. ###################################################
FROM $SERVICE_BASE_IMAGE AS service

ENV TZ America/New_York

# Install additional PHP deps.
RUN echo \
    $PHP_VER-xdebug\
    $PHP_VER-pgsql \
    $PHP_VER-fpm \
    $PHP_VER-redis \
    | xargs apt-get install -y

# Install:
# - sudo for running commands as www-data.
# - postgresql-client for configuration loading.
# - curl for self-init requests.
RUN apt-get install -y sudo postgresql-client curl

# Set up Nginx.
RUN apt-get install -y nginx
RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

# Populate service directory.
COPY --from=build_run /ncloud /ncloud

# Chown app.
RUN chown -R www-data:www-data /ncloud/server

# Load configs and boot script.
COPY container/fpm.conf /etc/php/$PHP_VER_NUM/fpm/php-fpm.conf
COPY container/fpm-pool.conf /etc/php/$PHP_VER_NUM/fpm/pool.d/www.conf
COPY container/nginx.template.conf nginx.template.conf
COPY container/boot.sh boot.sh

# Init supplimentary log.
RUN touch /ncloud/ncloud.log && \
    chown www-data:www-data /ncloud/ncloud.log

RUN apt-get install -y dos2unix
RUN dos2unix *.sh

# TEMPORARY WORKAROUND TO OUT OF DATE ESAS REGISTRATIONS ######
COPY container/patch-saml-settings.py patch-saml-settings.py

CMD python3 ./patch-saml-settings.py && ./boot.sh
###############################################################

#CMD ./boot.sh
