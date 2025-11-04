# ========================================
# CloudWatch Logs
# ========================================

# CloudWatch log group for ECS task logs
resource "aws_cloudwatch_log_group" "ecs_task" {
  name              = local.log_group_name
  retention_in_days = var.cloudwatch_log_retention_days

  tags = local.common_tags
}