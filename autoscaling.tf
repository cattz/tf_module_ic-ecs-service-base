# ========================================
# ECS Service Autoscaling
# ========================================

# Autoscaling target for the ECS service
resource "aws_appautoscaling_target" "ecs" {
  count = var.autoscaling.enabled ? 1 : 0

  max_capacity       = var.autoscaling.max_capacity
  min_capacity       = var.autoscaling.min_capacity
  resource_id        = "service/${var.ecs_cluster_name}/${local.service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  # Ensure the service is created before the autoscaling target
  depends_on = [module.ecs_service]

  tags = local.common_tags
}

# CPU-based autoscaling policy
resource "aws_appautoscaling_policy" "cpu" {
  count = var.autoscaling.enabled && var.autoscaling.cpu_target != null ? 1 : 0

  name               = "${local.service_name}-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs[0].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = var.autoscaling.cpu_target
    scale_in_cooldown  = var.autoscaling.scale_in_cooldown
    scale_out_cooldown = var.autoscaling.scale_out_cooldown

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

# Memory-based autoscaling policy (optional)
resource "aws_appautoscaling_policy" "memory" {
  count = var.autoscaling.enabled && var.autoscaling.memory_target != null ? 1 : 0

  name               = "${local.service_name}-memory-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs[0].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = var.autoscaling.memory_target
    scale_in_cooldown  = var.autoscaling.scale_in_cooldown
    scale_out_cooldown = var.autoscaling.scale_out_cooldown

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }
}
