resource "aws_sns_topic" "ticket_notifications" {
  name = "TicketNotifications"
}

# mail subscription
resource "aws_sns_topic_subscription" "admin_email_target" {
  topic_arn = aws_sns_topic.ticket_notifications.arn
  protocol  = "email"
  endpoint  = var.sns_email_endpoint
}