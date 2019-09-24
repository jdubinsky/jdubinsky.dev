terraform {
  backend "s3" {
    bucket = "jdev-tfstate-prod"
    key    = "terraform/prod/terraform.tfstate"
    region = "us-east-1"
  }
}
