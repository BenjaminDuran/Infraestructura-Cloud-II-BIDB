#!/bin/bash
exec > /var/log/user-data.log 2>&1
set -x

# Update + Docker + tools
yum update -y
yum install -y docker mariadb105 unzip jq
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
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install --update

# App dir vacio para despliegue manual posterior
mkdir -p /opt/tienda-tecnologica
chown ec2-user:ec2-user /opt/tienda-tecnologica

echo "EC2 listo. Despliegue de app pendiente." > /opt/tienda-tecnologica/README.txt
