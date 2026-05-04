output "ec2_public_ip" {
  value       = module.ec2.public_ip
  description = "IP publica EIP - frontend en http://<ip>"
}

output "frontend_url" {
  value = "http://${module.ec2.public_ip}"
}

output "backend_url" {
  value = "http://${module.ec2.public_ip}:3001"
}

output "ssh_command" {
  value = "ssh -i ${var.key_pair_name}.pem ec2-user@${module.ec2.public_ip}"
}

output "rds_endpoint" {
  value = module.rds.endpoint
}

output "ecr_registry" {
  value = local.ecr_registry
}

output "ecr_backend_repo_url" {
  value = module.ecr.repository_urls[var.ecr_repos[0]]
}

output "ecr_frontend_repo_url" {
  value = module.ecr.repository_urls[var.ecr_repos[1]]
}

output "vpc_id" {
  value = module.vpc.vpc_id
}
