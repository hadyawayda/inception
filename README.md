# Inception Project

Docker-based infrastructure with Nginx, WordPress, and MariaDB running on Alpine Linux 3.21.

## 🚀 Quick Start

### 1. Initialize the Project

Run the initialization script to set up secrets, environment variables, and data directories:

```bash
./init.sh
```

This script will:
- Create `secrets/` directory with database passwords
- Generate `srcs/.env` with all environment variables
- Create data directories at `/home/nabbas/data/`
- Add `nabbas.42.fr` to `/etc/hosts`

### 2. Build and Start Containers

```bash
make up
# OR
sudo docker compose -f srcs/docker-compose.yml up -d --build
```

### 3. Access the Site

- URL: https://nabbas.42.fr
- Admin User: `nathan` / `nathan`
- Second User: `wpuser` / `wpuser123`

## 📦 Stack Components

| Service | Base Image | Version |
|---------|------------|---------|
| Nginx | Alpine 3.21 | 1.26.3 |
| WordPress | Alpine 3.21 | Latest (PHP 8.3.19) |
| MariaDB | Alpine 3.21 | 11.4.8 |

## 🔧 Makefile Commands

```bash
make up        # Build and start all containers
make down      # Stop all containers
make clean     # Stop containers and remove volumes
make fclean    # Deep clean (prune all Docker resources)
make re        # Clean and rebuild
make ps        # Show container status
```

## 📁 Project Structure

```
inception/
├── init.sh                     # Initialization script
├── Makefile                    # Build automation
├── secrets/                    # Secret files (gitignored)
│   ├── db_password.txt
│   └── db_root_password.txt
└── srcs/
    ├── .env                    # Environment variables
    ├── docker-compose.yml      # Container orchestration
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   ├── conf/my.cnf
        │   └── tools/init-db.sh
        ├── nginx/
        │   ├── Dockerfile
        │   ├── conf/nginx.conf
        │   └── tools/init.sh
        └── wordpress/
            ├── Dockerfile
            └── tools/init.sh
```

## 🔐 Security

- Database passwords stored in `/run/secrets/` inside containers
- Secret files have `600` permissions (owner read/write only)
- Self-signed SSL certificate for HTTPS
- WordPress force-login plugin enabled

## 🗄️ Data Persistence

Data is persisted in host directories:
- `/home/nabbas/data/mariadb/` - Database files
- `/home/nabbas/data/wordpress/` - WordPress files

## 🧪 Testing

After deployment, verify all services:

```bash
# Check container status
make ps

# Test HTTPS connectivity
curl -k -I https://nabbas.42.fr

# Check logs
sudo docker logs mariadb
sudo docker logs wordpress
sudo docker logs nginx
```

## 🛠️ Troubleshooting

### Permission Denied (Docker)

If you get permission errors, add your user to the docker group:

```bash
sudo usermod -aG docker $USER
# Then log out and back in
```

### Port Already in Use

If port 443 is in use:

```bash
sudo lsof -i :443
# Kill the process or stop conflicting service
```

### Database Connection Issues

Clean data and restart:

```bash
make clean
sudo rm -rf /home/nabbas/data/mariadb/* /home/nabbas/data/wordpress/*
make up
```

## 📋 Configuration

### Environment Variables (srcs/.env)

Key configurations:
- `DOMAIN_NAME=nabbas.42.fr`
- `MYSQL_DATABASE=wordpress`
- `MYSQL_USER=wp_user`
- `WP_ADMIN_USER=nathan`
- `WP_USER_NAME=wpuser`

### Secret Files

- `secrets/db_password.txt` - WordPress database user password
- `secrets/db_root_password.txt` - MariaDB root password

Both currently set to: `admin` (change for production!)

## 🔄 Reset Everything

To completely reset the project:

```bash
make fclean
sudo rm -rf /home/nabbas/data/mariadb/* /home/nabbas/data/wordpress/*
./init.sh
make up
```

## 📝 Notes

- All containers run on Alpine Linux 3.21.5
- PHP 8.3 with OPcache enabled
- Nginx serves as reverse proxy to PHP-FPM
- MariaDB 11.4 for improved performance
- WordPress runs as `nobody` user for security

---

**42 Project - Inception**
