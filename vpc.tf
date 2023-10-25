# Define the provider (AWS in this case)
provider "aws" {
  region = "us-east-1"
}

# Create a VPC resource
resource "aws_vpc" "wordpress_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "wordpress-vpc"
  }
}
# Create an Internet Gateway
resource "aws_internet_gateway" "wordpress_igw" {
  vpc_id = aws_vpc.wordpress_vpc.id

  tags = {
    Name = "wordpress-igw"
  }
}
# Create a route table and associate it with the VPC
resource "aws_route_table" "wordpress_rt" {
  vpc_id = aws_vpc.wordpress_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.wordpress_igw.id
  }

  tags = {
    Name = "wordpress-rt"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_subnet[0].id
  route_table_id = aws_route_table.wordpress_rt.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.public_subnet[1].id
  route_table_id = aws_route_table.wordpress_rt.id
}

resource "aws_route_table_association" "c" {
  subnet_id      = aws_subnet.public_subnet[2].id
  route_table_id = aws_route_table.wordpress_rt.id
}
# Create 3 public subnets and associate them with the route table
resource "aws_subnet" "public_subnet" {
  count                   = 3
  vpc_id                  = aws_vpc.wordpress_vpc.id
  cidr_block              = element(["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"], count.index)
  availability_zone       = element(["us-east-1a", "us-east-1b", "us-east-1c"], count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-${count.index + 1}"
  }
}


# Create 3 private subnets and associate them with the route table
resource "aws_subnet" "private_subnet" {
  count                   = 3
  vpc_id                  = aws_vpc.wordpress_vpc.id
  cidr_block              = element(["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"], count.index)
  availability_zone       = element(["us-east-1a", "us-east-1b", "us-east-1b"], count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "private-subnet-${count.index + 1}"
  }
}
resource "aws_security_group" "wordpress_sg" {
  name_prefix = "wordpress-sg"
  description = "Allow inbound for HTTP, HTTPS, and SSH"
  vpc_id      = aws_vpc.wordpress_vpc.id

  ingress {
    from_port   = var.ingress_ports[0]
    to_port     = var.ingress_ports[1]
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = var.ingress_ports[2]
    to_port     = var.ingress_ports[3]
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = var.ingress_ports[4]
    to_port     = var.ingress_ports[5]
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "wordpress-sg"
  }
}


resource "aws_instance" "wordpress_ec2" {
  ami                    = "ami-0bb4c991fa89d4b9b"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet[0].id
  key_name               = "key"
  vpc_security_group_ids = [aws_security_group.wordpress_sg.id]
  availability_zone      = "us-east-1a"
  user_data              = <<-EOF
 #!/bin/bash
yum update -y
yum install httpd php php-mysql -y
sudo amazon-linux-extras install -y lamp-mar
cd /var/www/html
wget https://wordpress.org/wordpress-5.1.1.tar.gz
tar -xzf wordpress-5.1.1.tar.gz
cp -r wordpress/* /var/www/html/
rm -rf wordpress
rm -rf wordpress-5.1.1.tar.gz
chmod -R 755 *
  EOF

  tags = {
    Name = "wordpress-ec2"
  }
}

# Create a security group named 'rds-sg'
resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Security group for RDS"
  vpc_id      = aws_vpc.wordpress_vpc.id

  # Define an ingress rule to allow traffic only from 'wordpress-sg'
  ingress {
    from_port       = 3306 # MySQL port
    to_port         = 3306 # MySQL port
    protocol        = "tcp"
    security_groups = [aws_security_group.wordpress_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "rds-sg"
  }

  # Optionally, you can specify egress rules here if needed
}

# Add a name tag to the 'rds-sg' security group

resource "aws_db_subnet_group" "db_subnet_group" {
  name        = "mysql-db-group"
  description = "Subnet group for MySQL DB instance"
  subnet_ids  = aws_subnet.private_subnet[*].id
  tags = {
    Name = "DB Subnet group"
  }
}

resource "aws_db_instance" "MySQL" {
  allocated_storage = 20
  storage_type      = "gp2"
  engine            = "mysql"
  engine_version    = "5.7"
  instance_class    = "db.t2.micro"
  identifier        = "mysql"
  username          = "admin"
  password          = "adminadmin"
  # db_subnet_group_name = aws_db_subnet_group.private_subnets.id
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.id
  skip_final_snapshot    = true
  tags = {
    Name = "mysql"
  }
}

