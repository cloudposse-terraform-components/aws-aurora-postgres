locals {
  enabled = module.this.enabled

  vpc_id             = module.vpc.outputs.vpc_id
  private_subnet_ids = module.vpc.outputs.private_subnet_ids
  public_subnet_ids  = module.vpc.outputs.public_subnet_ids

  eks_security_group_enabled = local.enabled && var.eks_security_group_enabled
  allowed_eks_security_groups = [
    for eks in module.eks :
    eks.outputs.eks_cluster_managed_security_group_id
  ]
  allowed_security_groups = concat(data.aws_security_groups.allowed.ids, local.allowed_eks_security_groups, var.allowed_security_group_ids)

  zone_id = module.dns_gbl_delegated.outputs.default_dns_zone_id

  # 1. If manage_admin_user_password is true, AWS manages the password (admin_password must be empty)
  # 2. If admin_password is provided, that value is used (manage_admin_user_password must be false)
  # 3. If both are unset/false/empty, the module creates a random password
  create_password = local.enabled && var.admin_password == "" && !var.manage_admin_user_password
  admin_password  = var.manage_admin_user_password ? null : (local.create_password ? one(random_password.admin_password[*].result) : var.admin_password)

  admin_user    = length(var.admin_user) > 0 ? var.admin_user : one(random_pet.admin_user[*].id)
  database_name = length(var.database_name) > 0 ? var.database_name : one(random_pet.database_name[*].id)

  cluster_dns_name_prefix = format("%v%v%v%v", module.this.name, module.this.delimiter, var.cluster_name, module.this.delimiter)
  cluster_dns_name        = format("%v%v", local.cluster_dns_name_prefix, var.cluster_dns_name_part)
  reader_dns_name         = format("%v%v", local.cluster_dns_name_prefix, var.reader_dns_name_part)

  allowed_cidr_blocks = concat(
    var.allowed_cidr_blocks,
    [
      for k in keys(module.vpc_ingress) :
      module.vpc_ingress[k].outputs.vpc_cidr
    ]
  )
}

data "aws_security_groups" "allowed" {
  filter {
    name   = "tag:Name"
    values = var.allowed_security_group_names
  }
}

module "cluster" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  attributes = [var.cluster_name]

  context = module.this.context
}

resource "random_pet" "database_name" {
  count = local.enabled && length(var.database_name) == 0 ? 1 : 0

  separator = "_"

  keepers = {
    cluster_name = var.cluster_name
    db_name      = var.database_name
  }
}

resource "random_pet" "admin_user" {
  count = local.enabled && length(var.admin_user) == 0 ? 1 : 0

  length    = 2
  separator = "_"

  keepers = {
    cluster_name = var.cluster_name
    db_name      = var.database_name
  }
}

resource "random_password" "admin_password" {
  count = local.enabled && length(var.admin_password) == 0 ? 1 : 0

  length = 33
  # Leave special characters out to avoid quoting and other issues.
  # Special characters have no additional security compared to increasing length.
  special          = false
  override_special = "!#$%^&*()<>-_"

  keepers = {
    cluster_name = var.cluster_name
    db_name      = var.database_name
  }
}
