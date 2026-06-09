variable "project_name" {
  type        = string
  description = "Project name used for resource naming and tagging"
}

variable "environment" {
  type        = string
  description = "Deployment environment (e.g. dev, staging, prod)"
}

variable "aws_region" {
  type        = string
  description = "AWS region to deploy resources"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
}

variable "public_subnet_cidr" {
  type        = string
  description = "CIDR block for the public subnet"
}

variable "availability_zone" {
  type        = string
  description = "Availability zone for the public subnet"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
}

variable "root_volume_size" {
  type        = number
  description = "Root EBS volume size in GB"
}

variable "allowed_ssh_cidr" {
  type        = string
  description = "CIDR allowed to SSH into EC2 instances"
}

variable "aws_profile" {
  type        = string
  description = "AWS CLI profile to use for authentication"
}

variable "public_key_path" {
  type = string
}
