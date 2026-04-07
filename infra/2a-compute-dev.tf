resource "aws_instance" "dev" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = local.env_config.dev.instance_type
  subnet_id                   = local.env_config.dev.subnet_id
  vpc_security_group_ids      = [module.security_group.security_group_id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = true

  tags = {
    Name = "${local.name}-dev"
    env  = "dev"
  }
}