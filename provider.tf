terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  #  region = "ap-south-1"     #change region as per you requirement
  region = "us-west-2"     # us-west-2
}
