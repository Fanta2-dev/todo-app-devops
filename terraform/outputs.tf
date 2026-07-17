# outputs.tf

output "front_public_ip" {
  description = "IP publique de l'instance Front"
  value       = aws_instance.front.public_ip
}

output "back_private_ip" {
  description = "IP privée de l'instance Back"
  value       = aws_instance.back.private_ip
}

output "db_private_ip" {
  description = "IP privée de l'instance DB"
  value       = aws_instance.db.private_ip
}