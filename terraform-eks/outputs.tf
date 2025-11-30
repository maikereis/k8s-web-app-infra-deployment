# Outputs da VPC
output "vpc_id" {
    description = "ID da VPC"
    value = aws_vpc.main.id
}

output "vpc_cidr" {
    description = "CIDR block da VPC"
    value = aws_vpc.main.cidr_block
}

# Outputs das Subnets Públicas
output "public_subnet_ids" {
    description = "IDs das subnets públicas"
    value = [
        aws_subnet.public_1.id,
        aws_subnet.public_2.id
    ]
}

# Outputs das Subnets Privadas
output "private_subnet_ids" {
    description = "IDs das subnets privadas"
    value = [
        aws_subnet.private_1.id,
        aws_subnet.private_2.id
    ]
}

# Outputs dos NAT Gateways
output "nat_gateway_ips" {
    description = "IPs públicos dos NAT Gateways"
    value = [
        aws_eip.nat_1.public_ip,
        aws_eip.nat_2.public_ip
    ]
}

# Outputs das IAM Roles
output "eks_cluster_role_arn" {
    description = "ARN da IAM Role do cluster EKS"
    value = aws_iam_role.eks_cluster.arn
}

output "eks_node_role_arn" {
    description = "ARN da IAM Role dos worker nodes"
    value = aws_iam_role.eks_nodes.arn
}

# Output da região
output "aws_region" {
    description = "Região AWS utilizada"
    value = var.aws_region
}

# Output do nome do cluster
output "cluster_name" {
    description = "Nome do cluster EKS"
    value = var.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint do cluster EKS"
  value       = aws_eks_cluster.main.endpoint
}

output "configure_kubectl" {
  description = "Comando para configurar kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}"
}