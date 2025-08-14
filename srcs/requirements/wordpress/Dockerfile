FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive \
    WP_PATH=/var/www/html

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl tar less procps bash \
      php-cli php-mysql php-xml php-curl php-zip php-mbstring php-gd \
      php-fpm \
      mariadb-client \
    && rm -rf /var/lib/apt/lists/*

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
