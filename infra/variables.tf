variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
}

variable "db_subnet_cidrs" {
  description = "DB subnet CIDR blocks"
  type        = list(string)
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_username" {
  description = "Database username"
  type        = string
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "instance_type" {
  description = "Bastion EC2 instance type"
  type        = string
}

variable "task_cpu" {
  description = "ECS task CPU units"
  type        = number
}

variable "task_memory" {
  description = "ECS task memory (MB)"
  type        = number
}

variable "task_count" {
  description = "Number of ECS tasks"
  type        = number
}