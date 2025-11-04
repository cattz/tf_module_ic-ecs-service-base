# ========================================
# Service Outputs
# ========================================

output "service_id" {
  description = "ID of the ECS service"
  value       = module.ecs_service.id
}

output "service_name" {
  description = "Name of the ECS service"
  value       = module.ecs_service.name
}

output "service_arn" {
  description = "ARN of the ECS service"
  value       = module.ecs_service.id
}

output "task_definition_arn" {
  description = "ARN of the task definition (including revision)"
  value       = module.ecs_service.task_definition_arn
}

output "task_definition_family" {
  description = "Family of the task definition"
  value       = module.ecs_service.task_definition_family
}

output "task_definition_revision" {
  description = "Revision of the task definition"
  value       = module.ecs_service.task_definition_revision
}

# ========================================
# Security Outputs
# ========================================

output "security_group_id" {
  description = "Security group ID created by the ECS service module"
  value       = module.ecs_service.security_group_id
}

# ========================================
# Load Balancer Outputs
# ========================================

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.service.arn
}

output "target_group_name" {
  description = "Name of the target group"
  value       = aws_lb_target_group.service.name
}

# ========================================
# IAM Outputs
# ========================================

output "ecs_task_iam_role_arn" {
  description = "ARN of the ECS task IAM role"
  value       = module.ecs_iam_roles.ecs_task_iam_role_arn
}

output "ecs_task_execution_iam_role_arn" {
  description = "ARN of the ECS task execution IAM role"
  value       = module.ecs_iam_roles.ecs_task_execution_iam_role_arn
}

output "github_oidc_role_arn" {
  description = "ARN of the ECS CI/CD IAM role"
  value       = module.ecs_iam_roles.github_oidc_role_arn
}

output "ecs_task_iam_role_name" {
  description = "Name of the ECS task IAM role"
  value       = module.ecs_iam_roles.ecs_task_iam_role_name
}

output "ecs_task_execution_iam_role_name" {
  description = "Name of the ECS task execution IAM role"
  value       = module.ecs_iam_roles.ecs_task_execution_iam_role_name
}

output "github_oidc_role_name" {
  description = "Name of the ECS CI/CD IAM role"
  value       = module.ecs_iam_roles.github_oidc_role_name
}

# ========================================
# CloudWatch Outputs
# ========================================

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.ecs_task.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.ecs_task.arn
}

# ========================================
# Custom Task Definitions Outputs
# ========================================

output "custom_task_definitions" {
  description = "Map of custom task definition ARNs"
  value = {
    for key, task_def in aws_ecs_task_definition.custom : key => {
      arn      = task_def.arn
      family   = task_def.family
      revision = task_def.revision
    }
  }
}

# ========================================
# DNS Outputs
# ========================================

output "dns_records" {
  description = "Created DNS records"
  value = [
    for record in aws_route53_record.service : {
      name    = record.name
      type    = record.type
      records = record.records
      fqdn    = record.fqdn
    }
  ]
}

# ========================================
# Autoscaling Outputs
# ========================================

output "autoscaling_target_resource_id" {
  description = "Resource ID of the autoscaling target"
  value       = var.autoscaling.enabled ? aws_appautoscaling_target.ecs[0].resource_id : null
}

output "autoscaling_cpu_policy_arn" {
  description = "ARN of the CPU autoscaling policy"
  value       = var.autoscaling.enabled && var.autoscaling.cpu_target != null ? aws_appautoscaling_policy.cpu[0].arn : null
}

output "scheduled_action_scale_down_arn" {
  description = "ARN of the scale down scheduled action (null if scheduling is disabled or autoscaling is disabled)"
  value       = var.autoscaling.enabled && var.schedule != null && var.schedule.scale_down != null ? aws_appautoscaling_scheduled_action.scale_down[0].arn : null
}

output "scheduled_action_scale_up_arn" {
  description = "ARN of the scale up scheduled action (null if scheduling is disabled or autoscaling is disabled)"
  value       = var.autoscaling.enabled && var.schedule != null && var.schedule.scale_up != null ? aws_appautoscaling_scheduled_action.scale_up[0].arn : null
}

output "autoscaling_cpu_policy_name" {
  description = "Name of the CPU autoscaling policy"
  value       = var.autoscaling.enabled && var.autoscaling.cpu_target != null ? aws_appautoscaling_policy.cpu[0].name : null
}

output "autoscaling_memory_policy_arn" {
  description = "ARN of the memory autoscaling policy"
  value       = var.autoscaling.enabled && var.autoscaling.memory_target != null ? aws_appautoscaling_policy.memory[0].arn : null
}

output "autoscaling_memory_policy_name" {
  description = "Name of the memory autoscaling policy"
  value       = var.autoscaling.enabled && var.autoscaling.memory_target != null ? aws_appautoscaling_policy.memory[0].name : null
}