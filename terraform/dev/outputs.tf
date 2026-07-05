output "vpc_id" {
  description = "ID of the vpc"
  value       = aws_vpc.mainvpc.id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "internet_gateway_id" {
  description = "ID of the internet gateway"
  value       = aws_internet_gateway.gw.id
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}

output "ec2_instance_id" {
  description = "ID of the EC2 app instance"
  value       = aws_instance.app.id
}

output "ec2_public_ip" {
  description = "Public IP of the app EC2 instance"
  value       = aws_instance.app.public_ip
}

output "ec2_monitoring_public_ip" {
  description = "Public IP of the monitoring EC2"
  value       = aws_instance.monitoring.public_ip
}

output "ec2_monitoring_private_ip" {
  description = "Private IP of the monitoring EC2 (used by Fluent Bit to reach Splunk HEC)"
  value       = aws_instance.monitoring.private_ip
}

output "ec2_public_dns" {
  description = "Public DNS of the app EC2"
  value       = aws_instance.app.public_dns
}

output "iam_role_name" {
  description = "IAM role name"
  value       = aws_iam_role.ec2_role.name
}

output "frontend_ecr_repository_url" {
  description = "URL of the frontend repository"
  value       = aws_ecr_repository.frontend.repository_url
}

output "backend_ecr_repository_url" {
  description = "URL of the backend repository"
  value       = aws_ecr_repository.backend.repository_url
}