# ========================================
# Secrets Manager
# ========================================

# FluentBit Elasticsearch credentials
# Used to configure FluentBit sidecar for log forwarding
data "aws_secretsmanager_secret" "fluentbit" {
  name = "ic/${local.secret_env}/elastic/fluentbit"
}

data "aws_secretsmanager_secret_version" "fluentbit" {
  secret_id = data.aws_secretsmanager_secret.fluentbit.id
}
