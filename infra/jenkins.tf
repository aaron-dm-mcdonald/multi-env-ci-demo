resource "aws_instance" "jenkins" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t2.large"
  subnet_id                   = module.vpc.public_subnets[2]
  vpc_security_group_ids      = [module.security_group.security_group_id]
  iam_instance_profile        = aws_iam_instance_profile.jenkins_ec2_profile.name
  associate_public_ip_address = true

  user_data = file("../scripts/user-data/jenkins-userdata.sh")

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }

  tags = {
    Name = "jenkins-ci-server"
    env  = "jenkins"
  }
}


########################

resource "aws_iam_role" "jenkins_ec2_role" {
  name = "jenkins-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "jenkins-ec2-role"
    env  = "jenkins"
  }
}

resource "aws_iam_policy" "jenkins_ec2_policy" {
  name        = "jenkins-ec2-policy"
  description = "Permissions for Jenkins EC2 instance"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.artifact_storage.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2-instance-connect:SendSSHPublicKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "jenkins-ec2-policy"
    env  = "jenkins"
  }
}

resource "aws_iam_role_policy_attachment" "jenkins_ec2_attach" {
  role       = aws_iam_role.jenkins_ec2_role.name
  policy_arn = aws_iam_policy.jenkins_ec2_policy.arn
}

resource "aws_iam_instance_profile" "jenkins_ec2_profile" {
  name = "jenkins-ec2-profile"
  role = aws_iam_role.jenkins_ec2_role.name

  tags = {
    Name = "jenkins-ec2-profile"
    env  = "jenkins"
  }
}