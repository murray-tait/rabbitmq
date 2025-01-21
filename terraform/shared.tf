locals {
  domain                = var.domain
  environment           = coalesce(var.environment, terraform.workspace)
  app_name              = "labelling"
  project_name          = "translate"
  api_gw_subdomain      = "api.${local.fqdn}"
  callback_gw_subdomain = "callbacks.${local.fqdn}"
}

locals {
  tld_as_list = split(".", local.domain)
  fqdn_as_list = concat(
    [
      local.environment == "prod" ? "" : local.environment,
      local.app_name
    ],
    local.tld_as_list
  )
  fqdn = join(".", compact(local.fqdn_as_list))
}


locals {
  tags = {
    "AccountId"       = local.account_id
    "Region"          = local.region
    "Organization"    = "ETS"
    "CostCenter"      = "4374"
    "Requestor"       = "klwv406"
    "IDMD_Task"       = "Labelling"
    "applicationname" = "${local.project_name}-${local.app_name}"
    "managed"         = "terraform"
    "sub_system"      = var.sub_system
    "repository"      = "https://github.com/azu-ecs/translate-labeling-${var.sub_system}"
  }
}


locals {
  resource_prefix = "az-${local.region}-${local.account_id}-ets-${local.environment}-${local.app_name}"
}

locals {
  region = "eu-west-1"
  zone   = "eu-west-1a"
}

locals {
  account_id = local.account_id_map[local.environment]
  profile    = "${local.account_id}_AWSPowerUserAccess"
}

locals {
  account_id_map = {
    dev1     = "127214154594"
    endtoend = "481652375433"
    train    = ""
    preprod  = ""
    prod     = ""
  }
}
