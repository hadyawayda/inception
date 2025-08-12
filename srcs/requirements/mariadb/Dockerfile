# Use the Debian Trixie base image
FROM debian:trixie

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install MariaDB and necessary utilities
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        mariadb-server mariadb-client tini ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Copy MariaDB config and entrypoint script
COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh

# Make sure the entrypoint script is executable
RUN chmod +x /usr/local/bin/entrypoint.sh && \
    mkdir -p /var/lib/mariadb /run/mysqld && \
    chown -R mysql:mysql /var/lib/mariadb /run/mysqld

# Expose MariaDB default port
EXPOSE 3306

# Use tini to handle PID 1 and run the entrypoint script
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]

CMD ["mysqld"]
