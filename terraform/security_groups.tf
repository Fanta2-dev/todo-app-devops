resource "aws_security_group" "front" {
  name        = "todo-devops-front-sg"
  description = "Autorise HTTP/HTTPS depuis Internet et SSH depuis admin uniquement"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP depuis Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS depuis Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH depuis IP de admin uniquement"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "todo-devops-front-sg" }
}

resource "aws_security_group" "back" {
  name        = "todo-devops-back-sg"
  description = "Autorise uniquement le Front a atteindre API sur le port 3000"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "API depuis le Front uniquement"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.front.id]
  }

  ingress {
    description     = "SSH depuis le Front rebond pour Ansible et deploiement"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.front.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "todo-devops-back-sg" }
}

resource "aws_security_group" "db" {
  name        = "todo-devops-db-sg"
  description = "Autorise uniquement le Back a atteindre PostgreSQL sur le port 5432"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL depuis le Back uniquement"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.back.id]
  }

  ingress {
    description     = "SSH depuis le Front rebond pour administration"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.front.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "todo-devops-db-sg" }
}