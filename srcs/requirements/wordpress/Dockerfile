FROM alpine:3.19

RUN apk update && apk add --no-cache \
    php81 php81-fpm php81-mysqli php81-json php81-session \
    php81-gd php81-curl php81-xml php81-mbstring \
    php81-zip php81-opcache php81-phar php81-iconv \
    curl tar \
    netcat-openbsd \
    tzdata

# Configure PHP-FPM to listen on 0.0.0.0:9000 and increase memory limit
RUN sed -i 's|^listen = .*|listen = 0.0.0.0:9000|' /etc/php81/php-fpm.d/www.conf && \
    sed -i 's|;clear_env = no|clear_env = no|' /etc/php81/php-fpm.d/www.conf && \
    sed -i 's|memory_limit = .*|memory_limit = 256M|' /etc/php81/php.ini

WORKDIR /var/www/html

RUN mkdir -p /var/log/php81 /tmp/.wp-cli/cache && \
    chown -R nobody:nobody /var/log/php81 /var/www /tmp/.wp-cli

# Download WP-CLI
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && mv wp-cli.phar /usr/local/bin/wp && \
    ln -s /usr/bin/php81 /usr/bin/php

COPY tools/init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh

USER nobody

ENTRYPOINT ["/usr/local/bin/init.sh"]
CMD ["php-fpm81", "-F"]
