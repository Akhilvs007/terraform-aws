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
    key = "prod/services/webserver-cluster/terraform.tfstate"
    region = "us-east-2"
    dynamodb_table = "my-nasty-aws-dynamodb-table"
    encrypt = true
  }
}

module "webserver_cluster" {
  source = "../../../modules/services/webserver-cluster"

  cluster_name = "webserver-prod"
  instance_type = "t2.micro"
  min_size = 2
  max_size = 10
}