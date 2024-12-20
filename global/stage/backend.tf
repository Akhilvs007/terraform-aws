terraform {
    required_providers {
      aws = {
        source = "hashicorp/aws"
        version = "3.38"
      }
    }
    required_version = "1.9.8"
}

provider "aws" {
    region = "us-east-2"
}

terraform {
  backend "s3" {
    bucket = "my-nasty-s3-bucket"
    key = "global/s3/terraform.tfstate"
    region = "us-east-2"
    dynamodb_table = "my-nasty-aws-dynamodb-table"
    encrypt = true
  }
}

resource "aws_s3_bucket" "terraform_state" {
  
  bucket = "my-nasty-s3-bucket"

  lifecycle {
    prevent_destroy = true
  }

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_dynamodb_table" "terraform_locks" {
  name = "my-nasty-aws-dynamodb-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}