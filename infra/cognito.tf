# Main user directory for the ticketing platform
resource "aws_cognito_user_pool" "user_pool" {
  name = "mrp_user_pool"

  # Sign-in via email instead of username
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  # Restrict signups to admin invites only
  admin_create_user_config {
    allow_admin_create_user_only = true
  }

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  schema {
    attribute_data_type      = "String"
    name                     = "email"
    required                 = true
    mutable                  = true

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }
}

# Domain for the hosted Cognito UI
resource "aws_cognito_user_pool_domain" "main" {
  domain       = "mrpservicesauth"
  user_pool_id = aws_cognito_user_pool.user_pool.id
}

# App client configuration for the web frontend
resource "aws_cognito_user_pool_client" "client" {
  name         = "ticketing_app_client"
  user_pool_id = aws_cognito_user_pool.user_pool.id

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code", "implicit"]
  allowed_oauth_scopes                 = ["email", "openid", "phone", "profile"]
  supported_identity_providers         = ["COGNITO"]

  # Redirect targets after login/logout
  callback_urls = [
    "https://mrpservices.tech/admin/index.html",
    "https://mrpservices.tech/support/index.html"
  ]

  logout_urls = [
    "https://mrpservices.tech/admin/index.html",
    "https://mrpservices.tech/support/index.html"
  ]

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]

  generate_secret = false
}

# administrator Group for Role-Based Access Control ---

resource "aws_cognito_user_group" "admins" {
  name         = "Admins"
  user_pool_id = aws_cognito_user_pool.user_pool.id
  description  = "High-privilege group for ticketing system administrators"
  precedence   = 1
}