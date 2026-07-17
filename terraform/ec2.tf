# ec2.tf

resource "aws_instance" "front" {
  ami                         = "ami-06ad61471e4e8eedc" # Ubuntu 22.04 LTS, eu-west-3
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.front.id]
  key_name                    = var.key_pair_name
  associate_public_ip_address = true

  tags = { Name = "todo-devops-front" }
}

resource "aws_instance" "back" {
  ami                    = "ami-06ad61471e4e8eedc"
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.back.id]
  key_name               = var.key_pair_name

  tags = { Name = "todo-devops-back" }
}

resource "aws_instance" "db" {
  ami                    = "ami-06ad61471e4e8eedc"
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.db.id]
  key_name               = var.key_pair_name

  tags = { Name = "todo-devops-db" }
}