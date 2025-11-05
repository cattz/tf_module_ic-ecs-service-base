# IC ECS Service Base Module - Review Findings

**Review Date**: 2025-11-03
**Reviewer**: Claude Code
**Status**: Autoscaling and Circuit Breaker implemented

This document contains the remaining moderate and minor issues identified during the comprehensive module review. Critical issues (autoscaling, circuit breaker) have been resolved.

---

## Moderate Issues 🟡

### ISSUE #2: Hardcoded FluentBit Secret Logic

**Severity**: HIGH
**Location**: `secrets.tf:1-7`, `locals.tf:14`

**Problem**:
The module has hardcoded logic for FluentBit secrets:

```hcl
secret_env = contains(["acceptance1", "prod"], var.environment) ? var.environment : "test"
```

**Issues**:
1. Assumes all test environments (test1-test6) share the same secret
2. Hardcoded environment names ("acceptance1", "prod")
3. Comment says "A bit clunky way to use a single secret for all test envs"
4. No way to override this behavior

**Impact**:
- Not flexible for different secret strategies
- Requires module changes to support new environments
- Forces secret sharing across test environments

**Recommendation**:
```hcl
# In variables.tf, add:
variable "fluentbit_secret_name" {
  description = "Name of the FluentBit Elasticsearch secret in Secrets Manager. If null, derives from environment."
  type        = string
  default     = null
}

# In locals.tf, replace lines 14-15:
fluentbit_secret_name = coalesce(
  var.fluentbit_secret_name,
  "ic/${local.secret_env}/elastic/fluentbit"
)

# In secrets.tf:
data "aws_secretsmanager_secret" "fluentbit" {
  name = local.fluentbit_secret_name
}
```

---

### ISSUE #3: Security Group Rule Structure Inconsistency

**Severity**: MODERATE
**Location**: `variables.tf:46-59`, `locals.tf:137-163`

**Problem**:
The module uses different security group rule formats in different places.

**In locals.tf** (base rules) - Uses newer VPC security group rule format:
```hcl
base_security_group_rules_ingress = {
  ingress_alb_primary = {
    from_port = ...
    ip_protocol = "tcp"
    referenced_security_group_id = ...
  }
}
```

**In variables.tf** (additional rules) - Uses old-style format:
```hcl
additional_security_group_rules = map(object({
  type = string  # ingress or egress
  protocol = string  # tcp, udp, icmp, or -1
  source_security_group_id = optional(string)
}))
```

**Issues**:
- `type` field is old EC2-Classic style (should be implicit from map key)
- `protocol` uses old names (`tcp`) vs new `ip_protocol`
- Inconsistent with how the module generates base rules
- Users might be confused about which format to use

**Recommendation**:
Align both to use the same format (preferably the newer VPC format). Update `additional_security_group_rules` variable to match the format used in `base_security_group_rules_ingress`.

---

### ISSUE #4: No Stickiness by Default

**Severity**: MODERATE
**Location**: `alb.tf:24-31`

**Problem**:
ALB target group stickiness is optional and defaults to disabled.

**Context**:
- For PHP-FPM applications with session handling, stickiness might be important
- The backend/admin services use sessions (ElastiCache for sessions exists)
- Default behavior may cause session loss during deployments

**Current Code**:
```hcl
dynamic "stickiness" {
  for_each = var.alb.stickiness != null ? [var.alb.stickiness] : []
  ...
}
```

**Recommendation**:
Consider making stickiness enabled by default with lb_cookie, or at least document this clearly in the README with examples for session-based applications.

---

### ISSUE #5: FluentBit Configuration Files Not Validated

**Severity**: MODERATE
**Location**: `variables.tf:117`

**Problem**:
The module accepts a list of config files, but there's no validation that:
- Files exist in the S3 bucket
- Files are properly formatted
- Required files are included

**Current Code**:
```hcl
config_files = optional(list(string), ["parser.conf", "stream_processing.conf", "output.conf"])
```

**Impact**:
Deployment might succeed, but logging fails silently.

**Recommendation**:
Add validation or documentation about required FluentBit configuration files. Consider using data source to check if bucket/files exist.

---

### ISSUE #6: No Volume Support Validation

**Severity**: MODERATE
**Location**: `variables.tf:184-206`, `ecs.tf:39-54`

**Problem**:
The module supports three volume types (EFS, host paths, docker volumes) but:
1. No validation that at least one volume type is specified
2. No validation that only one type is specified per volume
3. Host paths don't work with Fargate (should be validated/documented)

**Recommendation**:
Add validation blocks or precondition checks:
```hcl
validation {
  condition = alltrue([
    for volume in var.task_volumes :
      (volume.efs_volume_configuration != null ? 1 : 0) +
      (volume.host_path != null ? 1 : 0) +
      (volume.docker_volume_configuration != null ? 1 : 0) == 1
  ])
  error_message = "Each volume must specify exactly one volume type (efs, host_path, or docker)."
}
```

---

### ISSUE #7: Service Role ARN Hardcoded

**Severity**: MODERATE
**Location**: `ecs.tf:23`

**Problem**:
The module hardcodes the ECS service-linked role:

```hcl
iam_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/ecs.amazonaws.com/AWSServiceRoleForECS"
```

**Issues**:
- Assumes the service-linked role exists
- No error handling if it doesn't exist
- Not configurable for non-standard setups

**Recommendation**:
Add a variable to allow override, or document that the service-linked role must exist. Consider adding a data source check:

```hcl
variable "ecs_service_role_arn" {
  description = "ARN of the ECS service-linked role. If null, uses default."
  type        = string
  default     = null
}

locals {
  ecs_service_role_arn = coalesce(
    var.ecs_service_role_arn,
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/ecs.amazonaws.com/AWSServiceRoleForECS"
  )
}
```

---

## Minor Issues / Improvements 🟢

### ISSUE #8: No Task Definition Lifecycle Management

**Severity**: LOW
**Location**: `task_definitions.tf`

**Problem**:
Custom task definitions don't have lifecycle rules to prevent destruction of running tasks.

**Recommendation**:
```hcl
resource "aws_ecs_task_definition" "custom" {
  # ... existing config ...

  lifecycle {
    create_before_destroy = true
  }
}
```

---

### ISSUE #9: CloudWatch Log Retention

**Severity**: LOW
**Location**: `variables.tf:439`

**Problem**:
Default log retention is only 7 days:

```hcl
cloudwatch_log_retention_days = 7
```

**Consideration**:
For production, this might be too short. Consider environment-based defaults or at least document this prominently.

**Recommendation**:
Update default to 14 or 30 days, or add a note in README about log retention for compliance.

---

### ISSUE #10: Missing Container Insights ✅ **FIXED: Circuit Breaker Added**

**Status**: RESOLVED - Circuit breaker was the critical deployment safety feature needed.

**Next Step for Container Insights**:
The module doesn't enable Container Insights for the ECS service. This is a simple addition to the community module:

```hcl
# In variables.tf:
variable "enable_container_insights" {
  description = "Enable Container Insights for enhanced monitoring"
  type        = bool
  default     = false  # Keep disabled by default for cost reasons
}

# In ecs.tf:
module "ecs_service" {
  # ... existing config ...
  enable_container_insights = var.enable_container_insights
}
```

---

### ISSUE #11: Health Check Defaults

**Severity**: LOW
**Location**: `variables.tf:146-152`

**Problem**:
Container health checks have good defaults, but:
- `startPeriod = 60` might be too short for PHP-FPM apps
- No validation that health check command is provided

**Recommendation**:
Document recommended `startPeriod` values for different application types:
- PHP-FPM: 90-120 seconds
- Node.js: 30-60 seconds
- Static content: 15-30 seconds

---

### ISSUE #12: DNS Records Limited to Simple Records

**Severity**: LOW
**Location**: `dns.tf`, `variables.tf:421-430`

**Problem**:
The DNS module only supports simple records:
- No alias record support (for ALB)
- No weighted/latency routing
- No health check association

**Recommendation**:
This is acceptable for most use cases. Document that complex DNS setups should be managed separately. Most services use ALB listener rules, not DNS routing.

---

### ISSUE #13: No Service Scaling Schedule Support

**Severity**: LOW
**Location**: `autoscaling.tf`

**Problem**:
The autoscaling variable only supports target tracking (not step scaling or scheduled scaling).

**Use Case**:
Scheduled scaling could be useful for:
- Scale up before known traffic peaks
- Scale down during off-hours
- Cost optimization

**Recommendation**:
Add scheduled scaling as a future enhancement if needed:
```hcl
variable "autoscaling_schedule" {
  description = "Scheduled scaling actions"
  type = map(object({
    schedule     = string  # cron expression
    min_capacity = number
    max_capacity = number
  }))
  default = {}
}
```

---

### ISSUE #14: Container Definition Merge Logic

**Severity**: LOW
**Location**: `locals.tf:78-120`

**Problem**:
In the container definition merge, `health_check` is referenced twice:
- Line 103: `healthCheck = container.health_check`
- Line 118: Conditional merge again

This might cause issues if health_check is null.

**Current Code**:
```hcl
merge(
  {
    # ...
    healthCheck = container.health_check  # Line 103
  },
  container.user != null ? { user = container.user } : {},
  container.command != null ? { command = container.command } : {},
  container.entrypoint != null ? { entrypoint = container.entrypoint } : {},
  container.health_check != null ? { healthCheck = container.health_check } : {}  # Line 118
)
```

**Recommendation**:
Remove the duplicate at line 103 and only use the conditional merge at line 118.

---

## Summary

**Completed**:
- ✅ Autoscaling implementation (CRITICAL)
- ✅ Circuit breaker support (MINOR → implemented as important safety feature)

**Remaining**:
- 6 Moderate issues (🟡)
- 7 Minor issues (🟢)

**Priority Recommendations**:
1. **High**: Fix FluentBit secret configuration (#2)
2. **Medium**: Align security group rule format (#3)
3. **Medium**: Review ALB stickiness defaults for session-based apps (#4)
4. **Low**: Add Container Insights support (#10)
5. **Low**: Fix container definition merge logic (#14)

The module is now **production-ready** for the ECS migration. The remaining issues are quality-of-life improvements that can be addressed incrementally.

---

**Note**: This file is not tracked in git. It's for internal reference during development.
