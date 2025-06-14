# A child module automatically inherits default (un-aliased) provider configurations from its parent.
# This means that explicit provider blocks appear only in the root module, and downstream modules can simply
# declare resources for that provider and have them automatically associated with the root provider configurations

# https://www.terraform.io/docs/providers/aws/r/rds_cluster.html
module "aurora_postgres_cluster" {
  source  = "cloudposse/rds-cluster/aws"
  version = "1.18.0"

  cluster_type   = "regional"
  engine         = var.engine
  engine_version = var.engine_version
  engine_mode    = var.engine_mode
  cluster_family = var.cluster_family
  instance_type  = var.instance_type
  cluster_size   = var.cluster_size
  admin_user     = local.admin_user
  admin_password = local.admin_password

  db_name                              = local.database_name
  publicly_accessible                  = var.publicly_accessible
  db_port                              = var.database_port
  vpc_id                               = local.vpc_id
  subnets                              = var.publicly_accessible ? local.public_subnet_ids : local.private_subnet_ids
  zone_id                              = local.zone_id
  cluster_dns_name                     = local.cluster_dns_name
  reader_dns_name                      = local.reader_dns_name
  security_groups                      = local.allowed_security_groups
  intra_security_group_traffic_enabled = var.intra_security_group_traffic_enabled
  allowed_cidr_blocks                  = local.allowed_cidr_blocks
  iam_database_authentication_enabled  = var.iam_database_authentication_enabled
  storage_encrypted                    = var.storage_encrypted
  kms_key_arn                          = var.storage_encrypted ? module.kms_key_rds.key_arn : null
  performance_insights_kms_key_id      = var.performance_insights_enabled ? module.kms_key_rds.key_arn : null
  maintenance_window                   = var.maintenance_window
  enabled_cloudwatch_logs_exports      = var.enabled_cloudwatch_logs_exports
  enhanced_monitoring_role_enabled     = var.enhanced_monitoring_role_enabled
  enhanced_monitoring_attributes       = var.enhanced_monitoring_attributes
  performance_insights_enabled         = var.performance_insights_enabled
  rds_monitoring_interval              = var.rds_monitoring_interval
  autoscaling_enabled                  = var.autoscaling_enabled
  autoscaling_policy_type              = var.autoscaling_policy_type
  autoscaling_target_metrics           = var.autoscaling_target_metrics
  autoscaling_target_value             = var.autoscaling_target_value
  autoscaling_scale_in_cooldown        = var.autoscaling_scale_in_cooldown
  autoscaling_scale_out_cooldown       = var.autoscaling_scale_out_cooldown
  autoscaling_min_capacity             = var.autoscaling_min_capacity
  autoscaling_max_capacity             = var.autoscaling_max_capacity
  scaling_configuration                = var.scaling_configuration
  serverlessv2_scaling_configuration   = var.serverlessv2_scaling_configuration
  skip_final_snapshot                  = var.skip_final_snapshot
  deletion_protection                  = var.deletion_protection
  snapshot_identifier                  = var.snapshot_identifier
  allow_major_version_upgrade          = var.allow_major_version_upgrade
  ca_cert_identifier                   = var.ca_cert_identifier
  retention_period                     = var.retention_period
  backup_window                        = var.backup_window

  cluster_parameters = concat([
    {
      apply_method = "immediate"
      name         = "log_statement"
      value        = "all"
    },
    {
      apply_method = "immediate"
      name         = "log_min_duration_statement"
      value        = "0"
    }
  ], var.cluster_parameters)

  context = module.cluster.context
}
