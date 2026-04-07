# module "prod_asg" {
#   source  = "terraform-aws-modules/autoscaling/aws"
#   version = "9.2.0"

#   name = "${local.name}-prod"

#   min_size         = 3
#   max_size         = 3
#   desired_capacity = 3

#   vpc_zone_identifier = module.vpc.public_subnets


#   image_id      = data.aws_ami.al2023.id
#   instance_type = local.env_config.prod.instance_type

#   create_iam_instance_profile = false
#   iam_instance_profile_name   = aws_iam_instance_profile.ec2_profile.name

#   security_groups = [module.security_group.security_group_id]

#   update_default_version = true

#   tags = {
#     Name      = "${local.name}-prod"
#     env       = "prod"
#     Project   = local.name
#     ManagedBy = "Terraform"
#   }
# }

resource "aws_instance" "prod" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = local.env_config.prod.instance_type
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [module.security_group.security_group_id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = true

  tags = {
    Name      = "${local.name}-prod"
    env       = "prod"
    Project   = local.name
    ManagedBy = "Terraform"
  }
}