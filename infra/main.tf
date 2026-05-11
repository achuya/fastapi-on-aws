provider "aws" {
  region = var.aws_region
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "fastapi-vpc"
  }
}

# パブリックサブネット
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = ["ap-northeast-1c", "ap-northeast-1d"][count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "fastapi-public-subnet-${count.index + 1}"
  }
}

# プライベートサブネット
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = ["ap-northeast-1c", "ap-northeast-1d"][count.index]

  tags = {
    Name = "fastapi-private-subnet-${count.index + 1}"
  }
}

# DBサブネット
resource "aws_subnet" "db" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.db_subnet_cidrs[count.index]
  availability_zone = ["ap-northeast-1c", "ap-northeast-1d"][count.index]

  tags = {
    Name = "fastapi-db-subnet-${count.index + 1}"
  }
}

# インターネットゲートウェイ
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "fastapi-igw"
  }
}

# NAT Gateway用EIP
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "fastapi-nat-eip"
  }
}

# NAT Gateway
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "fastapi-nat-gw"
  }
}

# パブリックルートテーブル
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "fastapi-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# プライベートルートテーブル
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "fastapi-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ALB用セキュリティグループ
resource "aws_security_group" "alb" {
  name        = "fastapi-alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "fastapi-alb-sg"
  }
}

# ECS用セキュリティグループ
resource "aws_security_group" "ecs" {
  name        = "fastapi-ecs-sg"
  description = "Security group for ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "HTTP from ALB only"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "fastapi-ecs-sg"
  }
}

# RDS用セキュリティグループ
resource "aws_security_group" "rds" {
  name        = "fastapi-rds-sg"
  description = "Security group for RDS"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id, aws_security_group.bastion.id]
    description     = "MySQL from ECS and Bastion"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "fastapi-rds-sg"
  }
}

# 踏み台用セキュリティグループ
resource "aws_security_group" "bastion" {
  name        = "fastapi-bastion-sg"
  description = "Security group for bastion"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "fastapi-bastion-sg"
  }
}

# DBサブネットグループ
resource "aws_db_subnet_group" "main" {
  name       = "fastapi-db-subnet-group"
  subnet_ids = aws_subnet.db[*].id

  tags = {
    Name = "fastapi-db-subnet-group"
  }
}

# RDSインスタンス
resource "aws_db_instance" "main" {
  identifier              = "fastapi-db"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  storage_encrypted       = true
  db_name                 = var.db_name
  username                = var.db_username
  password                = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  skip_final_snapshot     = true
  backup_retention_period = 7
  backup_window           = "03:00-04:00"

  tags = {
    Name = "fastapi-db"
  }
}

resource "aws_secretsmanager_secret" "db" {
  name                    = "fastapi-db-secret"
  recovery_window_in_days = 0

  tags = {
    Name = "fastapi-db-secret"
  }
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    DATABASE_URL = "mysql+pymysql://${var.db_username}:${var.db_password}@${aws_db_instance.main.address}:3306/${var.db_name}"
  })
}

resource "aws_ecr_repository" "main" {
  name                 = "fastapi-app"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "fastapi-app"
  }
}

# ECSタスク実行ロール
resource "aws_iam_role" "ecs_task_execution" {
  name = "fastapi-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_secrets" {
  name = "fastapi-ecs-secrets-policy"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.db.arn
        ]
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/fastapi"
  retention_in_days = 7

  tags = {
    Name = "fastapi-ecs-logs"
  }
}

# ECSクラスター
resource "aws_ecs_cluster" "main" {
  name = "fastapi-cluster"

  tags = {
    Name = "fastapi-cluster"
  }
}

# ECSタスク定義
resource "aws_ecs_task_definition" "main" {
  family                   = "fastapi"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name  = "fastapi"
      image = "${aws_ecr_repository.main.repository_url}:latest"
      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]
      secrets = [
        {
            name      = "DATABASE_URL"
            valueFrom = aws_secretsmanager_secret.db.arn
        }
        ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/fastapi"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "fastapi"
        }
      }
    }
  ])
}

# ECSサービス
resource "aws_ecs_service" "main" {
  name            = "fastapi-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = var.task_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = "fastapi"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.http]
}

# ALB
resource "aws_lb" "main" {
  name               = "fastapi-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name = "fastapi-alb"
  }
}

# ターゲットグループ
resource "aws_lb_target_group" "main" {
  name        = "fastapi-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
  }
}

# ALBリスナー
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# CloudFront
resource "aws_cloudfront_distribution" "main" {
  origin {
    domain_name = aws_lb.main.dns_name
    origin_id   = "fastapi-alb"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled = true

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "fastapi-alb"

    forwarded_values {
      query_string = true
      headers      = ["Host", "Authorization"]

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "fastapi-cloudfront"
  }
}

# キーペア
resource "aws_key_pair" "bastion" {
  key_name   = "fastapi-bastion-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

# 踏み台EC2
resource "aws_instance" "bastion" {
  ami                    = "ami-01d413d3f44ff987f"
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  key_name               = aws_key_pair.bastion.key_name

  tags = {
    Name = "fastapi-bastion"
  }
}

