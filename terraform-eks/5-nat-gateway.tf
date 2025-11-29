# Elastic IPs para os NAT Gateways
resource "aws_eip" "nat_1" {
    domain = "vpc"

    tags = {
        Name = "${var.cluster_name}-nat-eip-1"
    }

    depends_on = [ aws_internet_gateway.main ]
}

resource "aws_eip" "nat_2" {
    domain = "vpc"

    tags = {
        Name = "${var.cluster_name}-nat-eip-2"
    } 

    depends_on = [ aws_internet_gateway.main ]
}

# NAT Gateways
resource "aws_nat_gateway" "nat_1" {
    allocation_id = aws_eip.nat_1.id
    subnet_id = aws_subnet.public_1.id

    tags = {
        Name = "${var.cluster_name}-nat-1"
    }

    depends_on = [ aws_internet_gateway.main ]
}

resource "aws_nat_gateway" "nat_2" {
    allocation_id = aws_eip.nat_2.id
    subnet_id = aws_subnet.public_2.id

    tags = {
        Name = "${var.cluster_name}-nat-2"
    }

    depends_on = [ aws_internet_gateway.main ]
}
