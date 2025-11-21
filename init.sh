# 1. Navigate to project in WSL
cd "/home/nabbas/sgoinfre/inception"

# 2. Create data directories
mkdir -p /home/nabbas/data/mariadb /home/nabbas/data/wordpress

# 3. Add domain to /etc/hosts
echo "127.0.0.1 nabbas.42.fr" | sudo tee -a /etc/hosts

# 4. Clean and rebuild
make clean
make up

# 5. Check containers are running
docker ps
docker-compose -f srcs/docker-compose.yml ps