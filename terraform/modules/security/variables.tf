variable "project" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "admin_ip_cidr" {
  description = "CIDR del admin (ej: 1.2.3.4/32) para SSH"
  type        = string
}

variable "create_key_pair" {
  type    = bool
  default = true
}

variable "key_pair_name" {
  type = string
}

variable "ssh_public_key" {
  description = "Clave publica SSH (solo si create_key_pair=true)"
  type        = string
  default     = ""
}
