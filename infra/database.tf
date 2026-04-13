# Ticket storage backend
resource "aws_dynamodb_table" "tickets_table" {
  name           = "tickets"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id" 

  # PK setup
  attribute {
    name = "id"
    type = "S"
  }
}