locals {
  suffix = "${var.project_name}-${var.environment}"
}

module "x" {
  source = "./modules/x"

  providers = {
    random = random.legacy
  }

  suffix = local.suffix
}
