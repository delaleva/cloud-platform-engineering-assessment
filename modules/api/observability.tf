# A stub topic with no subscription. In a real deployment this would route to
# the on-call rota; here it gives the alarm a destination rather than leaving
# it to fire into nothing.
resource "aws_sns_topic" "alarms" {
  name              = "${var.name}-alarms"
  kms_master_key_id = var.kms_key_arn

  tags = {
    Name = "${var.name}-alarms"
  }
}

# Server errors from the target, not from the load balancer itself. The load
# balancer's own 5XX would fire on a certificate or listener fault, which is
# useful but noisier; this one means the API is failing requests it accepted.
resource "aws_cloudwatch_metric_alarm" "api_errors" {
  alarm_name          = "${var.name}-api-5xx"
  alarm_description   = "The API returned server errors to an authenticated client"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    LoadBalancer = aws_lb.this.arn_suffix
    TargetGroup  = aws_lb_target_group.api.arn_suffix
  }

  tags = {
    Name = "${var.name}-api-5xx"
  }
}
