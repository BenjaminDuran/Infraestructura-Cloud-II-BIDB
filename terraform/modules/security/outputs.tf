output "ec2_sg_id" {
  value = aws_security_group.ec2.id
}

output "rds_sg_id" {
  value = aws_security_group.rds.id
}

output "key_pair_name" {
  value = var.create_key_pair ? aws_key_pair.this[0].key_name : var.key_pair_name
}
