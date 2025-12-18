output "database_name" {
  value       = local.database_name
  description = "Postgres database name"
}

output "admin_username" {
  value       = module.aurora_postgres_cluster.master_username
  description = "Postgres admin username"
  sensitive   = true
}

output "master_hostname" {
  value       = module.aurora_postgres_cluster.master_host
  description = "Postgres master hostname"
}

output "replicas_hostname" {
  value       = module.aurora_postgres_cluster.replicas_host
  description = "Postgres replicas hostname"
}

output "cluster_endpoint" {
  value       = module.aurora_postgres_cluster.endpoint
  description = "Postgres cluster endpoint"
}

output "reader_endpoint" {
  value       = module.aurora_postgres_cluster.reader_endpoint
  description = "Postgres reader endpoint"
}

output "instance_endpoints" {
  value       = module.aurora_postgres_cluster.instance_endpoints
  description = "List of Postgres instance endpoints"
}

output "cluster_identifier" {
  value       = module.aurora_postgres_cluster.cluster_identifier
  description = "Postgres cluster identifier"
}

output "ssm_key_paths" {
  value       = module.parameter_store_write.names
  description = "Names (key paths) of all SSM parameters stored for this cluster"
}

output "config_map" {
  value = {
    cluster          = module.aurora_postgres_cluster.cluster_identifier
    database         = local.database_name
    hostname         = module.aurora_postgres_cluster.master_host
    port             = var.database_port
    endpoint         = module.aurora_postgres_cluster.endpoint
    username         = module.aurora_postgres_cluster.master_username
    password_ssm_key = local.admin_password_key
  }
  description = "Map containing information pertinent to a PostgreSQL client configuration."
  sensitive   = true
}

output "kms_key_arn" {
  value       = module.kms_key_rds.key_arn
  description = "KMS key ARN for Aurora Postgres"
}

output "allowed_security_groups" {
  value       = local.allowed_security_groups
  description = "The resulting list of security group IDs that are allowed to connect to the Aurora Postgres cluster."
}

output "security_group_id" {
  value       = module.aurora_postgres_cluster.security_group_id
  description = "The security group ID of the Aurora Postgres cluster"
}

# RDS Proxy Outputs
output "proxy_id" {
  value       = one(module.rds_proxy[*].proxy_id)
  description = "The ID of the RDS Proxy"
}

output "proxy_arn" {
  value       = one(module.rds_proxy[*].proxy_arn)
  description = "The ARN of the RDS Proxy"
}

output "proxy_endpoint" {
  value       = one(module.rds_proxy[*].proxy_endpoint)
  description = "The endpoint of the RDS Proxy"
}

output "proxy_dns_name" {
  value       = one(aws_route53_record.proxy[*].fqdn)
  description = "The DNS name of the RDS Proxy (Route53 record)"
}

output "proxy_target_endpoint" {
  value       = one(module.rds_proxy[*].proxy_target_endpoint)
  description = "Hostname for the target RDS DB Instance"
}

output "proxy_target_id" {
  value       = one(module.rds_proxy[*].proxy_target_id)
  description = "Identifier of db_proxy_name, target_group_name, target type, and resource identifier separated by forward slashes"
}

output "proxy_target_port" {
  value       = one(module.rds_proxy[*].proxy_target_port)
  description = "Port for the target Aurora DB cluster"
}

output "proxy_target_rds_resource_id" {
  value       = one(module.rds_proxy[*].proxy_target_rds_resource_id)
  description = "Identifier representing the DB cluster target"
}

output "proxy_target_type" {
  value       = one(module.rds_proxy[*].proxy_target_type)
  description = "Type of target (e.g. RDS_INSTANCE or TRACKED_CLUSTER)"
}

output "proxy_default_target_group_arn" {
  value       = one(module.rds_proxy[*].proxy_default_target_group_arn)
  description = "The Amazon Resource Name (ARN) representing the default target group"
}

output "proxy_default_target_group_name" {
  value       = one(module.rds_proxy[*].proxy_default_target_group_name)
  description = "The name of the default target group"
}

output "proxy_iam_role_arn" {
  value       = one(module.rds_proxy[*].proxy_iam_role_arn)
  description = "The ARN of the IAM role that the proxy uses to access secrets in AWS Secrets Manager"
}
