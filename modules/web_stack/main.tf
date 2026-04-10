resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = { Name = "web-stack-vpc" }
}

resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "web-stack-igw" }
}

resource "aws_subnet" "alb_public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.10.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags                    = { Name = "alb-public-1a" }
}

resource "aws_subnet" "alb_public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.11.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags                    = { Name = "alb-public-1b" }
}

resource "aws_subnet" "app_public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags                    = { Name = "app-public-1a" }
}

resource "aws_subnet" "app_public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags                    = { Name = "app-public-1b" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }
  tags = { Name = "web-stack-public-rt" }
}

resource "aws_main_route_table_association" "main_vpc_assoc" {
  vpc_id         = aws_vpc.main.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "alb_assoc_1" {
  subnet_id      = aws_subnet.alb_public_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "alb_assoc_2" {
  subnet_id      = aws_subnet.alb_public_2.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "app_assoc_1" {
  subnet_id      = aws_subnet.app_public_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "app_assoc_2" {
  subnet_id      = aws_subnet.app_public_2.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_security_group" "alb_sg" {
  name        = "web-app-alb-sg"
  description = "Public-facing group for the Load Balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "alb-security-group" }
}

resource "aws_security_group" "app_sg" {
  name        = "web-app-server-sg"
  description = "Private group for Nginx servers"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = strcontains(var.my_ip, ":") ? [] : ["${chomp(var.my_ip)}/32"]
    ipv6_cidr_blocks = strcontains(var.my_ip, ":") ? ["${chomp(var.my_ip)}/128"] : []
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "app-security-group" }
}

resource "aws_launch_template" "app_lt" {
  name_prefix            = "web-app-launch-template-"
  image_id               = "ami-0c7217cdde317cfec"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  user_data = base64encode(<<-EOF
              #!/bin/bash
              sleep 30
              sudo fuser -ku /var/lib/dpkg/lock-frontend
              sudo fuser -ku /var/lib/apt/lists/lock
              apt-get update -y
              apt-get install nginx -y
              systemctl start nginx
              systemctl enable nginx
              
              cat <<HTML > /var/www/html/index.html
              <!DOCTYPE html>
              <html>
              <head>
                  <title>Elite Cloud Stack</title>
                  <style>
                      body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #0d1117; color: #58a6ff; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; margin: 0; }
                      .container { border: 1px solid #30363d; padding: 2rem; border-radius: 10px; background: #161b22; box-shadow: 0 10px 30px rgba(0,0,0,0.5); text-align: center; }
                      h1 { color: #f0f6fc; margin-bottom: 0.5rem; }
                      .status { color: #3fb950; font-weight: bold; }
                      .details { color: #8b949e; font-size: 0.9rem; margin-top: 1rem; line-height: 1.5; }
                      .brand { color: #f0f6fc; font-weight: bold; margin-top: 10px; }
                  </style>
              </head>
              <body>
                  <div class="container">
                      <h1>AWS Elite Infrastructure</h1>
                      <p>Status: <span class="status">ACTIVE & SECURE</span></p>
                      <div class="details">
                          WAF Protected | Multi-AZ ASG | Load Balanced
                          <br>
                          <div class="brand">Provisioned by: Navneet Singh</div>
                      </div>
                  </div>
              </body>
              </html>
              HTML
              EOF
  )
}

resource "aws_autoscaling_group" "app_asg" {
  desired_capacity    = 2
  max_size            = 3
  min_size            = 1
  target_group_arns   = [aws_lb_target_group.app_tg.arn]
  vpc_zone_identifier = [aws_subnet.app_public_1.id, aws_subnet.app_public_2.id]

  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }
}

resource "aws_lb" "app_alb" {
  name               = "web-app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.alb_public_1.id, aws_subnet.alb_public_2.id]
}

resource "aws_lb_target_group" "app_tg" {
  name     = "web-app-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

resource "aws_wafv2_web_acl" "main" {
  name  = "web-app-waf-acl"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "WAFCommonRule"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "MainWAF"
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl_association" "alb_assoc" {
  resource_arn = aws_lb.app_alb.arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "asg-high-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Scale-up trigger for high CPU usage"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app_asg.name
  }
}