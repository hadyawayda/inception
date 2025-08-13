# -------- Stage 1: Build environment --------
FROM debian:trixie AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Install MariaDB + tini + utilities
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        mariadb-server mariadb-client tini ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Copy configs and scripts
COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY tools/healthcheck.sh /usr/local/bin/healthcheck.sh

# Set permissions
RUN chmod +x /usr/local/bin/entrypoint.sh \
    && chmod +x /usr/local/bin/healthcheck.sh \
    && mkdir -p /var/lib/mariadb /run/mysqld \
    && chown -R mysql:mysql /var/lib/mariadb /run/mysqld \
    && chmod 0644 /etc/mysql/mariadb.conf.d/50-server.cnf \
    && chown root:root /etc/mysql/mariadb.conf.d/50-server.cnf

# -------- Stage 2: Runtime environment --------
FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive

# Copy binaries, configs, and scripts from builder
COPY --from=builder /usr/bin/mariadbd /usr/bin/mariadbd
COPY --from=builder /usr/bin/mariadb /usr/bin/mariadb
COPY --from=builder /usr/bin/mysqladmin /usr/bin/mysqladmin
COPY --from=builder /usr/bin/tini /usr/bin/tini
COPY --from=builder /etc/mysql /etc/mysql
COPY --from=builder /var/lib/mariadb /var/lib/mariadb
COPY --from=builder /usr/local/bin/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --from=builder /usr/local/bin/healthcheck.sh /usr/local/bin/healthcheck.sh

# MariaDB runtime directories
RUN mkdir -p /run/mysqld \
    && chown -R mysql:mysql /run/mysqld \
    && chmod +x /usr/local/bin/entrypoint.sh \
    && chmod +x /usr/local/bin/healthcheck.sh

EXPOSE 3306

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["mysqld"]
