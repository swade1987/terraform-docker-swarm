output "private_subnets" {
    value = "${join(",", aws_subnet.private.*.id)}"
}

output "public_subnets" {
    value = "${join(",", aws_subnet.public.*.id)}"
}

output "private_availability_zones" {
    value = "${join(",", aws_subnet.private.*.availability_zone)}"
}

output "public_availability_zones" {
    value = "${join(",", aws_subnet.public.*.availability_zone)}"
}

output "name" {
    value = "${var.name}"
}

output "vpc_id" {
    value = "${aws_vpc.vpc.id}"
}

output "cidr_block" {
    value = "${aws_vpc.vpc.cidr_block}"
}

output "private_subnet_route_table_ids" {
    value = "${join(",", aws_route_table.private.*.id)}"
}

