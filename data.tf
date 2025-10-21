data "aws_caller_identity" "current" {}

data "aws_ecs_cluster" "cluster" {
  cluster_name = var.ecs_cluster_name
}