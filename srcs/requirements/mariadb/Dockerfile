FROM alpine:3.21

RUN apk update && apk add --no-cache \
    mariadb mariadb-client \
    tzdata

# Create run & data dirs
RUN mkdir -p /run/mysqld /var/lib/mysql && \
    chown -R mysql:mysql /run/mysqld /var/lib/mysql

COPY conf/my.cnf /etc/my.cnf
COPY tools/init-db.sh /usr/local/bin/init-db.sh

RUN chmod +x /usr/local/bin/init-db.sh

# Use exec-form CMD so mysqld is PID 1 (good Docker practice) :contentReference[oaicite:7]{index=7}
ENTRYPOINT ["/usr/local/bin/init-db.sh"]
CMD ["mysqld", "--user=mysql", "--console"]
