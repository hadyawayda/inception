FROM debian:trixie

ENV DEBIAN_FRONTEND=noninteractive \
    WP_PATH=/var/www/html \
    WP_CLI_ALLOW_ROOT=1 \
    PATH="/usr/local/aws-cli/v2/current/bin:$PATH"

# Install PHP, MariaDB client, curl, unzip, and dependencies for AWS CLI
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl tar less procps unzip jq groff less \
      mariadb-client \
      php8.4-cli php8.4-fpm php8.4-mysql php8.4-xml php8.4-curl php8.4-zip php8.4-mbstring php8.4-gd \
    && rm -rf /var/lib/apt/lists/*

# Install WP-CLI
RUN curl -fsSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
      -o /usr/local/bin/wp \
 && chmod +x /usr/local/bin/wp \
 && wp --info --allow-root

# Install AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
 && unzip awscliv2.zip \
 && ./aws/install \
 && rm -rf aws awscliv2.zip

# Provide an unversioned php-fpm alias so CMD ["php-fpm","-F"] works
RUN set -eux; ln -sf "$(command -v php-fpm8.4)" /usr/local/sbin/php-fpm

# Make sure the WP dir exists and is owned (plugins/themes need this)
RUN mkdir -p "${WP_PATH}/wp-content/mu-plugins" && chown -R www-data:www-data "${WP_PATH}"

# Entrypoint + healthcheck
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY tools/healthcheck.sh /usr/local/bin/healthcheck.sh
COPY conf/zz-docker.conf /etc/php/8.4/fpm/pool.d/zz-docker.conf

RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh

WORKDIR ${WP_PATH}
EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php-fpm","-F"]
