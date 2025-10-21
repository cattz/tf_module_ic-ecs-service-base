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