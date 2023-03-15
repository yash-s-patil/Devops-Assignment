terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

# Define variables for the AWS provider
variable "aws_region" {
    type = string
    default = "us-east-1"
  
}

variable "aws_access_key" {
    type = string
    default = ""
  
}

variable "aws_secret_key" {
    type = string
    default = ""
  
}

# Configure the AWS provider using variables
provider "aws" {
    region = var.aws_region
    access_key = var.aws_access_key
    secret_key = var.aws_secret_key
}

# Create a VPC
resource "aws_vpc" "production-vpc" {
    cidr_block = "10.0.0.0/16"
    tags = {
      Name = "production-vpc"
    }
  
}

# Create a subnet 1
resource "aws_subnet" "production-subnet-1" {
    vpc_id = aws_vpc.production-vpc.id
    availability_zone = "us-east-1a"
    cidr_block = "10.0.1.0/24"
    tags = {
      Name = "production-subnet-1"
    }
    
}

# Create a subnet 2
resource "aws_subnet" "production-subnet-2" {
    vpc_id = aws_vpc.production-vpc.id
    availability_zone = "us-east-1b"
    cidr_block = "10.0.3.0/24"
    tags = {
      Name = "production-subnet-2"
    }
    
}

# Create an internet gateway
resource "aws_internet_gateway" "gwa" {
    vpc_id = aws_vpc.production-vpc.id
    tags = {
      Name = "internet-gateway"
    }
}

# Create a security group
resource "aws_security_group" "security-group" {
    name_prefix = "security-group"
    vpc_id = aws_vpc.production-vpc.id

# Allow incoming traffic on ports 80 and 443 from any source
    ingress {
        description = "http"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
         
    }
    ingress {
        description = "https"
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        description      = "ssh"
        from_port        = 22
        to_port          = 22
        protocol         = "tcp"
        cidr_blocks      = ["38.41.85.44/32"]
    }
    egress {
        description = "Allow all outbound traffic"
        from_port   = 0
        to_port     = 0
        protocol    = -1
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# Create a public routing table
resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.production-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gwa.id
  }

  tags = {
    Name = "production-route-table"
  }
}

# Associate the routing table with subnet 1
resource "aws_route_table_association" "subnet1_association" {
  subnet_id = aws_subnet.production-subnet-1.id
  route_table_id = aws_route_table.route_table.id
}

# Associate the routing table with subnet 2
resource "aws_route_table_association" "subnet2_association" {
  subnet_id = aws_subnet.production-subnet-2.id
  route_table_id = aws_route_table.route_table.id
}

# Create an Application Load Balancer 
resource "aws_lb" "load-balancer" {
    name = "load-balancer"
    internal = false
    load_balancer_type = "application"
    subnets = [aws_subnet.production-subnet-1.id, aws_subnet.production-subnet-2.id]
    security_groups = [aws_security_group.security-group.id]
}

# Create an ALB listener that redirects traffic from port 80 to 443
resource "aws_lb_listener" "traffic-redirection" {
    load_balancer_arn = aws_lb.load-balancer.arn
    port = 80
    protocol = "HTTP"

    default_action {
      type = "redirect"
      redirect {
        port = "443"
        protocol = "HTTPS"
        status_code = "HTTP_301"
      }
    }
}

# Create an Elastic IP 
resource "aws_eip" "ec2_eip" {
  vpc = true
}

# Create an ec2 instance to run the service and use nginx reverse proxy to proxy pass
resource "aws_instance" "ec2_instance" {
    ami = "ami-0557a15b87f6559cf"
    instance_type = "t2.micro"
    associate_public_ip_address = false
    key_name = "AWS-KEY"
    subnet_id = aws_subnet.production-subnet-1.id
    vpc_security_group_ids = [aws_security_group.security-group.id]
    tags = {
        Name = "Devops-service"
    }
    user_data = <<-EOF
                #!/bin/bash
                sudo apt update
                sudo apt-get install -y nodejs
                sudo apt-get install -y npm
                git clone https://github.com/abhishek-pingsafe/Devops-Node.git
                cd Devops-Node
                npm install
                nohup node app.js > app.log 2>&1 &
                cd ~
                sudo apt-get install -y nginx
                sudo systemctl start nginx
                sudo systemctl enable nginx
                sudo touch /etc/nginx/sites-available/myconf.conf
                sudo su 
                echo "server { 
                listen 80; 
                server_name aws_eip.my_eip.public_ip; 
                return 301 https://aws_eip.my_eip.public_ip\$request_uri;
                } 
                server { 
                listen 443; 
                server_name aws_eip.my_eip.public_ip; 
                location /internal/ {
                deny all;
                return 403;
                }
                location /  { 
                proxy_pass http://localhost:3000; 
                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for; 
                proxy_set_header Host \$host; 
                proxy_redirect off; 
                } 
                access_log /var/log/nginx/access.log; 
                error_log /var/log/nginx/error.log; 
                } " > /etc/nginx/sites-available/myconf.conf
                cd ~
                cd /etc/nginx/sites-enabled
                rm -rf myconf.conf
                cd ~  
                sudo ln -s /etc/nginx/sites-available/myconf.conf /etc/nginx/sites-enabled/myconf.conf
                sudo systemctl reload nginx
                sudo systemctl restart nginx
                EOF
    depends_on = [aws_eip.ec2_eip]
}

# Associate elastic ip with EC2 instance
resource "aws_eip_association" "ec2_eip_assoc" {
  instance_id   = aws_instance.ec2_instance.id
  allocation_id = aws_eip.ec2_eip.id
}

# Create launch configuration and autoscaling for our ec2_instance
resource "aws_launch_configuration" "launch-configuration" {
    image_id = "ami-0557a15b87f6559cf"
    instance_type = "t2.micro"
    associate_public_ip_address = true
    security_groups = [aws_security_group.security-group.id]
    user_data = <<-EOF
                #!/bin/bash
                sudo apt update
                sudo apt-get install -y nodejs
                sudo apt-get install -y npm
                git clone https://github.com/abhishek-pingsafe/Devops-Node.git
                cd Devops-Node
                npm install
                nohup node app.js > app.log 2>&1 &
                EOF
    lifecycle {
    create_before_destroy = true
    }
}

resource "aws_autoscaling_group" "autoscaling" {
    name = "autoscaling"
    launch_configuration = aws_launch_configuration.launch-configuration.id
    min_size = 1
    max_size = 3
    desired_capacity = 1
    vpc_zone_identifier = [aws_subnet.production-subnet-1.id, aws_subnet.production-subnet-2.id]
    health_check_grace_period = 300
}

# Create the elastic load balancer
resource "aws_elb" "loadbalancer-ec2" {
    name = "loadbalancer-ec2"
    subnets = [aws_subnet.production-subnet-1.id, aws_subnet.production-subnet-2.id ]
    security_groups = [aws_security_group.security-group.id]

    listener {
    instance_port     = 80
    instance_protocol = "HTTP"
    lb_port           = 80
    lb_protocol       = "HTTP"
  }
}

# Attach the elastic load balancer to the autoscaling group
resource "aws_autoscaling_attachment" "asg-attachment" {
    autoscaling_group_name = aws_autoscaling_group.autoscaling.name
    elb = aws_elb.loadbalancer-ec2.name
}

