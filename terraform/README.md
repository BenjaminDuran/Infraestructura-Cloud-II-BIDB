# Tienda Tech - Infra Terraform (AWS Learner Lab)

Infra modular para la app `tienda-tech` (frontend Nginx + backend Node + MySQL RDS Multi-AZ) sobre AWS Academy Learner Lab.

## Arquitectura

- VPC `10.0.0.0/22` en `us-east-1` con 2 AZ.
- Subredes publicas `10.0.0.0/26` (1a) y `10.0.1.0/26` (1b).
- Subredes privadas `10.0.2.0/26` (1a) y `10.0.3.0/26` (1b).
- Internet Gateway + NAT Gateway (en subred publica 1a).
- EC2 `t3.micro` Amazon Linux 2023 en subred publica 1a, con Elastic IP.
- ECR: dos repos (`tienda-tech-backend`, `tienda-tech-frontend`).
- RDS MySQL 8.4 Multi-AZ (primaria 1a, standby 1b) en subredes privadas.
- Acceso SSH restringido a `admin_ip_cidr` (sin Session Manager).
- Instance Profile: `LabInstanceProfile` (existente en Learner Lab).

## Modulos

| Modulo     | Recursos                                              |
|------------|-------------------------------------------------------|
| `vpc`      | VPC, subredes, IGW, NAT, route tables                 |
| `security` | Key pair, SG EC2 (SSH/80/3001), SG RDS (3306 desde EC2) |
| `ecr`      | Repos ECR + lifecycle policy                          |
| `rds`      | Subnet group + db_instance MySQL Multi-AZ             |
| `ec2`      | AMI lookup + EC2 + EIP + user_data Docker            |

## Pre-requisitos

1. **AWS Learner Lab** activo. Copiar credenciales temporales (`AWS Details > AWS CLI`):
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_SESSION_TOKEN`
2. **Bucket S3** para state remoto (crearlo una vez):
   ```bash
   aws s3 mb s3://tienda-tech-tfstate-<sufijo-unico> --region us-east-1
   aws s3api put-bucket-versioning \
     --bucket tienda-tech-tfstate-<sufijo-unico> \
     --versioning-configuration Status=Enabled
   ```
3. **Key pair SSH** local:
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/tienda-tech-key -N ""
   cat ~/.ssh/tienda-tech-key.pub   # esta es ssh_public_key
   ```
4. Tu IP publica:
   ```bash
   curl -s ifconfig.me   # usar como X.X.X.X/32
   ```

## Uso local

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# editar terraform.tfvars con tu IP, key, password DB

# backend remoto (opcional pero recomendado)
cat > backend.tf <<EOF
terraform { backend "s3" {} }
EOF

terraform init \
  -backend-config="bucket=tienda-tech-tfstate-<sufijo>" \
  -backend-config="key=tienda-tech/terraform.tfstate" \
  -backend-config="region=us-east-1"

# 1) crear ECR primero
terraform apply -target=module.ecr -auto-approve

# 2) build + push imagenes
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
REG=$ACCOUNT.dkr.ecr.us-east-1.amazonaws.com
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $REG
docker build -t $REG/tienda-tech-backend:latest ../tienda-tech-backend && docker push $REG/tienda-tech-backend:latest
docker build -t $REG/tienda-tech-frontend:latest ../tienda-tech-frontend && docker push $REG/tienda-tech-frontend:latest

# 3) infra completa
terraform apply -auto-approve

# outputs
terraform output
```

## Workflows GitHub Actions

### `deploy.yml`
- Trigger: push a `main` (cambios en backend/frontend/terraform) o `workflow_dispatch`.
- Pasos: configura creds -> init -> apply ECR -> build/push imagenes -> apply full -> SSH a EC2 -> `docker compose pull && up -d`.

### `destroy.yml`
- Trigger: solo `workflow_dispatch`. Pide escribir `DESTROY` para confirmar.
- Pasos: configura creds -> init -> destroy.

### Secrets requeridos en GitHub (Settings > Secrets and variables > Actions)

| Secret                    | Descripcion                                            |
|---------------------------|--------------------------------------------------------|
| `AWS_ACCESS_KEY_ID`       | Lab credentials                                        |
| `AWS_SECRET_ACCESS_KEY`   | Lab credentials                                        |
| `AWS_SESSION_TOKEN`       | Lab credentials (renovar al iniciar nueva sesion lab)  |
| `TF_STATE_BUCKET`         | Nombre del bucket S3 para state                        |
| `ADMIN_IP_CIDR`           | Tu IP publica `/32` para SSH (ej `1.2.3.4/32`)         |
| `SSH_PUBLIC_KEY`          | Contenido `~/.ssh/tienda-tech-key.pub`                 |
| `SSH_PRIVATE_KEY`         | Contenido `~/.ssh/tienda-tech-key` (privada)           |
| `DB_PASSWORD`             | Password MySQL                                         |

## Acceso SSH

```bash
ssh -i ~/.ssh/tienda-tech-key ec2-user@<EIP>
```

Solo desde la IP definida en `admin_ip_cidr`. Si tu IP cambia: editar variable y `terraform apply`.

## Notas Learner Lab

- No se pueden crear roles IAM. Se usa `LabInstanceProfile` existente.
- Las credenciales temporales caducan al cerrar el lab; renovar `AWS_SESSION_TOKEN` y los otros secrets cada nueva sesion.
- `force_delete = true` en ECR y `skip_final_snapshot = true` en RDS para que `destroy` no falle.
- NAT Gateway tiene costo por hora; destruir cuando no se use.
