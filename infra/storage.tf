resource "aws_s3_bucket" "artifact_storage" {
  bucket_prefix = "artifact-storage-"

  force_destroy = true

  tags = {
    Name = "artifact-storage"
  }
}

resource "aws_s3_bucket_versioning" "artifact_storage" {
  bucket = aws_s3_bucket.artifact_storage.id

  versioning_configuration {
    status = "Enabled"
  }
}