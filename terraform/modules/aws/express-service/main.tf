# One Amazon ECS Express Mode service (Fargate + ALB + HTTPS + autoscaling, all
# managed by ECS). AWS recommends Express Mode for new customers now that App
# Runner is closed to them (April 30, 2026).
variable "name" { type = string }
variable "cluster" { type = string }
variable "image" { type = string }
variable "port" {
  type    = number
  default = 8080
}
variable "env" {
  type    = map(string)
  default = {}
}
variable "secret_env" {
  description = "ENV_NAME => Secrets Manager secret ARN."
  type        = map(string)
  default     = {}
}
variable "cpu" {
  type    = string
  default = "512"
}
variable "memory" {
  type    = string
  default = "1024"
}
variable "min_tasks" {
  type    = number
  default = 1
}
variable "max_tasks" {
  type    = number
  default = 2
}
variable "health_path" {
  type    = string
  default = "/"
}
variable "subnet_ids" { type = list(string) }
variable "security_group_ids" { type = list(string) }

data "aws_iam_policy_document" "tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ecs_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name_prefix        = substr("${var.name}-exec-", 0, 38)
  assume_role_policy = data.aws_iam_policy_document.tasks_assume.json
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "secrets" {
  count = length(var.secret_env) > 0 ? 1 : 0
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = values(var.secret_env)
  }
}

resource "aws_iam_role_policy" "secrets" {
  count  = length(var.secret_env) > 0 ? 1 : 0
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.secrets[0].json
}

resource "aws_iam_role" "infrastructure" {
  name_prefix        = substr("${var.name}-infra-", 0, 38)
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}

resource "aws_iam_role_policy_attachment" "infrastructure" {
  role       = aws_iam_role.infrastructure.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSInfrastructureRoleforExpressGatewayServices"
}

resource "aws_ecs_express_gateway_service" "this" {
  service_name            = var.name
  cluster                 = var.cluster
  execution_role_arn      = aws_iam_role.execution.arn
  infrastructure_role_arn = aws_iam_role.infrastructure.arn
  cpu                     = var.cpu
  memory                  = var.memory
  health_check_path       = var.health_path
  network_configuration = [{
    subnets         = var.subnet_ids
    security_groups = var.security_group_ids
  }]
  scaling_target = [{
    auto_scaling_metric       = "AVERAGE_CPU"
    auto_scaling_target_value = 60
    min_task_count            = var.min_tasks
    max_task_count            = var.max_tasks
  }]
  primary_container {
    image          = var.image
    container_port = var.port
    dynamic "environment" {
      for_each = var.env
      content {
        name  = environment.key
        value = environment.value
      }
    }
    dynamic "secret" {
      for_each = var.secret_env
      content {
        name       = secret.key
        value_from = secret.value
      }
    }
  }
  # Keep the policies until the service is gone (see the provider docs).
  depends_on = [aws_iam_role_policy_attachment.execution, aws_iam_role_policy_attachment.infrastructure, aws_iam_role_policy.secrets]
}

output "url" {
  value = try("https://${aws_ecs_express_gateway_service.this.ingress_paths[0].endpoint}", null)
}
