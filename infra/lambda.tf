## ----------------------- IAM Configuration ----------------------- ##

# Execution role for the ticketing backend
resource "aws_iam_role" "lambda_role" {
  name = "ticketing_system_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Permissions for DB operations, CloudWatch logs, and SNS alerts
resource "aws_iam_policy" "lambda_policy" {
  name        = "ticketing_system_lambda_policy"
  description = "Allow Lambda to write to DynamoDB and CloudWatch Logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:UpdateItem", "dynamodb:Scan"]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.tickets_table.arn
      },
      {
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Action   = "sns:Publish"
        Effect   = "Allow"
        Resource = aws_sns_topic.ticket_notifications.arn
      }
    ]
  })
}

# Link the policy to the IAM role
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

## ----------------------- Lambda Function ----------------------- ##

# Main Lambda function handling the ticketing logic
resource "aws_lambda_function" "ticket_handler" {
  filename      = var.lambda_zip_path
  function_name = var.lambda_function_name
  role          = aws_iam_role.lambda_role.arn
  handler       = var.lambda_handler # Entry point format: filename.function
  runtime       = "python3.12"

  # Trigger an update whenever the ZIP file content changes
  source_code_hash = filebase64sha256(var.lambda_zip_path)

  environment {
    variables = {
      TABLE_NAME           = aws_dynamodb_table.tickets_table.name
      ADMIN_GROUP_NAME     = var.admin_group
      TOPIC_ARN            = aws_sns_topic.ticket_notifications.arn
      COGNITO_USER_POOL_ID = aws_cognito_user_pool.user_pool.id
      COGNITO_CLIENT_ID    = aws_cognito_user_pool_client.client.id
    }
  }

  tags = var.tags
}