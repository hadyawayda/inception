FROM alpine:3.21

RUN apk update && apk add --no-cache \
    php83 php83-fpm php83-mysqli php83-json php83-session \
    php83-gd php83-curl php83-xml php83-mbstring \
    php83-zip php83-opcache php83-phar php83-iconv php83-tokenizer \
    curl tar \
    netcat-openbsd \
    tzdata

# Configure PHP-FPM to listen on 0.0.0.0:9000 and increase memory limit
RUN sed -i 's|^listen = .*|listen = 0.0.0.0:9000|' /etc/php83/php-fpm.d/www.conf && \
    sed -i 's|;clear_env = no|clear_env = no|' /etc/php83/php-fpm.d/www.conf && \
    sed -i 's|memory_limit = .*|memory_limit = 256M|' /etc/php83/php.ini

WORKDIR /var/www/html

RUN mkdir -p /var/log/php83 /tmp/.wp-cli/cache && \
    chown -R nobody:nobody /var/log/php83 /var/www /tmp/.wp-cli

# Download WP-CLI
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && mv wp-cli.phar /usr/local/bin/wp && \
    ln -sf /usr/bin/php83 /usr/bin/php

COPY tools/init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh

USER nobody

ENTRYPOINT ["/usr/local/bin/init.sh"]
CMD ["php-fpm83", "-F"]
