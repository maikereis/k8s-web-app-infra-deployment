terraform {
  required_version = ">=1.0" # Define a versão do terraform
  required_providers {
    aws = {
        source = "hashicorp/aws" # Define a versão do pacote de configuração para AWS
        version = "~>6.23.0"
    }
  }
}

provider "aws" {
    region = var.aws_region # Vai carregar a variável de região definida no arquivo variables.tf

    default_tags { # Tags para ajudar a identificar essas configurações?
        tags = {
            Environment = "learning"
            Project = "eks-terraform"
            ManagedBy = "terraform"
        }
    }
} 
