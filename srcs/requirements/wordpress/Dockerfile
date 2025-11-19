FROM alpine:3.19

RUN apk update && apk add --no-cache \
    php81 php81-fpm php81-mysqli php81-json php81-session \
    php81-gd php81-curl php81-xml php81-mbstring \
    php81-zip php81-opcache \
    curl tar \
    tzdata

# Configure PHP-FPM to listen on 0.0.0.0:9000
RUN sed -i 's|^listen = .*|listen = 0.0.0.0:9000|' /etc/php81/php-fpm.d/www.conf && \
    sed -i 's|;clear_env = no|clear_env = no|' /etc/php81/php-fpm.d/www.conf

WORKDIR /var/www

# Download WordPress
RUN curl -o wordpress.tar.gz https://wordpress.org/latest.tar.gz && \
    tar -xzf wordpress.tar.gz && rm wordpress.tar.gz && \
    chown -R nobody:nobody wordpress

COPY tools/init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh

USER nobody

ENTRYPOINT ["/usr/local/bin/init.sh"]
CMD ["php-fpm81", "-F"]
