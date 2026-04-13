# Main HTTP API Gateway entry point
resource "aws_apigatewayv2_api" "ticket_api" {
  name          = "ticket-system-api"
  protocol_type = "HTTP"
  
  cors_configuration {
    allow_origins = ["https://mrpservices.tech", "https://www.mrpservices.tech", "https://d1bukpv5zye5a1.cloudfront.net"]
    allow_methods = ["*"]
    allow_headers = ["*"]
  }
}

# Connect APIGW to the Lambda backend
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.ticket_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.ticket_handler.invoke_arn
}

# Catch-all route so FastAPI handles the actual sub-routing logic
resource "aws_apigatewayv2_route" "default_route" {
  api_id    = aws_apigatewayv2_api.ticket_api.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Keeping rate limits tight to prevent to wake up with a surprise :D (spam/high costs)
resource "aws_apigatewayv2_stage" "api_stage" {
  api_id      = aws_apigatewayv2_api.ticket_api.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 1
    throttling_rate_limit  = 3
  }
}

# IAM permissions to let APIGW trigger the Lambda
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ticket_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.ticket_api.execution_arn}/*/*"
}