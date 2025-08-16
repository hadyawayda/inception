FROM debian:trixie

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      nginx openssl ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

# Self-signed cert for local testing
RUN mkdir -p /etc/nginx/ssl && \
    openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
      -keyout /etc/nginx/ssl/server.key \
      -out /etc/nginx/ssl/server.crt \
      -subj "/CN=localhost"

# Your site config must point to wordpress:9000 via fastcgi_pass
COPY conf/site.conf /etc/nginx/conf.d/site.conf
COPY tools/healthcheck.sh /usr/local/bin/healthcheck.sh

RUN chmod +x /usr/local/bin/healthcheck.sh

EXPOSE 443

STOPSIGNAL SIGTERM
CMD ["nginx","-g","daemon off;"]
