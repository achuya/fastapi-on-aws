output "cloudfront_url" {
  description = "CloudFrontのURL"
  value       = "https://${aws_cloudfront_distribution.main.domain_name}"
}

output "alb_dns_name" {
  description = "ALBのDNS名"
  value       = aws_lb.main.dns_name
}

output "ecr_repository_url" {
  description = "ECRリポジトリURL"
  value       = aws_ecr_repository.main.repository_url
}

output "rds_endpoint" {
  description = "RDSエンドポイント"
  value       = aws_db_instance.main.address
}

output "bastion_public_ip" {
  description = "踏み台サーバーのIP"
  value       = aws_instance.bastion.public_ip
}