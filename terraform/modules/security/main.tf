resource "aws_key_pair" "this" {
  count      = var.create_key_pair ? 1 : 0
  key_name   = var.key_pair_name
  public_key = var.ssh_public_key
}

resource "aws_security_group" "ec2" {
  name        = "${var.project}-ec2-sg"
  description = "SG EC2 app web - SSH restringido + HTTP publico"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH solo desde IP admin"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_ip_cidr]
  }

  ingress {
    description = "HTTP frontend"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Backend API"
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-ec2-sg"
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.project}-rds-sg"
  description = "SG RDS - solo EC2"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL desde EC2 SG"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-rds-sg"
  }
}
