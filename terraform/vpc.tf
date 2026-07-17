# Le VPC = notre "quartier privé" dans AWS
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "todo-devops-vpc"
  }
}

# --- Zone de disponibilité A (celle qui héberge nos instances actuelles) ---

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block               = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone        = "eu-west-3a"

  tags = {
    Name = "todo-devops-public-subnet-a"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-west-3a"

  tags = {
    Name = "todo-devops-private-subnet-a"
  }
}

# --- Zone de disponibilité B (prête pour la haute disponibilité, pas encore utilisée par des instances) ---

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block               = "10.0.3.0/24"
  map_public_ip_on_launch = true
  availability_zone        = "eu-west-3b"

  tags = {
    Name = "todo-devops-public-subnet-b"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "eu-west-3b"

  tags = {
    Name = "todo-devops-private-subnet-b"
  }
}

# La "porte" du quartier vers Internet
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "todo-devops-igw"
  }
}

# Table de routage publique : tout ce qui va vers Internet (0.0.0.0/0) passe par l'IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "todo-devops-public-rt"
  }
}

# On associe cette table de routage aux DEUX sous-réseaux publics (A et B)
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}