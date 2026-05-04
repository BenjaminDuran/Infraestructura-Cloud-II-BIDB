resource "aws_db_subnet_group" "this" {
  name       = "${var.project}-db-subnet"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.project}-db-subnet"
  }
}

resource "aws_db_instance" "this" {
  identifier              = "${var.project}-mysql"
  engine                  = "mysql"
  engine_version          = var.engine_version
  instance_class          = var.instance_class
  allocated_storage       = var.allocated_storage
  storage_type            = "gp3"
  db_name                 = var.db_name
  username                = var.db_user
  password                = var.db_password
  port                    = 3306
  multi_az                = var.multi_az
  publicly_accessible     = false
  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = [var.rds_sg_id]
  skip_final_snapshot     = true
  deletion_protection     = false
  backup_retention_period = 1
  apply_immediately       = true

  tags = {
    Name = "${var.project}-mysql"
  }
}
