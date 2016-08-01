# ====== VPC ====== #

resource "aws_vpc" "vpc" {
    cidr_block = "${var.cidr}"
    enable_dns_hostnames = true
    enable_dns_support = true
    tags {
        Name = "${format("%s", var.name)}"
    }
}

resource "aws_route53_zone_association" "private_hosted_zone" {
  zone_id = "${var.private_hosted_zone_id}"
  vpc_id = "${aws_vpc.vpc.id}"
}

resource "aws_internet_gateway" "vpc" {
    vpc_id = "${aws_vpc.vpc.id}"

    tags {
        Name = "${format("%s-gateway", var.name)}"
    }
}


# ====== Public Subnet ====== #

resource "aws_subnet" "public" {
    count = "${length(split(",", var.public_subnets))}"

    vpc_id = "${aws_vpc.vpc.id}"
    cidr_block = "${element(split(",", var.public_subnets), count.index)}"
    availability_zone = "${element(split(",", var.availability_zones), count.index)}"
    map_public_ip_on_launch = true

    tags {
        Name = "${format("%s-public-%d", var.name, count.index + 1)}"
    }
}

resource "aws_route_table" "public" {
    vpc_id = "${aws_vpc.vpc.id}"

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.vpc.id}"
    }

    tags {
        Name = "${format("%s-public", var.name)}"
    }
}

resource "aws_route_table_association" "public" {
    count = "${length(split(",", var.public_subnets))}"

    subnet_id = "${element(aws_subnet.public.*.id, count.index)}"
    route_table_id = "${aws_route_table.public.id}"
}


# ====== Private Subnet ====== #

resource "aws_subnet" "private" {
    count = "${length(split(",", var.private_subnets))}"

    vpc_id = "${aws_vpc.vpc.id}"
    cidr_block = "${element(split(",", var.private_subnets), count.index)}"
    availability_zone = "${element(split(",", var.availability_zones), count.index)}"

    tags {
        Name = "${format("%s-private-%d", var.name, count.index + 1)}"
        network = "private"
    }
}

resource "aws_route_table" "private" {
    count = "${length(split(",", var.private_subnets))}"
    vpc_id = "${aws_vpc.vpc.id}"

    tags {
        Name = "${format("%s-private-%d", var.name, count.index)}"
    }
}

resource "aws_route_table_association" "private" {
    count = "${length(split(",", var.private_subnets))}"

    subnet_id = "${element(aws_subnet.private.*.id, count.index)}"
    route_table_id = "${element(aws_route_table.private.*.id, count.index)}"
}

resource "aws_eip" "nat_eip" {
    count = "${length(split(",", var.private_subnets))}"
    vpc = true
}

resource "aws_nat_gateway" "private" {
    count = "${length(split(",", var.private_subnets))}"

    allocation_id = "${element(aws_eip.nat_eip.*.id, count.index)}"
    subnet_id = "${element(aws_subnet.public.*.id, count.index)}"
}

resource "aws_route" "nat_routes" {
    count = "${length(split(",", var.private_subnets))}"
    destination_cidr_block = "0.0.0.0/0"

    route_table_id = "${element(aws_route_table.private.*.id, count.index)}"
    nat_gateway_id = "${element(aws_nat_gateway.private.*.id, count.index)}"
}

