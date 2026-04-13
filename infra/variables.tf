## ----------------------- general ----------------------- ##

variable "tags" {
  description = "Default tags for all the resources"
  type        = map(string)
}

## ----------------------- lambda variables ----------------------- ##

variable "lambda_zip_path" {
  description = "Path to the Lambda function zip file"
  type        = string
}

variable "lambda_function_name" {
  description = "The name of the Lambda function"
  type        = string
}

variable "lambda_handler" {
  description = "The entry point for the Lambda function"
  type        = string
}

variable "admin_group" {
  description = "cognito admin group name"
  type        = string
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