module "network" {
  source = "../../modules/network"

  name     = local.name
  vpc_cidr = "10.42.0.0/20"
  azs      = ["eu-west-2a", "eu-west-2b"]

  interface_endpoint_services = ["secretsmanager"]
}
