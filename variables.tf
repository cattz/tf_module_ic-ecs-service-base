# ========================================
# Core Configuration
# ========================================

variable "resources_prefix" {
  description = "Prefix for all resources (e.g., 'theic')"
  type        = string
  default     = "theic"
}

variable "environment" {
  description = "Environment name (e.g., 'dev', 'staging', 'prod')"
  type        = string
}

variable "name_suffix" {
  description = "Suffix for the service name (e.g., 'backend', 'adminpanel')"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

# ========================================
# Network Configuration
# ========================================

variable "vpc_id" {
  description = "VPC ID where the service will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the ECS service tasks"
  type        = list(string)
}

variable "service_security_groups" {
  description = "List of security group IDs to attach to the ECS service"
  type        = list(string)
  default     = []
}

variable "additional_security_group_rules" {
  description = "Additional security group rules to create for the service"
  type = map(object({
    type                     = string # ingress or egress
    from_port                = number
    to_port                  = number
    protocol                 = string # tcp, udp, icmp, or -1 for all
    description              = optional(string)
    cidr_blocks              = optional(list(string))
    ipv6_cidr_blocks         = optional(list(string))
    source_security_group_id = optional(string)
  }))
  default = {}
}

# ========================================
# ECS Configuration
# ========================================

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "service_cpu" {
  description = "CPU units for the ECS task (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 512
}

variable "service_memory" {
  description = "Memory for the ECS task in MB (512, 1024, 2048, etc.)"
  type        = number
  default     = 1024
}

variable "desired_count" {
  description = "Desired number of tasks for the ECS service"
  type        = number
  default     = 1
}

variable "deployment_minimum_healthy_percent" {
  description = "Minimum healthy percentage during deployments"
  type        = number
  default     = 100
}

variable "deployment_maximum_percent" {
  description = "Maximum percentage during deployments"
  type        = number
  default     = 200
}

variable "enable_execute_command" {
  description = "Enable ECS Exec for debugging"
  type        = bool
  default     = true
}

# ========================================
# Container Configuration
# ========================================

variable "fluentbit_container" {
  description = "Configuration for the FluentBit log router sidecar container"
  type = object({
    image             = optional(string, "public.ecr.aws/aws-observability/aws-for-fluent-bit:stable")
    cpu               = optional(number, 128)
    memory            = optional(number, 256)
    config_bucket_arn = string
    config_files      = optional(list(string), ["parser.conf", "stream_processing.conf", "output.conf"])
  })
}

variable "containers" {
  description = "Map of container definitions. Key is the container name."
  type = map(object({
    image                    = string
    image_tag                = optional(string, "latest")
    cpu                      = number
    memory                   = number
    essential                = optional(bool, true)
    readonly_root_filesystem = optional(bool, false)

    port_mappings = optional(list(object({
      name          = string
      containerPort = number
      hostPort      = optional(number)
      protocol      = optional(string, "tcp")
      appProtocol   = optional(string)
    })), [])

    environment = optional(map(string), {})

    secrets = optional(list(object({
      name      = string
      valueFrom = string
    })), [])

    health_check = optional(object({
      command     = list(string)
      interval    = optional(number, 30)
      timeout     = optional(number, 5)
      retries     = optional(number, 3)
      startPeriod = optional(number, 60)
    }))

    depends_on_containers = optional(list(string), ["fluent-bit"])

    volumes_from = optional(list(object({
      sourceContainer = string
      readOnly        = optional(bool, false)
    })), [])

    mount_points = optional(list(object({
      sourceVolume  = string
      containerPath = string
      readOnly      = optional(bool, false)
    })), [])

    user       = optional(string)
    command    = optional(list(string))
    entrypoint = optional(list(string))
  }))
  default = {}
}

variable "primary_container" {
  description = "Configuration for the primary container (used for ALB target and Service Connect)"
  type = object({
    name           = string
    port           = number
    http_port_name = string
  })
}

variable "task_volumes" {
  description = "Volumes to attach to the ECS task"
  type = map(object({
    efs_volume_configuration = optional(object({
      file_system_id          = string
      root_directory          = optional(string, "/")
      transit_encryption      = optional(string, "ENABLED")
      transit_encryption_port = optional(number)
      authorization_config = optional(object({
        access_point_id = optional(string)
        iam             = optional(string, "DISABLED")
      }))
    }))
    host_path = optional(string)
    docker_volume_configuration = optional(object({
      scope         = optional(string)
      autoprovision = optional(bool)
      driver        = optional(string)
      driver_opts   = optional(map(string))
      labels        = optional(map(string))
    }))
  }))
  default = {}
}

# ========================================
# Custom Task Definitions
# ========================================

variable "custom_task_definitions" {
  description = "Map of custom task definitions (e.g., migrations, one-off jobs)"
  type = map(object({
    cpu    = optional(number, 512)
    memory = optional(number, 1024)

    containers = map(object({
      image                    = string
      image_tag                = optional(string, "latest")
      cpu                      = number
      memory                   = number
      essential                = optional(bool, true)
      readonly_root_filesystem = optional(bool, false)

      port_mappings = optional(list(object({
        name          = string
        containerPort = number
        hostPort      = optional(number)
        protocol      = optional(string, "tcp")
        appProtocol   = optional(string)
      })), [])

      environment = optional(map(string), {})

      secrets = optional(list(object({
        name      = string
        valueFrom = string
      })), [])

      depends_on_containers = optional(list(string), ["fluent-bit"])

      volumes_from = optional(list(object({
        sourceContainer = string
        readOnly        = optional(bool, false)
      })), [])

      mount_points = optional(list(object({
        sourceVolume  = string
        containerPath = string
        readOnly      = optional(bool, false)
      })), [])

      user       = optional(string)
      command    = optional(list(string))
      entrypoint = optional(list(string))
    }))

    task_volumes = optional(map(object({
      efs_volume_configuration = optional(object({
        file_system_id          = string
        root_directory          = optional(string, "/")
        transit_encryption      = optional(string, "ENABLED")
        transit_encryption_port = optional(number)
        authorization_config = optional(object({
          access_point_id = optional(string)
          iam             = optional(string, "DISABLED")
        }))
      }))
      host_path = optional(string)
      docker_volume_configuration = optional(object({
        scope         = optional(string)
        autoprovision = optional(bool)
        driver        = optional(string)
        driver_opts   = optional(map(string))
        labels        = optional(map(string))
      }))
    })), {})
  }))
  default = {}
}

# ========================================
# Load Balancer Configuration
# ========================================

variable "alb" {
  description = "Application Load Balancer configuration"
  type = object({
    security_group_id = string
    listener_arn      = string
    health_check = object({
      enabled             = optional(bool, true)
      path                = string
      port                = optional(string, "traffic-port")
      protocol            = optional(string, "HTTP")
      interval            = optional(number, 30)
      timeout             = optional(number, 5)
      healthy_threshold   = optional(number, 2)
      unhealthy_threshold = optional(number, 3)
      matcher             = optional(string, "200-299")
    })
    deregistration_delay = optional(number, 30)
    stickiness = optional(object({
      enabled         = optional(bool, false)
      type            = optional(string, "lb_cookie")
      cookie_duration = optional(number, 86400)
    }))
  })
}

variable "alb_listener_rules" {
  description = "ALB listener rules for routing traffic to the service"
  type = list(object({
    priority = number
    conditions = list(object({
      path_pattern = optional(object({
        values = list(string)
      }))
      host_header = optional(object({
        values = list(string)
      }))
      http_header = optional(object({
        name   = string
        values = list(string)
      }))
      http_request_method = optional(object({
        values = list(string)
      }))
      query_string = optional(list(object({
        key   = optional(string)
        value = string
      })))
      source_ip = optional(object({
        values = list(string)
      }))
    }))
  }))
  default = []
}

# ========================================
# Service Discovery
# ========================================

variable "service_discovery_namespace_arn" {
  description = "ARN of the AWS Cloud Map namespace for Service Connect"
  type        = string
}

variable "service_connect_config" {
  description = "Service Connect configuration"
  type = object({
    enabled  = optional(bool, true)
    dns_name = optional(string) # Defaults to name_suffix if not provided
  })
  default = {
    enabled = true
  }
}

# ========================================
# Auto Scaling
# ========================================

variable "autoscaling" {
  description = "ECS service autoscaling configuration"
  type = object({
    enabled      = optional(bool, true)
    min_capacity = optional(number, 1)
    max_capacity = optional(number, 4)
    cpu_target   = optional(number, 75)
    memory_target = optional(number) # Optional memory-based scaling
    scale_in_cooldown  = optional(number, 60)
    scale_out_cooldown = optional(number, 60)
  })
  default = {
    enabled      = true
    min_capacity = 1
    max_capacity = 4
    cpu_target   = 75
  }
}

# ========================================
# IAM Configuration
# ========================================

variable "ecr_repositories_arns" {
  description = "List of ECR repository ARNs for the task execution role"
  type        = list(string)
}

variable "service_secret_arns" {
  description = "List of AWS Secrets Manager secret ARNs that the task needs access to"
  type        = list(string)
  default     = []
}

variable "ecs_task_custom_policies_arns" {
  description = "List of custom IAM policy ARNs to attach to the ECS task role"
  type        = list(string)
  default     = []
}

variable "oidc_subjects" {
  description = "List of OIDC subjects for GitHub Actions CI/CD role"
  type        = list(string)
  default     = []
}

# ========================================
# DNS Configuration
# ========================================

variable "dns_zone_id" {
  description = "Route53 hosted zone ID for DNS records"
  type        = string
}

variable "dns_records" {
  description = "DNS records to create for the service"
  type = list(object({
    name    = string
    type    = string
    ttl     = optional(number, 300)
    records = list(string)
  }))
  default = []
}

# ========================================
# CloudWatch Logging
# ========================================

variable "cloudwatch_log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 7
}

# ========================================
# Tags
# ========================================

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}