output "cloudfront_url" {
  description = "Cloudfront web url"
  value       = "https://${aws_cloudfront_distribution.s3_distribution.domain_name}"
}

output "s3_bucket_name" {
  value = aws_s3_bucket.frontend_bucket.id
}

# api gateway
output "api_url" {
  value = aws_apigatewayv2_api.ticket_api.api_endpoint
}

# cognito
output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.user_pool.id
}

output "cognito_client_id" {
  value = aws_cognito_user_pool_client.client.id
}