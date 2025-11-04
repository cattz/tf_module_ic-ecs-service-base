# ========================================
# Data Sources
# ========================================

# Fetch Route53 hosted zone details to get the zone name
# Used to automatically construct FQDNs from dns_records
data "aws_route53_zone" "dns_zone" {
  count   = var.dns_zone_id != "" ? 1 : 0
  zone_id = var.dns_zone_id
}

# ========================================
# Local Variables for ALB Configuration
# ========================================

locals {
  # Extract DNS record names and construct their FQDNs
  # These will be automatically added to host_header conditions in ALB listener rules
  dns_record_fqdns = length(data.aws_route53_zone.dns_zone) > 0 ? [
    for record in var.dns_records :
    "${record.name}.${data.aws_route53_zone.dns_zone[0].name}"
  ] : []
}

# ========================================
# Target Group
# ========================================

# Target Group for the ECS service
resource "aws_lb_target_group" "service" {
  name     = "${local.service_name}-tg"
  port     = var.primary_container.port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  target_type = "ip"

  deregistration_delay = var.alb.deregistration_delay

  health_check {
    enabled             = var.alb.health_check.enabled
    path                = var.alb.health_check.path
    port                = var.alb.health_check.port
    protocol            = var.alb.health_check.protocol
    interval            = var.alb.health_check.interval
    timeout             = var.alb.health_check.timeout
    healthy_threshold   = var.alb.health_check.healthy_threshold
    unhealthy_threshold = var.alb.health_check.unhealthy_threshold
    matcher             = var.alb.health_check.matcher
  }

  dynamic "stickiness" {
    for_each = var.alb.stickiness != null ? [var.alb.stickiness] : []
    content {
      enabled         = stickiness.value.enabled
      type            = stickiness.value.type
      cookie_duration = stickiness.value.cookie_duration
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.service_name}-tg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# ========================================
# ALB Listener Rules
# ========================================

resource "aws_lb_listener_rule" "service" {
  count = length(var.alb_listener_rules)

  listener_arn = var.alb.listener_arn
  priority     = var.alb_listener_rules[count.index].priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service.arn
  }

  dynamic "condition" {
    for_each = var.alb_listener_rules[count.index].conditions

    content {
      dynamic "path_pattern" {
        for_each = condition.value.path_pattern != null ? [condition.value.path_pattern] : []
        content {
          values = path_pattern.value.values
        }
      }

      dynamic "host_header" {
        for_each = condition.value.host_header != null ? [condition.value.host_header] : []
        content {
          # Automatically append DNS record FQDNs to user-provided host_header values
          # This ensures ALB routes traffic to all DNS records created for the service
          # Use distinct() to avoid duplicates if user manually specified a DNS record
          values = distinct(concat(
            host_header.value.values,
            local.dns_record_fqdns
          ))
        }
      }

      dynamic "http_header" {
        for_each = condition.value.http_header != null ? [condition.value.http_header] : []
        content {
          http_header_name = http_header.value.name
          values           = http_header.value.values
        }
      }

      dynamic "http_request_method" {
        for_each = condition.value.http_request_method != null ? [condition.value.http_request_method] : []
        content {
          values = http_request_method.value.values
        }
      }

      dynamic "query_string" {
        for_each = condition.value.query_string != null ? condition.value.query_string : []
        content {
          key   = query_string.value.key
          value = query_string.value.value
        }
      }

      dynamic "source_ip" {
        for_each = condition.value.source_ip != null ? [condition.value.source_ip] : []
        content {
          values = source_ip.value.values
        }
      }
    }
  }

  tags = local.common_tags
}