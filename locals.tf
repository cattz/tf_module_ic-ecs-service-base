locals {
  # Service naming
  service_name = "${var.resources_prefix}-${var.environment}-${var.name_suffix}"

  # CloudWatch log group
  log_group_name = "/${var.resources_prefix}/${var.environment}/${var.name_suffix}"

  # Service Connect DNS name
  service_connect_dns_name = coalesce(
    try(var.service_connect_config.dns_name, null),
    var.name_suffix
  )

  # Build complete container definitions including FluentBit
  container_definitions = merge(
    {
      "fluent-bit" = {
        cpu       = var.fluentbit_container.cpu
        memory    = var.fluentbit_container.memory
        essential = true
        image     = var.fluentbit_container.image
        firelens_configuration = {
          type = "fluentbit"
        }
        readonly_root_filesystem = false
        propagate_tags           = "SERVICE"

        log_configuration = {
          logDriver = "awslogs"
          options = {
            "awslogs-group"         = aws_cloudwatch_log_group.ecs_task.name
            "awslogs-region"        = var.region
            "awslogs-stream-prefix" = "fluentbit"
          }
        }

        health_check = {
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
          [
            {
              name  = "CLOUDWATCH_LOG_GROUP"
              value = aws_cloudwatch_log_group.ecs_task.name
            }
          ]
        )
      }
    },
    {
      for name, container in var.containers : name => merge(
        {
          cpu                      = container.cpu
          memory                   = container.memory
          essential                = container.essential
          image                    = "${container.image}:${container.image_tag}"
          readonly_root_filesystem = container.readonly_root_filesystem
          propagate_tags           = "SERVICE"

          enable_cloudwatch_logging = false
          log_configuration = {
            logDriver = "awsfirelens"
          }

          port_mappings = container.port_mappings

          environment = [
            for key, value in container.environment : {
              name  = key
              value = value
            }
          ]

          secrets = container.secrets

          dependencies = [
            for dep_name in container.depends_on_containers : {
              containerName = dep_name
              condition     = "START"
            }
          ]

          volumes_from = container.volumes_from
          mount_points = container.mount_points
        },
        container.user != null ? { user = container.user } : {},
        container.command != null ? { command = container.command } : {},
        container.entrypoint != null ? { entrypoint = container.entrypoint } : {},
        container.health_check != null ? { health_check = container.health_check } : {}
      )
    }
  )

  # Common tags
  common_tags = merge(
    {
      Environment    = var.environment
      Service        = local.service_name
      ManagedBy      = "Terraform"
      ResourcePrefix = var.resources_prefix
    },
    var.tags
  )
}

# Security group rules are managed by the ECS service module
# Additional custom rules can be passed via var.additional_security_group_rules

locals {
  # Base security group rules
  base_security_group_rules_ingress = merge(
    # Ingress from ALB to primary container
    {
      ingress_alb_primary = {
        name                         = "AllowFromALB"
        from_port                    = var.primary_container.port
        to_port                      = var.primary_container.port
        ip_protocol                  = "tcp"
        referenced_security_group_id = var.alb.security_group_id
      }
    },
    # Ingress for health check if different port
    var.alb.health_check.port != "traffic-port" && tonumber(var.alb.health_check.port) != var.primary_container.port ?
    {
      ingress_alb_healthcheck = {
        name                         = "AllowHealthCheckFromALB"
        from_port                    = tonumber(var.alb.health_check.port)
        to_port                      = tonumber(var.alb.health_check.port)
        protocol                     = "tcp"
        referenced_security_group_id = var.alb.security_group_id
      }
    } : {},
    # Additional custom rules
    var.additional_security_group_rules
  )
  base_security_group_rules_egress = {
    egress_all_v4 = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
    egress_all_v6 = {
      ip_protocol = "-1"
      cidr_ipv6   = "::/0"
    }
  }
}