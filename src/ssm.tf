locals {
  ssm_path_prefix = length(var.ssm_cluster_name_override) > 0 ? format("/%s/%s", var.ssm_path_prefix, var.ssm_cluster_name_override) : format("/%s/%s", var.ssm_path_prefix, module.cluster.id)

  admin_user_key     = format("%s/%s/%s", local.ssm_path_prefix, "admin", "user")
  admin_password_key = format("%s/%s/%s", local.ssm_path_prefix, "admin", "password")

  cluster_domain = trimprefix(module.aurora_postgres_cluster.endpoint, "${module.aurora_postgres_cluster.cluster_identifier}.cluster-")

  default_parameters = [
    {
      name        = format("%s/%s", local.ssm_path_prefix, "cluster_domain")
      value       = local.cluster_domain
      description = "AWS DNS name under which DB instances are provisioned"
      type        = "String"
      overwrite   = true
    },
    {
      name        = format("%s/%s", local.ssm_path_prefix, "db_host")
      value       = module.aurora_postgres_cluster.master_host
      description = "Aurora Postgres DB Master hostname"
      type        = "String"
      overwrite   = true
    },
    {
      name        = format("%s/%s", local.ssm_path_prefix, "db_port")
      value       = var.database_port
      description = "Aurora Postgres DB Master TCP port"
      type        = "String"
      overwrite   = true
    },
    {
      name        = format("%s/%s", local.ssm_path_prefix, "cluster_name")
      value       = module.aurora_postgres_cluster.cluster_identifier
      description = "Aurora Postgres DB Cluster Identifier"
      type        = "String"
      overwrite   = true
    }
  ]
  cluster_parameters = var.cluster_size > 0 ? [
    {
      name        = format("%s/%s", local.ssm_path_prefix, "replicas_hostname")
      value       = module.aurora_postgres_cluster.replicas_host
      description = "Aurora Postgres DB Replicas hostname"
      type        = "String"
      overwrite   = true
    },
  ] : []
  admin_user_parameters = [
    {
      name        = local.admin_user_key
      value       = local.admin_user
      description = "Aurora Postgres DB admin user"
      type        = "String"
      overwrite   = true
    },
    {
      name        = local.admin_password_key
      value       = local.admin_password
      description = "Aurora Postgres DB admin password"
      type        = "SecureString"
      overwrite   = true
    }
  ]

  parameter_write = concat(local.default_parameters, local.cluster_parameters, local.admin_user_parameters)
}

module "parameter_store_write" {
  source  = "cloudposse/ssm-parameter-store/aws"
  version = "0.13.0"

  # kms_arn will only be used for SecureString parameters
  kms_arn = module.kms_key_rds.key_arn

  parameter_write = local.parameter_write

  context = module.cluster.context
}
