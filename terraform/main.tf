data "aws_caller_identity" "current" {}

locals {
  ecr_registry = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com"
}

module "vpc" {
  source = "./modules/vpc"

  project              = var.project
  region               = var.region
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "security" {
  source = "./modules/security"

  project         = var.project
  vpc_id          = module.vpc.vpc_id
  admin_ip_cidr   = var.admin_ip_cidr
  create_key_pair = var.create_key_pair
  key_pair_name   = var.key_pair_name
  ssh_public_key  = var.ssh_public_key
}

module "ecr" {
  source = "./modules/ecr"

  project          = var.project
  repository_names = var.ecr_repos
}

module "rds" {
  source = "./modules/rds"

  project            = var.project
  private_subnet_ids = module.vpc.private_subnet_ids
  rds_sg_id          = module.security.rds_sg_id
  engine_version     = var.db_engine_version
  instance_class     = var.db_instance_class
  multi_az           = var.db_multi_az
  db_name            = var.db_name
  db_user            = var.db_user
  db_password        = var.db_password
}

module "ec2" {
  source = "./modules/ec2"

  project               = var.project
  region                = var.region
  instance_type         = var.instance_type
  subnet_id             = module.vpc.public_subnet_ids[0]
  security_group_id     = module.security.ec2_sg_id
  key_pair_name         = module.security.key_pair_name
  instance_profile_name = var.instance_profile_name

  ecr_registry  = local.ecr_registry
  backend_repo  = var.ecr_repos[0]
  frontend_repo = var.ecr_repos[1]
  image_tag     = var.image_tag

  db_host     = module.rds.endpoint
  db_user     = var.db_user
  db_password = var.db_password
  db_name     = var.db_name

  depends_on = [module.rds, module.ecr]
}
