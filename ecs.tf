module "ecs_service" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "~> 6.6" # Use latest 6.x version with bug fixes

  name        = local.service_name
  cluster_arn = data.aws_ecs_cluster.cluster.arn
  cpu         = var.service_cpu
  memory      = var.service_memory

  # Enable ECS Exec for debugging
  enable_execute_command = var.enable_execute_command

  propagate_tags = "SERVICE"

  # Network configuration
  subnet_ids                   = var.subnet_ids
  security_group_ids           = var.service_security_groups
  security_group_ingress_rules = local.base_security_group_rules_ingress
  security_group_egress_rules  = local.base_security_group_rules_egress

  # IAM roles
  create_iam_role = false
  iam_role_arn    = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/ecs.amazonaws.com/AWSServiceRoleForECS"

  create_tasks_iam_role = false
  tasks_iam_role_arn    = module.ecs_iam_roles.ecs_task_iam_role_arn

  create_task_exec_iam_role = false
  create_task_exec_policy   = false
  task_exec_iam_role_arn    = module.ecs_iam_roles.ecs_task_execution_iam_role_arn

  # Deployment configuration
  enable_autoscaling                 = false # Managed separately for more control
  desired_count                      = var.desired_count
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  deployment_maximum_percent         = var.deployment_maximum_percent

  # Circuit breaker for safer deployments
  deployment_circuit_breaker = var.deployment_circuit_breaker

  # Task volumes
  volume = {
    for volume_name, volume_config in var.task_volumes : volume_name => merge(
      {
        name = volume_name
      },
      volume_config.efs_volume_configuration != null ? {
        efs_volume_configuration = volume_config.efs_volume_configuration
      } : {},
      volume_config.host_path != null ? {
        host_path = volume_config.host_path
      } : {},
      volume_config.docker_volume_configuration != null ? {
        docker_volume_configuration = volume_config.docker_volume_configuration
      } : {}
    )
  }

  # Container definitions
  container_definitions = local.container_definitions

  # Service Connect configuration
  service_connect_configuration = var.service_connect_config.enabled ? {
    namespace = var.service_discovery_namespace_arn
    service = [{
      client_alias = {
        port     = var.primary_container.port
        dns_name = local.service_connect_dns_name
      }
      port_name      = var.primary_container.http_port_name
      discovery_name = local.service_name
    }]
  } : null

  # Load balancer integration
  load_balancer = {
    service = {
      target_group_arn = aws_lb_target_group.service.arn
      container_name   = var.primary_container.name
      container_port   = var.primary_container.port
    }
  }

  tags = local.common_tags
}