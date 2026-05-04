variable "project" {
  type = string
}

variable "region" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "key_pair_name" {
  type = string
}

variable "instance_profile_name" {
  description = "Nombre del Instance Profile (ej. LabInstanceProfile en Learner Lab)"
  type        = string
}

variable "ecr_registry" {
  type = string
}

variable "backend_repo" {
  type = string
}

variable "frontend_repo" {
  type = string
}

variable "image_tag" {
  type    = string
  default = "latest"
}

variable "db_host" {
  type = string
}

variable "db_user" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "db_name" {
  type = string
}
