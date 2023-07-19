module "resource_group" {
  source = "../modules/resource-group"
  name   = var.name
  region = var.region
}