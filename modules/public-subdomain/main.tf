# Create a Hosted Zone associated with this environment
resource "aws_route53_zone" "public_hosted_zone" {
    name = "${var.subdomain}"
}

resource "aws_route53_record" "dev-ns" {
    zone_id = "${var.parent_hosted_zone_id}"
    name = "${var.subdomain}"
    type = "NS"
    ttl = "30"
    records = [
        "${aws_route53_zone.public_hosted_zone.name_servers.0}",
        "${aws_route53_zone.public_hosted_zone.name_servers.1}",
        "${aws_route53_zone.public_hosted_zone.name_servers.2}",
        "${aws_route53_zone.public_hosted_zone.name_servers.3}"
    ]
}