data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    region        = var.region
    ecr_registry  = var.ecr_registry
    backend_repo  = var.backend_repo
    frontend_repo = var.frontend_repo
    image_tag     = var.image_tag
    db_host       = var.db_host
    db_user       = var.db_user
    db_password   = var.db_password
    db_name       = var.db_name
  })
}

resource "aws_instance" "this" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.security_group_id]
  key_name                    = var.key_pair_name
  iam_instance_profile        = var.instance_profile_name
  associate_public_ip_address = true
  user_data                   = local.user_data
  user_data_replace_on_change = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "${var.project}-app-web"
  }
}

resource "aws_eip" "this" {
  instance = aws_instance.this.id
  domain   = "vpc"

  tags = {
    Name = "${var.project}-eip"
  }
}
