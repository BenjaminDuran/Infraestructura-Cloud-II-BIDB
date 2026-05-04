#!/bin/bash
exec > /var/log/user-data.log 2>&1
set -x

# Update + Docker
yum update -y
yum install -y docker mariadb105 jq
systemctl enable docker
systemctl start docker
usermod -aG docker ec2-user

# Docker Compose plugin
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL https://github.com/docker/compose/releases/download/v2.29.2/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
yum install -y unzip
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install --update

# App dir
APP_DIR=/opt/tienda-tecnologica
mkdir -p $APP_DIR
cd $APP_DIR

# Login ECR
aws ecr get-login-password --region ${region} | \
  docker login --username AWS --password-stdin ${ecr_registry}

# .env
cat > $APP_DIR/.env <<EOF
DB_HOST=${db_host}
DB_USER=${db_user}
DB_PASSWORD=${db_password}
DB_NAME=${db_name}
DB_PORT=3306
EOF

# docker-compose.yml
cat > $APP_DIR/docker-compose.yml <<EOF
services:
  frontend:
    image: ${ecr_registry}/${frontend_repo}:${image_tag}
    container_name: tienda-tech-frontend
    ports:
      - "80:80"
    depends_on:
      - backend
    restart: always

  backend:
    image: ${ecr_registry}/${backend_repo}:${image_tag}
    container_name: tienda-tech-backend
    env_file: .env
    ports:
      - "3001:3001"
    restart: always
EOF

# Init DB schema (idempotente) + seed si la tabla esta vacia
export MYSQL_PWD='${db_password}'
mysql -h ${db_host} -u ${db_user} <<SQL
CREATE DATABASE IF NOT EXISTS ${db_name};
USE ${db_name};
SET NAMES utf8mb4;
CREATE TABLE IF NOT EXISTS productos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100),
  descripcion VARCHAR(255),
  precio DECIMAL(10,2),
  stock INT
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
INSERT INTO productos (nombre, descripcion, precio, stock)
SELECT * FROM (
  SELECT 'Laptop Lenovo ThinkPad','Intel i5, 16GB RAM, 512GB SSD',799990,5 UNION ALL
  SELECT 'Mouse Logitech MX Master 3','Mouse inalambrico ergonomico',10990,12 UNION ALL
  SELECT 'Teclado Mecanico Redragon','Switch Blue, retroiluminado',20990,20 UNION ALL
  SELECT 'Monitor LG 27"','Full HD IPS',179990,7
) seed
WHERE NOT EXISTS (SELECT 1 FROM productos);
SQL
unset MYSQL_PWD

# Up
docker compose -f $APP_DIR/docker-compose.yml pull
docker compose -f $APP_DIR/docker-compose.yml up -d
