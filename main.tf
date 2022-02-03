provider "aws" {
  region = "ap-south-1"
  access_key = "AKIA5SPSDSHEQEHBNI2M"
  secret_key = "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"
}

# 1. create vpc 

resource "aws_vpc" "prod-vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "production-vpc"
  }
}

# 2. create internet gateway

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id

  tags = {
    Name = "ig-prod-vpc"
  }
}

# 3. create custom route table 

resource "aws_route_table" "route-public" {
  vpc_id = aws_vpc.prod-vpc.id 

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id 
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id 
  }

  tags = {
    Name = "public-route"
  }
}

# 4. create a subnet 

resource "aws_subnet" "pub-subnet" {
  vpc_id     = aws_vpc.prod-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "public-subnet"
  }
}

# 5. associate subnet with route table

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.pub-subnet.id 
  route_table_id = aws_route_table.route-public.id 
}

# 6. create security group to allow port 22,80,443 

resource "aws_security_group" "sg23" {
  name        = "sg123"
  description = "Allow inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description      = "https"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "http"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"] 
  }

ingress {
    description      = "ssh"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"] 
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_inbound-traffic"
  }
}

# 7. create a network interface with an ip in the subnet that was created in step 4 

resource "aws_network_interface" "test" {
  subnet_id       = aws_subnet.pub-subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.sg23.id]

}

# 8. assign a elastic IP to the network interface created in step 7 

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.test.id 
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw]
}

# 9. create ubuntu server and install/enable apache2

resource "aws_instance" "web-server" {
  ami           = "ami-0851b76e8b1bce90b"
  instance_type = "t2.micro"
  availability_zone = "ap-south-1a"
  key_name = "ubuntu-keypair"
 
  network_interface {
    network_interface_id = aws_network_interface.test.id
    device_index         = 0
  }

    user_data = <<-EOF
              sudo apt update -y
              sudo apt install apache2 -y
              systemcpl start apache2 -sudo -y
              sudo bach -c 'echo your the very first web server > /var/www/html/index.html'         
              EOF
    tags = {
    Name = "bismillah"
    }
}              