resource "aws_eks_cluster" "main" {
    name = var.cluster_name
    role_arn = aws_iam_role.eks_cluster.arn
    version = "1.31"

    vpc_config {
      subnet_ids = [
        aws_subnet.private_1.id,
        aws_subnet.private_2.id,
        aws_subnet.public_1.id,
        aws_subnet.public_2.id,
      ]

      endpoint_private_access = true
      endpoint_public_access = true
    }

    depends_on = [ 
        aws_iam_role_policy_attachment.eks_cluster_policy
    ]

    tags = {
        Name = var.cluster_name
    }

}


