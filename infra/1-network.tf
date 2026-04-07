module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.1"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  public_subnets  = local.public_subnets
  private_subnets = local.private_subnets

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    Tier = "public"
  }

  private_subnet_tags = {
    Tier = "private"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"

  # Attach to both route tables so private/public instances can use it I guess
  route_table_ids = concat(
    module.vpc.public_route_table_ids,
    module.vpc.private_route_table_ids
  )

  tags = {
    Name = "${local.name}-s3-endpoint"
  }
}


module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.3.1"

  name        = "${local.name}-ec2-sg"
  description = "SG for dev, qa, and prod instances"
  vpc_id      = module.vpc.vpc_id

  # Inbound rules
  ingress_rules = [
    "ssh-tcp",
    "http-80-tcp"
  ]

  # Custom rule for port 8080
  ingress_with_cidr_blocks = [
    {
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
      description = "HTTP 8080"
    }
  ]

  # Allow from anywhere
  ingress_cidr_blocks = ["0.0.0.0/0"]

  # Egress (default allow all, but explicit for clarity)
  egress_rules = ["all-all"]

  tags = {
    Name = "${local.name}-ec2-sg"
  }
}