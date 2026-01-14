variable "region" {
  type        = string
  description = "AWS Region"
}

variable "dns_gbl_delegated_environment_name" {
  type        = string
  description = "The name of the environment where global `dns_delegated` is provisioned"
  default     = "gbl"
}

variable "cluster_name" {
  type        = string
  description = "Short name for this cluster"
}

variable "database_name" {
  type        = string
  description = "Name for an automatically created database on cluster creation. An empty name will generate a db name."
  default     = ""
}

variable "deletion_protection" {
  type        = bool
  default     = false
  description = "Specifies whether the Cluster should have deletion protection enabled. The database can't be deleted when this value is set to `true`"
}

variable "skip_final_snapshot" {
  type        = bool
  default     = false
  description = <<-EOT
    Normally AWS makes a snapshot of the database before deleting it. Set this to `true` in order to skip this.
    NOTE: The final snapshot has a name derived from the cluster name. If you delete a cluster, get a final snapshot,
    then create a cluster of the same name, its final snapshot will fail with a name collision unless you delete
    the previous final snapshot first.
    EOT
}

variable "storage_encrypted" {
  type        = bool
  default     = true
  description = "Specifies whether the DB cluster is encrypted"
}

variable "storage_type" {
  type        = string
  default     = null
  description = "One of 'standard' (magnetic), 'gp2' (general purpose SSD), 'io1' (provisioned IOPS SSD), 'aurora', or 'aurora-iopt1'"
}

variable "engine" {
  type        = string
  description = "Name of the database engine to be used for the DB cluster"
  default     = "postgresql"
}

variable "engine_version" {
  type        = string
  description = "Engine version of the Aurora global database"
  default     = "13.4"
}

variable "allow_major_version_upgrade" {
  type        = bool
  default     = false
  description = "Enable to allow major engine version upgrades when changing engine versions. Defaults to false."
}

variable "ca_cert_identifier" {
  description = "The identifier of the CA certificate for the DB instance"
  type        = string
  default     = null
}

variable "engine_mode" {
  type        = string
  description = "The database engine mode. Valid values: `global`, `multimaster`, `parallelquery`, `provisioned`, `serverless`"
}

variable "cluster_family" {
  type        = string
  description = "Family of the DB parameter group. Valid values for Aurora PostgreSQL: `aurora-postgresql9.6`, `aurora-postgresql10`, `aurora-postgresql11`, `aurora-postgresql12`"
  default     = "aurora-postgresql13"
}

variable "database_port" {
  type        = number
  description = "Database port"
  default     = 5432
}

# Don't use `admin`
# Read more: <https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_Limits.html>
# ("MasterUsername admin cannot be used as it is a reserved word used by the engine")
variable "admin_user" {
  type        = string
  description = "Postgres admin user name"
  default     = ""

  validation {
    condition = (
      length(var.admin_user) == 0 ||
      (var.admin_user != "admin" &&
        length(var.admin_user) >= 1 &&
      length(var.admin_user) <= 16)
    )
    error_message = "Per the RDS API, admin cannot be used as it is a reserved word used by the engine. Master username must be between 1 and 16 characters. If an empty string is provided then a random string will be used."
  }
}

# Must be longer than 8 chars
# Read more: <https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_Limits.html>
# ("The parameter MasterUserPassword is not a valid password because it is shorter than 8 characters")
variable "admin_password" {
  type        = string
  description = "Postgres password for the admin user"
  default     = ""
  sensitive   = true

  validation {
    condition = (
      length(var.admin_password) == 0 ||
      (length(var.admin_password) >= 8 &&
      length(var.admin_password) <= 128)
    )
    error_message = "Per the RDS API, master password must be between 8 and 128 characters. If an empty string is provided then a random password will be used."
  }
}

variable "manage_admin_user_password" {
  type        = bool
  default     = false
  description = "Set to true to allow RDS to manage the master user password in Secrets Manager. Cannot be set if admin_password is provided"
  nullable    = false
}

# https://aws.amazon.com/rds/aurora/pricing
variable "instance_type" {
  type        = string
  description = "EC2 instance type for Postgres cluster"
}

variable "cluster_size" {
  type        = number
  description = "Postgres cluster size"
}

variable "iam_database_authentication_enabled" {
  type        = bool
  description = "Specifies whether or mappings of AWS Identity and Access Management (IAM) accounts to database accounts is enabled"
  default     = false
}

variable "cluster_dns_name_part" {
  type        = string
  description = "Part of DNS name added to module and cluster name for DNS for cluster endpoint"
  default     = "writer"
}

variable "reader_dns_name_part" {
  type        = string
  description = "Part of DNS name added to module and cluster name for DNS for cluster reader"
  default     = "reader"
}

variable "ssm_path_prefix" {
  type        = string
  default     = "aurora-postgres"
  description = "Top level SSM path prefix (without leading or trailing slash)"
}

variable "publicly_accessible" {
  type        = bool
  description = "Set true to make this database accessible from the public internet"
  default     = false
}

variable "allowed_cidr_blocks" {
  type        = list(string)
  description = "List of CIDRs allowed to access the database (in addition to security groups and subnets)"
  default     = []
}

variable "maintenance_window" {
  type        = string
  default     = "wed:03:00-wed:04:00"
  description = "Weekly time range during which system maintenance can occur, in UTC"
}

variable "enabled_cloudwatch_logs_exports" {
  type        = list(string)
  description = "List of log types to export to cloudwatch. The following log types are supported: audit, error, general, slowquery"
  default     = []
}

variable "performance_insights_enabled" {
  type        = bool
  default     = false
  description = "Whether to enable Performance Insights"
}

variable "database_insights_mode" {
  type        = string
  description = "The database insights mode for the RDS cluster. Valid values are `standard`, `advanced`. See https://registry.terraform.io/providers/hashicorp/aws/6.16.0/docs/resources/rds_cluster#database_insights_mode-1"
  default     = null
}

variable "enhanced_monitoring_role_enabled" {
  type        = bool
  description = "A boolean flag to enable/disable the creation of the enhanced monitoring IAM role. If set to `false`, the module will not create a new role and will use `rds_monitoring_role_arn` for enhanced monitoring"
  default     = true
}

variable "enhanced_monitoring_attributes" {
  type        = list(string)
  description = "Attributes used to format the Enhanced Monitoring IAM role. If this role hits IAM role length restrictions (max 64 characters), consider shortening these strings."
  default     = ["enhanced-monitoring"]
}

variable "rds_monitoring_interval" {
  type        = number
  description = "The interval, in seconds, between points when enhanced monitoring metrics are collected for the DB instance. To disable collecting Enhanced Monitoring metrics, specify 0. The default is 0. Valid Values: 0, 1, 5, 10, 15, 30, 60"
  default     = 60
}

variable "promotion_tier" {
  type        = number
  default     = 0
  description = <<-EOT
    Failover Priority setting on instance level. The reader who has lower tier has higher priority to get promoted to writer.

    Readers in promotion tiers 0 and 1 scale at the same time as the writer. Readers in promotion tiers 2–15 scale independently from the writer. For more information, see: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2.how-it-works.html#aurora-serverless-v2.how-it-works.scaling
  EOT
}

variable "autoscaling_enabled" {
  type        = bool
  default     = false
  description = "Whether to enable cluster autoscaling"
}

variable "autoscaling_policy_type" {
  type        = string
  default     = "TargetTrackingScaling"
  description = "Autoscaling policy type. `TargetTrackingScaling` and `StepScaling` are supported"
}

variable "autoscaling_target_metrics" {
  type        = string
  default     = "RDSReaderAverageCPUUtilization"
  description = "The metrics type to use. If this value isn't provided the default is CPU utilization"
}

variable "autoscaling_target_value" {
  type        = number
  default     = 75
  description = "The target value to scale with respect to target metrics"
}

variable "autoscaling_scale_in_cooldown" {
  type        = number
  default     = 300
  description = "The amount of time, in seconds, after a scaling activity completes and before the next scaling down activity can start. Default is 300s"
}

variable "autoscaling_scale_out_cooldown" {
  type        = number
  default     = 300
  description = "The amount of time, in seconds, after a scaling activity completes and before the next scaling up activity can start. Default is 300s"
}

variable "autoscaling_min_capacity" {
  type        = number
  default     = 1
  description = "Minimum number of instances to be maintained by the autoscaler"
}

variable "autoscaling_max_capacity" {
  type        = number
  default     = 5
  description = "Maximum number of instances to be maintained by the autoscaler"
}

variable "snapshot_identifier" {
  type        = string
  default     = null
  description = "Specifies whether or not to create this cluster from a snapshot"
}

variable "allowed_security_group_names" {
  type        = list(string)
  description = "List of security group names (tags) that should be allowed access to the database"
  default     = []
}

variable "allowed_security_group_ids" {
  type        = list(string)
  description = "List of security group ids that should be allowed access to the database"
  default     = []
}

variable "eks_security_group_enabled" {
  type        = bool
  description = "Use the eks default security group"
  default     = false
}

variable "eks_component_names" {
  type        = set(string)
  description = "The names of the eks components"
  default     = ["eks/cluster"]
}

variable "allow_ingress_from_vpc_accounts" {
  type = list(object({
    vpc         = optional(string, "vpc")
    environment = optional(string)
    stage       = optional(string)
    tenant      = optional(string)
  }))
  default     = []
  description = <<-EOF
    List of account contexts to pull VPC ingress CIDR and add to cluster security group.
    e.g.
    {
      environment = "ue2",
      stage       = "auto",
      tenant      = "core"
    }

    Defaults to the "vpc" component in the given account
  EOF
}

variable "vpc_component_name" {
  type        = string
  default     = "vpc"
  description = "The name of the VPC component"
}

variable "scaling_configuration" {
  type = list(object({
    auto_pause               = bool
    max_capacity             = number
    min_capacity             = number
    seconds_until_auto_pause = number
    timeout_action           = string
  }))
  default     = []
  description = "List of nested attributes with scaling properties. Only valid when `engine_mode` is set to `serverless`. This is required for Serverless v1"
}

variable "serverlessv2_scaling_configuration" {
  type = object({
    min_capacity = number
    max_capacity = number
  })
  default     = null
  description = "Nested attribute with scaling properties for ServerlessV2. Only valid when `engine_mode` is set to `provisioned.` This is required for Serverless v2"
}

variable "restore_to_point_in_time" {
  type = list(object({
    source_cluster_identifier  = string
    restore_type               = optional(string, "copy-on-write")
    use_latest_restorable_time = optional(bool, true)
    restore_to_time            = optional(string, null)
  }))
  default     = []
  description = <<-EOT
    List of point-in-time recovery options. Valid parameters are:

    `source_cluster_identifier`
      Identifier of the source database cluster from which to restore.
    `restore_type`:
      Type of restore to be performed. Valid options are "full-copy" and "copy-on-write".
    `use_latest_restorable_time`:
      Set to true to restore the database cluster to the latest restorable backup time. Conflicts with `restore_to_time`.
    `restore_to_time`:
      Date and time in UTC format to restore the database cluster to. Conflicts with `use_latest_restorable_time`.
EOT
}

variable "intra_security_group_traffic_enabled" {
  type        = bool
  default     = false
  description = "Whether to allow traffic between resources inside the database's security group."
}

variable "cluster_parameters" {
  type = list(object({
    apply_method = string
    name         = string
    value        = string
  }))
  default     = []
  description = "List of DB cluster parameters to apply"
}

variable "retention_period" {
  type        = number
  default     = 5
  description = "Number of days to retain backups for"
}

variable "backup_window" {
  type        = string
  default     = "07:00-09:00"
  description = "Daily time range during which the backups happen, UTC"
}

variable "ssm_cluster_name_override" {
  type        = string
  default     = ""
  description = "Set a cluster name into the ssm path prefix"
}

# RDS Proxy Configuration
variable "proxy_enabled" {
  type        = bool
  default     = false
  description = "Whether to enable RDS Proxy for the Aurora cluster"
}

variable "proxy_debug_logging" {
  type        = bool
  default     = false
  description = "Whether the proxy includes detailed information about SQL statements in its logs"
}

variable "proxy_idle_client_timeout" {
  type        = number
  default     = 1800
  description = "The number of seconds that a connection to the proxy can be inactive before the proxy disconnects it"
}

variable "proxy_require_tls" {
  type        = bool
  default     = true
  description = "A Boolean parameter that specifies whether Transport Layer Security (TLS) encryption is required for connections to the proxy"
}

variable "proxy_connection_borrow_timeout" {
  type        = number
  default     = 120
  description = "The number of seconds for a proxy to wait for a connection to become available in the connection pool"
}

variable "proxy_init_query" {
  type        = string
  default     = null
  description = "One or more SQL statements for the proxy to run when opening each new database connection"
}

variable "proxy_max_connections_percent" {
  type        = number
  default     = 100
  description = "The maximum size of the connection pool for each target in a target group. Must be between 1 and 100."

  validation {
    condition     = var.proxy_max_connections_percent >= 1 && var.proxy_max_connections_percent <= 100
    error_message = "proxy_max_connections_percent must be between 1 and 100 (inclusive)."
  }
}

variable "proxy_max_idle_connections_percent" {
  type        = number
  default     = 50
  description = "Controls how actively the proxy closes idle database connections in the connection pool. Must be between 0 and 100."

  validation {
    condition     = var.proxy_max_idle_connections_percent >= 0 && var.proxy_max_idle_connections_percent <= 100
    error_message = "proxy_max_idle_connections_percent must be between 0 and 100 (inclusive)."
  }
}

variable "proxy_session_pinning_filters" {
  type        = list(string)
  default     = null
  description = "Each item in the list represents a class of SQL operations that normally cause all later statements in a session using a proxy to be pinned to the same underlying database connection"
}

variable "proxy_iam_role_attributes" {
  type        = list(string)
  default     = null
  description = "Additional attributes to add to the ID of the IAM role that the proxy uses to access secrets in AWS Secrets Manager"
}

variable "proxy_existing_iam_role_arn" {
  type        = string
  default     = null
  description = "The ARN of an existing IAM role that the proxy can use to access secrets in AWS Secrets Manager. If not provided, the module will create a role to access secrets in Secrets Manager"
}

variable "proxy_secret_arn" {
  type        = string
  default     = null
  description = "The ARN of the secret in AWS Secrets Manager that contains the database credentials. Required if manage_admin_user_password is false and proxy_auth is not provided"
}

variable "proxy_auth" {
  type = list(object({
    auth_scheme               = optional(string, "SECRETS")
    client_password_auth_type = optional(string)
    description               = optional(string)
    iam_auth                  = optional(string, "DISABLED")
    secret_arn                = optional(string)
    username                  = optional(string)
  }))
  default     = null
  description = <<-EOT
    Configuration blocks with authorization mechanisms to connect to the associated database instances or clusters.
    Each block supports:
    - auth_scheme: The type of authentication that the proxy uses for connections. Valid values: SECRETS
    - client_password_auth_type: The type of authentication the proxy uses for connections from clients. Valid values: MYSQL_NATIVE_PASSWORD, POSTGRES_SCRAM_SHA_256, POSTGRES_MD5, SQL_SERVER_AUTHENTICATION
    - description: A user-specified description about the authentication used by a proxy
    - iam_auth: Whether to require or disallow AWS IAM authentication. Valid values: DISABLED, REQUIRED, OPTIONAL
    - secret_arn: The ARN of the Secrets Manager secret containing the database credentials
    - username: The name of the database user to which the proxy connects
  EOT
}

variable "proxy_iam_auth" {
  type        = string
  default     = "DISABLED"
  description = "Whether to require or disallow AWS IAM authentication for connections to the proxy. Valid values: DISABLED, REQUIRED, OPTIONAL"

  validation {
    condition     = contains(["DISABLED", "REQUIRED", "OPTIONAL"], var.proxy_iam_auth)
    error_message = "Valid values for proxy_iam_auth are: DISABLED, REQUIRED, OPTIONAL."
  }
}

variable "proxy_client_password_auth_type" {
  type        = string
  default     = null
  description = "The type of authentication the proxy uses for connections from clients. Valid values: MYSQL_NATIVE_PASSWORD, POSTGRES_SCRAM_SHA_256, POSTGRES_MD5, SQL_SERVER_AUTHENTICATION"

  validation {
    condition     = var.proxy_client_password_auth_type == null || contains(["MYSQL_NATIVE_PASSWORD", "POSTGRES_SCRAM_SHA_256", "POSTGRES_MD5", "SQL_SERVER_AUTHENTICATION"], var.proxy_client_password_auth_type)
    error_message = "Valid values for proxy_client_password_auth_type are: MYSQL_NATIVE_PASSWORD, POSTGRES_SCRAM_SHA_256, POSTGRES_MD5, SQL_SERVER_AUTHENTICATION."
  }
}

variable "proxy_dns_enabled" {
  type        = bool
  default     = true
  description = "Whether to create a Route53 DNS record for the proxy endpoint"
}

variable "proxy_dns_name_part" {
  type        = string
  default     = "proxy"
  description = "Part of DNS name added to module and cluster name for DNS for the proxy endpoint"
}
