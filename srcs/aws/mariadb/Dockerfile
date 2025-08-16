# Use the Debian Trixie base image
FROM debian:trixie

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    PATH="/usr/local/aws-cli/v2/current/bin:$PATH"

# Install MariaDB, tini, curl, unzip (needed for AWS CLI)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        mariadb-server mariadb-client tini ca-certificates \
        curl unzip groff less jq && \
    rm -rf /var/lib/apt/lists/*

# Install AWS CLI v2 (so entrypoint/healthcheck can pull secrets)
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf aws awscliv2.zip

# Copy MariaDB config, entrypoint script, and healthcheck script
COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY tools/healthcheck.sh /usr/local/bin/healthcheck.sh

# Fix permissions
RUN chmod +x /usr/local/bin/entrypoint.sh && \
    chmod +x /usr/local/bin/healthcheck.sh && \
    mkdir -p /var/lib/mariadb /run/mysqld && \
    chown -R mysql:mysql /var/lib/mariadb /run/mysqld && \
    chmod 0644 /etc/mysql/mariadb.conf.d/50-server.cnf && \
    chown root:root /etc/mysql/mariadb.conf.d/50-server.cnf

# Expose MariaDB default port
EXPOSE 3306

# Use tini to handle PID 1 and run the entrypoint script
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]

CMD ["mysqld"]
