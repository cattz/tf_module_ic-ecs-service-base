# ========================================
# Data Sources
# ========================================

# Current AWS account information
data "aws_caller_identity" "current" {}

# ECS cluster information
data "aws_ecs_cluster" "cluster" {
  cluster_name = var.ecs_cluster_name
}