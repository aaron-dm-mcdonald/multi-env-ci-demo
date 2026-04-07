locals {
  name = "go-demo"

  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  vpc_cidr = "10.10.0.0/16"

  # cidrsubnet(base_cidr, newbits, netnum)
  #
  # base_cidr = "10.0.0.0/16"
  # newbits   = 8
  #
  # Adding 8 bits to /16 gives us /24 subnets.
  # netnum chooses which /24 subnet to carve out.
  #
  # So these become:
  # cidrsubnet("10.0.0.0/16", 8, 0)  -> 10.0.0.0/24
  # cidrsubnet("10.0.0.0/16", 8, 1)  -> 10.0.1.0/24
  # cidrsubnet("10.0.0.0/16", 8, 2)  -> 10.0.2.0/24

  public_subnets = [
    cidrsubnet(local.vpc_cidr, 8, 0),
    cidrsubnet(local.vpc_cidr, 8, 1),
    cidrsubnet(local.vpc_cidr, 8, 2)
  ]

  private_subnets = [
    cidrsubnet(local.vpc_cidr, 8, 10),
    cidrsubnet(local.vpc_cidr, 8, 11),
    cidrsubnet(local.vpc_cidr, 8, 12)
  ]

  env_config = {
    dev = {
      instance_type = "t3.micro"
      subnet_id     = module.vpc.public_subnets[0]
    }
    qa = {
      instance_type = "t3.micro"
      subnet_id     = module.vpc.public_subnets[1]
    }
    prod = {
      instance_type = "t3.small"
    }
  }

}
