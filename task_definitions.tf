# Custom task definitions (e.g., for migrations, one-off jobs)
module "custom_task_definition" {
  source  = "terraform-aws-modules/ecs/aws//modules/container-definition"
  version = "5.12.1"

  for_each = var.custom_task_definitions

  name       = "${local.service_name}-${each.key}"
  cpu        = each.value.cpu
  memory     = each.value.memory
  essential  = true

  # This module is used to generate task definition JSON
  # The actual task definition resource is created below
}

resource "aws_ecs_task_definition" "custom" {
  for_each = var.custom_task_definitions

  family                   = "${local.service_name}-${each.key}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = each.value.cpu
  memory                   = each.value.memory

  task_role_arn      = module.ecs_iam_roles.ecs_task_iam_role_arn
  execution_role_arn = module.ecs_iam_roles.ecs_task_execution_iam_role_arn

  # Build container definitions including FluentBit
  container_definitions = jsonencode(concat(
    # FluentBit container
    [{
      name      = "fluent-bit"
      cpu       = var.fluentbit_container.cpu
      memory    = var.fluentbit_container.memory
      essential = true
      image     = var.fluentbit_container.image

      firelensConfiguration = {
        type = "fluentbit"
      }

      readonlyRootFilesystem = false

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_task.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "fluentbit-${each.key}"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "nc -z localhost 24224 || exit 1"]
        interval    = 10
        timeout     = 5
        startPeriod = 30
        retries     = 3
      }

      environment = concat(
        [
          for idx, config_file in var.fluentbit_container.config_files : {
          name  = "aws_fluent_bit_init_s3_${idx + 1}"
          value = "${var.fluentbit_container.config_bucket_arn}/${config_file}"
        }
        ],
        [{
          name  = "CLOUDWATCH_LOG_GROUP"
          value = aws_cloudwatch_log_group.ecs_task.name
        }]
      )
    }],
    # Custom containers
    [
      for container_name, container_config in each.value.containers : merge(
      {
        name                   = container_name
        cpu                    = container_config.cpu
        memory                 = container_config.memory
        essential              = container_config.essential
        image                  = "${container_config.image}:${container_config.image_tag}"
        readonlyRootFilesystem = container_config.readonly_root_filesystem

        logConfiguration = {
          logDriver = "awsfirelens"
        }

        portMappings = [
          for pm in container_config.port_mappings : {
            name          = pm.name
            containerPort = pm.containerPort
            hostPort      = try(pm.hostPort, pm.containerPort)
            protocol      = try(pm.protocol, "tcp")
            appProtocol   = try(pm.appProtocol, null)
          }
        ]

        environment = [
          for key, value in container_config.environment : {
            name  = key
            value = value
          }
        ]

        secrets = container_config.secrets

        dependsOn = [
          for dep_name in container_config.depends_on_containers : {
            containerName = dep_name
            condition     = "START"
          }
        ]

        volumesFrom  = container_config.volumes_from
        mountPoints  = container_config.mount_points
      },
        container_config.user != null ? { user = container_config.user } : {},
        container_config.command != null ? { command = container_config.command } : {},
        container_config.entrypoint != null ? { entryPoint = container_config.entrypoint } : {}
    )
    ]
  ))

  # Task volumes
  dynamic "volume" {
    for_each = each.value.task_volumes

    content {
      name = volume.key

      dynamic "efs_volume_configuration" {
        for_each = volume.value.efs_volume_configuration != null ? [volume.value.efs_volume_configuration] : []
        content {
          file_system_id          = efs_volume_configuration.value.file_system_id
          root_directory          = efs_volume_configuration.value.root_directory
          transit_encryption      = efs_volume_configuration.value.transit_encryption
          transit_encryption_port = efs_volume_configuration.value.transit_encryption_port

          dynamic "authorization_config" {
            for_each = efs_volume_configuration.value.authorization_config != null ? [efs_volume_configuration.value.authorization_config] : []
            content {
              access_point_id = authorization_config.value.access_point_id
              iam             = authorization_config.value.iam
            }
          }
        }
      }

      dynamic "docker_volume_configuration" {
        for_each = volume.value.docker_volume_configuration != null ? [volume.value.docker_volume_configuration] : []
        content {
          scope         = docker_volume_configuration.value.scope
          autoprovision = docker_volume_configuration.value.autoprovision
          driver        = docker_volume_configuration.value.driver
          driver_opts   = docker_volume_configuration.value.driver_opts
          labels        = docker_volume_configuration.value.labels
        }
      }
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name        = "${local.service_name}-${each.key}"
      TaskType    = each.key
    }
  )
}