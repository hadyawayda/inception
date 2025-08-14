FROM debian:trixie

ENV DEBIAN_FRONTEND=noninteractive \
    WP_PATH=/var/www/html

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install PHP 8.4 explicitly (no guessing), plus MariaDB client
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl tar less procps bash \
      mariadb-client \
      php8.4-cli php8.4-fpm php8.4-mysql php8.4-xml php8.4-curl php8.4-zip php8.4-mbstring php8.4-gd \
    && rm -rf /var/lib/apt/lists/*

# Make sure "php-fpm" is always resolvable (symlink to the real binary)
RUN set -eux; \
    FPM="$(command -v php-fpm || command -v php-fpm8.4)"; \
    if [ -z "$FPM" ]; then echo "php-fpm not found after install" >&2; exit 1; fi; \
    ln -sf "$FPM" /usr/local/sbin/php-fpm

# Prepare runtime dirs and tune php-fpm to listen on TCP
RUN set -eux; \
    mkdir -p /run/php "$WP_PATH"; \
    chown -R www-data:www-data "$WP_PATH"; \
    pool="$(echo /etc/php/*/fpm/pool.d/www.conf)"; \
    sed -ri 's|^listen\s*=.*|listen = 0.0.0.0:9000|' "$pool"; \
    sed -ri 's|^;?clear_env\s*=.*|clear_env = no|' "$pool"; \
    sed -ri 's|^;?pid\s*=.*|pid = /run/php/php-fpm.pid|' /etc/php/*/fpm/php-fpm.conf

COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY tools/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh

WORKDIR ${WP_PATH}
EXPOSE 9000
HEALTHCHECK --interval=10s --timeout=3s --retries=5 CMD ["/usr/local/bin/healthcheck.sh"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php-fpm","-F"]
