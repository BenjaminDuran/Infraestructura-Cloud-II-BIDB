variable "project" {
  type    = string
  default = "tienda-tech"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/22"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.0.0/26", "10.0.1.0/26"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.2.0/26", "10.0.3.0/26"]
}

variable "admin_ip_cidr" {
  description = "CIDR del admin para SSH (ej. 1.2.3.4/32)"
  type        = string
}

variable "create_key_pair" {
  type    = bool
  default = false
}

variable "key_pair_name" {
  type    = string
  default = "vockey"
}

variable "ssh_public_key" {
  description = "Clave publica SSH (cuando create_key_pair=true)"
  type        = string
  default     = ""
}

variable "instance_profile_name" {
  description = "Instance Profile - en Learner Lab usar LabInstanceProfile"
  type        = string
  default     = "LabInstanceProfile"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "db_name" {
  type    = string
  default = "tienda_tecnologica"
}

variable "db_user" {
  type    = string
  default = "admin"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "db_engine_version" {
  type    = string
  default = "8.4.3"
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_multi_az" {
  type    = bool
  default = true
}

variable "ecr_repos" {
  type    = list(string)
  default = ["tienda-tech-backend", "tienda-tech-frontend"]
}
