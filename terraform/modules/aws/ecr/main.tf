# One ECR repository per image name, scan on push, keep the last N images.
variable "names" { type = list(string) }
variable "prefix" { type = string }
variable "keep_recent" {
  type    = number
  default = 10
}

resource "aws_ecr_repository" "this" {
  for_each             = toset(var.names)
  name                 = "${var.prefix}/${each.value}"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = false
  image_scanning_configuration {
    scan_on_push = true
  }
  encryption_configuration {
    encryption_type = "KMS"
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "keep the most recent images"
      selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = var.keep_recent }
      action       = { type = "expire" }
    }]
  })
}

output "repository_urls" { value = { for k, r in aws_ecr_repository.this : k => r.repository_url } }
output "registry" { value = split("/", values(aws_ecr_repository.this)[0].repository_url)[0] }
