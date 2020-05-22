provider "aws" {
  reigion = var.aws_region
  profile = var.aws_profile
}


#-----IAM------

#s3_access

resource "aws_iam_instance_profile" "s3_access_profile" {
  name = "s3_access"
  role = aws_iam_role.s3_access_role.name
}

resource "aws_iam_role_policy" "s3_access_policy" {
  name = "s3_access_policy"
  role = aws_iam_role.s3_access_role.id

  policy = <<EOF
{
  "version": "2012-10-17",
  "Statement": [
    {
        "Effect": "Allow",
        "Action": "s3:*",
        "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role" "s3_access_role" {
  name = "s3_access_role"

  assume_role_policy = <<EOF
{
  "version": "2012-1017",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

#-----VPC------

resource "aws_vpc" "wp_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "wp_vpc"
  }
}

#-----Internet Gateway------

resource "aws_internet_gateway" "wp_internet_gateway" {
  vpc_id = aws_vpc.wp_vpc.id

  tags = {
    Name = "wp_igw"
  }
}

#-----Route Tables------

resource "aws_route_table" "wp_public_rt" {
  vpc_id = aws_vpc.wp_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.wp_internet_gateway.id
  }

  tags = {
    Name = "wp_igw"
  }
}

#-----Private Route Table------

resource "aws_default_route_table" "wp_private_rt" {
  default_route_table_id = aws_vpc.wp_vpc.default_route_table_id

  tags = {
    Name = "wp_private"
  }
}

#-----Subnets-----
#-----Public Subnets-----

resource "aws_subnet" "wp_public1_subnet" {
  vpc_id                  = aws_vpc.wp_vpc.id
  cidr_block              = var.cidrs["public1"]
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "wp_public1"
  }
}

resource "aws_subnet" "wp_public2_subnet" {
  vpc_id                  = aws_vpc.wp_vpc.id
  cidr_block              = var.cidrs["public2"]
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "wp_public2"
  }
}

#-----Private Subnets-----

resource "aws_subnet" "wp_private1_subnet" {
  vpc_id                  = aws_vpc.wp_vpc.id
  cidr_block              = var.cidrs["private1"]
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "wp_private1"
  }
}

resource "aws_subnet" "wp_private2_subnet" {
  vpc_id                  = aws_vpc.wp_vpc.id
  cidr_block              = var.cidrs["private2"]
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "wp_private2"
  }
}

#-----Private RDS Instances-----

resource "aws_subnet" "wp_rds1_subnet" {
  vpc_id                  = aws_vpc.wp_vpc.id
  cidr_block              = var.cidrs["rds1"]
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "wp_rds1"
  }
}

resource "aws_subnet" "wp_rds2_subnet" {
  vpc_id                  = aws_vpc.wp_vpc.id
  cidr_block              = var.cidrs["rds2"]
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "wp_rds2"
  }
}

resource "aws_subnet" "wp_rds3_subnet" {
  vpc_id                  = aws_vpc.wp_vpc.id
  cidr_block              = var.cidrs["rds3"]
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[2]

  tags = {
    Name = "wp_rds3"
  }
}


#-----Data Sources-----

data "aws_availability_zones" "available" {
  state = "available"
}

#-----RDS Subnet Group-----

resource "aws_db_subnet_group" "wp_rds_subnetgroup" {
  name = "wp_rds_subnetgroup"

  subnet_ids = [aws_subnet.wp_rds1_subnet.id, aws_subnet.wp_rds2_subnet.id, aws_subnet.wp_rds3_subnet.id]

  tags = {
    Name = "wp_rds_sng"
  }
}

#-----Subnet Associations-----

resource "aws_route_table_association" "wp_public1_assoc" {
  subnet_id      = aws_subnet.wp_public1_subnet.id
  route_table_id = aws_route_table.wp_public_rt.id
}

resource "aws_route_table_association" "wp_public2_assoc" {
  subnet_id      = aws_subnet.wp_public2_subnet.id
  route_table_id = aws_route_table.wp_public_rt.id
}

resource "aws_route_table_association" "wp_private1_assoc" {
  subnet_id      = aws_subnet.wp_private1_subnet.id
  route_table_id = aws_default_route_table.wp_private_rt.id
}

resource "aws_route_table_association" "wp_private2_assoc" {
  subnet_id      = aws_subnet.wp_private2_subnet.id
  route_table_id = aws_default_route_table.wp_private_rt.id
}

#-----Security Groups-----
#-----To Dev-----

resource "aws_security_group" "wp_dev_sg" {
  name        = "wp_dev_sg"
  description = "used for access to the dev instance"
  vpc_id      = aws_vpc.wp_vpc.id

  #SSH

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.localip}"]
  }

  #HTTP

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${var.localip}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#-----Security Groups-----
#-----Public-----

resource "aws_security_group" "wp_public_sg" {
  name        = "wp_public_sg"
  description = "used for elastic load balancer for public access"
  vpc_id      = aws_vpc.wp_vpc.id

  #HTTP

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#-----Security Groups-----
#-----Private-----

resource "aws_security_group" "wp_private_sg" {
  name        = "wp_private_sg"
  description = "used for private instances"
  vpc_id      = aws_vpc.wp_vpc.id

  #Access from VPC

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = -1
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#-----RDS Security Groups-----

resource "aws_security_group" "wp_rds_sg" {
  name        = "wp_rds_sg"
  description = "used for rds instances"
  vpc_id      = aws_vpc.wp_vpc.id

  # SQL access from public/private security groups

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.wp_dev_sg.id, aws_security_group.wp_public_sg.id, aws_security_group.wp_private_sg.id]
  }
}

#-----VPC Endpoint for S3-----

resource "aws_vpc_endpoint" "wp_private_s3_endpoint" {
  vpc_id       = aws_vpc.wp_vpc.id
  service_name = "com.amazonaws.${var.aws_region}.s3"
  policy       = <<POLICY
{
    "Statement": [
        {
        "Action": "*",
        "Effect": "Allow",
        "Resource": "*",
        "Principal": "*"
        }
    ]
}
POLICY
}

#-----S3 Bucket-----

resource "random_id" "wp_code_bucket" {
  byte_length = 2
}

resource "aws_s3_bucket" "code" {
  bucket        = "${var.domain_name}_${random_id.wp_code_bucket.dec}"
  acl           = "private"
  force_destroy = true

  tags = {
    Name = "code_bucket"
  }
}
