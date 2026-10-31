# RDS for PostgreSQL (db.t4g.micro by default), private, encrypted, reachable only
# from the given app security group. Password is kept in Secrets Manager.
variable "name" { type = string }
variable "database" { type = string }
variable "user" { type = string }
variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "app_security_group_id" { type = string }
variable "engine_version" {
  type    = string
  default = "16"
}
variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}
variable "deletion_protection" {
  type    = bool
  default = true
}

resource "random_password" "db" {
  length  = 32
  special = false
}

resource "aws_db_subnet_group" "this" {
  name       = var.name
  subnet_ids = var.subnet_ids
}

resource "aws_security_group" "db" {
  name_prefix = "${var.name}-db-"
  description = "Postgres from the app tasks only"
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "app" {
  security_group_id            = aws_security_group.db.id
  description                  = "Postgres from app"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = var.app_security_group_id
}

resource "aws_db_instance" "this" {
  identifier                          = var.name
  engine                              = "postgres"
  engine_version                      = var.engine_version
  instance_class                      = var.instance_class
  allocated_storage                   = 20
  max_allocated_storage               = 50
  db_name                             = var.database
  username                            = var.user
  password                            = random_password.db.result
  db_subnet_group_name                = aws_db_subnet_group.this.name
  vpc_security_group_ids              = [aws_security_group.db.id]
  publicly_accessible                 = false
  storage_encrypted                   = true
  backup_retention_period             = 7
  deletion_protection                 = var.deletion_protection
  skip_final_snapshot                 = !var.deletion_protection
  final_snapshot_identifier           = var.deletion_protection ? "${var.name}-final" : null
  auto_minor_version_upgrade          = true
  copy_tags_to_snapshot               = true
  enabled_cloudwatch_logs_exports     = ["postgresql"]
  iam_database_authentication_enabled = true
  performance_insights_enabled        = true
}

resource "aws_secretsmanager_secret" "password" {
  name_prefix = "${var.name}-db-password-"
}

resource "aws_secretsmanager_secret_version" "password" {
  secret_id     = aws_secretsmanager_secret.password.id
  secret_string = random_password.db.result
}

output "host" { value = aws_db_instance.this.address }
output "port" { value = aws_db_instance.this.port }
output "database" { value = aws_db_instance.this.db_name }
output "user" { value = aws_db_instance.this.username }
output "password_secret_arn" { value = aws_secretsmanager_secret.password.arn }
output "password" {
  value     = random_password.db.result
  sensitive = true
}
