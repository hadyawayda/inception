FROM debian:trixie

ENV DEBIAN_FRONTEND=noninteractive \
    WP_PATH=/var/www/html \
    PHP_FPM_POOL=/etc/php/*/fpm/pool.d/www.conf

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl tar less \
      php-fpm php-mysql php-cli php-xml php-curl php-zip php-mbstring php-gd \
      mariadb-client \
    && rm -rf /var/lib/apt/lists/*

# Prepare runtime dirs
RUN mkdir -p /run/php "${WP_PATH}" && chown -R www-data:www-data "${WP_PATH}"

# php-fpm: listen on 0.0.0.0:9000 (so NGINX can reach it later)
RUN sed -ri 's|^listen\s*=\s*.*|listen = 0.0.0.0:9000|' $PHP_FPM_POOL && \
    sed -ri 's|^;?clear_env\s*=\s*no|clear_env = no|' $PHP_FPM_POOL

# Entrypoint
COPY tools/entrypoint.sh /usr/local/bin/wp-entrypoint
RUN chmod +x /usr/local/bin/wp-entrypoint

WORKDIR ${WP_PATH}
EXPOSE 9000
ENTRYPOINT ["/usr/local/bin/wp-entrypoint"]
CMD ["php-fpm8.2", "-F"]
