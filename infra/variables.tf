## ----------------------- general ----------------------- ##

variable "tags" {
  description = "Default tags for all the resources"
  type        = map(string)
  default = {
    Project     = "ticketing-service-serverless"
    Environment = "test"
    ManagedBy   = "terraform"
  }
}

## ----------------------- lambda variables ----------------------- ##

variable "lambda_zip_path" {
  description = "Path to the Lambda function zip file"
  type        = string
  default     = "lambda_function.zip"
}

variable "lambda_function_name" {
  description = "The name of the Lambda function"
  type        = string
  default     = "ticketing-service-lambda"
}

variable "lambda_handler" {
  description = "The entry point for the Lambda function"
  type        = string
  default     = "lambda_function.handler"
}

variable "admin_group" {
  description = "cognito admin group name"
  type        = string
  default     = "Admins"
}

## ----------------------- sns ----------------------- ##

variable "sns_email_endpoint" {
  description = "Notifications email"
  type        = string
}

## ----------------------- cloudfront ----------------------- ##

variable "cert_arn" {
  description = "Custom certificate ARN for CloudFront"
  type        = string
}