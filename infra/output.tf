output "instances" {
  value = {
    dev = {
      id         = aws_instance.dev.id
      private_ip = aws_instance.dev.private_ip
      public_ip  = aws_instance.dev.public_ip
    }
    qa = {
      id         = aws_instance.qa.id
      private_ip = aws_instance.qa.private_ip
      public_ip  = aws_instance.qa.public_ip
    }
  }
}

output "artifact_bucket_s3_uri" {
  value = "s3://${aws_s3_bucket.artifact_storage.bucket}"
}

output "subnet_cidrs" {
  value = {
    public  = local.public_subnets
    private = local.private_subnets
  }
}

output "jenkins_url" {
  value = "http://${aws_instance.jenkins.public_dns}:8080"
}