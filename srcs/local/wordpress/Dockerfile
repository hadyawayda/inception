# Use the Debian Bookworm base image
FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive \
    WP_PATH=/var/www/html \
    WP_CLI_ALLOW_ROOT=1

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl tar less procps unzip \
      mariadb-client \
      php8.2-cli php8.2-fpm php8.2-mysql php8.2-xml php8.2-curl php8.2-zip php8.2-mbstring php8.2-gd \
    && rm -rf /var/lib/apt/lists/*

# Install WP-CLI
RUN curl -fsSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
      -o /usr/local/bin/wp \
 && chmod +x /usr/local/bin/wp \
 && wp --info --allow-root

# Provide an unversioned php-fpm alias so CMD ["php-fpm","-F"] works
RUN set -eux; ln -sf "$(command -v php-fpm8.2)" /usr/local/sbin/php-fpm

# Make sure the WP dir exists and is owned (plugins/themes need this)
RUN mkdir -p "${WP_PATH}/wp-content/mu-plugins" && chown -R www-data:www-data "${WP_PATH}"

# Entrypoint + healthcheck
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY tools/healthcheck.sh /usr/local/bin/healthcheck.sh
COPY conf/zz-docker.conf /etc/php/8.2/fpm/pool.d/zz-docker.conf

RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh

WORKDIR ${WP_PATH}
EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php-fpm","-F"]
