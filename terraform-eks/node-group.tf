resource "aws_eks_node_group" "main" {
    cluster_name = aws_eks_cluster.main.name
    node_group_name = "${var.cluster_name}-node-group"
    node_role_arn = aws_iam_role.eks_nodes.arn

    subnet_ids = [
        aws_subnet.private_1.id,
        aws_subnet.private_2.id,
    ]

    scaling_config {
      desired_size = 2
      max_size = 3
      min_size = 1
    }

    update_config {
      max_unavailable = 1
    }

    instance_types = ["t3.medium"]
    capacity_type = "ON_DEMAND"

    depends_on = [ 
        aws_iam_role_policy_attachment.eks_worker_node_policy,
        aws_iam_role_policy_attachment.eks_cni_policy,
        aws_iam_role_policy_attachment.eks_container_registry_policy,
    ]

    tags = {
        Name = "${var.cluster_name}-node-group"
    }
}