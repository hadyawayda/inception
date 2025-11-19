FROM alpine:3.19

RUN apk update && apk add --no-cache \
    nginx openssl \
    tzdata

RUN mkdir -p /run/nginx /etc/nginx/ssl /var/www && \
    chown -R nginx:nginx /run/nginx /var/www

COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY tools/init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh

WORKDIR /var/www

ENTRYPOINT ["/usr/local/bin/init.sh"]
CMD ["nginx", "-g", "daemon off;"]
