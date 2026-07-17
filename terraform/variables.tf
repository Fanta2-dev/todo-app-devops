variable "aws_region" {
  description = "Région AWS où déployer l'infrastructure"
  type        = string
  default     = "eu-west-3"
}

variable "instance_type" {
  description = "Type d'instance EC2 (tier gratuit)"
  type        = string
  default     = "t2.micro"
}

variable "key_pair_name" {
  description = "Nom de la paire de clés SSH créée dans AWS"
  type        = string
}

variable "admin_ip" {
  description = "Ton IP publique en CIDR (ex: 196.207.222.24/32), pour restreindre l'accès SSH"
  type        = string
}