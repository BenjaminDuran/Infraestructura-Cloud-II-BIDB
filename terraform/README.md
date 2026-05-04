# Tienda Tech - Infra Terraform (AWS Learner Lab)

Infra modular para la app `tienda-tech` (frontend Nginx + backend Node + MySQL RDS Multi-AZ) sobre AWS Academy Learner Lab.

> **Alcance**: este Terraform y los workflows **solo provisionan la infraestructura** (red, SG, ECR, RDS, EC2 con Docker pre-instalado). El despliegue de la aplicacion (build de imagenes, push a ECR, `docker compose up` en EC2) se hace **aparte**.

## Arquitectura

- VPC `10.0.0.0/22` en `us-east-1` con 2 AZ.
- Subredes publicas `10.0.0.0/26` (1a) y `10.0.1.0/26` (1b).
- Subredes privadas `10.0.2.0/26` (1a) y `10.0.3.0/26` (1b).
- Internet Gateway + NAT Gateway (en subred publica 1a).
- EC2 `t3.micro` Amazon Linux 2023 en subred publica 1a, con Elastic IP.
- ECR: dos repos vacios (`tienda-tech-backend`, `tienda-tech-frontend`).
- RDS MySQL 8.4 Multi-AZ (primaria 1a, standby 1b) en subredes privadas.
- Acceso SSH restringido a `admin_ip_cidr` (sin Session Manager).
- Instance Profile: `LabInstanceProfile` (existente en Learner Lab).

## Modulos

| Modulo     | Recursos                                                     |
|------------|--------------------------------------------------------------|
| `vpc`      | VPC, subredes, IGW, NAT, route tables                        |
| `security` | Key pair (opcional), SG EC2 (SSH/80/3001), SG RDS (3306)     |
| `ecr`      | Repos ECR + lifecycle policy (mantiene 5 imagenes)           |
| `rds`      | Subnet group + db_instance MySQL Multi-AZ                    |
| `ec2`      | AMI lookup + EC2 + EIP + user_data minimo (docker + tools)   |

## user_data EC2

Solo instala:
- Docker + plugin `docker compose`
- AWS CLI v2
- Cliente MySQL (`mariadb105`)
- Crea `/opt/tienda-tecnologica/` (vacio, listo para despliegue manual)

No genera `docker-compose.yml`, no hace login a ECR, no inicializa la DB.

## Pre-requisitos

1. **AWS Learner Lab** activo. Copiar credenciales temporales (`AWS Details > AWS CLI`):
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_SESSION_TOKEN`
2. **Bucket S3** para state remoto (crearlo una vez):
   ```bash
   aws s3 mb s3://tfstate-tienda-tech-<sufijo> --region us-east-1
   aws s3api put-bucket-versioning \
     --bucket tfstate-tienda-tech-<sufijo> \
     --versioning-configuration Status=Enabled
   aws s3api put-public-access-block \
     --bucket tfstate-tienda-tech-<sufijo> \
     --public-access-block-configuration \
     "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
   ```
3. **Key pair SSH del Lab** (`vockey`):
   - En AWS Details > Download PEM > guarda como `labsuser.pem`.
   - `chmod 400 labsuser.pem`
   - Esta key ya existe en EC2 como `vockey`. No se crea via Terraform.
4. Tu IP publica:
   ```bash
   curl -s ifconfig.me   # usar como X.X.X.X/32
   ```

## Uso local

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# editar terraform.tfvars con tu IP, password DB

# backend remoto
cat > backend.tf <<EOF
terraform { backend "s3" {} }
EOF

terraform init \
  -backend-config="bucket=tfstate-tienda-tech-<sufijo>" \
  -backend-config="key=tienda-tech/terraform.tfstate" \
  -backend-config="region=us-east-1"

terraform apply -auto-approve

# outputs (IPs, endpoints, registry)
terraform output
```

## Workflows GitHub Actions

### `deploy.yml` - solo infra
- Trigger: push de tag `v*.*.*` (ej `v0.1.0`) o `workflow_dispatch`.
- Pasos: configura creds -> init backend S3 -> `terraform apply` -> imprime outputs.
- **No** construye ni publica imagenes. **No** hace SSH a EC2.

**Lanzar despliegue de infra**:
```bash
git tag v0.1.0
git push origin v0.1.0
```

### `destroy.yml` - destruccion manual
- Trigger: solo `workflow_dispatch`. Requiere escribir `DESTROY` para confirmar.
- Pasos: configura creds -> init -> `terraform destroy`.

### Secrets requeridos en GitHub (Settings > Secrets and variables > Actions)

| Secret                    | Descripcion                                            |
|---------------------------|--------------------------------------------------------|
| `AWS_ACCESS_KEY_ID`       | Lab credentials                                        |
| `AWS_SECRET_ACCESS_KEY`   | Lab credentials                                        |
| `AWS_SESSION_TOKEN`       | Lab credentials (renovar al iniciar nueva sesion lab)  |
| `TF_STATE_BUCKET`         | Nombre del bucket S3 para state                        |
| `ADMIN_IP_CIDR`           | Tu IP publica `/32` para SSH (ej `1.2.3.4/32`)         |
| `DB_PASSWORD`             | Password MySQL (sin `/ @ " '` ni espacios)             |

## Despliegue de la aplicacion (manual, post-infra)

Cuando `terraform apply` termina, EC2 esta lista pero sin app. Pasos:

```bash
# Outputs utiles
EIP=$(terraform output -raw ec2_public_ip)
RDS=$(terraform output -raw rds_endpoint)
REG=$(terraform output -raw ecr_registry)

# 1. Build + push imagenes desde tu maquina local
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $REG
docker build -t $REG/tienda-tech-backend:latest ../tienda-tech-backend
docker build -t $REG/tienda-tech-frontend:latest ../tienda-tech-frontend
docker push $REG/tienda-tech-backend:latest
docker push $REG/tienda-tech-frontend:latest

# 2. SSH a EC2 (con la key vockey del Lab)
ssh -i labsuser.pem ec2-user@$EIP

# 3. Dentro de EC2: crear .env + docker-compose.yml + up
cd /opt/tienda-tecnologica

cat > .env <<EOF
DB_HOST=<rds-endpoint>
DB_USER=admin
DB_PASSWORD=<tu-password>
DB_NAME=tienda_tecnologica
DB_PORT=3306
EOF

cat > docker-compose.yml <<EOF
services:
  frontend:
    image: <registry>/tienda-tech-frontend:latest
    container_name: tienda-tech-frontend
    ports: ["80:80"]
    depends_on: [backend]
    restart: always
  backend:
    image: <registry>/tienda-tech-backend:latest
    container_name: tienda-tech-backend
    env_file: .env
    ports: ["3001:3001"]
    restart: always
EOF

# 4. Init DB
mysql -h <rds-endpoint> -u admin -p < init.sql

# 5. Login ECR + up
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <registry>
docker compose pull
docker compose up -d
docker ps
```

## Acceso SSH

```bash
chmod 400 labsuser.pem
ssh -i labsuser.pem ec2-user@<EIP>
```

Solo desde la IP definida en `admin_ip_cidr`. Si tu IP cambia: actualiza secret `ADMIN_IP_CIDR` y re-corre el workflow.

## Notas Learner Lab

- No se pueden crear roles IAM. Se usa `LabInstanceProfile` existente.
- Las credenciales temporales caducan al cerrar el lab; renovar `AWS_SESSION_TOKEN` y otros secrets cada nueva sesion.
- `force_delete = true` en ECR y `skip_final_snapshot = true` en RDS para que `destroy` no falle.
- NAT Gateway tiene costo por hora (~$0.045/h); destruir cuando no se use.
- RDS Multi-AZ tarda 10-20 min en provisionar.
