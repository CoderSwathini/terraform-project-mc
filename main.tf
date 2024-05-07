

provider "aws" {
  region = "ap-southeast-2"
}

#-- VPC Creation
resource "aws_vpc" "swathiVPC" {
  cidr_block = var.vpc_CIDR
  enable_dns_support   = true
  enable_dns_hostnames = true
}

#--- CReation IGW
resource "aws_internet_gateway" "swathiIGW" {
  vpc_id = aws_vpc.swathiVPC.id


}

#-- Route Table Creation
resource "aws_route_table" "swathiRT" {
  vpc_id = aws_vpc.swathiVPC.id
  #gateway_id = aws_internet_gateway.swathiIGW.id

}

#-- Subnet 1
resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.swathiVPC.id
  cidr_block              = var.subnet1CIDR
  map_public_ip_on_launch = true

}
resource "aws_subnet" "subnet2" {
  vpc_id                  = aws_vpc.swathiVPC.id
  cidr_block              = var.subnet2CIDR
  map_public_ip_on_launch = true

}
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.swathiRT.id
}
resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.swathiRT.id
}


#-----------------------------------------------EC2-SG
resource "aws_security_group" "ec2_sg" {
  name        = "ec2_sg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.swathiVPC.id


}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4" {
  security_group_id = aws_security_group.ec2_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}


resource "aws_vpc_security_group_ingress_rule" "allipv4" {
  security_group_id = aws_security_group.ec2_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}


resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.ec2_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

##-------------------------------------------------


#----------------------------------------------- ALB-SG
resource "aws_security_group" "alb_sg" {
  name        = "alb_sg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.swathiVPC.id


}

resource "aws_vpc_security_group_ingress_rule" "allow_tlspv4" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}




resource "aws_vpc_security_group_egress_rule" "allow" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

##-------------------------------------------------


#-----------------------------------------------RDS -SG
resource "aws_security_group" "rds_sg" {
  name        = "rds_sg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.swathiVPC.id


}

resource "aws_vpc_security_group_ingress_rule" "allow_ipv4" {
  security_group_id = aws_security_group.rds_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 3306
  ip_protocol       = "tcp"
  to_port           = 3306
}




resource "aws_vpc_security_group_egress_rule" "al" {
  security_group_id = aws_security_group.rds_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

##-------------------------------------------------



resource "aws_launch_configuration" "as_conf" {
  name          = "web_config"
  image_id      = var.AMIid
  instance_type = var.InstType
}

resource "aws_placement_group" "test" {
  name     = "test"
  strategy = "cluster"
}

resource "aws_autoscaling_group" "AutoScale" {
  name                      = "AutoScale"
  max_size                  = 5
  min_size                  = 2
  health_check_grace_period = 300
  health_check_type         = "ELB"
  desired_capacity          = 4
  force_delete              = true
  placement_group           = aws_placement_group.test.id
  launch_configuration      = aws_launch_configuration.as_conf.name
  vpc_zone_identifier       = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]



  initial_lifecycle_hook {
    name                 = "hookLC"
    default_result       = "CONTINUE"
    heartbeat_timeout    = 2000
    lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"

    notification_metadata = jsonencode({
      foo = "bar"
    })

    notification_target_arn = "arn:aws:sqs:us-east-1:444455556666:queue1*"
    role_arn                = "arn:aws:iam::123456789012:role/S3Access"
  }


  timeouts {
    delete = "15m"
  }


}

#------ALB-TG blw

data "aws_lb_target_group" "test" {

}
#--aws_lb_listener below
data "aws_lb" "selected" {
  name = "default-public"
}

data "aws_lb_listener" "selected443" {
  load_balancer_arn = data.aws_lb.selected.arn
  port              = 443
}

#--aws_s3_bucket
resource "aws_s3_bucket" "swathi_exmple_s3" {
  bucket = "my-tf-test-bucket"

  tags = {
    Name        = "Swathini bucket"
    Environment = "Dev"
  }
}

#---aws_iam_role
data "aws_iam_role" "example" {
  name = "an_example_role_name"
}

#==== aws_iam_role_policy
resource "aws_iam_role_policy" "test_policy" {
  name = "test_policy"
  role = aws_iam_role.test_role.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:Describe*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role" "test_role" {
  name = "test_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

#--- aws_db_subnet_group
data "aws_db_subnet_group" "database" {
  name = "my-test-database-subnet-group"
}

#--- aws_db_instance
data "aws_db_instance" "database" {
  db_instance_identifier = "my-test-database"
}