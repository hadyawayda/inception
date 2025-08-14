FROM debian:trixie

ENV DEBIAN_FRONTEND=noninteractive \
    WP_PATH=/var/www/html

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl tar less procps \
      mariadb-client \
      php8.4-cli php8.4-fpm php8.4-mysql php8.4-xml php8.4-curl php8.4-zip php8.4-mbstring php8.4-gd \
    && rm -rf /var/lib/apt/lists/*

# Provide an unversioned php-fpm alias so CMD ["php-fpm","-F"] works
RUN set -eux; ln -sf "$(command -v php-fpm8.4)" /usr/local/sbin/php-fpm

# Entrypoint + healthcheck
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY tools/healthcheck.sh /usr/local/bin/healthcheck.sh
COPY conf/zz-docker.conf /etc/php/8.4/fpm/pool.d/zz-docker.conf

RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh

WORKDIR ${WP_PATH}
EXPOSE 9000
HEALTHCHECK --interval=10s --timeout=3s --retries=5 CMD ["/usr/local/bin/healthcheck.sh"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php-fpm","-F"]
