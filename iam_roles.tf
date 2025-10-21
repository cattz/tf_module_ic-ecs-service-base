module "ecs_iam_roles" {
  source = "git@github.com:theinnercircle/tf_module_ecs-iam-roles.git?ref=main"

  resources_prefix = var.resources_prefix
  environment      = var.environment
  name_suffix      = var.name_suffix
  ecs_cluster_arn  = data.aws_ecs_cluster.cluster.arn

  ecs_services_ci_arns = [module.ecs_service.id]

  ecs_services_ci_task_definitions_arns = [
    # Wildcard for task definition revisions to work with GitHub Actions
    "*"
  ]

  ecs_task_log_group_arn      = aws_cloudwatch_log_group.ecs_task.arn
  ecr_repositories_arns       = var.ecr_repositories_arns
  oidc_subjects               = var.oidc_subjects
  fluentbit_config_bucket_arn = var.fluentbit_container.config_bucket_arn

  service_secret_arns           = var.service_secret_arns
  ecs_task_custom_policies_arns = var.ecs_task_custom_policies_arns
}