terraform {
  backend "s3" {
    bucket = "mrpservices-tfstates-prod" 
    key    = "mrp-serverless-ticketing/terraform.tfstate"   
    region = "eu-central-1"                 
  }
}