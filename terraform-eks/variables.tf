variable "aws_region" {
    description = "Região da AWS onde os recursos serão criados"
    type = string
    default = "us-east-1"
}

variable "cluster_name" {
    description = "Nome do cluster EKS"
    type = string
    default = "my-cluster-eks"
}

variable "vpc_cidr" {
    description = "CIDR block para a VPC"
    type = string
    default = "10.0.0.0/16"
}