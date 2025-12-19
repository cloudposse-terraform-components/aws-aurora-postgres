locals {
  proxy_enabled = local.enabled && var.proxy_enabled

  # Supported engine families for RDS Proxy: MYSQL, POSTGRESQL, SQLSERVER
  # Map the engine variable to the appropriate proxy engine family
  proxy_engine_family = var.engine == "postgresql" ? "POSTGRESQL" : (
    var.engine == "mysql" ? "MYSQL" : (
      var.engine == "sqlserver" ? "SQLSERVER" : upper(var.engine)
    )
  )

  # Get the secret ARN for authentication - either from managed password or user-provided
  # When manage_admin_user_password is true, the cluster creates a secret in Secrets Manager
  proxy_secret_arn = var.manage_admin_user_password ? module.aurora_postgres_cluster.master_user_secret[0].secret_arn : var.proxy_secret_arn

  # Build auth configuration
  proxy_auth = var.proxy_auth != null ? var.proxy_auth : (
    local.proxy_secret_arn != null ? [
      {
        auth_scheme               = "SECRETS"
        client_password_auth_type = var.proxy_client_password_auth_type
        description               = "Authenticate using Secrets Manager"
        iam_auth                  = var.proxy_iam_auth
        secret_arn                = local.proxy_secret_arn
        username                  = null
      }
    ] : []
  )

  # Proxy DNS name
  proxy_dns_name = format("%v%v", local.cluster_dns_name_prefix, var.proxy_dns_name_part)
}

# Dedicated security group for RDS Proxy
resource "aws_security_group" "proxy" {
  count = local.proxy_enabled ? 1 : 0

  name        = "${module.cluster.id}-proxy"
  description = "Security group for RDS Proxy"
  vpc_id      = local.vpc_id

  tags = module.cluster.tags
}

# Egress rule: Allow proxy to connect to Aurora cluster on database port
resource "aws_security_group_rule" "proxy_egress_to_cluster" {
  count = local.proxy_enabled ? 1 : 0

  type                     = "egress"
  from_port                = var.database_port
  to_port                  = var.database_port
  protocol                 = "tcp"
  source_security_group_id = module.aurora_postgres_cluster.security_group_id
  security_group_id        = aws_security_group.proxy[0].id
  description              = "Allow proxy to connect to Aurora cluster"
}

# Ingress rule on Aurora cluster: Allow connections from proxy security group
resource "aws_security_group_rule" "cluster_ingress_from_proxy" {
  count = local.proxy_enabled ? 1 : 0

  type                     = "ingress"
  from_port                = var.database_port
  to_port                  = var.database_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.proxy[0].id
  security_group_id        = module.aurora_postgres_cluster.security_group_id
  description              = "Allow connections from RDS Proxy"
}

module "rds_proxy" {
  source  = "cloudposse/rds-db-proxy/aws"
  version = "1.1.1"

  count = local.proxy_enabled ? 1 : 0

  db_cluster_identifier = module.aurora_postgres_cluster.cluster_identifier

  auth          = local.proxy_auth
  engine_family = local.proxy_engine_family
  # RDS Proxy must always be in private subnets for security
  vpc_subnet_ids               = local.private_subnet_ids
  vpc_security_group_ids       = [aws_security_group.proxy[0].id]
  debug_logging                = var.proxy_debug_logging
  idle_client_timeout          = var.proxy_idle_client_timeout
  require_tls                  = var.proxy_require_tls
  connection_borrow_timeout    = var.proxy_connection_borrow_timeout
  init_query                   = var.proxy_init_query
  max_connections_percent      = var.proxy_max_connections_percent
  max_idle_connections_percent = var.proxy_max_idle_connections_percent
  session_pinning_filters      = var.proxy_session_pinning_filters
  iam_role_attributes          = var.proxy_iam_role_attributes
  existing_iam_role_arn        = var.proxy_existing_iam_role_arn
  kms_key_id                   = var.storage_encrypted ? module.kms_key_rds.key_arn : null

  context = module.cluster.context
}

resource "aws_route53_record" "proxy" {
  count = local.proxy_enabled && var.proxy_dns_enabled ? 1 : 0

  zone_id = local.zone_id
  name    = local.proxy_dns_name
  type    = "CNAME"
  ttl     = 60
  records = [module.rds_proxy[0].proxy_endpoint]
}

check "proxy_engine_supported" {
  assert {
    condition     = !var.proxy_enabled || contains(["mysql", "postgresql", "sqlserver"], var.engine)
    error_message = "RDS Proxy only supports MYSQL, POSTGRESQL, and SQLSERVER engine families. The engine '${var.engine}' is not supported."
  }
}
