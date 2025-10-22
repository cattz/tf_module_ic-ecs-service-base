# IC ECS Service Base Module

A comprehensive Terraform module for deploying ECS Fargate services with standardized configuration and best practices. This base module provides all common infrastructure for ECS services while allowing customization through wrapper modules.

## Features

- ✅ **Standardized ECS Service**: Pre-configured Fargate service with best practices
- ✅ **Automatic FluentBit Logging**: Built-in log aggregation and forwarding
- ✅ **Flexible Container Support**: Define any number of containers with custom configurations
- ✅ **Custom Task Definitions**: Support for migrations, one-off jobs, and other custom tasks
- ✅ **ALB Integration**: Automatic target group and listener rule configuration
- ✅ **Auto-scaling**: CPU and memory-based autoscaling support
- ✅ **Service Discovery**: AWS Cloud Map integration for service-to-service communication
- ✅ **IAM Role Management**: Integrated with ecs-iam-roles module
- ✅ **DNS Management**: Route53 record creation
- ✅ **Security Groups**: Configurable security group rules
- ✅ **ECS Exec**: Enabled for debugging and troubleshooting

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         ALB                                  │
│                    (Listener Rules)                          │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                    Target Group                              │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                    ECS Service                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                    Task Definition                      │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │ │
│  │  │  FluentBit   │  │  Container 1 │  │  Container N │ │ │
│  │  │  (Logging)   │  │              │  │              │ │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘ │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                Service Discovery (Cloud Map)                 │
└─────────────────────────────────────────────────────────────┘
```

## Usage

### Basic Example

```hcl
module "backend_service" {
  source = "git@github.com:theinnercircle/tf_modules//ic-ecs-service-base?ref=main"

  # Core configuration
  resources_prefix = "theic"
  environment      = "prod"
  name_suffix      = "backend"
  region           = "us-east-1"

  # Network
  vpc_id                 = "vpc-xxx"
  subnet_ids             = ["subnet-xxx", "subnet-yyy"]
  service_security_groups = ["sg-vpc-endpoints"]

  # ECS
  ecs_cluster_name = "theic-prod-cluster"
  service_cpu      = 1024
  service_memory   = 2048
  desired_count    = 2

  # FluentBit logging
  fluentbit_container = {
    config_bucket_arn = "arn:aws:s3:::my-fluentbit-config"
    config_files      = ["parser.conf", "output.conf"]
  }

  # Containers
  containers = {
    webserver = {
      image      = "123456789012.dkr.ecr.us-east-1.amazonaws.com/webserver"
      image_tag  = "v1.0.0"
      cpu        = 256
      memory     = 512
      
      port_mappings = [{
        name          = "http"
        containerPort = 80
      }]
      
      health_check = {
        command = ["CMD-SHELL", "curl -f http://localhost/health || exit 1"]
      }
    }
    
    app = {
      image      = "123456789012.dkr.ecr.us-east-1.amazonaws.com/app"
      image_tag  = "v1.0.0"
      cpu        = 512
      memory     = 1024
      
      environment = {
        APP_ENV = "production"
      }
      
      secrets = [{
        name      = "DB_PASSWORD"
        valueFrom = "arn:aws:secretsmanager:us-east-1:123456789012:secret:db-password"
      }]
      
      volumes_from = [{
        sourceContainer = "webserver"
      }]
    }
  }

  primary_container = {
    name           = "webserver"
    port           = 80
    http_port_name = "http"
  }

  # Load balancer
  alb = {
    security_group_id = "sg-alb"
    listener_arn      = "arn:aws:elasticloadbalancing:..."
    health_check = {
      path = "/health"
      port = "80"
    }
  }

  alb_listener_rules = [{
    priority = 100
    conditions = [{
      host_header = {
        values = ["backend.example.com"]
      }
    }]
  }]

  # Service Discovery
  service_discovery_namespace_arn = "arn:aws:servicediscovery:..."

  # Auto-scaling
  autoscaling = {
    enabled      = true
    min_capacity = 2
    max_capacity = 10
    cpu_target   = 70
  }

  # IAM
  ecr_repositories_arns = [
    "arn:aws:ecr:us-east-1:123456789012:repository/webserver",
    "arn:aws:ecr:us-east-1:123456789012:repository/app"
  ]
  
  service_secret_arns = [
    "arn:aws:secretsmanager:us-east-1:123456789012:secret:db-password",
    "arn:aws:secretsmanager:us-east-1:123456789012:secret:app-secrets"
  ]
  
  oidc_subjects = ["repo:myorg/myrepo:*"]

  # DNS
  dns_zone_id = "Z123456"
  dns_records = [{
    name    = "backend.example.com"
    type    = "CNAME"
    records = ["alb-123456.us-east-1.elb.amazonaws.com"]
  }]
}
```

### With Custom Task Definitions (Migrations)

```hcl
module "adminpanel_service" {
  source = "git@github.com:theinnercircle/tf_modules//ic-ecs-service-base?ref=main"

  # ... basic configuration ...

  # Custom task definition for migrations
  custom_task_definitions = {
    migrations = {
      cpu    = 512
      memory = 1024
      
      containers = {
        migration = {
          image      = "123456789012.dkr.ecr.us-east-1.amazonaws.com/app"
          image_tag  = "v1.0.0"
          cpu        = 256
          memory     = 512
          
          command = ["php", "artisan", "migrate", "--force"]
          
          environment = {
            APP_ENV = "production"
          }
          
          secrets = [{
            name      = "DB_PASSWORD"
            valueFrom = "arn:aws:secretsmanager:..."
          }]
        }
      }
    }
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5 |
| aws | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| ecs_service | terraform-aws-modules/ecs/aws//modules/service | 5.12.1 |
| ecs_iam_roles | git@github.com:theinnercircle/tf_module_ecs-iam-roles.git | main |

## Inputs

See [variables.tf](./variables.tf) for complete input documentation.

## Outputs

See [outputs.tf](./outputs.tf) for complete output documentation.

## Container Configuration

### FluentBit (Fixed)
The FluentBit container is automatically included in all tasks for log aggregation. It's configured via the `fluentbit_container` variable.

### Application Containers (Flexible)
Define any number of containers via the `containers` variable. Each container supports:
- Resource limits (CPU/memory)
- Port mappings
- Environment variables
- Secrets from AWS Secrets Manager
- Health checks
- Volume mounts
- Dependencies on other containers
- Custom commands and entrypoints

### Primary Container
One container must be designated as the primary container via the `primary_container` variable. This container is:
- Registered with the ALB target group
- Used for Service Connect discovery

## Custom Task Definitions

The module supports creating additional task definitions for use cases like:
- Database migrations
- One-off data processing jobs
- Scheduled tasks (used with EventBridge)

Custom tasks:
- Share the same IAM roles as the service
- Include FluentBit for logging
- Can have different resource requirements than the service

## Security

### Security Groups
The module automatically creates security group rules for:
- Ingress from ALB to primary container
- Health check traffic (if on a different port)
- Egress to all destinations

Additional rules can be added via `additional_security_group_rules`.

### IAM Roles
Three IAM roles are created via the `ecs-iam-roles` module:
1. **Task Role**: Used by containers at runtime
2. **Task Execution Role**: Used for task creation/destruction
3. **CI/CD Role**: Used by GitHub Actions for deployments

## Auto-scaling

The module supports both CPU and memory-based autoscaling:
- CPU-based scaling (default, always enabled)
- Memory-based scaling (optional)
- Configurable cooldown periods
- Min/max capacity limits

## Service Discovery

Service Connect is used for service-to-service communication within the ECS cluster. Each service is registered with a DNS name (defaults to `name_suffix`).

## Best Practices

1. **Use specific image tags**: Never use `latest` in production
2. **Enable auto-scaling**: Set appropriate min/max values
3. **Configure health checks**: Use meaningful health check endpoints
4. **Use secrets for sensitive data**: Never put passwords in environment variables
5. **Set appropriate resource limits**: CPU and memory based on actual usage
6. **Enable ECS Exec**: Useful for debugging (enabled by default)

## Migration from Existing Modules

To migrate from existing service modules:

1. Create a wrapper module (see examples in `ic-app`, `ic-adminpanel`)
2. Map existing variables to the new base module variables
3. Move service-specific resources to the wrapper module
4. Update terragrunt configurations to use the wrapper module

## License

Proprietary - The Inner Circle

## Authors

Infrastructure Team - The Inner Circle
```
<!-- BEGIN_TF_DOCS -->
# IC ECS Service Base Module

A comprehensive Terraform module for deploying ECS Fargate services with standardized configuration and best practices. This base module provides all common infrastructure for ECS services while allowing customization through wrapper modules.

## Features

- ✅ **Standardized ECS Service**: Pre-configured Fargate service with best practices
- ✅ **Automatic FluentBit Logging**: Built-in log aggregation and forwarding
- ✅ **Flexible Container Support**: Define any number of containers with custom configurations
- ✅ **Custom Task Definitions**: Support for migrations, one-off jobs, and other custom tasks
- ✅ **ALB Integration**: Automatic target group and listener rule configuration
- ✅ **Auto-scaling**: CPU and memory-based autoscaling support
- ✅ **Service Discovery**: AWS Cloud Map integration for service-to-service communication
- ✅ **IAM Role Management**: Integrated with ecs-iam-roles module
- ✅ **DNS Management**: Route53 record creation
- ✅ **Security Groups**: Configurable security group rules
- ✅ **ECS Exec**: Enabled for debugging and troubleshooting

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         ALB                                  │
│                    (Listener Rules)                          │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                    Target Group                              │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                    ECS Service                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                    Task Definition                      │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │ │
│  │  │  FluentBit   │  │  Container 1 │  │  Container N │ │ │
│  │  │  (Logging)   │  │              │  │              │ │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘ │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                Service Discovery (Cloud Map)                 │
└─────────────────────────────────────────────────────────────┘
```

## Usage

### Basic Example

```hcl
module "backend_service" {
  source = "git@github.com:theinnercircle/tf_modules//ic-ecs-service-base?ref=main"

  # Core configuration
  resources_prefix = "theic"
  environment      = "prod"
  name_suffix      = "backend"
  region           = "us-east-1"

  # Network
  vpc_id                 = "vpc-xxx"
  subnet_ids             = ["subnet-xxx", "subnet-yyy"]
  service_security_groups = ["sg-vpc-endpoints"]

  # ECS
  ecs_cluster_name = "theic-prod-cluster"
  service_cpu      = 1024
  service_memory   = 2048
  desired_count    = 2

  # FluentBit logging
  fluentbit_container = {
    config_bucket_arn = "arn:aws:s3:::my-fluentbit-config"
    config_files      = ["parser.conf", "output.conf"]
  }

  # Containers
  containers = {
    webserver = {
      image      = "123456789012.dkr.ecr.us-east-1.amazonaws.com/webserver"
      image_tag  = "v1.0.0"
      cpu        = 256
      memory     = 512

      port_mappings = [{
        name          = "http"
        containerPort = 80
      }]

      health_check = {
        command = ["CMD-SHELL", "curl -f http://localhost/health || exit 1"]
      }
    }

    app = {
      image      = "123456789012.dkr.ecr.us-east-1.amazonaws.com/app"
      image_tag  = "v1.0.0"
      cpu        = 512
      memory     = 1024

      environment = {
        APP_ENV = "production"
      }

      secrets = [{
        name      = "DB_PASSWORD"
        valueFrom = "arn:aws:secretsmanager:us-east-1:123456789012:secret:db-password"
      }]

      volumes_from = [{
        sourceContainer = "webserver"
      }]
    }
  }

  primary_container = {
    name           = "webserver"
    port           = 80
    http_port_name = "http"
  }

  # Load balancer
  alb = {
    security_group_id = "sg-alb"
    listener_arn      = "arn:aws:elasticloadbalancing:..."
    health_check = {
      path = "/health"
      port = "80"
    }
  }

  alb_listener_rules = [{
    priority = 100
    conditions = [{
      host_header = {
        values = ["backend.example.com"]
      }
    }]
  }]

  # Service Discovery
  service_discovery_namespace_arn = "arn:aws:servicediscovery:..."

  # Auto-scaling
  autoscaling = {
    enabled      = true
    min_capacity = 2
    max_capacity = 10
    cpu_target   = 70
  }

  # IAM
  ecr_repositories_arns = [
    "arn:aws:ecr:us-east-1:123456789012:repository/webserver",
    "arn:aws:ecr:us-east-1:123456789012:repository/app"
  ]

  service_secret_arns = [
    "arn:aws:secretsmanager:us-east-1:123456789012:secret:db-password",
    "arn:aws:secretsmanager:us-east-1:123456789012:secret:app-secrets"
  ]

  oidc_subjects = ["repo:myorg/myrepo:*"]

  # DNS
  dns_zone_id = "Z123456"
  dns_records = [{
    name    = "backend.example.com"
    type    = "CNAME"
    records = ["alb-123456.us-east-1.elb.amazonaws.com"]
  }]
}
```

### With Custom Task Definitions (Migrations)

```hcl
module "adminpanel_service" {
  source = "git@github.com:theinnercircle/tf_modules//ic-ecs-service-base?ref=main"

  # ... basic configuration ...

  # Custom task definition for migrations
  custom_task_definitions = {
    migrations = {
      cpu    = 512
      memory = 1024

      containers = {
        migration = {
          image      = "123456789012.dkr.ecr.us-east-1.amazonaws.com/app"
          image_tag  = "v1.0.0"
          cpu        = 256
          memory     = 512

          command = ["php", "artisan", "migrate", "--force"]

          environment = {
            APP_ENV = "production"
          }

          secrets = [{
            name      = "DB_PASSWORD"
            valueFrom = "arn:aws:secretsmanager:..."
          }]
        }
      }
    }
  }
}
```

## Container Configuration

### FluentBit (Fixed)
The FluentBit container is automatically included in all tasks for log aggregation. It's configured via the `fluentbit_container` variable.

### Application Containers (Flexible)
Define any number of containers via the `containers` variable. Each container supports:
- Resource limits (CPU/memory)
- Port mappings
- Environment variables
- Secrets from AWS Secrets Manager
- Health checks
- Volume mounts
- Dependencies on other containers
- Custom commands and entrypoints

### Primary Container
One container must be designated as the primary container via the `primary_container` variable. This container is:
- Registered with the ALB target group
- Used for Service Connect discovery

## Custom Task Definitions

The module supports creating additional task definitions for use cases like:
- Database migrations
- One-off data processing jobs
- Scheduled tasks (used with EventBridge)

Custom tasks:
- Share the same IAM roles as the service
- Include FluentBit for logging
- Can have different resource requirements than the service

## Security

### Security Groups
The module automatically creates security group rules for:
- Ingress from ALB to primary container
- Health check traffic (if on a different port)
- Egress to all destinations

Additional rules can be added via `additional_security_group_rules`.

### IAM Roles
Three IAM roles are created via the `ecs-iam-roles` module:
1. **Task Role**: Used by containers at runtime
2. **Task Execution Role**: Used for task creation/destruction
3. **CI/CD Role**: Used by GitHub Actions for deployments

## Auto-scaling

The module supports both CPU and memory-based autoscaling:
- CPU-based scaling (default, always enabled)
- Memory-based scaling (optional)
- Configurable cooldown periods
- Min/max capacity limits

## Service Discovery

Service Connect is used for service-to-service communication within the ECS cluster. Each service is registered with a DNS name (defaults to `name_suffix`).

## Best Practices

1. **Use specific image tags**: Never use `latest` in production
2. **Enable auto-scaling**: Set appropriate min/max values
3. **Configure health checks**: Use meaningful health check endpoints
4. **Use secrets for sensitive data**: Never put passwords in environment variables
5. **Set appropriate resource limits**: CPU and memory based on actual usage
6. **Enable ECS Exec**: Useful for debugging (enabled by default)

## Migration from Existing Modules

To migrate from existing service modules:

1. Create a wrapper module (see examples in `ic-app`, `ic-adminpanel`)
2. Map existing variables to the new base module variables
3. Move service-specific resources to the wrapper module
4. Update terragrunt configurations to use the wrapper module

## Module Dependencies

This module uses:
- [`terraform-aws-modules/ecs/aws//modules/service`](https://registry.terraform.io/modules/terraform-aws-modules/ecs/aws/latest) v6.x [[1]](https://github.com/terraform-aws-modules/terraform-aws-ecs/releases)
- Internal `ecs-iam-roles` module from the Inner Circle infrastructure

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.7 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_ecs_iam_roles"></a> [ecs\_iam\_roles](#module\_ecs\_iam\_roles) | git@github.com:theinnercircle/tf_module_ecs-iam-roles.git | main |
| <a name="module_ecs_service"></a> [ecs\_service](#module\_ecs\_service) | terraform-aws-modules/ecs/aws//modules/service | ~> 6.6 |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.ecs_task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ecs_task_definition.custom](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_lb_listener_rule.service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_lb_target_group.service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_route53_record.service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_ecs_cluster.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecs_cluster) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_security_group_rules"></a> [additional\_security\_group\_rules](#input\_additional\_security\_group\_rules) | Additional security group rules to create for the service | <pre>map(object({<br/>    type                     = string # ingress or egress<br/>    from_port                = number<br/>    to_port                  = number<br/>    protocol                 = string # tcp, udp, icmp, or -1 for all<br/>    description              = optional(string)<br/>    cidr_blocks              = optional(list(string))<br/>    ipv6_cidr_blocks         = optional(list(string))<br/>    source_security_group_id = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_alb"></a> [alb](#input\_alb) | Application Load Balancer configuration | <pre>object({<br/>    security_group_id = string<br/>    listener_arn      = string<br/>    health_check = object({<br/>      enabled             = optional(bool, true)<br/>      path                = string<br/>      port                = optional(string, "traffic-port")<br/>      protocol            = optional(string, "HTTP")<br/>      interval            = optional(number, 30)<br/>      timeout             = optional(number, 5)<br/>      healthy_threshold   = optional(number, 2)<br/>      unhealthy_threshold = optional(number, 3)<br/>      matcher             = optional(string, "200-299")<br/>    })<br/>    deregistration_delay = optional(number, 30)<br/>    stickiness = optional(object({<br/>      enabled         = optional(bool, false)<br/>      type            = optional(string, "lb_cookie")<br/>      cookie_duration = optional(number, 86400)<br/>    }))<br/>  })</pre> | n/a | yes |
| <a name="input_alb_listener_rules"></a> [alb\_listener\_rules](#input\_alb\_listener\_rules) | ALB listener rules for routing traffic to the service | <pre>list(object({<br/>    priority = number<br/>    conditions = list(object({<br/>      path_pattern = optional(object({<br/>        values = list(string)<br/>      }))<br/>      host_header = optional(object({<br/>        values = list(string)<br/>      }))<br/>      http_header = optional(object({<br/>        name   = string<br/>        values = list(string)<br/>      }))<br/>      http_request_method = optional(object({<br/>        values = list(string)<br/>      }))<br/>      query_string = optional(list(object({<br/>        key   = optional(string)<br/>        value = string<br/>      })))<br/>      source_ip = optional(object({<br/>        values = list(string)<br/>      }))<br/>    }))<br/>  }))</pre> | `[]` | no |
| <a name="input_autoscaling"></a> [autoscaling](#input\_autoscaling) | ECS service autoscaling configuration | <pre>object({<br/>    enabled            = optional(bool, true)<br/>    min_capacity       = optional(number, 1)<br/>    max_capacity       = optional(number, 4)<br/>    cpu_target         = optional(number, 75)<br/>    memory_target      = optional(number) # Optional memory-based scaling<br/>    scale_in_cooldown  = optional(number, 60)<br/>    scale_out_cooldown = optional(number, 60)<br/>  })</pre> | <pre>{<br/>  "cpu_target": 75,<br/>  "enabled": true,<br/>  "max_capacity": 4,<br/>  "min_capacity": 1<br/>}</pre> | no |
| <a name="input_cloudwatch_log_retention_days"></a> [cloudwatch\_log\_retention\_days](#input\_cloudwatch\_log\_retention\_days) | Number of days to retain CloudWatch logs | `number` | `7` | no |
| <a name="input_containers"></a> [containers](#input\_containers) | Map of container definitions. Key is the container name. | <pre>map(object({<br/>    image                    = string<br/>    image_tag                = optional(string, "latest")<br/>    cpu                      = number<br/>    memory                   = number<br/>    essential                = optional(bool, true)<br/>    readonly_root_filesystem = optional(bool, false)<br/><br/>    port_mappings = optional(list(object({<br/>      name          = string<br/>      containerPort = number<br/>      hostPort      = optional(number)<br/>      protocol      = optional(string, "tcp")<br/>      appProtocol   = optional(string)<br/>    })), [])<br/><br/>    environment = optional(map(string), {})<br/><br/>    secrets = optional(list(object({<br/>      name      = string<br/>      valueFrom = string<br/>    })), [])<br/><br/>    health_check = optional(object({<br/>      command     = list(string)<br/>      interval    = optional(number, 30)<br/>      timeout     = optional(number, 5)<br/>      retries     = optional(number, 3)<br/>      startPeriod = optional(number, 60)<br/>    }))<br/><br/>    depends_on_containers = optional(list(string), ["fluent-bit"])<br/><br/>    volumes_from = optional(list(object({<br/>      sourceContainer = string<br/>      readOnly        = optional(bool, false)<br/>    })), [])<br/><br/>    mount_points = optional(list(object({<br/>      sourceVolume  = string<br/>      containerPath = string<br/>      readOnly      = optional(bool, false)<br/>    })), [])<br/><br/>    user       = optional(string)<br/>    command    = optional(list(string))<br/>    entrypoint = optional(list(string))<br/>  }))</pre> | `{}` | no |
| <a name="input_custom_task_definitions"></a> [custom\_task\_definitions](#input\_custom\_task\_definitions) | Map of custom task definitions (e.g., migrations, one-off jobs) | <pre>map(object({<br/>    cpu    = optional(number, 512)<br/>    memory = optional(number, 1024)<br/><br/>    containers = map(object({<br/>      image                    = string<br/>      image_tag                = optional(string, "latest")<br/>      cpu                      = number<br/>      memory                   = number<br/>      essential                = optional(bool, true)<br/>      readonly_root_filesystem = optional(bool, false)<br/><br/>      port_mappings = optional(list(object({<br/>        name          = string<br/>        containerPort = number<br/>        hostPort      = optional(number)<br/>        protocol      = optional(string, "tcp")<br/>        appProtocol   = optional(string)<br/>      })), [])<br/><br/>      environment = optional(map(string), {})<br/><br/>      secrets = optional(list(object({<br/>        name      = string<br/>        valueFrom = string<br/>      })), [])<br/><br/>      depends_on_containers = optional(list(string), ["fluent-bit"])<br/><br/>      volumes_from = optional(list(object({<br/>        sourceContainer = string<br/>        readOnly        = optional(bool, false)<br/>      })), [])<br/><br/>      mount_points = optional(list(object({<br/>        sourceVolume  = string<br/>        containerPath = string<br/>        readOnly      = optional(bool, false)<br/>      })), [])<br/><br/>      user       = optional(string)<br/>      command    = optional(list(string))<br/>      entrypoint = optional(list(string))<br/>    }))<br/><br/>    task_volumes = optional(map(object({<br/>      efs_volume_configuration = optional(object({<br/>        file_system_id          = string<br/>        root_directory          = optional(string, "/")<br/>        transit_encryption      = optional(string, "ENABLED")<br/>        transit_encryption_port = optional(number)<br/>        authorization_config = optional(object({<br/>          access_point_id = optional(string)<br/>          iam             = optional(string, "DISABLED")<br/>        }))<br/>      }))<br/>      host_path = optional(string)<br/>      docker_volume_configuration = optional(object({<br/>        scope         = optional(string)<br/>        autoprovision = optional(bool)<br/>        driver        = optional(string)<br/>        driver_opts   = optional(map(string))<br/>        labels        = optional(map(string))<br/>      }))<br/>    })), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_deployment_maximum_percent"></a> [deployment\_maximum\_percent](#input\_deployment\_maximum\_percent) | Maximum percentage during deployments | `number` | `200` | no |
| <a name="input_deployment_minimum_healthy_percent"></a> [deployment\_minimum\_healthy\_percent](#input\_deployment\_minimum\_healthy\_percent) | Minimum healthy percentage during deployments | `number` | `100` | no |
| <a name="input_desired_count"></a> [desired\_count](#input\_desired\_count) | Desired number of tasks for the ECS service | `number` | `1` | no |
| <a name="input_dns_records"></a> [dns\_records](#input\_dns\_records) | DNS records to create for the service | <pre>list(object({<br/>    name    = string<br/>    type    = string<br/>    ttl     = optional(number, 300)<br/>    records = list(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_dns_zone_id"></a> [dns\_zone\_id](#input\_dns\_zone\_id) | Route53 hosted zone ID for DNS records | `string` | n/a | yes |
| <a name="input_ecr_repository_arns"></a> [ecr\_repository\_arns](#input\_ecr\_repository\_arns) | List of ECR repository ARNs for the task execution role | `list(string)` | n/a | yes |
| <a name="input_ecs_cluster_name"></a> [ecs\_cluster\_name](#input\_ecs\_cluster\_name) | Name of the ECS cluster | `string` | n/a | yes |
| <a name="input_ecs_task_custom_policies_arns"></a> [ecs\_task\_custom\_policies\_arns](#input\_ecs\_task\_custom\_policies\_arns) | List of custom IAM policy ARNs to attach to the ECS task role | `list(string)` | `[]` | no |
| <a name="input_enable_execute_command"></a> [enable\_execute\_command](#input\_enable\_execute\_command) | Enable ECS Exec for debugging | `bool` | `true` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (e.g., 'dev', 'staging', 'prod') | `string` | n/a | yes |
| <a name="input_fluentbit_container"></a> [fluentbit\_container](#input\_fluentbit\_container) | Configuration for the FluentBit log router sidecar container | <pre>object({<br/>    image             = optional(string, "public.ecr.aws/aws-observability/aws-for-fluent-bit:stable")<br/>    cpu               = optional(number, 128)<br/>    memory            = optional(number, 256)<br/>    config_bucket_arn = string<br/>    config_files      = optional(list(string), ["parser.conf", "stream_processing.conf", "output.conf"])<br/>  })</pre> | n/a | yes |
| <a name="input_name_suffix"></a> [name\_suffix](#input\_name\_suffix) | Suffix for the service name (e.g., 'backend', 'adminpanel') | `string` | n/a | yes |
| <a name="input_oidc_subjects"></a> [oidc\_subjects](#input\_oidc\_subjects) | List of OIDC subjects for GitHub Actions CI/CD role | `list(string)` | `[]` | no |
| <a name="input_primary_container"></a> [primary\_container](#input\_primary\_container) | Configuration for the primary container (used for ALB target and Service Connect) | <pre>object({<br/>    name           = string<br/>    port           = number<br/>    http_port_name = string<br/>  })</pre> | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region | `string` | n/a | yes |
| <a name="input_resources_prefix"></a> [resources\_prefix](#input\_resources\_prefix) | Prefix for all resources (e.g., 'theic') | `string` | `"theic"` | no |
| <a name="input_service_connect_config"></a> [service\_connect\_config](#input\_service\_connect\_config) | Service Connect configuration | <pre>object({<br/>    enabled  = optional(bool, true)<br/>    dns_name = optional(string) # Defaults to name_suffix if not provided<br/>  })</pre> | <pre>{<br/>  "enabled": true<br/>}</pre> | no |
| <a name="input_service_cpu"></a> [service\_cpu](#input\_service\_cpu) | CPU units for the ECS task (256, 512, 1024, 2048, 4096) | `number` | `512` | no |
| <a name="input_service_discovery_namespace_arn"></a> [service\_discovery\_namespace\_arn](#input\_service\_discovery\_namespace\_arn) | ARN of the AWS Cloud Map namespace for Service Connect | `string` | n/a | yes |
| <a name="input_service_memory"></a> [service\_memory](#input\_service\_memory) | Memory for the ECS task in MB (512, 1024, 2048, etc.) | `number` | `1024` | no |
| <a name="input_service_secret_arns"></a> [service\_secret\_arns](#input\_service\_secret\_arns) | List of AWS Secrets Manager secret ARNs that the task needs access to | `list(string)` | `[]` | no |
| <a name="input_service_security_groups"></a> [service\_security\_groups](#input\_service\_security\_groups) | List of security group IDs to attach to the ECS service | `list(string)` | `[]` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | List of subnet IDs for the ECS service tasks | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_task_volumes"></a> [task\_volumes](#input\_task\_volumes) | Volumes to attach to the ECS task | <pre>map(object({<br/>    efs_volume_configuration = optional(object({<br/>      file_system_id          = string<br/>      root_directory          = optional(string, "/")<br/>      transit_encryption      = optional(string, "ENABLED")<br/>      transit_encryption_port = optional(number)<br/>      authorization_config = optional(object({<br/>        access_point_id = optional(string)<br/>        iam             = optional(string, "DISABLED")<br/>      }))<br/>    }))<br/>    host_path = optional(string)<br/>    docker_volume_configuration = optional(object({<br/>      scope         = optional(string)<br/>      autoprovision = optional(bool)<br/>      driver        = optional(string)<br/>      driver_opts   = optional(map(string))<br/>      labels        = optional(map(string))<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID where the service will be deployed | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_custom_task_definitions"></a> [custom\_task\_definitions](#output\_custom\_task\_definitions) | Map of custom task definition ARNs |
| <a name="output_dns_records"></a> [dns\_records](#output\_dns\_records) | Created DNS records |
| <a name="output_ecs_task_execution_iam_role_arn"></a> [ecs\_task\_execution\_iam\_role\_arn](#output\_ecs\_task\_execution\_iam\_role\_arn) | ARN of the ECS task execution IAM role |
| <a name="output_ecs_task_execution_iam_role_name"></a> [ecs\_task\_execution\_iam\_role\_name](#output\_ecs\_task\_execution\_iam\_role\_name) | Name of the ECS task execution IAM role |
| <a name="output_ecs_task_iam_role_arn"></a> [ecs\_task\_iam\_role\_arn](#output\_ecs\_task\_iam\_role\_arn) | ARN of the ECS task IAM role |
| <a name="output_ecs_task_iam_role_name"></a> [ecs\_task\_iam\_role\_name](#output\_ecs\_task\_iam\_role\_name) | Name of the ECS task IAM role |
| <a name="output_github_oidc_role_arn"></a> [github\_oidc\_role\_arn](#output\_github\_oidc\_role\_arn) | ARN of the ECS CI/CD IAM role |
| <a name="output_github_oidc_role_name"></a> [github\_oidc\_role\_name](#output\_github\_oidc\_role\_name) | Name of the ECS CI/CD IAM role |
| <a name="output_log_group_arn"></a> [log\_group\_arn](#output\_log\_group\_arn) | ARN of the CloudWatch log group |
| <a name="output_log_group_name"></a> [log\_group\_name](#output\_log\_group\_name) | Name of the CloudWatch log group |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | Security group ID created by the ECS service module |
| <a name="output_service_arn"></a> [service\_arn](#output\_service\_arn) | ARN of the ECS service |
| <a name="output_service_id"></a> [service\_id](#output\_service\_id) | ID of the ECS service |
| <a name="output_service_name"></a> [service\_name](#output\_service\_name) | Name of the ECS service |
| <a name="output_target_group_arn"></a> [target\_group\_arn](#output\_target\_group\_arn) | ARN of the target group |
| <a name="output_target_group_name"></a> [target\_group\_name](#output\_target\_group\_name) | Name of the target group |
| <a name="output_task_definition_arn"></a> [task\_definition\_arn](#output\_task\_definition\_arn) | ARN of the task definition (including revision) |
| <a name="output_task_definition_family"></a> [task\_definition\_family](#output\_task\_definition\_family) | Family of the task definition |
| <a name="output_task_definition_revision"></a> [task\_definition\_revision](#output\_task\_definition\_revision) | Revision of the task definition |

## License

Proprietary - The Inner Circle

## Authors

Infrastructure Team - The Inner Circle
<!-- END_TF_DOCS -->